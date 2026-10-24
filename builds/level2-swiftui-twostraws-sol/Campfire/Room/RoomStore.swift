import SwiftUI
import CampfireKit
import Observation

@MainActor @Observable
final class RoomStore {
    private(set) var items: [MessageItem] = []
    private(set) var roomName = "General"
    private(set) var streamDone = false
    private(set) var streamRunning = false
    private(set) var newestID = 50_000
    private(set) var revision = 0
    var textSize: DynamicTypeSize = .large
    var overrideTextSize = false

    @ObservationIgnored private(set) var dataset: Dataset?
    @ObservationIgnored private(set) var all: [Message] = []
    @ObservationIgnored private var users: [UserID: User] = [:]
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var boostTask: Task<Void, Never>?
    @ObservationIgnored private let generation: Task<Dataset, Never>?
    @ObservationIgnored var beforeChange: (() -> Void)?
    @ObservationIgnored var afterChange: (() -> Void)?
    @ObservationIgnored var visibleTopID: (() -> Int?)?

    var isAtNewestPage: Bool { items.last?.id == newestID }
    var hasOlder: Bool { (items.first?.id ?? 1) > 1 }
    var hasNewer: Bool { (items.last?.id ?? newestID) < newestID }

    init(generation: Task<Dataset, Never>? = nil) { self.generation = generation }

    func load() async {
        guard dataset == nil else { return }
        // Generation is CPU work; keep the main actor free for the first frame.
        let data: Dataset
        if let generation { data = await generation.value }
        else { data = await Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }.value }
        dataset = data
        all = data.messages
        users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        roomName = data.room.name
        setWindow(Array(Windowing.lastPage(all)))
    }

    func reset() {
        streamTask?.cancel(); boostTask?.cancel()
        streamRunning = false; streamDone = false
        if let dataset { all = dataset.messages }
        newestID = all.last?.id ?? 50_000
        textSize = .large
        overrideTextSize = true
        setWindow(Array(Windowing.lastPage(all)))
    }

    func jumpTo2500() { setWindow(Array(Windowing.around(2500, in: all))) }

    func jumpToNewest() { setWindow(Array(Windowing.lastPage(all))) }

    func loadOlder(preserving anchor: MessageID?) {
        guard let first = items.first?.id, hasOlder else { revision += 1; return }
        var messages = Array(Windowing.page(before: first, in: all)) + items.map(\.message)
        if messages.count > Windowing.maxLoaded {
            let limit = max(Windowing.maxLoaded, (messages.firstIndex { $0.id == anchor } ?? 0) + Windowing.pageSize)
            messages = Array(messages.prefix(limit))
        }
        setWindow(messages)
    }

    func loadNewer(preserving anchor: MessageID?) {
        guard let last = items.last?.id, hasNewer else { return }
        var messages = items.map(\.message) + Array(Windowing.page(after: last, in: all))
        if messages.count > Windowing.maxLoaded {
            let canRemove = messages.firstIndex { $0.id == anchor } ?? messages.count
            messages.removeFirst(min(messages.count - Windowing.maxLoaded, canRemove))
        }
        setWindow(messages)
    }

    func increaseTextSize(from current: DynamicTypeSize) {
        let sizes = DynamicTypeSize.allCases
        let index = sizes.firstIndex(of: current) ?? 3
        textSize = index + 1 < sizes.count ? sizes[index + 1] : .large
        overrideTextSize = true
        revision += 1
    }

    func startStream() {
        guard !streamRunning, !streamDone, let dataset else { return }
        streamRunning = true
        streamTask = Task { [weak self] in
            for await event in FakeLiveFeed(dataset: dataset).play() {
                guard !Task.isCancelled, let self else { return }
                self.receive(event)
            }
            guard !Task.isCancelled else { return }
            self?.streamRunning = false
            self?.streamDone = true
        }
    }

    func boostBurst() {
        guard let id = all.last?.id else { return }
        boostTask?.cancel()
        boostTask = Task { [weak self] in
            for (index, emoji) in ["👍", "🎉", "🔥", "❤️", "😂"].enumerated() {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                guard let boost = self.makeBurstBoost(user: index + 2, content: emoji, target: id) else { continue }
                self.receive(.boost(messageID: id, boost))
            }
        }
    }

    private func makeBurstBoost(user: Int, content: String, target: Int) -> Boost? {
        // The unchanged package has no public Boost initializer. Reuse a matching
        // value from its deterministic dataset, keeping IDs unique in this strip.
        let used = Set(all[target - 1].boosts.map(\.id))
        return dataset?.messages.lazy.flatMap(\.boosts).first {
            $0.boosterID == user && $0.content == content && !used.contains($0.id)
        }
    }

    private func receive(_ event: FeedEvent) {
        switch event {
        case .message(let message):
            guard message.id > newestID else { return }
            let appendToWindow = isAtNewestPage
            beforeChange?()
            all.append(message)
            newestID = message.id
            if appendToWindow {
                let previous = items.last?.message
                items.append(MessageItem(message: message, previous: previous, users: users, currentUserID: 1))
                if items.count > Windowing.maxLoaded {
                    let visibleIndex = items.firstIndex { $0.id == visibleTopID?() } ?? 0
                    let removable = min(items.count - Windowing.maxLoaded, visibleIndex)
                    if removable > 0 { items.removeFirst(removable) }
                    else { items.removeLast() }
                }
            }
            revision += 1
            afterChange?()
        case .boost(let id, let boost):
            guard all.indices.contains(id - 1) else { return }
            beforeChange?()
            all[id - 1].boosts.append(boost)
            items.first { $0.id == id }?.message.boosts.append(boost)
            revision += 1
            afterChange?()
        case .typingStarted, .typingStopped:
            break
        }
    }

    private func setWindow(_ messages: [Message]) {
        let existing = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        items = messages.map { message in
            let previous = message.id > 1 ? all[message.id - 2] : nil
            if let item = existing[message.id], item.message == message { return item }
            return MessageItem(message: message, previous: previous, users: users, currentUserID: 1)
        }
        revision += 1
    }
}
