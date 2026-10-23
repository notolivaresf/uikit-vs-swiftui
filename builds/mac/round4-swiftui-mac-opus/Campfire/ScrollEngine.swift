import SwiftUI
import QuartzCore
import CampfireKit

/// What the room holds still across a change: the bottom (pinned), or a row's top at a distance from the
/// header's bottom edge.
enum ScrollAnchor: Equatable {
    case pinned
    case row(MessageID, y: CGFloat)
    /// The reader moved to rows that are not laid out yet; the anchor is read once they are.
    case free
}

/// Keeps the room where the reader left it. It watches the scroll geometry and every row's frame; when
/// the layout changes (rows added, rows growing, text size, window size) it scrolls so the anchor is where
/// it was; when the reader scrolls it re-reads the anchor.
@MainActor
@Observable
final class ScrollEngine {
    enum ScrollCommand {
        case bottom
        case offset(CGFloat)
        /// Align the row's view so that its point at `anchor` (a fraction of its height) meets the viewport's
        /// point at the same fraction of the viewport's height.
        case row(MessageID, anchor: CGFloat)
    }
    /// Set by the view: moves its ScrollPosition.
    @ObservationIgnored var scroller: ((ScrollCommand) -> Void)?
    /// How SwiftUI itself should hold the content while it changes size (it avoids a frame of drift).
    var sizeAnchor: UnitPoint = .bottom
    private(set) var pinned = true
    private(set) var stateLabel = ""
    private(set) var lastMs = 0

    @ObservationIgnored let store: ChatStore
    @ObservationIgnored private(set) var anchor: ScrollAnchor = .pinned
    @ObservationIgnored private var frames: [MessageID: CGRect] = [:]
    @ObservationIgnored private var geometry: ScrollGeometry?
    @ObservationIgnored private var lastCommandAt: CFTimeInterval = 0
    /// Where our last scroll command should land (nil: unknown, such as a jump to a row not laid out yet).
    @ObservationIgnored private var expectedOffset: CGFloat?

    private func isOwnLanding(_ y: CGFloat) -> Bool {
        if let e = expectedOffset, abs(y - e) < 1 { return true }
        return CACurrentMediaTime() - lastCommandAt < 0.05
    }

    @ObservationIgnored private var phase: ScrollPhase = .idle
    /// Trackpad and mouse-wheel scrolls report a phase; scroll-bar drags do not.
    private var userIsScrolling: Bool { phase != .idle && phase != .animating }

    func phaseChanged(to new: ScrollPhase) {
        phase = new
        if new == .idle { refreshLabel() }
    }

    @ObservationIgnored private var pagingInFlight = false
    @ObservationIgnored private var requestedRow: MessageID?
    @ObservationIgnored var headerHeight: CGFloat = Metrics.headerHeight

    static let pinThreshold: CGFloat = 100
    static let pagingThreshold: CGFloat = 800

    init(store: ChatStore) {
        self.store = store
        makeLiveAtBottom()
    }

    // MARK: Virtualization

    /// Rows with ids in this range are real views; the others are spacers of their known or estimated height.
    private(set) var liveLow: MessageID = .max
    private(set) var liveHigh: MessageID = .min
    /// The live range runs to the newest loaded row, so rows arriving at the bottom are live at once.
    @ObservationIgnored private var liveToEnd = true
    @ObservationIgnored private var measured: [MessageID: (height: CGFloat, scale: CGFloat, width: CGFloat, boosts: Int)] = [:]
    @ObservationIgnored private let estimator = HeightEstimator()
    /// Height of what sits above the first row (the welcome card, or room under the header).
    @ObservationIgnored var leadHeight: CGFloat = Metrics.headerHeight
    @ObservationIgnored private var contentWidth: CGFloat { geometry?.containerSize.width ?? 393 }

    func isLive(_ id: MessageID) -> Bool {
        id >= liveLow && (id <= liveHigh || (liveToEnd && id >= liveHigh))
    }

    /// A row's height including the space above it, as laid out (measured) or as estimated.
    func height(of row: RowModel, isFirst: Bool) -> CGFloat {
        let m = Metrics(s: store.textScale)
        let gap = MessageRow.gap(for: row, isFirst: isFirst, metrics: m)
        let width = contentWidth
        if let h = measured[row.id], h.boosts == row.message.boosts.count {
            if h.scale == m.s && abs(h.width - width) < 0.5 { return h.height + gap }
            // Laid out before at another text size or width: scaling that is close and costs nothing.
            if abs(h.width - width) < 0.5 { return h.height * m.s / h.scale + gap }
        }
        return estimator.height(of: row, isFirst: isFirst, metrics: m, width: width, store: store)
    }

