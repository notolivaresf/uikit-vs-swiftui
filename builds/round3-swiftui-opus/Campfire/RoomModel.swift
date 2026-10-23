import CampfireKit
import QuartzCore
import SwiftUI

/// When the app's own code started running; the launch `ms` is measured from here.
enum Launch {
    nonisolated(unsafe) private(set) static var start: CFTimeInterval = 0
    static func markStart() { if start == 0 { start = CACurrentMediaTime() } }
}

/// A programmatic scroll: to a y measured from the inset edge, to a row's top, or to the bottom when
/// both are nil.
struct ScrollRequest: Equatable {
    let serial: Int
    let y: CGFloat?
    var rowID: Int? = nil
    let animated: Bool
}

/// What the scroll view reports about itself.
struct ScrollMetrics: Equatable {
    var offsetY: CGFloat = 0
    var contentHeight: CGFloat = 0
    var containerHeight: CGFloat = 0
    var containerWidth: CGFloat = 0
    /// The scroll view reaches under the status bar; these are the automatic insets for it.
    var insetTop: CGFloat = 0
    var insetBottom: CGFloat = 0

    /// Content y at the top of the scroll view's own frame (the header's top edge).
    var visibleTop: CGFloat { offsetY + insetTop }
    var visibleBottom: CGFloat { offsetY + insetTop + containerHeight }
    var minOffset: CGFloat { -insetTop }
    var maxOffset: CGFloat { max(minOffset, contentHeight + insetBottom - containerHeight - insetTop) }
}

/// The single room: which messages are loaded, where the scroll view is, and the debug state.
@MainActor
@Observable
final class RoomModel {
    // MARK: Observed by views

    private(set) var rows: [RowModel] = []
    private(set) var isLoaded = false
    /// The welcome card shows once the oldest message is loaded.
    private(set) var showsWelcome = false
    /// Asks the list to scroll; ScrollPosition itself lives in the view's state.
    private(set) var scrollRequest: ScrollRequest?
    @ObservationIgnored private var scrollSerial = 0
    /// Which edge the scroll view keeps still when its content or container changes size.
    private(set) var sizeAnchor: UnitPoint = .bottom
    private(set) var showsJumpButton = false
    private(set) var stateLabel = "first 0 last 0 loaded 0 pinned yes top 0 y 0.0 ms 0"
    private(set) var streamDone = false
    /// The long-pressed message's selected text, if any.
    private(set) var selection: MessageSelection?
    @ObservationIgnored private var selectedText = ""
    /// Set by "Text size +"; nil follows the system setting.
    private(set) var typeSizeOverride: DynamicTypeSize?

    // MARK: Data

    @ObservationIgnored private var messages: [Message] = []
    @ObservationIgnored private var builder: RowBuilder?
    @ObservationIgnored private var dataset: Dataset?
    @ObservationIgnored private var extraBoosts: [Int: [BoostItem]] = [:]
    /// Indices into `messages` of the loaded rows.
    @ObservationIgnored private var window: Range<Int> = 0..<0
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var burstTask: Task<Void, Never>?
    @ObservationIgnored private var burstSerial = 0
    @ObservationIgnored var systemTypeSize: DynamicTypeSize = .large

    static let pageSize = Windowing.pageSize
    static let maxLoaded = Windowing.maxLoaded
    /// Trim only once this many rows over the cap, so the stream does not trim on every message.
    static let trimSlack = 20
    static let pinDistance: CGFloat = 100
    static let trace = ProcessInfo.processInfo.environment["CF_TRACE"] != nil
    nonisolated(unsafe) static var traceFile: FileHandle? = {
        guard ProcessInfo.processInfo.environment["CF_TRACE"] != nil else { return nil }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("trace.txt")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try? FileHandle(forWritingTo: url)
    }()
    static func print(_ s: String) {
        Swift.print(s)
        traceFile?.write((String(format: "%.3f ", CACurrentMediaTime()) + s + "\n").data(using: .utf8)!)
    }
    static let loadMoreDistance: CGFloat = 400

