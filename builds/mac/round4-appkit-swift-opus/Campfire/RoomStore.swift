import Foundation
import CampfireKit

/// Builds the dataset on a background thread as early as possible; `wait()` hands it over.
enum DatasetLoader {
    private static var dataset: Dataset?
    private static let done = DispatchSemaphore(value: 0)
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        DispatchQueue.global(qos: .userInteractive).async {
            dataset = FakeData.generate(size: .k50)
            done.signal()
        }
    }

    static func wait() -> Dataset {
        start()
        done.wait()
        done.signal()
        return dataset!
    }
}

/// A boost as the app shows it. CampfireKit's `Boost` has no public initializer, and boosts added after a
/// message was made (live stream, Boost burst) need one.
struct AppBoost: Equatable {
    let id: Int
    let boosterID: UserID
    let content: String

    init(id: Int, boosterID: UserID, content: String) {
        self.id = id; self.boosterID = boosterID; self.content = content
    }

    init(_ b: Boost) { self.init(id: b.id, boosterID: b.boosterID, content: b.content) }
}

/// All messages of the room: the generated history plus whatever the live stream has added, with boosts that
/// arrived after a message was made. Pages come from `Windowing`, presentation from `Grouping`.
final class RoomStore {
    let dataset: Dataset
    private(set) var live: [Message] = []
    private var extraBoosts: [MessageID: [AppBoost]] = [:]
    private let usersByID: [UserID: User]

    init() {
        dataset = DatasetLoader.wait()
        usersByID = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
    }

    var currentUserID: UserID { dataset.currentUserID }
    var oldestID: MessageID { dataset.messages.first?.id ?? 0 }
    var newestID: MessageID { live.last?.id ?? dataset.messages.last?.id ?? 0 }
    var totalCount: Int { dataset.messages.count + live.count }

    func user(_ id: UserID) -> User? { usersByID[id] }
    func name(of id: UserID) -> String { usersByID[id]?.name ?? "Someone" }

    // MARK: Index of a message in history + live (ids are contiguous, starting at 1).

    private func globalIndex(of id: MessageID) -> Int? {
        let n = dataset.messages.count
        let i = id - (dataset.messages.first?.id ?? 1)
        if i >= 0, i < n, dataset.messages[i].id == id { return i }
        let j = i - n
        if j >= 0, j < live.count, live[j].id == id { return i }
        if let k = dataset.messages.firstIndex(where: { $0.id == id }) { return k }
        if let k = live.firstIndex(where: { $0.id == id }) { return n + k }
        return nil
    }

    private func rawMessage(at index: Int) -> Message {
        let n = dataset.messages.count
        return index < n ? dataset.messages[index] : live[index - n]
    }

    /// The message's own boosts followed by any added later.
    func boosts(of m: Message) -> [AppBoost] {
        m.boosts.map(AppBoost.init) + (extraBoosts[m.id] ?? [])
    }

    private func messages(in range: Range<Int>) -> [Message] {
        let lo = max(0, range.lowerBound), hi = min(totalCount, range.upperBound)
        guard lo < hi else { return [] }
        return (lo..<hi).map { rawMessage(at: $0) }
    }

    func message(_ id: MessageID) -> Message? {
        globalIndex(of: id).map { rawMessage(at: $0) }
    }

    // MARK: Pages

    /// The newest page of 40.
    func newestPage() -> [Message] {
        if live.isEmpty { return Array(Windowing.lastPage(dataset.messages)) }
        return messages(in: (totalCount - Windowing.pageSize)..<totalCount)
    }

    /// Up to 40 messages before `id`.
    func page(before id: MessageID) -> [Message] {
        if id <= (dataset.messages.last?.id ?? 0) {
            return Array(Windowing.page(before: id, in: dataset.messages))
        }
        guard let i = globalIndex(of: id) else { return [] }
        return messages(in: (i - Windowing.pageSize)..<i)
    }

    /// Up to 40 messages after `id`.
    func page(after id: MessageID) -> [Message] {
        if live.isEmpty { return Array(Windowing.page(after: id, in: dataset.messages)) }
        guard let i = globalIndex(of: id) else { return [] }
        return messages(in: (i + 1)..<(i + 1 + Windowing.pageSize))
    }

    /// `id` with 40 messages either side.
    func page(around id: MessageID) -> [Message] {
        if live.isEmpty { return Array(Windowing.around(id, in: dataset.messages)) }
        guard let i = globalIndex(of: id) else { return [] }
        return messages(in: (i - Windowing.pageSize)..<(i + Windowing.pageSize + 1))
    }

    /// Presentations of a run of consecutive messages, computed against the message before the run so that a
    /// row reads the same whichever page brought it in.
    func presentations(of run: [Message]) -> [MessagePresentation] {
        guard let first = run.first else { return [] }
        var previous: Message?
        if let i = globalIndex(of: first.id), i > 0 { previous = rawMessage(at: i - 1) }
        return Grouping.presentations(of: run, previous: previous, currentUserID: currentUserID)
    }

    // MARK: Live changes

    func appendLive(_ m: Message) {
        guard m.id > newestID else { return }
        live.append(m)
    }

    /// Records a boost; returns false if the message is unknown.
    @discardableResult
    func addBoost(_ boost: AppBoost, to id: MessageID) -> Bool {
        guard globalIndex(of: id) != nil else { return false }
        extraBoosts[id, default: []].append(boost)
        return true
    }
}
