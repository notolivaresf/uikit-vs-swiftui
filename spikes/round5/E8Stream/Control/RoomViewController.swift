import UIKit
import CampfireKit

/// The single Campfire room.
///
/// Rows are laid out by `RoomLayout` from heights computed up front, so every change follows one path
/// (`performUpdate`): note whether the room is pinned and which row is at the top, change the data,
/// re-lay out, then either stay at the bottom or put that row back where it was.
final class RoomViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, RoomLayoutProvider {
    /// Made on first use, which waits for the dataset; the views are built before that, while it is generated.
    private lazy var store = RoomStore()
    private let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")

    private let roomLayout = RoomLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: roomLayout)
    private var messageCell: UICollectionView.CellRegistration<MessageCell, Int>!
    private var welcomeCell: UICollectionView.CellRegistration<WelcomeCell, Int>!
    private let header = HeaderView()
    private let composer = ComposerView()
    private let jumpButton = JumpToBottomButton()
    private var debugBar: DebugBar?

    private(set) var layoutItems: [Int] = []
    private var rowCache: [Int: RowBox] = [:]
    private var cacheWidth: CGFloat = 0
    private var scale = TypeScale(category: .large)

    /// Whether the room follows new messages. Changed by the user's scrolling and by our own jumps.
    private var isPinned = true
    private var didInitialLoad = false
    private var loadScheduled = false
    private var suppressScrollTracking = false

    private var streamTask: Task<Void, Never>?
    private var streamDone = false
    private var pendingEvents: [FeedEvent] = []
    private var flushScheduled = false
    private var burstTask: Task<Void, Never>?
    private var nextBoostID = 0

    private var lastMs = 0
    private var timingStart: TimeInterval?
    private var committed = false
    /// One display link for the whole life of the room, paused between measurements: a link made at the
    /// moment of measuring skips a frame before its first callback, an unpaused one fires on the next frame.
    private lazy var timingLink: CADisplayLink = {
        let link = CADisplayLink(target: WeakTarget(self), selector: #selector(WeakTarget.frame(_:)))
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        return link
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background
        scale = TypeScale(category: traitCollection.preferredContentSizeCategory)

        collectionView.backgroundColor = Palette.background
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.automaticallyAdjustsScrollIndicatorInsets = false
        collectionView.isPrefetchingEnabled = false
        collectionView.allowsSelection = false
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.accessibilityIdentifier = "room"
        roomLayout.provider = self
        view.addSubview(collectionView)

        messageCell = UICollectionView.CellRegistration<MessageCell, Int> { [unowned self] cell, _, id in
            if let row = self.rowLayout(for: id) { cell.configure(row) }
        }
        welcomeCell = UICollectionView.CellRegistration<WelcomeCell, Int> { _, _, _ in }
        collectionView.dataSource = self

        view.addSubview(header)
        view.addSubview(composer)
        jumpButton.isHidden = true
        jumpButton.addTarget(self, action: #selector(jumpToBottomTapped), for: .touchUpInside)
        view.addSubview(jumpButton)

        if benchmark {
            let bar = DebugBar()
            bar.onAction = { [weak self] action, time in self?.debugAction(action, tappedAt: time) }
            view.addSubview(bar)
            debugBar = bar
        }

        _ = timingLink
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: RoomViewController, _) in
            vc.contentSizeCategoryChanged()
        }
    }

    /// First content: the newest page, at the bottom, as soon as the view has its real size.
    private func initialLoad() {
        didInitialLoad = true
        header.roomName = store.roomName
        let width = rowWidth
        if let rows = DatasetLoader.takePrefetched(width: width, category: scale.category) {
            cacheWidth = width
            rowCache.merge(rows.mapValues(RowBox.init)) { current, _ in current }
        }
        applySnapshot()
        collectionView.layoutIfNeeded()
        scrollToBottom()
        collectionView.layoutIfNeeded()
        isPinned = true
        refreshChrome()
        finishTiming(from: appLaunchUptime)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        let w = view.bounds.width, h = view.bounds.height
        let headerBottom = safe.top + Metrics.headerHeight

        var bottom = h
        if let debugBar {
            let barHeight = debugBar.preferredHeight(for: w) + safe.bottom
            debugBar.frame = CGRect(x: 0, y: h - barHeight, width: w, height: barHeight)
            bottom = h - barHeight
        }
        composer.bottomInset = debugBar == nil ? max(24, safe.bottom) : 24
        let composerHeight = ComposerView.fieldTop + ComposerView.fieldHeight + composer.bottomInset
        composer.frame = CGRect(x: 0, y: bottom - composerHeight, width: w, height: composerHeight)
        header.topInset = safe.top
        header.frame = CGRect(x: 0, y: 0, width: w, height: headerBottom)
        jumpButton.frame = CGRect(x: w - safe.right - 14 - 42, y: composer.frame.minY - 14 - 42, width: 42, height: 42)

        let listFrame = CGRect(x: 0, y: 0, width: w, height: composer.frame.minY)
        guard listFrame != collectionView.frame || collectionView.contentInset.top != headerBottom else { return }
        guard didInitialLoad else {
            collectionView.frame = listFrame
            collectionView.contentInset.top = headerBottom
            collectionView.verticalScrollIndicatorInsets.top = headerBottom
            if w > 0 && h > 0 {
                initialLoad()
                if Probe.autoStream {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.startStream() }
                }
                if Probe.autoJump {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        Probe.runJumps(jump: { self?.jump(to: 2500) }, back: { self?.resetToNewest() })
                    }
                }
            }
            return
        }
        // Size change (rotation, window resize): keep the top row in place, or stay pinned.
        let pinned = isPinned
        let anchor = captureAnchor()
        suppressScrollTracking = true
        collectionView.frame = listFrame
        collectionView.contentInset.top = headerBottom
        collectionView.verticalScrollIndicatorInsets.top = headerBottom
        prefillRows(layoutItems)
        roomLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        reconfigureVisibleCells(nil)
        reposition(pinned: pinned, anchor: anchor)
        suppressScrollTracking = false
        refreshChrome()
    }

    // MARK: Rows

    private var rowWidth: CGFloat {
        let safe = collectionView.safeAreaInsets
        return collectionView.bounds.width - safe.left - safe.right
    }

    private func rowBox(for id: Int, width: CGFloat? = nil) -> RowBox? {
        let width = width ?? rowWidth
        if width != cacheWidth {
            rowCache.removeAll(keepingCapacity: true)
            cacheWidth = width
        }
        if let cached = rowCache[id] { return cached }
        guard let row = RowLayoutBuilder(store: store, width: width, scale: scale).layout(for: id) else { return nil }
        let box = RowBox(row)
        rowCache[id] = box
        return box
    }

    private func rowLayout(for id: Int) -> RowLayout? { rowBox(for: id)?.row }

    func rowMetrics(for id: Int, width: CGFloat) -> (height: CGFloat, gapBefore: CGFloat) {
        if id == 0 { return (WelcomeCell.height, 0) }
        guard let box = rowBox(for: id, width: width) else { return (0, 0) }
        return (box.row.height, box.row.gapBefore)
    }

    /// Lays out the rows not cached yet, spread over the cores, so a page of new rows (or a new text size)
    /// costs a fraction of laying them out one by one here.
    private func prefillRows(_ ids: [Int]) {
        let width = rowWidth
        if width != cacheWidth {
            rowCache.removeAll(keepingCapacity: true)
            cacheWidth = width
        }
        let missing = ids.filter { $0 != 0 && rowCache[$0] == nil }
        guard missing.count >= 4 else { return }
        let rows = ParallelRowLayout.layouts(for: missing, store: store, width: width, scale: scale)
        for (id, row) in zip(missing, rows) { rowCache[id] = row.map(RowBox.init) }
    }

    /// Shows the store's window: the rows added when it only grows (a page before, new messages after),
    /// otherwise a reload (a trim, Reset, a jump to another part of the room).
    /// `rebuilt`: rows whose layouts were rebuilt (their height may have changed); nil means all of them.
    private func applySnapshot(rebuilt: Set<Int>? = nil) {
        let old = layoutItems
        let new = (store.hasOlder ? [] : [0]) + Array(store.window)
        prefillRows(new)
        if let rebuilt {
            // Message ids are contiguous after the optional welcome card, so a row's index is arithmetic.
            let base = new.first == 0 ? 1 : 0
            let first = new.count > base ? new[base] : 0
            let lowest = rebuilt.compactMap { id -> Int? in
                let i = base + id - first
                return new.indices.contains(i) && new[i] == id ? i : nil
            }.min()
            roomLayout.invalidateRows(from: lowest ?? .max)
        } else {
            roomLayout.invalidateRows(from: 0)
        }
        let (deleted, inserted, kept) = Self.difference(from: old, to: new)
        if kept == 0 || !deleted.isEmpty {
            // Removing rows in a batch update makes UIKit shift the offset by their height later, animated,
            // on top of the room's own positioning; a reload leaves the offset to the room.
            layoutItems = new
            collectionView.reloadData()
            placeOffsetBeforeLayout()
        } else if !inserted.isEmpty {
            UIView.performWithoutAnimation {
                collectionView.performBatchUpdates {
                    layoutItems = new
                    collectionView.insertItems(at: inserted)
                }
            }
        } else {
            // Same rows, new heights (a text size, a boost): cells are made only where the room ends up.
            placeOffsetBeforeLayout()
        }
    }

    /// Puts the offset where the room will end up before the collection view lays out the change. If the
    /// content shrank past the offset, UIKit would otherwise scroll it back with an animation of its own.
    private func placeOffsetBeforeLayout() {
        roomLayout.computeFrames()
        let target = roomLayout.targetOffset?()
            ?? CGPoint(x: 0, y: min(collectionView.contentOffset.y, layoutMaxOffset))
        if target != collectionView.contentOffset { collectionView.contentOffset = target }
    }

    /// Both lists are ascending (the welcome card, 0, first), so one merge pass finds what changed.
    private static func difference(from old: [Int], to new: [Int]) -> (deleted: [IndexPath], inserted: [IndexPath], kept: Int) {
        var deleted: [IndexPath] = [], inserted: [IndexPath] = []
        var i = 0, j = 0, kept = 0
        while i < old.count || j < new.count {
            if j == new.count || (i < old.count && old[i] < new[j]) {
                deleted.append(IndexPath(item: i, section: 0)); i += 1
            } else if i == old.count || new[j] < old[i] {
                inserted.append(IndexPath(item: j, section: 0)); j += 1
            } else {
                kept += 1; i += 1; j += 1
            }
        }
        return (deleted, inserted, kept)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        layoutItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let id = layoutItems[indexPath.item]
        return id == 0 ? collectionView.dequeueConfiguredReusableCell(using: welcomeCell, for: indexPath, item: id)
                       : collectionView.dequeueConfiguredReusableCell(using: messageCell, for: indexPath, item: id)
    }

    /// Re-applies row layouts to visible cells (all of them when `ids` is nil).
    private func reconfigureVisibleCells(_ ids: Set<Int>?) {
        for case let cell as MessageCell in collectionView.visibleCells where ids?.contains(cell.messageID) ?? true {
            if let row = rowLayout(for: cell.messageID) { cell.configure(row) }
        }
    }

    // MARK: Position

    struct Anchor { let id: Int; let delta: CGFloat }

    private var visibleTop: CGFloat { collectionView.contentOffset.y + collectionView.contentInset.top }
    private var maxOffset: CGFloat {
        max(-collectionView.contentInset.top, collectionView.contentSize.height - collectionView.bounds.height)
    }
    private var distanceFromBottom: CGFloat {
        collectionView.contentSize.height - (collectionView.contentOffset.y + collectionView.bounds.height)
    }

    /// The topmost message row at least partly visible below the header, and where its top is.
    /// A row's last 1.6 pt is margin (a threaded row below overlaps it), so it does not count as visible.
    private func topRow() -> Anchor? {
        let top = visibleTop
        let frames = roomLayout.frames
        let items = roomLayout.items
        func visibleBottom(_ i: Int) -> CGFloat { frames[i].maxY - Metrics.rowBottomPad }
        var lo = 0, hi = frames.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if visibleBottom(mid) <= top { lo = mid + 1 } else { hi = mid }
        }
        var i = lo
        while i < frames.count && (items[i] == 0 || visibleBottom(i) <= top) { i += 1 }
        guard i < frames.count else { return nil }
        return Anchor(id: items[i], delta: frames[i].minY - top)
    }

    private func captureAnchor() -> Anchor? { topRow() }

    /// The offset that puts `anchor` back where it was (from the layout's current frames).
    private func offset(restoring anchor: Anchor) -> CGPoint? {
        guard let frame = roomLayout.frame(of: anchor.id) else { return nil }
        // Same distance from the header; if the row got shorter than its hidden part, keep a sliver of it visible.
        let delta = max(anchor.delta, -(frame.height - Metrics.rowBottomPad - 8))
        let y = frame.minY - delta - collectionView.contentInset.top
        return CGPoint(x: 0, y: min(max(y, -collectionView.contentInset.top), layoutMaxOffset))
    }

    /// The bottom offset for the layout's current content height (`contentSize` may not have caught up yet).
    private var layoutMaxOffset: CGFloat {
        max(-collectionView.contentInset.top, roomLayout.collectionViewContentSize.height - collectionView.bounds.height)
    }

    private func targetOffset(pinned: Bool, anchor: Anchor?) -> CGPoint? {
        if pinned && store.windowReachesNewest { return CGPoint(x: 0, y: layoutMaxOffset) }
        return anchor.flatMap(offset(restoring:))
    }

    private func restore(_ anchor: Anchor) {
        if let offset = offset(restoring: anchor) { collectionView.contentOffset = offset }
    }

    private func scrollToBottom() {
        collectionView.contentOffset = CGPoint(x: 0, y: maxOffset)
    }

    private func reposition(pinned: Bool, anchor: Anchor?) {
        if let offset = targetOffset(pinned: pinned, anchor: anchor), offset != collectionView.contentOffset {
            collectionView.contentOffset = offset
        }
        collectionView.layoutIfNeeded()
    }

    /// The one update path: remember pinned/top row, change, re-lay out, put the room back.
    /// `change` returns the ids whose rows changed (nil: all rows).
    private func performUpdate(_ change: (_ pinned: Bool, _ anchor: Anchor?) -> Set<Int>?) {
        let pinned = isPinned
        let anchor = captureAnchor()
        suppressScrollTracking = true
        let changed = change(pinned, anchor)
        if let changed { for id in changed { rowCache[id] = nil } } else { rowCache.removeAll() }
        // The layout puts the room back during the update itself, so cells are made only for where it ends up.
        roomLayout.targetOffset = { [unowned self] in self.targetOffset(pinned: pinned, anchor: anchor) }
        defer { roomLayout.targetOffset = nil }
        applySnapshot(rebuilt: changed)
        collectionView.layoutIfNeeded()
        reconfigureVisibleCells(changed)
        reposition(pinned: pinned, anchor: anchor)
        isPinned = pinned && store.windowReachesNewest
        suppressScrollTracking = false
        refreshChrome()
    }

    /// Campfire keeps at most 300 rows; trims the side away from the reader.
    private func trimWindow(pinned: Bool, anchor: Anchor?, keepNewest: Bool) {
        guard store.window.count >= Windowing.maxLoaded + 20 else { return }
        if keepNewest {
            let newLower = store.window.upperBound - Windowing.maxLoaded + 1
            guard pinned || (anchor?.id ?? .max) >= newLower else { return }
        } else {
            let newUpper = store.window.lowerBound + Windowing.maxLoaded - 1
            guard !pinned, (anchor?.id ?? .min) <= newUpper else { return }
        }
        store.trimIfNeeded(keepNewest: keepNewest)
        rowCache = rowCache.filter { store.window.contains($0.key) }
    }

    // MARK: Window changes

    private func loadOlder() {
        guard store.hasOlder else { return }
        performUpdate { pinned, anchor in
            store.loadOlder()
            trimWindow(pinned: pinned, anchor: anchor, keepNewest: false)
            return [store.window.lowerBound]
        }
    }

    private func loadNewer() {
        guard !store.windowReachesNewest else { return }
        performUpdate { pinned, anchor in
            store.loadNewer()
            trimWindow(pinned: pinned, anchor: anchor, keepNewest: true)
            return []
        }
    }

    private func resetToNewest() {
        suppressScrollTracking = true
        store.resetToNewest()
        rowCache = rowCache.filter { store.window.contains($0.key) }
        roomLayout.targetOffset = { [unowned self] in CGPoint(x: 0, y: self.layoutMaxOffset) }
        defer { roomLayout.targetOffset = nil }
        applySnapshot()
        collectionView.layoutIfNeeded()
        reconfigureVisibleCells(nil)
        scrollToBottom()
        collectionView.layoutIfNeeded()
        isPinned = true
        suppressScrollTracking = false
        refreshChrome()
    }

    private func jump(to id: MessageID) {
        var t = [CACurrentMediaTime()]
        suppressScrollTracking = true
        store.jump(to: id)
        roomLayout.targetOffset = { [unowned self] in self.offset(restoring: Anchor(id: id, delta: 0)) }
        defer { roomLayout.targetOffset = nil }
        rowCache = rowCache.filter { store.window.contains($0.key) }
        applySnapshot()
        t.append(CACurrentMediaTime())
        collectionView.layoutIfNeeded()
        reconfigureVisibleCells(nil)
        t.append(CACurrentMediaTime())
        restore(Anchor(id: id, delta: 0))
        collectionView.layoutIfNeeded()
        t.append(CACurrentMediaTime())
        isPinned = store.windowReachesNewest && distanceFromBottom <= 100
        suppressScrollTracking = false
        refreshChrome()
        t.append(CACurrentMediaTime())
        if Probe.autoJump { Probe.phases("snapshot layout+reconfigure restore chrome", t) }
    }

    @objc private func jumpToBottomTapped() {
        if store.windowReachesNewest {
            suppressScrollTracking = true
            scrollToBottom()
            collectionView.layoutIfNeeded()
            isPinned = true
            suppressScrollTracking = false
            refreshChrome()
        } else {
            resetToNewest()
        }
    }

    // MARK: Dynamic Type

    private func contentSizeCategoryChanged() {
        let category = traitCollection.preferredContentSizeCategory
        guard category != scale.category, didInitialLoad else {
            scale = TypeScale(category: category)
            return
        }
        performUpdate { _, _ in
            scale = TypeScale(category: category)
            return nil
        }
    }

    private static let sizeSteps: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge,
    ]

    private func stepTextSize() {
        let current = traitCollection.preferredContentSizeCategory
        if let i = Self.sizeSteps.firstIndex(of: current), i + 1 < Self.sizeSteps.count {
            traitOverrides.preferredContentSizeCategory = Self.sizeSteps[i + 1]
        } else {
            traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
        }
        updateTraitsIfNeeded()
        contentSizeCategoryChanged()
    }

    // MARK: Live stream

    private func startStream() {
        guard streamTask == nil else { return }
        let feed = FakeLiveFeed(dataset: store.dataset)
        Probe.streamStarted()
        streamTask = Task { @MainActor [weak self] in
            for await event in feed.play() {
                self?.receive(event)
            }
            self?.streamFinished()
        }
    }

    private func receive(_ event: FeedEvent) {
        pendingEvents.append(event)
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.flushEvents() }
    }

    private func flushEvents() {
        flushScheduled = false
        let events = pendingEvents
        pendingEvents.removeAll()
        guard !events.isEmpty else { return }
        Probe.updates += 1
        performUpdate { pinned, anchor in
            var changed = Set<Int>()
            for event in events {
                switch event {
                case .message(let message):
                    _ = store.appendLive(message)
                case .boost(let id, let boost):
                    if store.addBoost(boost, to: id) { changed.insert(id) }
                case .typingStarted, .typingStopped:
                    break
                }
            }
            trimWindow(pinned: pinned, anchor: anchor, keepNewest: true)
            return changed
        }
    }

    private func streamFinished() {
        flushEvents()
        Probe.streamDone()
        streamDone = true
        debugBar?.doneLabel.isHidden = false
        debugBar?.setNeedsLayout()
    }

    private func boostBurst() {
        let target = store.newestID
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        burstTask?.cancel()
        burstTask = Task { @MainActor [weak self] in
            for i in 0..<5 {
                if i > 0 {
                    try? await Task.sleep(for: .milliseconds(200))
                    if Task.isCancelled { return }
                }
                guard let self else { return }
                self.performUpdate { _, _ in
                    self.store.addBoost(BoostItem(boosterID: 2 + i, content: emoji[i]), to: target) ? [target] : []
                }
            }
        }
    }

    // MARK: Scrolling

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard didInitialLoad, !suppressScrollTracking else { return }
        if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
            isPinned = store.windowReachesNewest && distanceFromBottom <= 100
            maybeLoadMore()
        }
        refreshChrome()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { userScrollEnded() }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { userScrollEnded() }
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { userScrollEnded() }

    private func userScrollEnded() {
        isPinned = store.windowReachesNewest && distanceFromBottom <= 100
        maybeLoadMore()
        refreshChrome()
    }

    /// Reaching the top loads the page before; reaching the bottom of an older window loads the page after.
    private func maybeLoadMore() {
        guard !loadScheduled else { return }
        if store.hasOlder && visibleTop < 200 {
            loadScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.loadScheduled = false
                self?.loadOlder()
            }
        } else if !store.windowReachesNewest && distanceFromBottom < 200 {
            loadScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.loadScheduled = false
                self?.loadNewer()
            }
        }
    }

    // MARK: Chrome and debug bar

    private func refreshChrome() {
        jumpButton.isHidden = isPinned
        updateStateLabel()
    }

    private func updateStateLabel() {
        guard let debugBar else { return }
        let window = store.window
        var text = "first \(window.lowerBound) last \(window.upperBound) loaded \(window.count) pinned \(isPinned ? "yes" : "no")"
        if let top = topRow() {
            var y = (top.delta * 10).rounded() / 10
            if y == 0 { y = 0 }   // no "-0.0"
            text += " top \(top.id) y \(String(format: "%.1f", y))"
        } else {
            text += " top 0 y 0.0"
        }
        text += " ms \(lastMs)"
        if debugBar.stateLabel.text != text {
            debugBar.stateLabel.text = text
            debugBar.stateLabel.accessibilityValue = text
        }
    }

    private func debugAction(_ action: DebugBar.Action, tappedAt time: TimeInterval) {
        switch action {
        case .reset:
            if traitOverrides.contains(UITraitPreferredContentSizeCategory.self) {
                traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
                updateTraitsIfNeeded()
                contentSizeCategoryChanged()
            }
            resetToNewest()
            finishTiming(from: time)
        case .jump:
            jump(to: 2500)
            finishTiming(from: time)
        case .loadOlder:
            loadOlder()
            finishTiming(from: time)
        case .startStream:
            startStream()
        case .textSize:
            stepTextSize()
            finishTiming(from: time)
        case .boostBurst:
            boostBurst()
        }
    }

    /// Reports the time from `start` to the next frame on screen (the rows are already laid out).
    private func finishTiming(from start: TimeInterval) {
        timingStart = start
        committed = false
        timingLink.isPaused = false
        // Count only a frame that starts after this change is committed, so the frame counted is one that can
        // show it (a frame that began while the change was being made would be too early). Core Animation
        // commits in a before-waiting observer of order 2,000,000; this one runs right after it.
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, false, 3_000_000) { [weak self] _, _ in
            self?.committed = true
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    fileprivate func timingFrame(_ link: CADisplayLink) {
        guard committed else { return }   // the first frame after the change was committed
        link.isPaused = true
        guard let start = timingStart else { return }
        timingStart = nil
        lastMs = max(0, Int((ProcessInfo.processInfo.systemUptime - start) * 1000))
        updateStateLabel()
    }
}

/// Display link target that does not keep the room alive.
private final class WeakTarget {
    weak var room: RoomViewController?
    init(_ room: RoomViewController) { self.room = room }
    @objc func frame(_ link: CADisplayLink) {
        guard let room else { link.invalidate(); return }
        room.timingFrame(link)
    }
}