    // MARK: Scroll state

    @ObservationIgnored private var metrics = ScrollMetrics()
    /// The last frame each row reported, in the content's coordinate space (frames do not change while
    /// scrolling). Never dropped: a row reports only when its frame differs from its last report, so this
    /// stays equal to what the lazy stack has for every realized row. Rows it let go may be stale, which is
    /// why only rows in `visible` count.
    @ObservationIgnored private var frames: [Int: CGRect] = [:]
    /// Rows at least partly inside the scroll view's bounds.
    @ObservationIgnored private var visible: Set<Int> = []
    @ObservationIgnored private var rowWidth: CGFloat = 0
    /// Jump, Reset and rotation: scroll to the anchored row by id first (the lazy stack may not have it
    /// realized, and its offsets for rows it has not realized are estimates), then place it exactly.
    @ObservationIgnored private var scrollToAnchorRow = false
    /// Load older while pinned holds the top row still, then pins again if still at the bottom.
    @ObservationIgnored private var repinAfterSettle = false
    /// Reset goes to the newest row like a jump, then pins.
    @ObservationIgnored private var pinAfterSettle = false
    /// The row to hold still, and its top relative to the header's bottom edge.
    @ObservationIgnored private var anchor: (id: Int, y: CGFloat)?
    @ObservationIgnored private(set) var pinned = true
    @ObservationIgnored private var userScrolling = false
    @ObservationIgnored private var userDriven = false
    /// The last correction asked of the scroll view, so one layout pass does not repeat it per row.
    @ObservationIgnored private var lastRequest: (target: CGFloat, from: CGFloat)?
    @ObservationIgnored private var settleScheduled = false
    @ObservationIgnored private var settlePasses = 0
    @ObservationIgnored private var measureStart: CFTimeInterval?
    @ObservationIgnored private var lastMs = 0
    @ObservationIgnored let headerHeight = Metrics.headerHeight

    // MARK: Loading

    /// Generation starts as soon as the model exists, before the first frame is drawn.
    @ObservationIgnored private let generation = Task.detached(priority: .userInitiated) {
        FakeData.generate(size: .k50)
    }

    func load() async {
        guard dataset == nil else { return }
        if Self.trace { Self.print("load start +\(Int((CACurrentMediaTime() - Launch.start) * 1000))ms") }
        let data = await generation.value
        if Self.trace { Self.print("generated +\(Int((CACurrentMediaTime() - Launch.start) * 1000))ms") }
        dataset = data
        messages = data.messages
        var people: [Int: Person] = [:]
        for u in data.users { people[u.id] = Person(id: u.id, name: u.name) }
        builder = RowBuilder(people: people, currentUserID: data.currentUserID)
        measureStart = Launch.start
        pinned = true
        sizeAnchor = .bottom
        applyWindow(latestWindow())
        isLoaded = true
        if Self.trace { Self.print("rows built +\(Int((CACurrentMediaTime() - Launch.start) * 1000))ms") }
        scheduleSettle()
    }

    private var windowAtEnd: Bool { window.upperBound == messages.count }

    private func latestWindow() -> Range<Int> { max(0, messages.count - Self.pageSize)..<messages.count }

    private func makeRow(at index: Int) -> RowModel {
        let m = messages[index]
        return builder!.row(for: m, after: index > 0 ? messages[index - 1] : nil, extraBoosts: extraBoosts[m.id] ?? [])
    }

    /// Replaces the loaded range, reusing rows that stay loaded.
    private func applyWindow(_ new: Range<Int>) {
        let old = window
        var result: [RowModel] = []
        result.reserveCapacity(new.count)
        for i in new {
            result.append(old.contains(i) ? rows[i - old.lowerBound] : makeRow(at: i))
        }
        window = new
        rows = result
        if showsWelcome != (new.lowerBound == 0) { showsWelcome = new.lowerBound == 0 }
        let ids = Set(result.map(\.id))
        visible = visible.filter { ids.contains($0) }
    }

