import CampfireKit
import Foundation
import Observation

/// The one room: all messages in memory, the loaded window the list shows, and the live stream.
@MainActor
@Observable
final class RoomStore {
    enum StreamState { case idle, running, done }

    @ObservationIgnored let dataset: Dataset
    @ObservationIgnored let scroller: RoomScroller
    @ObservationIgnored private var all: [Message]
    @ObservationIgnored private let users: [UserID: User]
    @ObservationIgnored private var window: Range<Int> = 0..<0
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var localBoosts: [MessageID: [BoostItem]] = [:]
    @ObservationIgnored private var nextLocalBoostID = 5_000_000

    /// The loaded window, oldest first.
    private(set) var rows: [RowModel] = []
    private(set) var streamState = StreamState.idle

    var currentUserID: UserID { dataset.currentUserID }
    var roomName: String { dataset.room.name }
    var isAtRoomStart: Bool { window.lowerBound == 0 }
    var isAtRoomEnd: Bool { window.upperBound == all.count }
    var newestMessageID: MessageID? { all.last?.id }

    init(dataset: Dataset, scroller: RoomScroller) {
        self.dataset = dataset
        self.scroller = scroller
        all = dataset.messages
        users = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
        setWindow(range(of: Windowing.lastPage(all)))
        scroller.store = self
    }

    func user(_ id: UserID) -> User? {
        users[id]
    }

    // MARK: Windowing

    /// Back to the newest page, pinned to the bottom.
    func showNewest() {
        scroller.willReplaceContent(anchor: .bottom)
        setWindow(range(of: Windowing.lastPage(all)))
    }

    /// Loads one page of older messages above the window. Returns false at the start of the room.
    @discardableResult
    func loadOlder() -> Bool {
        guard let first = rows.first, window.lowerBound > 0 else { return false }
        let page = range(of: Windowing.page(before: first.id, in: all))
        guard !page.isEmpty else { return false }
        scroller.willMutate()
        var next = page.lowerBound..<window.upperBound
        if next.count > Windowing.maxLoaded + 20 {
            next = next.lowerBound..<(next.lowerBound + Windowing.maxLoaded)
        }
        setWindow(next)
        return true
    }

    /// Loads one page of newer messages below the window. Returns false at the end of the room.
    @discardableResult
    func loadNewer() -> Bool {
        guard let last = rows.last, window.upperBound < all.count else { return false }
        let page = range(of: Windowing.page(after: last.id, in: all))
        guard !page.isEmpty else { return false }
        scroller.willMutate()
        var next = window.lowerBound..<page.upperBound
        if next.count > Windowing.maxLoaded + 20 {
            next = (next.upperBound - Windowing.maxLoaded)..<next.upperBound
        }
        setWindow(next)
        return true
    }

    /// Loads the page around a message and puts its top just under the header.
    func jump(to id: MessageID) {
        let around = range(of: Windowing.around(id, in: all))
        guard !around.isEmpty else { return }
        scroller.willReplaceContent(anchor: .row(id, 0))
        setWindow(around)
    }

    // MARK: Live updates

    func startStream() {
        guard streamState == .idle else { return }
        streamState = .running
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard let self else { return }
                self.apply(event)
            }
            self?.streamState = .done
        }
    }

    /// Five boosts on the newest message, one every 200 ms, from users 2 to 6.
    func boostBurst() {
        guard let target = all.last?.id else { return }
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        Task { [weak self] in
            for (offset, content) in emoji.enumerated() {
                guard let self else { return }
                self.addLocalBoost(by: offset + 2, content: content, to: target)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func addLocalBoost(by booster: UserID, content: String, to id: MessageID) {
        nextLocalBoostID += 1
        localBoosts[id, default: []].append(BoostItem(id: nextLocalBoostID, boosterID: booster, content: content))
        guard let index = index(of: id), window.contains(index) else { return }
        scroller.willMutate()
        setWindow(window)
    }

    private func apply(_ event: FeedEvent) {
        switch event {
        case .message(let message): append(message)
        case .boost(let id, let boost): addBoost(boost, to: id)
        case .typingStarted, .typingStopped: break
        }
    }

    /// While pinned to the live end, older rows beyond this many are dropped from the top: the reader is at
    /// the bottom, and scrolling up pages them back in. Keeps each live append cheap.
    static let pinnedWindow = 100

    private func append(_ message: Message) {
        let followsWindow = isAtRoomEnd
        all.append(message)
        // Not pinned: stay put. The new rows wait below until the reader comes back down.
        guard followsWindow, scroller.isPinned else { return }
        scroller.willMutate()
        var next = window.lowerBound..<all.count
        if next.count > Self.pinnedWindow + 20 {
            next = (next.upperBound - Self.pinnedWindow)..<next.upperBound
        }
        setWindow(next)
    }

    private func addBoost(_ boost: Boost, to id: MessageID) {
        guard let index = index(of: id) else { return }
        all[index].boosts.append(boost)
        guard window.contains(index) else { return }
        scroller.willMutate()
        setWindow(window)
    }

    // MARK: Helpers

    private func index(of id: MessageID) -> Int? {
        // Ids are dense and increasing, so the id usually is the position; fall back to a search.
        let guess = id - (all.first?.id ?? 1)
        if all.indices.contains(guess), all[guess].id == id { return guess }
        return all.firstIndex { $0.id == id }
    }

    private func range(of slice: ArraySlice<Message>) -> Range<Int> {
        slice.startIndex..<slice.endIndex
    }

    private func setWindow(_ range: Range<Int>) {
        window = range
        let slice = Array(all[range])
        let previous = range.lowerBound > 0 ? all[range.lowerBound - 1] : nil
        let presentations = Grouping.presentations(of: slice, previous: previous, currentUserID: currentUserID)
        rows = zip(slice, presentations).map { message, presentation in
            RowModel(message: message, presentation: presentation,
                     boosts: message.boosts.map(BoostItem.init) + (localBoosts[message.id] ?? []))
        }
        scroller.didMutate(ids: rows.map(\.id), windowAtEnd: isAtRoomEnd, windowAtStart: isAtRoomStart)
    }
}
