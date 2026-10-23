import SwiftUI
import Observation
import CampfireKit

@MainActor @Observable
final class ChatRow: Identifiable {
    let id: Int
    let content: Message
    var boosts: [Boost]
    let isEmojiOnly: Bool

    var message: Message {
        var value = content
        value.boosts = boosts
        return value
    }
    let presentation: MessagePresentation
    let author: String
    let time: String
    let day: String
    let copyText: String

    init(message: Message, previous: Message?, users: [Int: User]) {
        id = message.id
        content = message
        boosts = message.boosts
        isEmojiOnly = message.isEmojiOnly
        presentation = Grouping.presentation(of: message, after: previous, currentUserID: 1)
        author = users[message.creatorID]?.name ?? ""
        var style = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            .locale(Locale(identifier: "en_US"))
        style.timeZone = .gmt
        time = message.createdAt.formatted(style)
        var dayStyle = Date.FormatStyle.dateTime.month(.wide).day().year().locale(Locale(identifier: "en_US"))
        dayStyle.timeZone = .gmt
        day = presentation.isFirstOfDay ? message.createdAt.formatted(dayStyle).uppercased() : ""
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
    @ObservationIgnored private var loadedByID: [Int: ChatRow] = [:]
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
            let row = ChatRow(message: message, previous: previous, users: users)
            loadedByID[row.id] = row
            return row
        }
    }

    private func replaceRows(_ messages: [Message]) {
        loadedByID.removeAll(keepingCapacity: true)
        rows = makeRows(messages)
    }

    private func trimFirst(_ count: Int) {
        for row in rows.prefix(count) { loadedByID[row.id] = nil }
        rows.removeFirst(count)
    }

    private func trimLast(_ count: Int) {
        for row in rows.suffix(count) { loadedByID[row.id] = nil }
        rows.removeLast(count)
    }

    // IDs in CampfireKit's generated history and feed are contiguous.
    // Bound the input to Windowing to the requested page, so its internal
    // lookup never scans the entire history.
    private func context(around id: Int, before: Int, after: Int) -> [Message] {
        let index = id - 1
        guard history.indices.contains(index), history[index].id == id else { return [] }
        return Array(history[max(0, index - before)..<min(history.count, index + after + 1)])
    }

    func reset() {
        feedTask?.cancel()
        burstTask?.cancel()
        streaming = false
        streamDone = false
        hasUnread = false
        if let dataset { history = dataset.messages }
        replaceRows(Array(Windowing.lastPage(history)))
        revision += 1
    }

    func jump(to id: Int) {
        replaceRows(Array(Windowing.around(id, in: context(around: id, before: Windowing.pageSize, after: Windowing.pageSize))))
        revision += 1
    }

    @discardableResult func loadOlder() -> Bool {
        guard let first = rows.first?.id else { return false }
        let page = Array(Windowing.page(before: first, in: context(around: first, before: Windowing.pageSize, after: 0)))
        guard !page.isEmpty else { return false }
        rows.insert(contentsOf: makeRows(page), at: 0)
        if rows.count > Windowing.maxLoaded + 20 { trimLast(rows.count - Windowing.maxLoaded) }
        revision += 1
        return true
    }

    func loadNewer() {
        guard let last = rows.last?.id else { return }
        let page = Array(Windowing.page(after: last, in: context(around: last, before: 0, after: Windowing.pageSize)))
        guard !page.isEmpty else { return }
        rows.append(contentsOf: makeRows(page))
        if rows.count > Windowing.maxLoaded + 20 { trimFirst(rows.count - Windowing.maxLoaded) }
        revision += 1
    }

    func newest() {
        hasUnread = false
        replaceRows(Array(Windowing.lastPage(history)))
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
                        loadedByID[row.id] = row
                        rows.append(row)
                        if followsBottom && rows.count > Windowing.pageSize * 3 {
                            trimFirst(Windowing.pageSize)
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
        let index = id - 1
        guard history.indices.contains(index), history[index].id == id else { return }
        history[index].boosts.append(boost)
        if let row = loadedByID[id] {
            row.boosts = history[index].boosts
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

