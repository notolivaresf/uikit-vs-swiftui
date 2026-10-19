import CampfireKit
import SwiftUI

/// The single room: the loaded window of messages, the live stream and the debug-bar actions.
@MainActor @Observable
final class RoomStore {
    // MARK: Data

    @ObservationIgnored private(set) var dataset: Dataset?
    /// Every message, oldest first: the generated history followed by whatever the live stream added.
    @ObservationIgnored private var all: [Message] = []
    private(set) var people = People(names: [:])
    @ObservationIgnored let currentUserID = FakeData.currentUserID

    // MARK: Window

    /// Loaded window `all[lo..<hi]`.
    @ObservationIgnored private(set) var lo = 0
    @ObservationIgnored private(set) var hi = 0
    private(set) var rows: [RowItem] = []
    private(set) var isLoaded = false
    @ObservationIgnored private var fixtureMode = false
    var atOldest: Bool { lo == 0 }
    var hasNewest: Bool { hi == all.count }

    // MARK: Live

    private(set) var streamDone = false
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var nextBurstBoostID = 5_000_000
    /// Boosts added by this app (the debug burst). `Boost` has no public initializer, so they live beside the messages.
    @ObservationIgnored private var localBoosts: [MessageID: [BoostItem]] = [:]

    // MARK: Presentation state

    /// `nil` follows the system Dynamic Type setting.
    var typeOverride: DynamicTypeSize?
    private(set) var showJumpToBottom = false
    var debugLabel = "first 0 last 0 loaded 0 pinned yes top 0 y 0.0 ms 0"

    @ObservationIgnored let scroller = ScrollCoordinator()
    @ObservationIgnored let selection = SelectionModel()
    /// The latest programmatic scroll; the list applies it to its own ScrollPosition. A token rather than the
    /// ScrollPosition itself, so the scroll view's write-backs never invalidate views that read the store.
    private(set) var scrollRequest = ScrollRequest(serial: 0, target: .y(0))

    /// Mirrors `scroller.anchor == .bottom`; drives the scroll view's own bottom anchoring while pinned.
    var isPinned = true

    func requestScrollToBottom() {
        scrollRequest = ScrollRequest(serial: scrollRequest.serial &+ 1, target: .bottom)
    }

    func requestScroll(toY y: CGFloat) {
        scrollRequest = ScrollRequest(serial: scrollRequest.serial &+ 1, target: .y(y))
    }

    /// Brings a row that is not laid out yet into view (lazy stack); the coordinator then fine-tunes by its frame.
    func requestScroll(toRow id: MessageID) {
        scrollRequest = ScrollRequest(serial: scrollRequest.serial &+ 1, target: .row(id))
    }

