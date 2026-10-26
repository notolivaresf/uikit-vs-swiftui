import Foundation
import CampfireKit

/// A boost as the app shows it. Boosts from the dataset and the live feed are copied in; the debug bar's
/// "Boost burst" adds its own (CampfireKit does not let the app create `Boost` values).
struct BoostItem: Equatable {
    let boosterID: UserID
    let content: String
}

/// All messages in memory, oldest first. Ids are contiguous from 1, so a message's index is `id - 1`.
final class Store {
    static let shared = Store()

    private let lock = NSCondition()
    private var loaded: Dataset?

    private(set) var dataset: Dataset!
    private(set) var all: [Message] = []
    private(set) var users: [User] = []
    private var extraBoosts: [MessageID: [BoostItem]] = [:]
    /// Bumped whenever a message's boosts change, so cached row geometry can be checked cheaply.
    private(set) var revisions: [MessageID: Int] = [:]

    /// Starts building the 50,000 messages on a background thread. Called from the first line of main.
    func startLoading() {
        Thread.detachNewThread { [self] in
            let d = FakeData.generate(size: .k50)
            lock.lock(); loaded = d; lock.broadcast(); lock.unlock()
        }
    }

    /// Blocks until the dataset is built (main thread, once, at launch).
    func waitUntilReady() {
        if dataset != nil { return }
        lock.lock()
        while loaded == nil { lock.wait() }
        let d = loaded!
        lock.unlock()
        dataset = d
        all = d.messages
        users = d.users.sorted { $0.id < $1.id }
    }

    var currentUserID: UserID { dataset.currentUserID }

    func user(_ id: UserID) -> User? { id >= 1 && id <= users.count ? users[id - 1] : nil }

    func index(of id: MessageID) -> Int? { id >= 1 && id <= all.count ? id - 1 : nil }

    func message(_ id: MessageID) -> Message? { index(of: id).map { all[$0] } }

    func boosts(of m: Message) -> [BoostItem] {
        let base = m.boosts.map { BoostItem(boosterID: $0.boosterID, content: $0.content) }
        guard let extra = extraBoosts[m.id] else { return base }
        return base + extra
    }

    func revision(of id: MessageID) -> Int { revisions[id] ?? 0 }

    func append(_ m: Message) {
        precondition(m.id == all.count + 1, "live ids continue the dataset")
        all.append(m)
    }

    func addBoost(_ b: BoostItem, to id: MessageID) {
        guard index(of: id) != nil else { return }
        extraBoosts[id, default: []].append(b)
        revisions[id, default: 0] += 1
    }
}
