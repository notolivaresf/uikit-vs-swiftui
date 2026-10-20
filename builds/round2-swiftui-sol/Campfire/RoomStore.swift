import SwiftUI
import Observation
import CampfireKit

@MainActor @Observable
final class ChatRow: Identifiable {
    let id: Int
    var message: Message
    let presentation: MessagePresentation
    let author: String
    let time: String
    let day: String
    let copyText: String

    init(message: Message, previous: Message?, users: [Int: User]) {
        id = message.id
        self.message = message
        presentation = Grouping.presentation(of: message, after: previous, currentUserID: 1)
        author = users[message.creatorID]?.name ?? ""
        var style = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            .locale(Locale(identifier: "en_US"))
        style.timeZone = .gmt
        time = message.createdAt.formatted(style)
        var dayStyle = Date.FormatStyle.dateTime.month(.wide).day().year().locale(Locale(identifier: "en_US"))
        dayStyle.timeZone = .gmt
        day = message.createdAt.formatted(dayStyle).uppercased()
        copyText = message.blocks.map {
            switch $0 {
            case .text(let text): text
            case .mention(let id): users[id]?.name ?? ""
            case .code(_, let source): source
            }
        }.joined()
    }
}

@MainActor @Observable
final class RoomStore {
    private(set) var rows: [ChatRow] = []
    private(set) var ready = false
    private(set) var streaming = false
    private(set) var streamDone = false
    private(set) var revision = 0
    private(set) var hasUnread = false
    @ObservationIgnored var followsBottom = true
    @ObservationIgnored private(set) var dataset: Dataset?
    @ObservationIgnored private(set) var history: [Message] = []
    @ObservationIgnored private(set) var users: [Int: User] = [:]
    @ObservationIgnored private var feedTask: Task<Void, Never>?
    @ObservationIgnored private var burstTask: Task<Void, Never>?
    @ObservationIgnored private var burstBoosts: [Boost] = []

    func load() async {
        guard !ready else { return }
        let data = await Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }.value
        dataset = data
        history = data.messages
        users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        reset()
        ready = true
    }

    private func makeRows(_ messages: [Message]) -> [ChatRow] {
        messages.map { message in
            let previous = message.id > 1 && message.id - 2 < history.count ? history[message.id - 2] : nil
            return ChatRow(message: message, previous: previous, users: users)
        }
    }

    func reset() {
        feedTask?.cancel()
        burstTask?.cancel()
        streaming = false
        streamDone = false
        hasUnread = false
        if let dataset { history = dataset.messages }
        rows = makeRows(Array(Windowing.lastPage(history)))
        revision += 1
    }

    func jump(to id: Int) {
        rows = makeRows(Array(Windowing.around(id, in: history)))
        revision += 1
    }

    @discardableResult func loadOlder() -> Bool {
        guard let first = rows.first?.id else { return false }
        let page = Array(Windowing.page(before: first, in: history))
        guard !page.isEmpty else { return false }
        rows.insert(contentsOf: makeRows(page), at: 0)
        if rows.count > Windowing.maxLoaded + 20 { rows.removeLast(rows.count - Windowing.maxLoaded) }
        revision += 1
        return true
    }

    func loadNewer() {
        guard let last = rows.last?.id else { return }
        let page = Array(Windowing.page(after: last, in: history))
        guard !page.isEmpty else { return }
        rows.append(contentsOf: makeRows(page))
        if rows.count > Windowing.maxLoaded + 20 { rows.removeFirst(rows.count - Windowing.maxLoaded) }
        revision += 1
    }

    func newest() {
        hasUnread = false
        rows = makeRows(Array(Windowing.lastPage(history)))
        revision += 1
    }

    func startStream() {
        guard !streaming, !streamDone, let dataset else { return }
        streaming = true
        streamDone = false
        feedTask = Task {
            let feed = FakeLiveFeed(dataset: dataset)
            for await event in feed.play() {
                guard !Task.isCancelled else { return }
                switch event {
                case .message(let message):
                    let wasNewest = rows.last?.id == history.last?.id
                    history.append(message)
                    hasUnread = !followsBottom
                    if wasNewest && (followsBottom || rows.count < Windowing.maxLoaded) {
                        let row = ChatRow(message: message, previous: history.dropLast().last, users: users)
                        rows.append(row)
                        if followsBottom && rows.count > 80 {
                            rows.removeFirst(rows.count - 80)
                        }
                        revision += 1
                    }
                case .boost(let id, let boost): addBoost(boost, to: id)
                case .typingStarted, .typingStopped: break
                }
            }
            if !Task.isCancelled { streaming = false; streamDone = true }
        }
    }

    private func addBoost(_ boost: Boost, to id: Int) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].boosts.append(boost)
        if let row = rows.first(where: { $0.id == id }) {
            row.message = history[index]
            revision += 1
        }
    }

    func boostBurst() {
        guard let id = history.last?.id else { return }
        if burstBoosts.isEmpty {
            let reactions = ["👍", "🎉", "🔥", "❤️", "😂"]
            // CampfireKit owns Boost construction; use its existing seeded values.
            burstBoosts = reactions.enumerated().compactMap { offset, reaction in
                history.lazy.flatMap(\.boosts).first { $0.boosterID == offset + 2 && $0.content == reaction }
            }
        }
        burstTask?.cancel()
        burstTask = Task {
            for boost in burstBoosts {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                addBoost(boost, to: id)
            }
        }
    }
}

