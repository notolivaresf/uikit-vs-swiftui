import UIKit
import CampfireKit

/// The loaded window of the room: the messages on hand, their presentation and the current text size.
public final class RoomModel {
    public let dataset: Dataset
    public let users: [UserID: User]
    public private(set) var items: [RowItem] = []
    public var category: UIContentSizeCategory = .large
    /// True while the window ends at the newest message, so live messages belong at its end.
    public private(set) var atLiveEdge = true

    public init() {
        dataset = FakeData.generate(count: 50_000)
        users = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
        loadLast()
    }

    var me: UserID { dataset.currentUserID }
    public var firstID: Int { items.first?.message.id ?? 0 }
    public var lastID: Int { items.last?.message.id ?? 0 }

    private func items(for slice: ArraySlice<Message>, after previous: Message?) -> [RowItem] {
        let p = Grouping.presentations(of: Array(slice), previous: previous, currentUserID: me)
        return zip(slice, p).map { RowItem(message: $0, presentation: $1) }
    }

    /// Ids run 1...N in order, so a message's place in the dataset is its id minus one.
    private func slice(_ from: Int, _ to: Int) -> ArraySlice<Message> {
        dataset.messages[max(0, from - 1)..<min(dataset.messages.count, to)]
    }

    public func loadLast() {
        let s = Windowing.lastPage(dataset.messages)
        items = items(for: s, after: nil)
        atLiveEdge = true
    }

    /// Replaces the window with the messages around `id`.
    public func load(around id: Int) {
        let s = slice(id - Windowing.pageSize, id + Windowing.pageSize + 1)
        items = items(for: s, after: nil)
        atLiveEdge = false
    }

    /// Adds the page before the first loaded message. Returns how many were added and the id of the old first
    /// message when its presentation changed (it is now threaded under a new neighbour), so its saved height can go.
    public func loadOlder() -> (count: Int, changedID: MessageID?) {
        guard let first = items.first else { return (0, nil) }
        let s = slice(first.message.id - Windowing.pageSize, first.message.id - 1)
        guard !s.isEmpty else { return (0, nil) }
        let new = items(for: s, after: nil)
        let oldFirstPres = Grouping.presentation(of: first.message, after: s.last, currentUserID: me)
        let changed = oldFirstPres != first.presentation
        items[0] = RowItem(message: first.message, presentation: oldFirstPres)
        items.insert(contentsOf: new, at: 0)
        return (new.count, changed ? first.message.id : nil)
    }

    public func append(_ m: Message) {
        let p = Grouping.presentation(of: m, after: items.last?.message, currentUserID: me)
        items.append(RowItem(message: m, presentation: p))
    }

    /// Adds a boost to a loaded message; returns its row.
    public func addBoost(to id: MessageID, _ b: Boost) -> Int? {
        guard let i = index(ofID: id) else { return nil }
        var m = items[i].message
        m.boosts.append(b)
        items[i] = RowItem(message: m, presentation: items[i].presentation)
        return i
    }

    public func index(ofID id: MessageID) -> Int? {
        let i = id - firstID
        return items.indices.contains(i) && items[i].message.id == id ? i : nil
    }
}
