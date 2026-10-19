import Foundation
import CampfireKit

/// All messages (history plus whatever the live stream added) and the loaded window into them.
/// Paging uses CampfireKit's Windowing; threading and day breaks use Grouping.
final class RoomStore {
    let dataset: Dataset
    private(set) var all: [Message]
    /// Loaded window: indices lo..<hi into `all`.
    private(set) var lo = 0
    private(set) var hi = 0

    init() {
        dataset = DatasetPreload.dataset()
        all = dataset.messages
    }

    var count: Int { hi - lo }
    var includesNewest: Bool { hi == all.count }
    var newestID: MessageID? { all.last?.id }

    func index(of id: MessageID) -> Int? {
        let i = id - 1  // ids are 1...n in order, the live stream continues them
        if i >= 0, i < all.count, all[i].id == id { return i }
        return all.firstIndex { $0.id == id }
    }

    func presentation(at i: Int) -> MessagePresentation {
        Grouping.presentation(of: all[i], after: i > 0 ? all[i - 1] : nil, currentUserID: dataset.currentUserID)
    }

    private func setWindow(_ slice: ArraySlice<Message>) {
        lo = slice.startIndex
        hi = slice.endIndex
    }

    func showNewest() { setWindow(Windowing.lastPage(all)) }

    func jump(to id: MessageID) { setWindow(Windowing.around(id, in: all)) }

    /// Prepends a page; trims the newest end when the window grows past Campfire's limit. Returns rows added.
    @discardableResult
    func loadOlder() -> Int {
        guard lo > 0 else { return 0 }
        let page = Windowing.page(before: all[lo].id, in: all)
        guard !page.isEmpty else { return 0 }
        let added = lo - page.startIndex
        lo = page.startIndex
        if count > Windowing.maxLoaded + 20 { hi = lo + Windowing.maxLoaded }
        return added
    }

    /// Appends a page; trims the oldest end when needed. Returns rows trimmed from the top.
    @discardableResult
    func loadNewer() -> Int {
        guard hi < all.count, hi > 0 else { return 0 }
        let page = Windowing.page(after: all[hi - 1].id, in: all)
        guard !page.isEmpty else { return 0 }
        hi = page.endIndex
        return trimOldest()
    }

    @discardableResult
    func trimOldest() -> Int {
        guard count > Windowing.maxLoaded + 20 else { return 0 }
        let n = count - Windowing.maxLoaded
        lo += n
        return n
    }

    /// Adds a live message. Returns true if it entered the loaded window (the window was showing the newest).
    /// When the window is already full (`canGrow` false), the message stays outside it, like Campfire's 300 cap.
    func append(_ m: Message, canGrow: Bool = true) -> Bool {
        let joins = includesNewest && (canGrow || count < Windowing.maxLoaded + 20)
        all.append(m)
        if joins { hi = all.count }
        return joins
    }

    /// Boosts added on this device (Boost burst); CampfireKit's Boost has no public initializer.
    private(set) var localBoosts: [MessageID: [BoostItem]] = [:]

    /// Returns the index of the boosted message, if known.
    func addBoost(_ b: Boost, to id: MessageID) -> Int? {
        guard let i = index(of: id) else { return nil }
        all[i].boosts.append(b)
        return i
    }

    func addLocalBoost(_ b: BoostItem, to id: MessageID) -> Int? {
        guard let i = index(of: id) else { return nil }
        localBoosts[id, default: []].append(b)
        return i
    }
}

/// Generates the dataset on a background thread as early as possible; the room waits for it on first use.
enum DatasetPreload {
    private static let lock = NSCondition()
    nonisolated(unsafe) private static var result: Dataset?
    nonisolated(unsafe) private static var started = false

    static func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        Thread.detachNewThread {
            let d = FakeData.generate(size: .k50)
            lock.lock()
            result = d
            lock.broadcast()
            lock.unlock()
        }
    }

    static func dataset() -> Dataset {
        start()
        lock.lock()
        defer { lock.unlock() }
        while result == nil { lock.wait() }
        return result!
    }
}
