import UIKit
import CampfireKit

/// The single Campfire room.
///
/// Rows are laid out by `RoomLayout` from heights computed up front, so every change follows one path
/// (`performUpdate`): note whether the room is pinned and which row is at the top, change the data,
/// re-lay out, then either stay at the bottom or put that row back where it was.
final class RoomViewController: UIViewController, UICollectionViewDelegate, RoomLayoutProvider {
    private let store = RoomStore()
    private let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")

    private let roomLayout = RoomLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: roomLayout)
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private lazy var header = HeaderView(roomName: store.roomName)
    private let composer = ComposerView()
    private let jumpButton = JumpToBottomButton()
    private var debugBar: DebugBar?

    private(set) var layoutItems: [Int] = []
    private var rowCache: [Int: RowLayout] = [:]
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
    private var timingLink: CADisplayLink?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        PlaceholderImages.shared.store = store
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

        let messageCell = UICollectionView.CellRegistration<MessageCell, Int> { [unowned self] cell, _, id in
            if let row = self.rowLayout(for: id) { cell.configure(row) }
        }
        let welcomeCell = UICollectionView.CellRegistration<WelcomeCell, Int> { _, _, _ in }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, id in
            id == 0 ? cv.dequeueConfiguredReusableCell(using: welcomeCell, for: indexPath, item: id)
                    : cv.dequeueConfiguredReusableCell(using: messageCell, for: indexPath, item: id)
        }

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

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: RoomViewController, _) in
            vc.contentSizeCategoryChanged()
        }
    }

    /// First content: the newest page, at the bottom, as soon as the view has its real size.
    private func initialLoad() {
        didInitialLoad = true
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
            if w > 0 && h > 0 { initialLoad() }
            return
        }
        // Size change (rotation, window resize): keep the top row in place, or stay pinned.
        let pinned = isPinned
        let anchor = captureAnchor()
        suppressScrollTracking = true
        collectionView.frame = listFrame
        collectionView.contentInset.top = headerBottom
        collectionView.verticalScrollIndicatorInsets.top = headerBottom
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

    private func rowLayout(for id: Int, width: CGFloat? = nil) -> RowLayout? {
        let width = width ?? rowWidth
        if width != cacheWidth {
            rowCache.removeAll(keepingCapacity: true)
            cacheWidth = width
        }
        if let cached = rowCache[id] { return cached }
        guard let row = RowLayoutBuilder(store: store, width: width, scale: scale).layout(for: id) else { return nil }
        rowCache[id] = row
        return row
    }

    func rowMetrics(for id: Int, width: CGFloat) -> (height: CGFloat, gapBefore: CGFloat) {
        if id == 0 { return (WelcomeCell.height, 0) }
        guard let row = rowLayout(for: id, width: width) else { return (0, 0) }
        return (row.height, row.gapBefore)
    }

    private func applySnapshot() {
        layoutItems = (store.hasOlder ? [] : [0]) + Array(store.window)
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(layoutItems)
        roomLayout.invalidateLayout()
        dataSource.apply(snapshot, animatingDifferences: false)
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

    private func restore(_ anchor: Anchor) {
        guard let frame = roomLayout.frame(of: anchor.id) else { return }
        // Same distance from the header; if the row got shorter than its hidden part, keep a sliver of it visible.
        let delta = max(anchor.delta, -(frame.height - Metrics.rowBottomPad - 8))
        let y = frame.minY - delta - collectionView.contentInset.top
        collectionView.contentOffset = CGPoint(x: 0, y: min(max(y, -collectionView.contentInset.top), maxOffset))
    }

    private func scrollToBottom() {
        collectionView.contentOffset = CGPoint(x: 0, y: maxOffset)
    }

    private func reposition(pinned: Bool, anchor: Anchor?) {
        if pinned && store.windowReachesNewest {
            scrollToBottom()
        } else if let anchor {
            restore(anchor)
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
        applySnapshot()
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
        suppressScrollTracking = true
        store.jump(to: id)
        rowCache = rowCache.filter { store.window.contains($0.key) }
        applySnapshot()
        collectionView.layoutIfNeeded()
        reconfigureVisibleCells(nil)
        restore(Anchor(id: id, delta: 0))
        collectionView.layoutIfNeeded()
        isPinned = store.windowReachesNewest && distanceFromBottom <= 100
        suppressScrollTracking = false
        refreshChrome()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.flushEvents() }
    }

    private func flushEvents() {
        flushScheduled = false
        let events = pendingEvents
        pendingEvents.removeAll()
        guard !events.isEmpty else { return }
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
        timingLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(timingFrame(_:)))
        link.add(to: .main, forMode: .common)
        timingLink = link
    }

    @objc private func timingFrame(_ link: CADisplayLink) {
        link.invalidate()
        timingLink = nil
        guard let start = timingStart else { return }
        timingStart = nil
        lastMs = max(0, Int((ProcessInfo.processInfo.systemUptime - start) * 1000))
        updateStateLabel()
    }
}
