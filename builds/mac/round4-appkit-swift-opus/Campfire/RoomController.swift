import AppKit
import CampfireKit

/// Where the reader is: stuck to the bottom, or a row's top at some offset from the header's bottom edge.
enum Anchor {
    case pinned
    case row(MessageID, offset: CGFloat)
}

/// Owns the room: the loaded window of messages, their layout, scrolling, the live stream and the debug bar.
final class RoomController: NSObject {
    let benchmark: Bool
    let store: RoomStore
    let rootView = RootView()
    let scrollView = RoomScrollView()
    let documentView = RoomDocumentView()
    let header = HeaderView()
    let composer = ComposerView()
    let jumpButton = JumpButton()
    private(set) var debugBar: DebugBar?

    private(set) var items: [RowItem] = []
    private var scaleIndex = 0
    private var typography = Typography(scale: 1)
    private var layoutWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0
    private var adjusting = 0
    private var unseenNew = false
    private var lastMs = 0
    private var streamTask: Task<Void, Never>?
    private var streamStarted = false
    private var burstTimer: Timer?
    private var nextBoostID = 5_000_000
    private var placeholderCache: [MessageID: NSImage] = [:]
    private var stateUpdateScheduled = false
    private var loadScheduled = false

    init(benchmark: Bool) {
        self.benchmark = benchmark
        store = RoomStore()
        super.init()

        rootView.controller = self
        rootView.wantsLayer = true

        scrollView.controller = self
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: Metrics.headerHeight, left: 0, bottom: 0, right: 0)
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Palette.background
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        documentView.controller = self
        scrollView.documentView = documentView
        scrollView.contentView.postsBoundsChangedNotifications = true
        rootView.addSubview(scrollView)

        header.scrollTarget = scrollView
        rootView.addSubview(header)
        composer.scrollTarget = scrollView
        rootView.addSubview(composer)

        jumpButton.target = self
        jumpButton.action = #selector(jumpToBottom(_:))
        jumpButton.isHidden = true
        rootView.addSubview(jumpButton)

