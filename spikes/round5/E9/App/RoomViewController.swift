import UIKit
import QuartzCore
import CampfireKit

/// Fires once on the next display-link frame (used to stop the debug timer when the frame reaches the screen).
final class NextFrame: NSObject {
    private var link: CADisplayLink?
    private var callbacks: [() -> Void] = []

    func then(_ body: @escaping () -> Void) {
        callbacks.append(body)
        if link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        }
    }

    @objc private func tick() {
        link?.invalidate()
        link = nil
        let cbs = callbacks
        callbacks = []
        cbs.forEach { $0() }
    }
}

final class RoomViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, ChatLayoutSource {
    private enum Anchor {
        case bottom
        /// Message id and the distance of its row top below the header's bottom edge.
        case row(MessageID, CGFloat)
    }

    let benchmark: Bool
    private var users: [User] = []
    /// Every message, index = id - 1.
    private var store: [Message] = []
    /// Loaded window of `store`: [lo, hi).
    private var lo = 0
    private var hi = 0
    private var ready = false

    private let layout = ChatLayout()
    private var collectionView: UICollectionView!
    private let header = HeaderView()
    private let composer = ComposerBar()
    private var debugBar: DebugBar?
    private let jumpButton = CircleButton(symbol: "arrow.down", pointSize: 17, weight: .bold, label: "Jump to bottom")

    private var style: TextStyle!
    private var measurer: RowMeasurer?
    private var rowCache: [MessageID: RowLayout] = [:]
    private var measuredWidth: CGFloat = 0

    private let nextFrame = NextFrame()
    private var lastMs = 0
    private var pendingAnchor: Anchor?
    private var olderScheduled = false
    private var handlingTraitChange = false
    private var textSizeTapInProgress = false

    private enum LiveChange {
        case message(Message)
        case boost(MessageID, BoostItem)
    }

    private var pending: [LiveChange] = []
    /// Boosts added after launch (CampfireKit's `Boost` cannot be created outside the package).
    private var addedBoosts: [MessageID: [BoostItem]] = [:]
    private var flushScheduled = false
    private var streamTask: Task<Void, Never>?