    @ObservationIgnored private var measureRevision = 0
    @ObservationIgnored private var topsCache: (key: [CGFloat], tops: [CGFloat])?

    /// Top of every row in content coordinates (including the space above it), plus the content's end.
    private func rowTops() -> [CGFloat] {
        let key: [CGFloat] = [CGFloat(store.version), store.textScale, contentWidth, CGFloat(measureRevision), leadHeight,
                              CGFloat(store.rows.count)]
        if let c = topsCache, c.key == key { return c.tops }
        var tops: [CGFloat] = []
        tops.reserveCapacity(store.rows.count + 1)
        var y = leadHeight
        for (i, row) in store.rows.enumerated() {
            tops.append(y)
            y += height(of: row, isFirst: i == 0)
        }
        tops.append(y)
        topsCache = (key, tops)
        return tops
    }

    /// The live rows and the spacers standing in for the rows above and below them.
    func liveSlice() -> (above: CGFloat, rows: ArraySlice<RowModel>, below: CGFloat) {
        let rows = store.rows
        guard !rows.isEmpty, let lo = index(of: max(liveLow, rows[0].id)) else { return (0, [], 0) }
        let hiID = liveToEnd ? rows[rows.count - 1].id : min(liveHigh, rows[rows.count - 1].id)
        guard let hi = index(of: hiID), hi >= lo else { return (0, [], 0) }
        let tops = rowTops()
        return (tops[lo] - tops[0], rows[lo...hi], tops[rows.count] - tops[hi + 1])
    }

    /// Index of a loaded row: loaded ids are contiguous.
    private func index(of id: MessageID) -> Int? {
        guard let first = store.rows.first?.id else { return nil }
        let i = id - first
        return store.rows.indices.contains(i) ? i : nil
    }

    /// Makes the rows near the viewport live, with a margin either side so scrolling finds them ready.
    func updateLiveRange(force: Bool = false) {
        guard let g = geometry, !store.rows.isEmpty, requestedRow == nil else { return }
        let viewport = max(g.containerSize.height, 300)
        let top = offset, bottom = offset + viewport
        let rows = store.rows
        let tops = rowTops()
        func indexRange(_ lo: CGFloat, _ hi: CGFloat) -> ClosedRange<Int> {
            var a = 0
            while a < rows.count - 1 && tops[a + 1] <= lo { a += 1 }
            var b = a
            while b < rows.count - 1 && tops[b + 1] < hi { b += 1 }
            return a...b
        }
        let want = indexRange(top - viewport, bottom + viewport)
        if !force, liveLow != .max {
            let need = indexRange(top - viewport * 0.4, bottom + viewport * 0.4)
            let covered = isLive(rows[need.lowerBound].id) && isLive(rows[need.upperBound].id)
            // Also let go of rows that have drifted far out of view (rows keep arriving while pinned).
            let liveCount = (index(of: liveToEnd ? rows[rows.count - 1].id : liveHigh) ?? 0)
                - (index(of: max(liveLow, rows[0].id)) ?? 0) + 1
            if covered && liveCount <= want.count + 12 { return }
        }
        setLive(rows[want.lowerBound].id, rows[want.upperBound].id)
    }

    private func setLive(_ low: MessageID, _ high: MessageID) {
        let toEnd = high == store.rows.last?.id
        if liveLow != low { liveLow = low }
        if liveHigh != high { liveHigh = high }
        liveToEnd = toEnd
    }

    /// Before scrolling to a row that may be a spacer: make it and its neighbourhood live.
    private func makeLive(around id: MessageID) {
        let rows = store.rows
        guard let i = index(of: id) else { return }
        let viewport = max(geometry?.containerSize.height ?? 800, 300)
        let tops = rowTops()
        var a = i, b = i
        while a > 0 && tops[i] - tops[a] < viewport { a -= 1 }
        while b < rows.count - 1 && tops[b + 1] - tops[i] < viewport * 2 { b += 1 }
        setLive(rows[a].id, rows[b].id)
    }

    /// The newest rows, enough to fill the viewport twice over.
    private func makeLiveAtBottom() {
        let rows = store.rows
        guard !rows.isEmpty else { return }
        let viewport = max(geometry?.containerSize.height ?? 800, 300)
        let tops = rowTops()
        var a = rows.count - 1
        while a > 0 && tops[rows.count] - tops[a] < viewport * 2 { a -= 1 }
        setLive(rows[a].id, rows[rows.count - 1].id)
    }

