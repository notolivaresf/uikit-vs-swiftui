import Foundation
import CampfireKit

/// A boost as the room shows it. Boosts added in the app (the debug "Boost burst") live beside the
/// CampfireKit ones, because `Boost` has no public initializer.
struct BoostItem: Hashable {
    let boosterID: UserID
    let content: String
}

/// Generates the dataset on a background thread as early as possible; the store waits for it.
enum DatasetLoader {
    private static let done = DispatchSemaphore(value: 0)
    nonisolated(unsafe) private static var result: Dataset?

    static func start() {
        let thread = Thread {
            result = FakeData.generate(size: .k50)
            done.signal()
        }
        thread.qualityOfService = .userInteractive
        thread.stackSize = 8 << 20
        thread.start()
    }

    static func wait() -> Dataset {
        done.wait()
        done.signal()
        return result!
    }
}

/// Every message of the room (history plus live ones), the people, and the loaded window.
/// Message ids are contiguous from 1, so a message is found by index.
final class RoomStore {
    let dataset: Dataset
    private(set) var messages: [Message]
    private var usersByID: [UserID: User] = [:]
    let currentUserID: UserID

    /// The loaded window: a contiguous range of message ids.
    private(set) var window: ClosedRange<MessageID>

    init() {
        dataset = DatasetLoader.wait()
        messages = dataset.messages
        currentUserID = dataset.currentUserID
        for user in dataset.users { usersByID[user.id] = user }
        let page = Windowing.lastPage(messages)
        window = page.first!.id...page.last!.id
    }

    var roomName: String { dataset.room.name }
    var newestID: MessageID { messages.last!.id }
    var windowReachesNewest: Bool { window.upperBound == newestID }
    var hasOlder: Bool { window.lowerBound > messages.first!.id }

    func user(_ id: UserID) -> User? { usersByID[id] }

    func message(_ id: MessageID) -> Message? {
        let index = id - 1
        return messages.indices.contains(index) ? messages[index] : nil
    }

    func presentation(of id: MessageID) -> MessagePresentation? {
        guard let message = message(id) else { return nil }
        return Grouping.presentation(of: message, after: self.message(id - 1), currentUserID: currentUserID)
    }

    // MARK: Window changes

    func resetToNewest() {
        let page = Windowing.lastPage(messages)
        window = page.first!.id...page.last!.id
    }

    func jump(to id: MessageID) {
        let page = Windowing.around(id, in: messages)
        guard let first = page.first, let last = page.last else { return }
        window = first.id...last.id
    }

    /// Prepends the page before the window. Returns the ids added.
    @discardableResult
    func loadOlder() -> [MessageID] {
        let page = Windowing.page(before: window.lowerBound, in: messages)
        guard let first = page.first else { return [] }
        let added = Array(first.id..<window.lowerBound)
        window = first.id...window.upperBound
        return added
    }

    /// Appends the page after the window. Returns the ids added.
    @discardableResult
    func loadNewer() -> [MessageID] {
        let page = Windowing.page(after: window.upperBound, in: messages)
        guard let last = page.last else { return [] }
        let added = Array((window.upperBound + 1)...last.id)
        window = window.lowerBound...last.id
        return added
    }

    /// Campfire keeps at most `Windowing.maxLoaded` messages and trims once it is 20 or more over.
    /// Returns true if something was trimmed.
    @discardableResult
    func trimIfNeeded(keepNewest: Bool) -> Bool {
        let count = window.count
        guard count >= Windowing.maxLoaded + 20 else { return false }
        if keepNewest {
            window = (window.upperBound - Windowing.maxLoaded + 1)...window.upperBound
        } else {
            window = window.lowerBound...(window.lowerBound + Windowing.maxLoaded - 1)
        }
        return true
    }

    // MARK: Live changes

    /// Adds a live message. It joins the window only when the window already reaches the newest message.
    func appendLive(_ message: Message) -> Bool {
        guard message.id == newestID + 1 else { return false }
        let follows = windowReachesNewest
        messages.append(message)
        if follows { window = window.lowerBound...message.id }
        return follows
    }

    private var addedBoosts: [MessageID: [BoostItem]] = [:]

    func boosts(of id: MessageID) -> [BoostItem] {
        let own = message(id)?.boosts.map { BoostItem(boosterID: $0.boosterID, content: $0.content) } ?? []
        return own + (addedBoosts[id] ?? [])
    }

    /// Adds a boost from the live feed. Returns true if the message is in the loaded window.
    func addBoost(_ boost: Boost, to id: MessageID) -> Bool {
        let index = id - 1
        guard messages.indices.contains(index) else { return false }
        messages[index].boosts.append(boost)
        return window.contains(id)
    }

    /// Adds a boost made in the app. Returns true if the message is in the loaded window.
    func addBoost(_ boost: BoostItem, to id: MessageID) -> Bool {
        guard message(id) != nil else { return false }
        addedBoosts[id, default: []].append(boost)
        return window.contains(id)
    }
}