    static let maxLoaded = Windowing.maxLoaded
    static let sizes: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge,
    ]

    init(benchmark: Bool) {
        self.benchmark = benchmark
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: View

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background
        style = TextStyle(traits: traitCollection)

        layout.source = self
        let cv = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        cv.backgroundColor = Palette.background
        cv.contentInsetAdjustmentBehavior = .never
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self
        cv.selfSizingInvalidation = .disabled
        #if NO_PREFETCH
        cv.isPrefetchingEnabled = false
        #endif
        cv.register(MessageCell.self, forCellWithReuseIdentifier: MessageCell.reuseID)
        cv.register(WelcomeView.self, forSupplementaryViewOfKind: ChatLayout.welcomeKind, withReuseIdentifier: WelcomeView.reuseID)
        cv.accessibilityIdentifier = "room"
        collectionView = cv
        view.addSubview(cv)
        view.addSubview(header)
        view.addSubview(composer)
        jumpButton.isHidden = true
        jumpButton.accessibilityIdentifier = "Jump to bottom"
        jumpButton.addTarget(self, action: #selector(jumpToBottomTapped), for: .touchUpInside)
        view.addSubview(jumpButton)
        if benchmark {
            let bar = DebugBar()
            let actions: [Selector] = [#selector(resetTapped(_:event:)), #selector(jumpTapped(_:event:)),
                                       #selector(loadOlderTapped(_:event:)), #selector(streamTapped(_:event:)),
                                       #selector(textSizeTapped(_:event:)), #selector(burstTapped(_:event:))]
            for (b, a) in zip(bar.buttons, actions) { b.addTarget(self, action: a, for: .touchUpInside) }
            debugBar = bar
            view.addSubview(bar)
        }

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: RoomViewController, _: UITraitCollection) in
            vc.textSizeDidChange()
        }

        DataBoot.whenReady { [weak self] d in self?.start(with: d) }
    }

    private var safe: UIEdgeInsets { view.safeAreaInsets }
    private var headerBottom: CGFloat { safe.top + Geo.headerHeight }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        // Capture the reader's place with the old geometry before anything moves.
        let widthChanging = ready && b.width - safe.left - safe.right != collectionView.bounds.width
        let anchor = widthChanging ? (pendingAnchor ?? captureAnchor()) : nil

        header.safeTop = safe.top
        header.safeLeft = safe.left
        header.safeRight = safe.right
        header.frame = CGRect(x: 0, y: 0, width: b.width, height: headerBottom)
        var bottom = b.height
        if let bar = debugBar {
            let h = DebugBar.height(forWidth: b.width - safe.left - safe.right) + safe.bottom
            bar.frame = CGRect(x: safe.left, y: bottom - h, width: b.width - safe.left - safe.right, height: h)
            bottom -= h
        }
        let composerPad = debugBar == nil ? max(23.4, safe.bottom) : 6
        let composerH = ComposerBar.topPad + ComposerBar.height + composerPad
        composer.frame = CGRect(x: safe.left, y: bottom - composerH, width: b.width - safe.left - safe.right, height: composerH)
        jumpButton.frame = CGRect(x: b.width - safe.right - 14 - 41, y: composer.frame.minY - 12 - 41, width: 41, height: 41)

        let cvFrame = CGRect(x: safe.left, y: 0, width: b.width - safe.left - safe.right, height: b.height)
        let insets = UIEdgeInsets(top: headerBottom, left: 0, bottom: b.height - composer.frame.minY, right: 0)
        if collectionView.frame != cvFrame { collectionView.frame = cvFrame }
        if collectionView.contentInset != insets {
            collectionView.contentInset = insets
            collectionView.verticalScrollIndicatorInsets = insets
        }
        if let anchor {
            relayoutAll(keeping: anchor)
            pendingAnchor = nil
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if ready { pendingAnchor = captureAnchor() }
        let anchor = pendingAnchor
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self, self.ready, let anchor else { return }
            self.pendingAnchor = nil
            self.restore(anchor)
            self.updateState()
        }
    }

    // MARK: Data

    private func start(with d: Dataset) {
        users = d.users
        store = d.messages
        measurer = nil
        ready = true
        view.layoutIfNeeded()
        showNewest()
        let jumpID = UserDefaults.standard.integer(forKey: "uvsJump")
        if jumpID > 0 { jump(to: jumpID) }
        Probe.sayMemory("first-content")
        if Probe.autoStream {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.startStream() }
        }
        if Probe.autoJump {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                Probe.runJumps(jump: { self?.jump(to: 2500) }, back: { self?.showNewest() })
            }
        }
        if Probe.autoTextSize {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.autoTextSizeRun(step: 0) }
        }
        nextFrame.then { [weak self] in
            guard let self else { return }
            self.lastMs = Int(((CACurrentMediaTime() - appLaunchStart) * 1000).rounded())
            self.updateState()
        }
    }

    private func presentation(_ index: Int) -> MessagePresentation {
        Grouping.presentation(of: store[index], after: index > 0 ? store[index - 1] : nil, currentUserID: FakeData.currentUserID)
    }

    private func currentMeasurer() -> RowMeasurer {
        let w = collectionView.bounds.width
        if let m = measurer, m.width == w, m.style === style { return m }
        let m = RowMeasurer(style: style, width: w, users: users)
        measurer = m
        rowCache.removeAll(keepingCapacity: true)
        return m
    }

    private func rowLayout(_ i: Int) -> RowLayout {
        let index = lo + i
        let id = store[index].id
        let m = currentMeasurer()
        if let r = rowCache[id] { return r }
        let message = store[index]
        var boosts = message.boosts.map { BoostItem(boosterID: $0.boosterID, content: $0.content) }
        if let extra = addedBoosts[id] { boosts += extra }
        let r = m.measure(message, presentation(index), boosts: boosts)
        rowCache[id] = r
        return r
    }

    /// Keeps the measured rows to the loaded window (plus a margin) so the cache stays bounded.
    private func pruneCache() {
        guard rowCache.count > 2 * Self.maxLoaded else { return }
        let keep = (store[lo].id)...(store[hi - 1].id)
        rowCache = rowCache.filter { keep.contains($0.key) }
    }

    // MARK: ChatLayoutSource

    var rowCount: Int { hi - lo }
    var welcomeHeight: CGFloat { lo == 0 && hi > 0 ? Geo.welcomeHeight : 0 }
    func rowHeight(at index: Int) -> CGFloat { rowLayout(index).height }
    func spacingBefore(row index: Int) -> CGFloat { presentation(lo + index).isThreaded ? 0 : Geo.rowGap }
    func layoutWidthChanged(_ width: CGFloat) { _ = currentMeasurer() }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { hi - lo }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MessageCell.reuseID, for: indexPath) as! MessageCell
        Probe.cells += 1
        cell.configure(rowLayout(indexPath.item), style: style)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: WelcomeView.reuseID, for: indexPath)
    }

    // MARK: Geometry

    private var visibleTop: CGFloat { collectionView.contentOffset.y + collectionView.contentInset.top }
    private var visibleBottom: CGFloat {
        collectionView.contentOffset.y + collectionView.bounds.height - collectionView.contentInset.bottom
    }
    private var atLatest: Bool { hi == store.count }

    private var bottomOffsetY: CGFloat {
        let cv = collectionView!
        return max(-cv.contentInset.top, layout.totalHeight + cv.contentInset.bottom - cv.bounds.height)
    }

    private func isPinned() -> Bool {
        guard ready, atLatest, hi > lo, let f = layout.frame(ofRow: hi - lo - 1) else { return false }
        return f.maxY - visibleBottom <= 100
    }

    /// The topmost row at least partly visible below the header, and its top relative to the header's bottom edge.
    private func topRow() -> (index: Int, y: CGFloat)? {
        #if TOP_FIX
        // A row showing less than 1 pt below the header is not the top row (pixel rounding of the
        // restored offset can leave a sliver of the row above when the two rows touch).
        let i = layout.firstRow(bottomBelow: visibleTop + 1)
        #else
        let i = layout.firstRow(bottomBelow: visibleTop)
        #endif
        guard i < hi - lo, let f = layout.frame(ofRow: i) else { return nil }
        return (i, f.minY - visibleTop)
    }

    /// Spike: prints the top row and the geometry around it at full precision.
    private func traceTop(_ tag: String) {
        layout.rebuildIfNeeded()
        let vt = visibleTop
        var s = String(format: "TRACE %@ offset %.4f visibleTop %.4f", tag, collectionView.contentOffset.y, vt)
        if let t = topRow() {
            s += String(format: " top %d y %.4f", store[lo + t.index].id, t.y)
            for i in max(0, t.index - 1)...min(hi - lo - 1, t.index + 1) {
                if let f = layout.frame(ofRow: i) {
                    s += String(format: " | row %d minY %.4f maxY %.4f gapBefore %.2f", store[lo + i].id, f.minY, f.maxY, spacingBefore(row: i))
                }
            }
        }
        Probe.say(s)
    }

    /// Spike: jump to 2,500, then three text size steps 0.8 s apart, like the scored check.
    private func autoTextSizeRun(step: Int) {
        if step == 0 {
            jump(to: 2500)
            traceTop("after-jump")
        } else {
            let current = traitCollection.preferredContentSizeCategory
            let i = Self.sizes.firstIndex(of: current) ?? 3
            if i + 1 < Self.sizes.count {
                traitOverrides.preferredContentSizeCategory = Self.sizes[i + 1]
            } else {
                traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            }
            textSizeTapInProgress = true
            updateTraitsIfNeeded()
            textSizeTapInProgress = false
            updateState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.traceTop("settled-\(step)")
            Probe.say("LABEL \(step) \(self.debugBar?.stateLabel.text ?? "")")
            if step < 3 { self.autoTextSizeRun(step: step + 1) }
        }
    }

    private func captureAnchor() -> Anchor {
        if isPinned() { return .bottom }
        return rowAnchor()
    }

    private func rowAnchor() -> Anchor {
        guard let t = topRow() else { return .bottom }
        return .row(store[lo + t.index].id, t.y)
    }

    private func pixelRound(_ v: CGFloat) -> CGFloat {
        let s = view.window?.screen.scale ?? 3
        return (v * s).rounded() / s
    }

    private func offset(for anchor: Anchor) -> CGPoint {
        layout.rebuildIfNeeded()
        let cv = collectionView!
        switch anchor {
        case .bottom:
            return CGPoint(x: 0, y: pixelRound(bottomOffsetY))
        case .row(let id, let dy):
            let i = id - 1 - lo
            guard i >= 0, i < hi - lo, let f = layout.frame(ofRow: i) else { return CGPoint(x: 0, y: bottomOffsetY) }
            let y = f.minY - dy - cv.contentInset.top
            return CGPoint(x: 0, y: pixelRound(min(max(y, -cv.contentInset.top), bottomOffsetY)))
        }
    }

    private func restore(_ anchor: Anchor) {
        let o = offset(for: anchor)
        if collectionView.contentOffset != o { collectionView.contentOffset = o }
    }

    /// Re-measure every row (new width or text size) and put the reader back where they were.
    private func relayoutAll(keeping anchor: Anchor) {
        _ = currentMeasurer()
        layout.invalidateAllRows()
        layout.targetOffsetProvider = { [unowned self] in self.offset(for: anchor) }
        UIView.performWithoutAnimation {
            collectionView.reloadData()
            restore(anchor)
            collectionView.layoutIfNeeded()
            restore(anchor)
        }
        layout.targetOffsetProvider = nil
        updateState()
    }

    /// Replaces the loaded window and places the anchor, without animation.
    private func replaceWindow(lo newLo: Int, hi newHi: Int, anchor: Anchor) {
        lo = newLo
        hi = newHi
        pruneCache()
        layout.invalidateAllRows()
        layout.targetOffsetProvider = { [unowned self] in self.offset(for: anchor) }
        UIView.performWithoutAnimation {
            collectionView.reloadData()
            restore(anchor)
            collectionView.layoutIfNeeded()
            restore(anchor)
        }
        layout.targetOffsetProvider = nil
    }

    private func showNewest() {
        replaceWindow(lo: max(0, store.count - Windowing.pageSize), hi: store.count, anchor: .bottom)
        updateState()
    }

    // MARK: Operations

    private func loadOlder() {
        guard ready, lo > 0 else { return }
        let anchor = rowAnchor()
        let k = min(Windowing.pageSize, lo)
        // The old first row gets a new neighbour above it: measure it again.
        rowCache[store[lo].id] = nil
        layout.invalidateAllRows()
        layout.targetOffsetProvider = { [unowned self] in self.offset(for: anchor) }
        UIView.performWithoutAnimation {
            collectionView.performBatchUpdates {
                lo -= k
                collectionView.insertItems(at: (0..<k).map { IndexPath(item: $0, section: 0) })
            }
            restore(anchor)
            collectionView.layoutIfNeeded()
            restore(anchor)
        }
        layout.targetOffsetProvider = nil
        if hi - lo > Self.maxLoaded {
            // Trim the newest rows in a step of its own.
            replaceWindow(lo: lo, hi: lo + Self.maxLoaded, anchor: anchor)
        }
        updateState()
    }

    private func jump(to id: MessageID) {
        guard ready, id >= 1, id <= store.count else { return }
        let index = id - 1
        let newLo = max(0, index - 10)
        let newHi = min(store.count, newLo + Windowing.pageSize)
        replaceWindow(lo: newLo, hi: newHi, anchor: .row(id, 0))
        updateState()
    }

    private func textSizeDidChange() {
        guard !handlingTraitChange else { return }
        style = TextStyle(traits: traitCollection)
        guard ready else { return }
        if textSizeTapInProgress {
            let a = captureAnchor()
            traceTop("before-step anchor \(a)")
            relayoutAll(keeping: a)
            traceTop("after-step")
        } else {
            // A system change can arrive in the middle of a layout pass; re-lay out the room just after it.
            let anchor = captureAnchor()
            DispatchQueue.main.async { [weak self] in self?.relayoutAll(keeping: anchor) }
        }
    }

    // MARK: Live updates

    private func enqueue(_ e: FeedEvent) {
        switch e {
        case .message(let m): enqueue(LiveChange.message(m))
        case .boost(let id, let b): enqueue(LiveChange.boost(id, BoostItem(boosterID: b.boosterID, content: b.content)))
        default: break
        }
    }

    private func enqueue(_ c: LiveChange) {
        pending.append(c)
        if !flushScheduled {
            flushScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.flush() }
        }
    }

    private func flush() {
        flushScheduled = false
        guard ready, !pending.isEmpty else { return }
        let events = pending
        Probe.updates += 1
        pending.removeAll()
        let wasLatest = atLatest
        let anchor = captureAnchor()
        var changed = Set<MessageID>()
        for e in events {
            switch e {
            case .message(let m):
                if m.id == store.count + 1 { store.append(m) }
            case .boost(let id, let b):
                if id >= 1 && id <= store.count {
                    addedBoosts[id, default: []].append(b)
                    changed.insert(id)
                }
            }
        }
        for id in changed { rowCache[id] = nil }
        var newRows = wasLatest ? store.count - hi : 0

        // Trim the oldest rows first, as a step of its own, if the room is pinned and would grow past the cap.
        if newRows > 0, case .bottom = anchor, hi - lo + newRows > Self.maxLoaded + 20 {
            let keep = max(Windowing.pageSize, Self.maxLoaded - newRows)
            replaceWindow(lo: hi - keep, hi: hi, anchor: .bottom)
        }
        if newRows > 0 && hi - lo + newRows > 4 * Self.maxLoaded { newRows = 0 }  // reader far up: stop growing the window

        let changedRows = changed.map { $0 - 1 - lo }.filter { $0 >= 0 && $0 < hi - lo }.sorted()
        guard newRows > 0 || !changedRows.isEmpty else { updateState(); return }

        layout.targetOffsetProvider = { [unowned self] in self.offset(for: anchor) }
        UIView.performWithoutAnimation {
            collectionView.performBatchUpdates {
                let old = hi - lo
                if let first = changedRows.first {
                    layout.invalidateRows(from: first)
                    collectionView.reconfigureItems(at: changedRows.map { IndexPath(item: $0, section: 0) })
                }
                if newRows > 0 {
                    hi += newRows
                    layout.invalidateRows(from: old)
                    collectionView.insertItems(at: (old..<old + newRows).map { IndexPath(item: $0, section: 0) })
                }
            }
            restore(anchor)
            collectionView.layoutIfNeeded()
            restore(anchor)
        }
        layout.targetOffsetProvider = nil
        pruneCache()
        updateState()
    }

    private func startStream() {
        guard ready, streamTask == nil, let feed = DataBoot.liveFeed() else { return }
        debugBar?.streamDoneLabel.isHidden = true
        Probe.streamStarted()
        streamTask = Task { @MainActor [weak self] in
            for await e in feed.play() {
                self?.enqueue(e)
            }
            guard let self else { return }
            self.flush()
            Probe.streamDone()
            Probe.say("PROBE rowCache \(self.rowCache.count) loaded \(self.hi - self.lo)")
            self.debugBar?.streamDoneLabel.isHidden = false
            self.debugBar?.setNeedsLayout()
        }
    }

    private func boostBurst() {
        guard ready, let target = store.last?.id else { return }
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(i)) { [weak self] in
                guard let self else { return }
                self.enqueue(LiveChange.boost(target, BoostItem(boosterID: 2 + i, content: emoji[i])))
            }
        }
    }

    // MARK: Debug bar

    private func timed(_ event: UIEvent?, _ body: () -> Void) {
        let t0 = event?.timestamp ?? CACurrentMediaTime()
        body()
        updateState()
        nextFrame.then { [weak self] in
            guard let self else { return }
            self.lastMs = max(0, Int(((CACurrentMediaTime() - t0) * 1000).rounded()))
            self.updateState()
        }
    }

    @objc private func resetTapped(_ sender: UIButton, event: UIEvent) {
        timed(event) {
            if traitOverrides.contains(UITraitPreferredContentSizeCategory.self) {
                handlingTraitChange = true
                traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
                updateTraitsIfNeeded()
                handlingTraitChange = false
                style = TextStyle(traits: traitCollection)
            }
            showNewest()
        }
    }

    @objc private func jumpTapped(_ sender: UIButton, event: UIEvent) { timed(event) { jump(to: 2500) } }
    @objc private func loadOlderTapped(_ sender: UIButton, event: UIEvent) { timed(event) { loadOlder() } }
    @objc private func streamTapped(_ sender: UIButton, event: UIEvent) { startStream() }
    @objc private func burstTapped(_ sender: UIButton, event: UIEvent) { boostBurst() }

    @objc private func textSizeTapped(_ sender: UIButton, event: UIEvent) {
        timed(event) {
            let current = traitCollection.preferredContentSizeCategory
            let i = Self.sizes.firstIndex(of: current) ?? 3
            if i + 1 < Self.sizes.count {
                traitOverrides.preferredContentSizeCategory = Self.sizes[i + 1]
            } else {
                traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            }
            textSizeTapInProgress = true
            updateTraitsIfNeeded()
            textSizeTapInProgress = false
        }
    }

    @objc private func jumpToBottomTapped() {
        if atLatest {
            collectionView.setContentOffset(offset(for: .bottom), animated: true)
        } else {
            showNewest()
        }
    }

    private func updateState() {
        guard ready else { return }
        let pinned = isPinned()
        jumpButton.isHidden = pinned
        guard let bar = debugBar, hi > lo else { return }
        var topID = 0
        var y: CGFloat = 0
        if let t = topRow() {
            topID = store[lo + t.index].id
            y = t.y
        }
        if abs(y) < 0.05 { y = 0 }
        let text = "first \(store[lo].id) last \(store[hi - 1].id) loaded \(hi - lo) pinned \(pinned ? "yes" : "no") top \(topID) y \(String(format: "%.1f", y)) ms \(lastMs)"
        if bar.stateLabel.text != text { bar.stateLabel.text = text }
    }

    // MARK: Scrolling

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard ready else { return }
        if (scrollView.isTracking || scrollView.isDecelerating) && lo > 0 && !olderScheduled && visibleTop < 300 {
            olderScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.olderScheduled = false
                self?.loadOlder()
            }
        }
        if !scrollView.isTracking && !scrollView.isDecelerating { updateState() }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateState() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateState() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { updateState() }
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { updateState() }
}