    private func index(of id: Int) -> Int? {
        let guess = id - 1
        if guess >= 0, guess < messages.count, messages[guess].id == id { return guess }
        return messages.firstIndex { $0.id == id }
    }

    // MARK: Paging

    func loadOlder() {
        guard isLoaded, window.lowerBound > 0 else { return }
        captureAnchorIfNeeded()
        if pinned, let top = topRow() {
            // Hold the row in view still rather than the bottom edge: the lazy stack's bottom moves with its
            // estimates for the rows coming in. Pinned again once it settles, if still at the bottom.
            anchor = (top.id, top.y)
            pinned = false
            repinAfterSettle = true
        }
        sizeAnchor = .bottom
        if Self.trace, let t = topRow() { Self.print("loadOlder before top=\(t.id) y=\(t.y)") }
        applyWindow(max(0, window.lowerBound - Self.pageSize)..<window.upperBound)
        scheduleSettle()
    }

    private func loadNewer() {
        guard isLoaded, !windowAtEnd else { return }
        captureAnchorIfNeeded()
        sizeAnchor = .top
        applyWindow(window.lowerBound..<min(messages.count, window.upperBound + Self.pageSize))
        scheduleSettle()
    }

    /// Drops rows from the end away from the reader once well over the cap: one edge per pass so the
    /// scroll view's size anchor keeps everything on screen still.
    private func trimIfNeeded() -> Bool {
        guard rows.count > Self.maxLoaded + Self.trimSlack else { return false }
        let excess = rows.count - Self.maxLoaded
        let keepNewest: Bool
        if pinned {
            keepNewest = true
        } else if let a = anchor, let i = rows.firstIndex(where: { $0.id == a.id }) {
            keepNewest = i >= rows.count / 2
        } else {
            keepNewest = true
        }
        if keepNewest {
            sizeAnchor = .bottom
            applyWindow((window.lowerBound + excess)..<window.upperBound)
        } else {
            sizeAnchor = .top
            applyWindow(window.lowerBound..<(window.upperBound - excess))
        }
        return true
    }

    // MARK: Live feed