    /// Generation starts as soon as the store exists, in parallel with the first scene setup.
    @ObservationIgnored private let generation = Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }

    init() {
        scroller.store = self
    }

    // MARK: Loading

    func load() async {
        guard dataset == nil else { return }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "uvsFixture") {
            people = Fixture.people
            rows = Fixture.rows
            fixtureMode = true
            scroller.anchor = UserDefaults.standard.bool(forKey: "uvsFixtureTop") ? .row(id: 1, y: 2000) : .bottom
            isLoaded = true
            return
        }
        #endif
        dlog("load start \((ContinuousClock.now - Launch.start))")
        let data = await generation.value
        dlog("generated \((ContinuousClock.now - Launch.start))")
        dataset = data
        all = data.messages
        people = People(names: Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0.name) }))
        let page = Windowing.lastPage(all)
        lo = page.startIndex
        hi = page.endIndex
        rebuildRows()
        dlog("rows built \((ContinuousClock.now - Launch.start))")
        scroller.anchor = .bottom
        scroller.beginMeasure(from: Launch.start, expectLayout: true)
        isLoaded = true
        if UserDefaults.standard.bool(forKey: "uvsAutoStream") {
            // Profiling aid: start the live stream without a tap.
            try? await Task.sleep(for: .seconds(1))
            startStream()
        }
    }

    private func rebuildRows() {
        let window = all[lo..<hi]
        let previous = lo > 0 ? all[lo - 1] : nil
        let presentations = Grouping.presentations(of: Array(window), previous: previous, currentUserID: currentUserID)
        rows = zip(window, presentations).map { m, p in
            RowItem(message: m, presentation: p, authorName: people.name(m.creatorID), extraBoosts: localBoosts[m.id] ?? [])
        }
        scroller.rowsChanged(Set(rows.map(\.id)))
    }

    /// Prepends the page before the first loaded message. Returns false at the start of history.
    @discardableResult
    func loadOlder() -> Bool {
        guard lo > 0, let first = rows.first else { return false }
        let page = Windowing.page(before: first.id, in: all)
        guard !page.isEmpty else { return false }
        scroller.willChangeLayout()
        lo = page.startIndex
        if hi - lo > Windowing.maxLoaded + 20 { hi = lo + Windowing.maxLoaded }
        rebuildRows()
        return true
    }

    /// Appends the page after the last loaded message (when the window is not at the newest).
    @discardableResult
    func loadNewer() -> Bool {
        guard hi < all.count, let last = rows.last else { return false }
        let page = Windowing.page(after: last.id, in: all)
        guard !page.isEmpty else { return false }
        scroller.willChangeLayout()
        hi = page.endIndex
        trimTop()
        rebuildRows()
        return true
    }

    private func trimTop() {
        guard hi - lo > Windowing.maxLoaded + 20 else { return }
        var newLo = hi - Windowing.maxLoaded
        // Never trim the row the reader is anchored to (or the page above it).
        if case .row(let id, _) = scroller.anchor {
            let index = id - 1
            newLo = min(newLo, max(lo, index - Windowing.pageSize))
        }
        lo = newLo
    }

    func showNewest() {
        let page = Windowing.lastPage(all)
        lo = page.startIndex
        hi = page.endIndex
        rebuildRows()
        scroller.anchor = .bottom
        scroller.willChangeLayout()
    }

    func jump(to id: MessageID) {
        let page = Windowing.around(id, in: all)
        guard !page.isEmpty else { return }
        lo = page.startIndex
        hi = page.endIndex
        rebuildRows()
        scroller.anchor = .row(id: id, y: 0)
        scroller.willChangeLayout()
    }

    func setJumpToBottomVisible(_ visible: Bool) {
        if showJumpToBottom != visible { showJumpToBottom = visible }
    }

    // MARK: Live stream

    func startStream() {
        guard streamTask == nil, let dataset else { return }
        streamDone = false
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard let self else { return }
                self.handle(event)
            }
            self?.streamDone = true
        }
    }

    private func handle(_ event: FeedEvent) {
        switch event {
        case .message(let m):
            let wasNewest = hasNewest
            all.append(m)
            if wasNewest {
                scroller.willChangeLayout()
                hi = all.count
                trimTop()
                rebuildRows()
            } else {
                setJumpToBottomVisible(true)
            }
        case .boost(let id, let boost):
            addBoost(boost, to: id)
        case .typingStarted, .typingStopped:
            break
        }
    }

    private func addBoost(_ boost: Boost, to id: MessageID) {
        let index = id - 1
        guard all.indices.contains(index), all[index].id == id else { return }
        all[index].boosts.append(boost)
        boostsChanged(at: index)
    }

    private func addLocalBoost(_ boost: BoostItem, to id: MessageID) {
        let index = id - 1
        guard all.indices.contains(index), all[index].id == id else { return }
        localBoosts[id, default: []].append(boost)
        boostsChanged(at: index)
    }

    private func boostsChanged(at index: Int) {
        if index >= lo && index < hi {
            scroller.willChangeLayout()
            rebuildRows()
        }
    }

    /// Adds 5 boosts to the newest message, one every 200 ms, from users 2 to 6.
    func boostBurst() {
        guard let target = all.last?.id else { return }
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        Task { [weak self] in
            for (i, e) in emoji.enumerated() {
                guard let self else { return }
                if i > 0 { try? await Task.sleep(for: .milliseconds(200)) }
                self.nextBurstBoostID += 1
                self.addLocalBoost(BoostItem(id: self.nextBurstBoostID, boosterID: i + 2, content: e), to: target)
            }
        }
    }

    // MARK: Debug bar

    func debugReset() {
        scroller.beginMeasure(expectLayout: true)
        typeOverride = nil
        showNewest()
    }

    func debugJump() {
        scroller.beginMeasure(expectLayout: true)
        jump(to: 2500)
    }

    func debugLoadOlder() {
        scroller.beginMeasure(expectLayout: lo > 0)
        loadOlder()
    }

    func debugTextSizeUp(current: DynamicTypeSize) {
        scroller.beginMeasure(expectLayout: true)
        scroller.willChangeLayout()
        let all = DynamicTypeSize.allCases
        if let i = all.firstIndex(of: current), i + 1 < all.count {
            typeOverride = all[i + 1]
        } else {
            typeOverride = .large
        }
    }

    // MARK: Label

    func labelPrefix() -> String {
        let first = rows.first?.id ?? 0
        let last = rows.last?.id ?? 0
        return "first \(first) last \(last) loaded \(rows.count)"
    }
}

struct ScrollRequest: Equatable {
    enum Target: Equatable {
        case y(CGFloat)
        case row(MessageID)
        case bottom
    }
    let serial: Int
    let target: Target
}
