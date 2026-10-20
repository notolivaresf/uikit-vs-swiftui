import SwiftUI
import CampfireKit

struct RoomBoost: Identifiable, Equatable, Sendable {
    let id: Int
    let userID: UserID
    let content: String
    init(_ boost: Boost) { id = boost.id; userID = boost.boosterID; content = boost.content }
    init(id: Int, userID: UserID, content: String) { self.id = id; self.userID = userID; self.content = content }
}

struct RoomRow: Identifiable, Sendable {
    let message: Message
    let presentation: MessagePresentation
    var id: Int { message.id }
}

@MainActor @Observable
final class RoomStore {
    @ObservationIgnored let dataset: Dataset
    @ObservationIgnored var history: [Message]
    @ObservationIgnored let users: [UserID: User]
    @ObservationIgnored let started: ContinuousClock.Instant
    @ObservationIgnored private var feedTask: Task<Void, Never>?
    @ObservationIgnored private var boostTask: Task<Void, Never>?
    var loaded: [Message]
    var rows: [RoomRow] = []
    var extraBoosts: [MessageID: [RoomBoost]] = [:]
    var version = 0
    var streaming = false
    var streamDone = false
    var unread = 0
    var newestID: Int { history.last?.id ?? 0 }
    var firstID: Int { loaded.first?.id ?? 0 }
    var lastID: Int { loaded.last?.id ?? 0 }
    var canLoadOlder: Bool { firstID > 1 }
    var canLoadNewer: Bool { lastID < newestID }
    var onFeedChange: ((FeedEvent) -> Void)?

    init(started: ContinuousClock.Instant) {
        self.started = started
        let data = FakeData.generate(size: .k50)
        dataset = data
        users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        history = data.messages
        loaded = Array(Windowing.lastPage(data.messages))
        rebuild()
    }

    func rebuild() {
        let previous = firstID > 1 ? history[firstID - 2] : nil
        let presentations = Grouping.presentations(of: loaded, previous: previous, currentUserID: dataset.currentUserID)
        rows = zip(loaded, presentations).map { RoomRow(message: $0, presentation: $1) }
        version += 1
    }

    func reset() {
        feedTask?.cancel(); feedTask = nil
        boostTask?.cancel(); boostTask = nil
        history = dataset.messages
        extraBoosts = [:]
        loaded = Array(Windowing.lastPage(history))
        streaming = false; streamDone = false; unread = 0
        rebuild()
    }

    func older(preserving id: MessageID) {
        guard canLoadOlder else { return }
        loaded.insert(contentsOf: Windowing.page(before: firstID, in: history), at: 0)
        if loaded.count > Windowing.maxLoaded {
            let extra = loaded.count - Windowing.maxLoaded
            let anchorIndex = loaded.firstIndex { $0.id == id } ?? 0
            if anchorIndex >= Windowing.maxLoaded { loaded.removeFirst(extra) }
            else { loaded.removeLast(extra) }
        }
        rebuild()
    }

    func newer() {
        guard canLoadNewer else { return }
        loaded.append(contentsOf: Windowing.page(after: lastID, in: history))
        if loaded.count > Windowing.maxLoaded { loaded.removeFirst(loaded.count - Windowing.maxLoaded) }
        rebuild()
    }

    func jump(to id: Int) {
        loaded = Array(Windowing.around(id, in: history))
        rebuild()
    }

    func latest() {
        loaded = Array(Windowing.lastPage(history))
        unread = 0
        rebuild()
    }

    func receive(_ event: FeedEvent, pinned: Bool) {
        switch event {
        case .message(let message):
            guard message.id == newestID + 1 else { return }
            history.append(message)
            if lastID == message.id - 1 && (pinned || loaded.count < Windowing.maxLoaded) {
                loaded.append(message)
                if loaded.count > Windowing.maxLoaded { loaded.removeFirst(loaded.count - Windowing.maxLoaded) }
                rebuild()
            }
            if !pinned { unread += 1 }
        case .boost(let id, let boost):
            extraBoosts[id, default: []].append(RoomBoost(boost))
            version += 1
        case .typingStarted, .typingStopped: break
        }
    }

    func startStream() {
        guard !streaming && !streamDone else { return }
        streaming = true
        let feed = FakeLiveFeed(dataset: dataset)
        feedTask = Task { [weak self] in
            for await event in feed.play() {
                guard !Task.isCancelled else { return }
                self?.onFeedChange?(event)
            }
            guard !Task.isCancelled else { return }
            self?.streaming = false
            self?.streamDone = true
        }
    }

    func burst() {
        boostTask?.cancel()
        let target = newestID
        boostTask = Task { [weak self] in
            for (i, emoji) in ["👍", "🎉", "🔥", "❤️", "😂"].enumerated() {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                // The package's Boost initializer is internal; keep debug-only boosts as view data.
                self.onBurst?(target, RoomBoost(id: 2_000_000 + self.version * 10 + i,
                                                userID: i + 2, content: emoji))
            }
        }
    }
    var onBurst: ((MessageID, RoomBoost) -> Void)?

    func addDebugBoost(_ id: MessageID, _ boost: RoomBoost) {
        extraBoosts[id, default: []].append(boost)
        version += 1
    }
}