    func startStream() {
        guard streamTask == nil, let dataset else { return }
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                self?.handle(event)
            }
            self?.streamDone = true
        }
    }

    private func handle(_ event: FeedEvent) {
        switch event {
        case .message(let m):
            appendLive(m)
        case .boost(let messageID, let b):
            guard let builder else { return }
            addBoost(BoostItem(id: "b\(b.id)", booster: builder.person(b.boosterID), content: b.content), to: messageID)
        case .typingStarted, .typingStopped:
            break
        }
    }

    private func appendLive(_ m: Message) {
        let wasAtEnd = windowAtEnd
        messages.append(m)
        guard wasAtEnd else { scheduleSettle(); return }
        if pinned || rows.count < Self.maxLoaded {
            captureAnchorIfNeeded()
            sizeAnchor = pinned ? .bottom : .top
            window = window.lowerBound..<messages.count
            rows.append(makeRow(at: messages.count - 1))
        } else {
            updateJumpButton()
        }
        scheduleSettle()
    }

    private func addBoost(_ boost: BoostItem, to messageID: Int) {
        extraBoosts[messageID, default: []].append(boost)
        guard let i = index(of: messageID), window.contains(i) else { return }
        captureAnchorIfNeeded()
        if pinned {
            sizeAnchor = .bottom
        } else if let f = frames[messageID], f.maxY <= metrics.visibleTop + headerHeight {
            sizeAnchor = .bottom
        } else {
            sizeAnchor = .top
        }
        rows[i - window.lowerBound].boosts.append(boost)
        scheduleSettle()
    }

    // MARK: Selection

    func beginSelection(rowID: Int) {
        guard rows.contains(where: { $0.id == rowID }) else { return }
        selectedText = ""
        selection = MessageSelection(rowID: rowID)
    }

    /// What the system selection currently covers in the selected message's editor.
    func updateSelectedText(_ text: String) {
        selectedText = text
    }

    func clearSelection() {
        if selection != nil { selection = nil }
    }

    /// Whether a point in the list's content falls on the selected message.
    func selectionContains(_ point: CGPoint) -> Bool {
        guard let selection, let f = frames[selection.rowID] else { return false }
        return f.contains(point)
    }

    /// The range picked in the editor, or the whole message when nothing is picked.
    var textToCopy: String {
        guard let selection, let row = rows.first(where: { $0.id == selection.rowID }) else { return "" }
        return selectedText.isEmpty ? row.copyText : selectedText
    }

    func copySelection() {
        Pasteboard.copy(textToCopy)
        clearSelection()
    }

    // MARK: Debug bar

    func reset() {
        beginMeasure()
        typeSizeOverride = nil
        applyWindow(latestWindow())
        clearSelection()
        // Like a jump to the newest message (its top cannot reach the header, so the scroll stops at the
        // bottom), then pinned. Going there by row works from anywhere; leaning on the bottom edge does not
        // when rows above have just been dropped, as the lazy stack's estimate for them moves the edge.
        pinned = false
        anchor = rows.last.map { ($0.id, 0) }
        sizeAnchor = .top
        lastRequest = nil
        scrollToAnchorRow = true
        pinAfterSettle = true
        reconcile()
        scheduleSettle()
    }

    func jump(to id: Int) {
        beginMeasure()
        guard let i = index(of: id) else { return }
        pinned = false
        anchor = (id, 0)
        sizeAnchor = .top
        applyWindow(max(0, i - Self.pageSize)..<min(messages.count, i + Self.pageSize + 1))
        lastRequest = nil
        scrollToAnchorRow = true
        reconcile()
        updateJumpButton()
        scheduleSettle()
    }

    func debugLoadOlder() {
        beginMeasure()
        loadOlder()
        scheduleSettle()
    }

    func increaseTextSize() {
        beginMeasure()
        captureAnchorIfNeeded()
        let current = typeSizeOverride ?? systemTypeSize
        let all = DynamicTypeSize.allCases
        if let i = all.firstIndex(of: current), i + 1 < all.count {
            typeSizeOverride = all[i + 1]
        } else {
            typeSizeOverride = .large
        }
        sizeAnchor = pinned ? .bottom : .top
        scheduleSettle()
    }

    func boostBurst() {
        guard let builder, let target = messages.last?.id else { return }
        burstTask?.cancel()
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        burstTask = Task { [weak self] in
            for k in 0..<5 {
                if k > 0 { try? await Task.sleep(for: .milliseconds(200)) }
                guard let self, !Task.isCancelled else { return }
                self.burstSerial += 1
                self.addBoost(BoostItem(id: "burst\(self.burstSerial)", booster: builder.person(k + 2), content: emoji[k]),
                              to: target)
            }
        }
    }

    func jumpToBottom() {
        pinned = true
        anchor = nil
        sizeAnchor = .bottom
        if !windowAtEnd { applyWindow(latestWindow()) }
        requestScroll(y: nil, animated: true)
        updateJumpButton()
        scheduleSettle()
    }

    private func beginMeasure() { measureStart = CACurrentMediaTime() }

    // MARK: Scroll tracking

    func scrollMetricsChanged(_ m: ScrollMetrics) {
        let resized = m.containerWidth != metrics.containerWidth || m.containerHeight != metrics.containerHeight
        if Self.trace { Self.print("metrics \(m.offsetY) content=\(m.contentHeight) scrolling=\(userScrolling)") }
        metrics = m
        if userScrolling && !resized {
            guard userDriven else { return }
            if Self.trace, let t = topRow() { Self.print("scroll top=\(t.id) y=\(t.y) offset=\(m.offsetY) content=\(m.contentHeight) rows=\(rows.count)") }
            trackUserScroll()
        } else {
            if resized {
                sizeAnchor = pinned ? .bottom : .top
                // Every row re-lays out at the new width and the anchored one may leave the realized range:
                // go to it by id again, as for a jump, then place it exactly.
                if !pinned, anchor != nil {
                    scrollToAnchorRow = true
                    lastRequest = nil
                }
            }
            reconcile()
            scheduleSettle()
        }
    }

    func scrollPhaseChanged(_ phase: ScrollPhase) {
        let wasScrolling = userScrolling
        if Self.trace { Self.print("phase \(phase)") }
        userScrolling = phase != .idle
        // A finger moved it (not an animation of ours or the system's, as in a rotation): only then is what
        // ends up on screen the reader's choice to remember.
        if phase == .tracking || phase == .interacting || phase == .decelerating { userDriven = true }
        if phase == .idle && wasScrolling {
            if userDriven { trackUserScroll() }
            userDriven = false
            scheduleSettle()
        }
    }

    func rowFrameChanged(_ id: Int, _ frame: CGRect) {
        frames[id] = frame
        rowWidth = frame.width
        if !userScrolling { reconcile() }
        scheduleSettle()
    }

    func rowVisibilityChanged(_ id: Int, _ isVisible: Bool) {
        if isVisible { visible.insert(id) } else { visible.remove(id) }
        scheduleSettle()
    }

    /// The reader moved: remember what they are looking at and whether they are at the bottom.
    private func trackUserScroll() {
        guard isLoaded else { return }
        if Self.trace { Self.print("trackUserScroll") }
        if let top = topRow() { anchor = (top.id, top.y) }
        let distance = metrics.contentHeight - metrics.visibleBottom
        pinned = windowAtEnd && distance <= Self.pinDistance
        sizeAnchor = pinned ? .bottom : .top
        updateJumpButton()
        if metrics.visibleTop < Self.loadMoreDistance, window.lowerBound > 0 {
            // Rows added above while the scroll view is moving would shift what is on screen (it keeps
            // its offset mid-fling), so older pages load once it comes to rest.
            if !userScrolling { loadOlder() }
        } else if distance < Self.loadMoreDistance, !windowAtEnd {
            loadNewer()
        }
    }

    private func captureAnchorIfNeeded() {
        if !pinned, anchor == nil, let top = topRow() { anchor = (top.id, top.y) }
    }

    private func updateJumpButton() {
        let show = !pinned
        if showsJumpButton != show { showsJumpButton = show }
    }

    /// A frame reported at the rows' present width (one from before a rotation is stale). Every row spans
    /// the list, so the latest report gives the width.
    private func isCurrent(_ f: CGRect) -> Bool {
        abs(f.width - rowWidth) < 1
    }

    /// The first row at least partly below the header, and its top relative to the header's bottom.
    private func topRow() -> (id: Int, y: CGFloat)? {
        let limit = metrics.visibleTop + headerHeight
        // Only realized rows have frames; the topmost one reaching below the header is the answer.
        // Rows showing less than half a point below the header (pixel rounding) count as hidden.
        var best: (id: Int, minY: CGFloat)?
        for id in visible {
            guard let f = frames[id], f.maxY > limit + 0.5, f.height > 0, isCurrent(f) else { continue }
            if best == nil || f.minY < best!.minY { best = (id, f.minY) }
        }
        guard let best else { return nil }
        return (best.id, best.minY - limit)
    }

    /// Puts the pinned bottom or the anchored row back where it belongs. Returns true when already there.
    @discardableResult
    private func reconcile() -> Bool {
        guard isLoaded, !userScrolling, metrics.containerHeight > 0 else { return true }
        var target: CGFloat
        if pinned {
            target = metrics.maxOffset
        } else if let a = anchor, !scrollToAnchorRow, visible.contains(a.id), let f = frames[a.id], isCurrent(f) {
            target = min(max(metrics.minOffset, f.minY - headerHeight - a.y - metrics.insetTop), metrics.maxOffset)
        } else if let a = anchor {
            // Not realized yet. After a jump: bring it on screen first, then a later pass places it exactly.
            // Otherwise its new frame is on the way.
            if scrollToAnchorRow {
                scrollToAnchorRow = false
                scrollSerial += 1
                scrollRequest = ScrollRequest(serial: scrollSerial, y: nil, rowID: a.id, animated: false)
            }
            return false
        } else {
            return true
        }
        target = (target * 3).rounded() / 3  // the scroll view snaps to pixels anyway
        if abs(target - metrics.offsetY) <= 0.25 { return true }
        if let last = lastRequest, abs(last.target - target) < 0.01, last.from == metrics.offsetY { return false }
        lastRequest = (target, metrics.offsetY)
        // ScrollPosition measures y from the inset edge, so offset -insetTop is y 0.
        if Self.trace { Self.print("scrollTo target=\(target) offset=\(metrics.offsetY) pinned=\(pinned) anchor=\(String(describing: anchor)) content=\(metrics.contentHeight)") }
        requestScroll(y: target + metrics.insetTop, animated: false)
        return false
    }

    private func requestScroll(y: CGFloat?, animated: Bool) {
        scrollSerial += 1
        scrollRequest = ScrollRequest(serial: scrollSerial, y: y, animated: animated)
    }

    private func scheduleSettle() {
        guard !settleScheduled else { return }
        settleScheduled = true
        DispatchQueue.main.async { [weak self] in self?.settle() }
    }

    /// Runs after SwiftUI has laid out and committed a change: corrects the position, trims, then reports.
    private func settle() {
        settleScheduled = false
        if Self.trace { Self.print("settle passes=\(settlePasses) m=\(metrics)") }
        guard isLoaded else { return }
        let placed = reconcile()
        let anchored = pinned || anchor.map { visible.contains($0.id) && frames[$0.id].map(isCurrent) == true } ?? true
        let ready = !rows.isEmpty && !visible.isEmpty && anchored && metrics.containerHeight > 0
        if (!placed || !ready) && settlePasses < 20 {
            settlePasses += 1
            if settlePasses == 10, !pinned, let a = anchor, !visible.contains(a.id) {
                scrollToAnchorRow = true  // the scroll to it did not land; once more
            }
            scheduleSettle()
            return
        }
        settlePasses = 0
        if pinAfterSettle {
            pinAfterSettle = false
            pinned = true
            anchor = nil
            sizeAnchor = .bottom
            updateJumpButton()
            if !reconcile() {
                scheduleSettle()
                return
            }
        }
        if repinAfterSettle {
            repinAfterSettle = false
            if windowAtEnd && metrics.contentHeight - metrics.visibleBottom <= Self.pinDistance {
                pinned = true
                anchor = nil
                sizeAnchor = .bottom
            }
            updateJumpButton()
        }
        if !userScrolling, trimIfNeeded() {
            scheduleSettle()
            return
        }
        if let start = measureStart {
            lastMs = max(0, Int(((CACurrentMediaTime() - start) * 1000).rounded(.down)))
            measureStart = nil
        }
        refreshLabel()
    }

    private func refreshLabel() {
        let first = rows.first?.id ?? 0
        let last = rows.last?.id ?? 0
        let top = topRow()
        var y = top.map { ($0.y * 10).rounded() / 10 } ?? 0
        if y == 0 { y = 0 }  // no "-0.0"
        let label = "first \(first) last \(last) loaded \(rows.count) pinned \(pinned ? "yes" : "no") "
            + "top \(top?.id ?? 0) y \(String(format: "%.1f", y)) ms \(lastMs)"
        if label != stateLabel { stateLabel = label }
        if Self.trace { Self.print("LABEL " + label) }
    }
}