        if benchmark {
            let bar = DebugBar { [weak self] title in self?.debugClick(title) }
            rootView.addSubview(bar)
            debugBar = bar
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(boundsChanged(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        nc.addObserver(self, selector: #selector(liveScrollEnded(_:)), name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
        nc.addObserver(self, selector: #selector(scrollerStyleChanged(_:)), name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
    }

    // MARK: - Chrome layout

    func layoutChrome() {
        let b = rootView.bounds
        var top: CGFloat = 0
        if let bar = debugBar {
            bar.frame = CGRect(x: 0, y: 0, width: b.width, height: DebugBar.height)
            top = DebugBar.height
        }
        let composerTop = b.height - Metrics.composerHeight
        scrollView.frame = CGRect(x: 0, y: top, width: b.width, height: max(0, composerTop - top))
        header.frame = CGRect(x: 0, y: top, width: b.width, height: Metrics.headerHeight)
        composer.frame = CGRect(x: 0, y: composerTop, width: b.width, height: Metrics.composerHeight)
        jumpButton.frame = CGRect(x: b.width - 14 - 44, y: composerTop - 14 - 44, width: 44, height: 44)
    }

    @objc private func scrollerStyleChanged(_ n: Notification) {
        scrollView.scrollerStyle = .overlay
    }

    // MARK: - Geometry

    private var clip: NSClipView { scrollView.contentView }
    private var insetTop: CGFloat { scrollView.contentInsets.top }
    /// Document y of the header's bottom edge.
    private var headerBottomY: CGFloat { clip.bounds.origin.y + insetTop }
    private var visibleBottomY: CGFloat { clip.bounds.maxY }
    private var maxOriginY: CGFloat { max(-insetTop, documentView.frame.height - clip.bounds.height) }
    private var atNewest: Bool { items.last?.message.id == store.newestID }
    private var hasOlder: Bool { (items.first?.message.id ?? 0) > store.oldestID }
    private var isPinned: Bool { atNewest && contentHeight - visibleBottomY <= 100 }

    private func setOrigin(_ y: CGFloat) {
        let target = min(max(y, -insetTop), maxOriginY)
        adjusting += 1
        clip.setBoundsOrigin(NSPoint(x: 0, y: target))
        scrollView.reflectScrolledClipView(clip)
        adjusting -= 1
        documentView.tile()
    }

    private func scrollToBottom() { setOrigin(maxOriginY) }

    /// Indices of rows that intersect document y range `from...to`.
    func rowIndices(from: CGFloat, to: CGFloat) -> Range<Int> {
        guard !items.isEmpty else { return 0..<0 }
        let start = firstIndex { $0.bottom > from }
        var end = start
        while end < items.count, items[end].y < to { end += 1 }
        return start..<end
    }

    /// First index whose row satisfies a predicate that is false then true along the list.
    private func firstIndex(where pred: (RowItem) -> Bool) -> Int {
        var lo = 0, hi = items.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if pred(items[mid]) { hi = mid } else { lo = mid + 1 }
        }
        return lo
    }

    private func index(of id: MessageID) -> Int? {
        guard let first = items.first?.message.id else { return nil }
        let i = id - first
        if i >= 0, i < items.count, items[i].message.id == id { return i }
        return items.firstIndex { $0.message.id == id }
    }

    /// The topmost row at least partly visible below the header.
    private func topVisibleIndex() -> Int? {
        // A row counts from its top to its bubble's bottom: a threaded row starts 1.2 pt above the previous
        // row's frame bottom, inside that row's empty bottom margin.
        let i = firstIndex { $0.bottom - Metrics.bubbleBottomMargin > headerBottomY }
        guard i < items.count, items[i].y < visibleBottomY else { return nil }
        return i
    }

    // MARK: - Anchoring

    /// The last anchor restored and the clip origin it produced. The clip view rounds its origin to device
    /// pixels, so while nobody has scrolled since, the exact anchor is reused instead of re-measuring (no drift).
    private var lastRestored: (anchor: Anchor, originY: CGFloat)?

    func captureAnchor() -> Anchor? {
        guard !items.isEmpty, layoutWidth > 0 else { return nil }
        if isPinned { return .pinned }
        return rowAnchor()
    }

    private func rowAnchor() -> Anchor? {
        if let last = lastRestored, last.originY == clip.bounds.origin.y, case .row(let id, _) = last.anchor, index(of: id) != nil {
            return last.anchor
        }
        guard let i = topVisibleIndex() else { return items.isEmpty ? nil : .pinned }
        return .row(items[i].message.id, offset: items[i].y - headerBottomY)
    }

    private func restore(_ anchor: Anchor?) {
        switch anchor {
        case .row(let id, let offset)?:
            if let i = index(of: id) {
                setOrigin(items[i].y - offset - insetTop)
                lastRestored = (anchor!, clip.bounds.origin.y)
            } else {
                scrollToBottom()
            }
        case .pinned?, nil:
            scrollToBottom()
        }
    }

    // MARK: - Layout

    private var context: LayoutContext { LayoutContext(width: layoutWidth, typography: typography, store: store) }

    private func makeItems(_ messages: [Message]) -> [RowItem] {
        let ctx = context
        let pres = store.presentations(of: messages)
        return zip(messages, pres).map { m, p in
            let boosts = store.boosts(of: m)
            return RowItem(message: m, boosts: boosts, presentation: p, layout: RowLayoutBuilder.make(m, boosts: boosts, p, ctx))
        }
    }

    private func relayoutAll() {
        relayout(items.indices)
    }

    /// Lays out rows again for the current width and text size, then repositions all rows.
    private func relayout(_ range: Range<Int>) {
        layoutWidth = clip.bounds.width
        let ctx = context
        for i in range {
            items[i].layout = RowLayoutBuilder.make(items[i].message, boosts: items[i].boosts, items[i].presentation, ctx)
        }
        recomputePositions()
    }

    /// Rows laid out for another width or text size (left behind by a live resize).
    private var hasStaleRows: Bool {
        items.contains { $0.layout.width != layoutWidth || $0.layout.scale != typography.scale }
    }

    private func recomputePositions() {
        let gap = Metrics.gapBetweenRows
        let topSection: CGFloat = hasOlder ? 0 : Metrics.welcomeHeight
        var y = topSection + gap
        for i in items.indices {
            if i > 0 {
                y = items[i - 1].bottom + gap + (items[i].presentation.isThreaded ? Metrics.threadedMarginTop : 0)
            }
            items[i].y = y
        }
        contentHeight = items.last?.bottom ?? y
        updateDocumentSize()
        let width = clip.bounds.width
        documentView.welcome.isHidden = hasOlder
        documentView.welcome.frame = CGRect(x: 0, y: 0, width: width, height: Metrics.welcomeHeight)
    }

    private func updateDocumentSize() {
        let size = NSSize(width: clip.bounds.width, height: max(contentHeight, clip.bounds.height - insetTop))
        if documentView.frame.size != size {
            adjusting += 1
            documentView.setFrameSize(size)
            adjusting -= 1
        }
    }

    // MARK: - Lifecycle

    func start() {
        layoutChrome()
        items = makeItems(store.newestPage())
        relayoutAll()
        scrollToBottom()
    }

    func didShowWindow() {
        lastMs = commitFrame(since: launchStart)
        updateStateNow()
    }

    func scrollViewDidResize(anchor: Anchor?) {
        guard !items.isEmpty else { return }
        if clip.bounds.width == layoutWidth {
            recomputePositions()
        } else if scrollView.inLiveResize {
            // While the user drags, re-lay out only the rows around the viewport (the anchor keeps them in place);
            // the rest follow when the resize ends.
            let near = rowIndices(from: headerBottomY - 2000, to: visibleBottomY + 2000)
            let lo = max(0, near.lowerBound - 2), hi = min(items.count, near.upperBound + 2)
            relayout(lo..<hi)
            layoutWidth = clip.bounds.width
        } else {
            relayoutAll()
        }
        restore(anchor)
        scheduleStateUpdate()
    }

    func resizeEnded() {
        if hasStaleRows {
            let anchor = captureAnchor()
            relayoutAll()
            restore(anchor)
        }
        scheduleStateUpdate()
    }

    /// Keeps at most `Windowing.maxLoaded` rows (Campfire trims once 20 over), dropping only rows far outside
    /// the viewport, from the end away from the reader.
    private func trimIfNeeded(dropOldest: Bool) {
        let limit = Windowing.maxLoaded
        guard items.count > limit + 20 else { return }
        let excess = items.count - limit
        let anchor = captureAnchor()
        if dropOldest {
            let farAbove = firstIndex { $0.bottom > headerBottomY - 1500 }
            let n = min(excess, farAbove)
            guard n > 0 else { return }
            items.removeFirst(n)
        } else {
            let farBelow = items.count - firstIndex { $0.y > visibleBottomY + 1500 }
            let n = min(excess, farBelow)
            guard n > 0 else { return }
            items.removeLast(n)
        }
        recomputePositions()
        restore(anchor)
    }

    // MARK: - Scrolling

    @objc private func boundsChanged(_ n: Notification) {
        documentView.tile()
        guard adjusting == 0 else { return }
        if isPinned { unseenNew = false }
        updateJumpButton()
        scheduleStateUpdate()
        maybeLoadMore()
    }

    @objc private func liveScrollEnded(_ n: Notification) { scheduleStateUpdate() }

    private func maybeLoadMore() {
        guard !loadScheduled, let first = items.first else { return }
        let nearTop = hasOlder && headerBottomY < first.y + 200
        let nearBottom = !atNewest && contentHeight - visibleBottomY < 200
        guard nearTop || nearBottom else { return }
        loadScheduled = true
        DispatchQueue.main.async {
            self.loadScheduled = false
            if nearTop { self.loadOlder() } else { self.loadNewer() }
        }
    }

    func loadOlder() {
        guard let first = items.first else { return }
        let older = store.page(before: first.message.id)
        guard !older.isEmpty else { return }
        let anchor = rowAnchor()
        items.insert(contentsOf: makeItems(older), at: 0)
        recomputePositions()
        restore(anchor)
        trimIfNeeded(dropOldest: false)
        updateJumpButton()
        scheduleStateUpdate()
    }

    private func loadNewer() {
        guard let last = items.last else { return }
        let newer = store.page(after: last.message.id)
        guard !newer.isEmpty else { return }
        let anchor = rowAnchor()
        items.append(contentsOf: makeItems(newer))
        recomputePositions()
        restore(anchor)
        trimIfNeeded(dropOldest: true)
        updateJumpButton()
        scheduleStateUpdate()
    }

    private func updateJumpButton() {
        jumpButton.isHidden = isPinned || !(unseenNew || !atNewest)
    }

    @objc private func jumpToBottom(_ sender: Any?) {
        if !atNewest {
            items = makeItems(store.newestPage())
            recomputePositions()
        }
        unseenNew = false
        scrollToBottom()
        updateJumpButton()
        scheduleStateUpdate()
    }

    // MARK: - Commands

    func reset() {
        scaleIndex = 0
        typography = Typography(scale: Typography.scales[0])
        items = makeItems(store.newestPage())
        relayoutAll()
        unseenNew = false
        scrollToBottom()
        updateJumpButton()
    }

    func jump(to id: MessageID) {
        let page = store.page(around: id)
        guard !page.isEmpty else { return }
        items = makeItems(page)
        recomputePositions()
        restore(.row(id, offset: 0))
        updateJumpButton()
    }

    func changeTextSize(by delta: Int, wrap: Bool = false) {
        let n = Typography.scales.count
        let next = wrap ? (scaleIndex + delta + n) % n : min(max(scaleIndex + delta, 0), n - 1)
        setTextSize(index: next)
    }

    func resetTextSize() { setTextSize(index: 0) }

    private func setTextSize(index: Int) {
        guard index != scaleIndex else { return }
        let anchor = captureAnchor()
        scaleIndex = index
        typography = Typography(scale: Typography.scales[index])
        relayoutAll()
        restore(anchor)
        scheduleStateUpdate()
    }

    // MARK: - Live

    private func startStream() {
        guard !streamStarted else { return }
        streamStarted = true
        let stream = FakeLiveFeed(dataset: store.dataset).play()
        streamTask = Task { @MainActor [weak self] in
            for await event in stream { self?.handle(event) }
            self?.streamFinished()
        }
    }

    private func handle(_ event: FeedEvent) {
        switch event {
        case .message(let m):
            let wasNewest = atNewest
            let anchor = captureAnchor()
            store.appendLive(m)
            guard wasNewest else {
                unseenNew = true
                updateJumpButton()
                scheduleStateUpdate()
                return
            }
            items.append(contentsOf: makeItems([m]))
            recomputePositions()
            restore(anchor)
            if case .row? = anchor { unseenNew = true }
            trimIfNeeded(dropOldest: true)
            updateJumpButton()
            scheduleStateUpdate()
        case .boost(let id, let b):
            if store.addBoost(AppBoost(b), to: id) { boostsChanged(id) }
        case .typingStarted, .typingStopped:
            break
        }
    }

    private func streamFinished() {
        debugBar?.doneLabel.isHidden = false
        debugBar?.resizeSubviews(withOldSize: debugBar?.bounds.size ?? .zero)
    }

    /// A row's boosts changed: re-lay it out and keep the room pinned or in place.
    private func boostsChanged(_ id: MessageID) {
        guard let i = index(of: id) else { return }
        let anchor = captureAnchor()
        items[i].boosts = store.boosts(of: items[i].message)
        items[i].layout = RowLayoutBuilder.make(items[i].message, boosts: items[i].boosts, items[i].presentation, context)
        recomputePositions()
        restore(anchor)
        scheduleStateUpdate()
    }

    private func boostBurst() {
        let users = [2, 3, 4, 5, 6]
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        var k = 0
        burstTimer?.invalidate()
        let fire: (Timer?) -> Void = { [weak self] timer in
            guard let self, k < users.count else { timer?.invalidate(); return }
            let id = self.store.newestID
            let boost = AppBoost(id: self.nextBoostID, boosterID: users[k], content: emoji[k])
            self.nextBoostID += 1
            k += 1
            if self.store.addBoost(boost, to: id) { self.boostsChanged(id) }
            if k == users.count { timer?.invalidate() }
        }
        fire(nil)
        let timer = Timer(timeInterval: 0.2, repeats: true) { fire($0) }
        RunLoop.main.add(timer, forMode: .common)
        burstTimer = timer
    }

    // MARK: - Development

    func devScrollToTop() {
        items = makeItems([store.message(store.oldestID)!] + store.page(after: store.oldestID))
        recomputePositions()
        setOrigin(-insetTop)
    }

    func devScroll(by d: CGFloat) { setOrigin(clip.bounds.origin.y - d) }

    /// While drag-selecting, scrolls when the mouse is above the header's bottom edge or below the room.
    func autoscrollForSelection(toward y: CGFloat) {
        if y < headerBottomY {
            setOrigin(clip.bounds.origin.y - max(4, (headerBottomY - y) / 2))
        } else if y > visibleBottomY {
            setOrigin(clip.bounds.origin.y + max(4, (y - visibleBottomY) / 2))
        } else {
            return
        }
        maybeLoadMore()
        scheduleStateUpdate()
    }

    /// Index of the row containing document y (the first row whose bottom is below it), clamped to the last row.
    func rowIndex(containingY y: CGFloat) -> Int {
        min(firstIndex { $0.bottom > y }, max(items.count - 1, 0))
    }

    // MARK: - Images

    /// Placeholder image for an image attachment, drawn by CampfireKit's `Placeholder` (solid colour, so a small
    /// bitmap with the same aspect scales up exactly).
    func placeholderImage(for id: MessageID, attachment: Attachment?) -> NSImage? {
        if let hit = placeholderCache[id] { return hit }
        guard case .image(let w, let h, let color)? = attachment else { return nil }
        let k = max(1, max(w, h) / 40)
        let data = Placeholder.pngData(width: max(1, w / k), height: max(1, h / k), color: color)
        let img = NSImage(data: data)
        placeholderCache[id] = img
        return img
    }

    // MARK: - Debug bar

    private func debugClick(_ title: String) {
        // The action fires on mouse up; use that event's time when it is available.
        var t0 = CACurrentMediaTime()
        if let e = NSApp.currentEvent, e.type == .leftMouseUp, t0 - e.timestamp >= 0, t0 - e.timestamp < 1 { t0 = e.timestamp }
        var measured = true
        switch title {
        case "Reset": reset()
        case "Jump to 2500": jump(to: 2500)
        case "Load older": loadOlder()
        case "Start stream": startStream(); measured = false
        case "Text size +": changeTextSize(by: 1, wrap: true)
        case "Boost burst": boostBurst(); measured = false
        default: measured = false
        }
        guard measured else { scheduleStateUpdate(); return }
        lastMs = commitFrame(since: t0)
        updateStateNow()
    }

    /// Lays out and draws the window, commits it to the screen, and returns whole milliseconds since `t0`.
    private func commitFrame(since t0: CFTimeInterval) -> Int {
        documentView.tile()
        rootView.window?.displayIfNeeded()
        CATransaction.flush()
        return Int(((CACurrentMediaTime() - t0) * 1000).rounded())
    }

    private func scheduleStateUpdate() {
        guard debugBar != nil, !stateUpdateScheduled else { return }
        stateUpdateScheduled = true
        DispatchQueue.main.async {
            self.stateUpdateScheduled = false
            self.updateStateNow()
        }
    }

    private func updateStateNow() {
        guard let bar = debugBar else { return }
        let text = stateText()
        if bar.stateLabel.stringValue != text { bar.stateLabel.stringValue = text }
    }

    func stateText() -> String {
        let first = items.first?.message.id ?? 0
        let last = items.last?.message.id ?? 0
        var top = 0
        var y: CGFloat = 0
        if let i = topVisibleIndex() {
            top = items[i].message.id
            y = items[i].y - headerBottomY
        }
        var rounded = (y * 10).rounded() / 10
        if rounded == 0 { rounded = 0 }
        return "first \(first) last \(last) loaded \(items.count) pinned \(isPinned ? "yes" : "no") top \(top) y \(String(format: "%.1f", rounded)) ms \(lastMs)"
    }
}