    // MARK: Inputs from the view

    /// Live rows that are in the view hierarchy now. Counted, because a row can appear again before its old
    /// appearance's disappear arrives.
    @ObservationIgnored private var realized: [MessageID: Int] = [:]

    func rowAppeared(_ id: MessageID) {
        realized[id, default: 0] += 1
        scheduleLabelRefresh()
    }

    @ObservationIgnored private var labelRefreshScheduled = false

    /// Coalesces label updates from many row callbacks into one per run loop pass.
    private func scheduleLabelRefresh() {
        guard !labelRefreshScheduled else { return }
        labelRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.labelRefreshScheduled = false
            self.refreshLabel()
        }
    }

    func rowDisappeared(_ id: MessageID) {
        let n = (realized[id] ?? 0) - 1
        realized[id] = n > 0 ? n : nil
    }

    func rowFrameChanged(_ id: MessageID, _ frame: CGRect) {
        if let i = index(of: id) {
            let row = store.rows[i]
            let value = (frame.height, store.textScale, contentWidth, row.message.boosts.count)
            if let old = measured[id], old == value {} else {
                measured[id] = value
                measureRevision &+= 1
            }
        }
        let old = frames[id]
        frames[id] = frame
        scheduleLabelRefresh()
        guard old != frame else { return }
        noteLayout()
        if case .row(let anchorID, _) = anchor, anchorID == id {
            restore()
        } else if anchor == .free {
            readAnchor()
        }
    }

    func geometryChanged(from old: ScrollGeometry, to new: ScrollGeometry) {
        geometry = new
        let layoutChanged = old.contentSize != new.contentSize || old.containerSize != new.containerSize
        if userIsScrolling {
            // The reader is in control: what they look at is the anchor, judged against the content as it was
            // before this pass (so rows arriving below do not count as having scrolled away from the bottom).
            let oldBottom = old.contentSize.height + old.contentInsets.bottom - old.containerSize.height
            if oldBottom - new.contentOffset.y <= Self.pinThreshold {
                anchor = .pinned
            } else if let (id, y) = topRow() {
                anchor = .row(id, y: y)
            } else {
                anchor = .free
            }
            setPinned(anchor == .pinned)
            if layoutChanged {
                noteLayout()
                restore()
            }
            considerPaging()
        } else if layoutChanged || requestedRow != nil {
            if layoutChanged { noteLayout() }
            restore()
        } else if isOwnLanding(new.contentOffset.y) {
            // Our own scroll landing (possibly in steps): keep holding the anchor.
            restore()
        } else {
            // Moved by the scroll bar, the keyboard or anything else that is not us: the reader's choice.
            readAnchor()
            considerPaging()
        }
        updateLiveRange()
        refreshLabel()
    }

    // MARK: Anchor

    private var offset: CGFloat { geometry?.contentOffset.y ?? 0 }

    private var maxOffset: CGFloat {
        guard let g = geometry else { return 0 }
        return max(-g.contentInsets.top, g.contentSize.height + g.contentInsets.bottom - g.containerSize.height)
    }

    private var distanceFromBottom: CGFloat { maxOffset - offset }
    var bottomOffset: CGFloat { maxOffset }

    /// Reads the anchor from what is on screen now (after the reader scrolled).
    private func readAnchor() {
        if distanceFromBottom <= Self.pinThreshold {
            anchor = .pinned
        } else if let (id, y) = topRow() {
            anchor = .row(id, y: y)
        } else {
            anchor = .free
        }
        setPinned(anchor == .pinned)
    }

    private func setPinned(_ value: Bool) {
        if pinned != value { pinned = value }
        let wanted: UnitPoint = value ? .bottom : .top
        if !pagingInFlight, sizeAnchor != wanted { sizeAnchor = wanted }
    }

    /// The first row at least partly visible below the header, and its top relative to the header's bottom.
    /// Live rows report their frames; the row on top is nearly always one of them.
    func topRow() -> (MessageID, CGFloat)? {
        let line = offset + headerHeight
        // A row's last 1.6 pt is empty margin (a threaded row below tucks into it), so it does not count.
        let margin = Metrics(s: store.textScale).bubbleBottom
        var best: (MessageID, CGRect)?
        for (id, f) in frames where realized[id] != nil && f.maxY - margin > line + 0.01 {
            if best == nil || f.minY < best!.1.minY || (f.minY == best!.1.minY && id < best!.0) { best = (id, f) }
        }
        let visibleBelowHeader = (geometry?.containerSize.height ?? 0) - headerHeight
        if let best, store.isLoaded(best.0), best.1.minY - line < visibleBelowHeader {
            // A row just above it that is not a real view yet (still a spacer) may be the one on top.
            if best.1.minY > line + 0.01, let i = index(of: best.0), i > 0, realized[store.rows[i - 1].id] == nil,
               let fromSpacers = topRowFromLayout(line: line, margin: margin) {
                return fromSpacers
            }
            return (best.0, best.1.minY - line)
        }
        // Right after a long jump only rows far away may be laid out; the spacers' geometry is exact too.
        return topRowFromLayout(line: line, margin: margin)
    }

    /// The top row from the stack's own layout (spacer heights are the rows' measured or estimated heights).
    private func topRowFromLayout(line: CGFloat, margin: CGFloat) -> (MessageID, CGFloat)? {
        let rows = store.rows
        guard !rows.isEmpty, geometry != nil else { return nil }
        let tops = rowTops()
        let m = Metrics(s: store.textScale)
        for i in rows.indices {
            let nextGap = i + 1 < rows.count ? MessageRow.gap(for: rows[i + 1], isFirst: false, metrics: m) : 0
            let bottom = tops[i + 1] - nextGap
            if bottom - margin > line + 0.01 {
                let top = tops[i] + MessageRow.gap(for: rows[i], isFirst: i == 0, metrics: m)
                let visibleBelowHeader = (geometry?.containerSize.height ?? 0) - headerHeight
                return top - line < visibleBelowHeader ? (rows[i].id, top - line) : nil
            }
        }
        return nil
    }

    /// Scrolls so the anchor is where it should be.
    func restore() {
        guard let g = geometry else { return }
        switch anchor {
        case .free:
            readAnchor()
        case .pinned:
            if abs(distanceFromBottom) > 0.25 {
                expectedOffset = maxOffset
                noteScroll()
                scroller?(.bottom)
            }
        case .row(let id, let y):
            guard store.isLoaded(id) else { return }
            guard let f = frames[id], realized[id] != nil else {
                // Still a spacer: make it live and bring it up; its frame then arrives and the next pass refines.
                if requestedRow != id {
                    requestedRow = id
                    expectedOffset = nil
                    makeLive(around: id)
                    noteScroll()
                    scroller?(.row(id, anchor: 0))
                }
                return
            }
            requestedRow = nil
            let current = f.minY - offset - headerHeight
            // Clamp to what the content allows at its ends.
            let wantedOffset = min(max(f.minY - headerHeight - y, -g.contentInsets.top), maxOffset)
            if abs(wantedOffset - offset) > 0.25, abs(current - y) > 0.25 {
                // The content is a plain stack, so its coordinates are exact: scroll straight to the offset.
                expectedOffset = wantedOffset
                noteScroll()
                scroller?(.offset(wantedOffset))
            }
        }
        setPinned(anchor == .pinned)
    }

    func setAnchor(_ new: ScrollAnchor) {
        anchor = new
        setPinned(new == .pinned)
    }

    // MARK: Paging

    private func considerPaging() {
        guard !pagingInFlight, let g = geometry, g.contentSize.height > 0, !store.rows.isEmpty else { return }
        if offset < Self.pagingThreshold, store.hasOlder {
            page { $0.loadOlderKeepingPlace() }
        } else if distanceFromBottom < Self.pagingThreshold, store.hasNewer {
            page { $0.loadNewerKeepingPlace() }
        }
    }

    private func page(_ work: @escaping @MainActor (ScrollEngine) -> Void) {
        pagingInFlight = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            work(self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.pagingInFlight = false
                self.setPinned(self.anchor == .pinned)
            }
        }
    }

    /// Prepends a page; the row being read stays where it is.
    @discardableResult
    func loadOlderKeepingPlace() -> Bool {
        if anchor == .pinned, let (id, y) = topRow(), distanceFromBottom > 0.5 { anchor = .row(id, y: y) }
        sizeAnchor = .bottom
        return store.loadOlder()
    }

    @discardableResult
    func loadNewerKeepingPlace() -> Bool {
        if anchor == .pinned, let (id, y) = topRow() { anchor = .row(id, y: y) }
        sizeAnchor = .top
        return store.loadNewer()
    }

    /// Before a change that re-lays out every row: hold on to what the reader sees now.
    func captureAnchor() {
        guard geometry != nil else { return }
        if userIsScrolling { readAnchor() }
    }

    // MARK: Commands

    func reset() {
        store.showNewest()
        store.resetTextSize()
        pruneFrames()
        makeLiveAtBottom()
        setAnchor(.pinned)
        restore()
    }

    func jump(to id: MessageID) {
        store.showAround(id)
        pruneFrames()
        makeLive(around: id)
        setAnchor(.row(id, y: 0))
        sizeAnchor = .top
        requestedRow = id
        expectedOffset = nil
        noteScroll()
        scroller?(.row(id, anchor: 0))
    }

    func jumpToBottom() {
        if store.hasNewer {
            store.showNewest()
            pruneFrames()
        }
        makeLiveAtBottom()
        setAnchor(.pinned)
        restore()
    }

    /// After the slice is replaced wholesale, the old rows' frames mean nothing.
    private func pruneFrames() {
        guard store.generation != framesGeneration else { return }
        framesGeneration = store.generation
        frames.removeAll()
        realized.removeAll()
    }

    @ObservationIgnored private var framesGeneration = 0

    // MARK: Debug label and timing

    func refreshLabel() {
        let top = topRow()
        let topText = top.map { String($0.0) } ?? "-"
        let yText = top.map { String(format: "%.1f", Self.clean($0.1)) } ?? "0.0"
        let text = "first \(store.firstLoadedID ?? 0) last \(store.lastLoadedID ?? 0) loaded \(store.loadedCount) "
            + "pinned \(pinned ? "yes" : "no") top \(topText) y \(yText) ms \(lastMs)"
        if text != stateLabel { stateLabel = text }
    }

    private static func clean(_ v: CGFloat) -> CGFloat {
        let r = (v * 10).rounded() / 10
        return r == 0 ? 0 : r
    }

    /// Starts timing (at a debug-bar click's mouse up, or at launch). `expectLayout` says the work changes
    /// what is laid out, so the timing must wait for a layout pass.
    func beginMeasure(at start: CFTimeInterval, expectLayout: Bool, requireRows: Bool = false) {
        measureToken &+= 1
        let token = measureToken
        measure = Measure(start: start, expectLayout: expectLayout, requireRows: requireRows)
        layoutSinceMeasure = false
        installCommitObserver()
        // Make sure a run loop pass follows even if nothing else wakes it, and never wait forever.
        DispatchQueue.main.async {}
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.measureToken == token else { return }
            self.afterCommit(force: true)
        }
    }

    /// Times a debug-bar click: `start` is the mouse up; the work runs now; the time is taken once the
    /// result is laid out and committed.
    func measured(start: CFTimeInterval, _ work: () -> Void) {
        let version = store.version, step = store.textSizeStep
        scrolledThisPass = false
        work()
        beginMeasure(at: start, expectLayout: store.version != version || store.textSizeStep != step)
    }

    private struct Measure {
        let start: CFTimeInterval
        let expectLayout: Bool
        let requireRows: Bool
    }

    @ObservationIgnored private var measure: Measure?
    @ObservationIgnored private var measureToken = 0
    @ObservationIgnored private var layoutSinceMeasure = false
    @ObservationIgnored private var scrolledThisPass = false
    @ObservationIgnored private var observer: CFRunLoopObserver?

    private func noteLayout() { layoutSinceMeasure = true }
    private func noteScroll() {
        scrolledThisPass = true
        lastCommandAt = CACurrentMediaTime()
    }

    /// Runs on the main run loop after Core Animation has committed the pass's layout.
    private func installCommitObserver() {
        guard observer == nil else { return }
        let obs = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 2_100_000) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.afterCommit() }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), obs, .commonModes)
        observer = obs
    }

    private func afterCommit(force: Bool = false) {
        guard let m = measure else { return }
        defer { scrolledThisPass = false }
        if !force, m.requireRows && (geometry == nil || frames.isEmpty || anchor != .pinned || distanceFromBottom > 0.5) { return }
        if !force, m.expectLayout && !m.requireRows && !layoutSinceMeasure { return }
        if !force, scrolledThisPass { return }
        if !force, !store.rows.isEmpty, topRow() == nil { return }
        measure = nil
        lastMs = Int(((CACurrentMediaTime() - m.start) * 1000).rounded(.down))
        refreshLabel()
    }
}

func dlog(_ s: @autoclosure () -> String) {
    if debugLogging { fputs(s() + "\n", stderr) }
}
let debugLogging = ProcessInfo.processInfo.environment["CF_LOG"] != nil
