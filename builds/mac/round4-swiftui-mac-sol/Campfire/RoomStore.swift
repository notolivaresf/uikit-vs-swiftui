import SwiftUI
import CampfireKit

@MainActor @Observable
final class RoomStore {
    let dataset: Dataset
    @ObservationIgnored private(set) var history: [Message]
    let users: [Int: User]
    var messages: [Message]
    var textStep = 0
    var revision = 0
    var streamDone = false
    var streamRunning = false
    var hasNewMessages = false
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var burstTask: Task<Void, Never>?

    init() {
        let data = FakeData.generate(size: .k50)
        dataset = data
        history = data.messages
        users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        messages = Array(Windowing.lastPage(data.messages))
    }

    var scale: CGFloat { 1 + CGFloat(textStep) * 0.125 }
    func presentation(_ message: Message) -> MessagePresentation {
        let index = message.id - 1
        let previous = index > 0 && index <= history.count ? history[index - 1] : nil
        return Grouping.presentation(of: message, after: previous, currentUserID: dataset.currentUserID)
    }
    func reset() {
        streamTask?.cancel()
        burstTask?.cancel()
        streamTask = nil
        streamRunning = false
        streamDone = false
        history = dataset.messages
        messages = Array(Windowing.lastPage(history))
        textStep = 0
        hasNewMessages = false
        revision += 1
    }
    func jumpTo2500() {
        messages = Array(Windowing.around(2500, in: history))
        revision += 1
    }
    @discardableResult func loadOlder(topID: Int) -> Bool {
        guard let first = messages.first else { return false }
        let older = Windowing.page(before: first.id, in: history)
        guard !older.isEmpty else { return false }
        messages.insert(contentsOf: older, at: 0)
        if messages.count > Windowing.maxLoaded {
            // Drop the distant end only; the visible anchor is retained.
            let keep = max(Windowing.maxLoaded, (messages.firstIndex { $0.id == topID } ?? 0) + 45)
            messages = Array(messages.prefix(keep))
        }
        revision += 1
        return true
    }
    func loadNewer() {
        guard let last = messages.last, last.id < history.count else { return }
        messages.append(contentsOf: Windowing.page(after: last.id, in: history))
        if messages.count > Windowing.maxLoaded { messages.removeFirst(Windowing.pageSize) }
        revision += 1
    }
    func newest() {
        messages = Array(Windowing.lastPage(history))
        hasNewMessages = false
        revision += 1
    }
    func increaseTextSize() {
        textStep = (textStep + 1) % 5
        revision += 1
    }
    func startStream(scroll: RoomScroll) {
        guard !streamRunning else { return }
        streamRunning = true
        streamDone = false
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard !Task.isCancelled, let self else { return }
                switch event {
                case .message(let message):
                    // A completed script cannot be replayed into duplicate ids.
                    guard message.id > self.history.count else { continue }
                    self.history.append(message)
                    self.hasNewMessages = !scroll.pinned
                    if self.messages.last?.id == message.id - 1 {
                        let canTrim = self.messages.count < Windowing.maxLoaded ||
                            scroll.topID > (self.messages.first?.id ?? 0) + Windowing.pageSize
                        if canTrim {
                            scroll.preserve()
                            self.messages.append(message)
                            if self.messages.count > Windowing.maxLoaded {
                                self.messages.removeFirst(Windowing.pageSize)
                            }
                            self.revision += 1
                        }
                    }
                case .boost(let messageID, let boost):
                    self.add(boost, to: messageID, scroll: scroll)
                case .typingStarted, .typingStopped: break
                }
            }
            guard !Task.isCancelled, let self else { return }
            self.streamRunning = false
            self.streamDone = true
        }
    }
    func boostBurst(scroll: RoomScroll) {
        guard let target = history.last?.id else { return }
        burstTask?.cancel()
        // Boost has no public memberwise initializer. Reuse the exact seeded
        // package values for the five requested author/content pairs.
        let contents = ["👍", "🎉", "🔥", "❤️", "😂"]
        let allBoosts = dataset.messages.flatMap(\.boosts)
        let boosts = contents.enumerated().compactMap { index, content in
            allBoosts.first { $0.boosterID == index + 2 && $0.content == content }
        }
        burstTask = Task { [weak self] in
            for boost in boosts {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                self.add(boost, to: target, scroll: scroll)
            }
        }
    }
    private func add(_ boost: Boost, to id: Int, scroll: RoomScroll) {
        guard id > 0, id <= history.count else { return }
        history[id - 1].boosts.append(boost)
        if let index = messages.firstIndex(where: { $0.id == id }) {
            scroll.preserve()
            messages[index].boosts.append(boost)
            revision += 1
        }
    }
}
