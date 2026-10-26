import UIKit
import CampfireKit

/// The reader's place: the top row on screen and its distance from the header, and whether the room was pinned.
struct Anchor {
    var id: MessageID?
    var dy: CGFloat
    var pinned: Bool
}

final class ChatViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
                                MessageCellDelegate {
    private let store = Store.shared
    private let benchmark: Bool
    private let layout = ChatLayout()
    private var cv: UICollectionView!
    private let header = HeaderView()
    private let composer = ComposerView()
    private var debugBar: DebugBar?
    private let jumpButton = UIButton(type: .custom)

    private var items: [Message] = []
    private var pres: [MessagePresentation] = []
    private var geos: [MessageID: RowGeo] = [:]
    private var type = TypeScale(category: .large)
    private var measurerCache: Measurer?

    private var didInitialLoad = false
    private var rotationAnchor: Anchor?
    private var olderScheduled = false
    private var newerScheduled = false
    private var streamTask: Task<Void, Never>?
    private var streamFinished = false
    private var boostSerial = 0

    private var lastMs = 0
    private var timingStart: CFTimeInterval?
    private var timingLink: CADisplayLink?

    /// Campfire keeps at most 300 messages loaded and trims 20+ over.
    private let maxLoaded = Windowing.maxLoaded

    init(benchmark: Bool) {
        self.benchmark = benchmark
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { false }

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.contentInsetAdjustmentBehavior = .never
        cv.contentInset = UIEdgeInsets(top: Metrics.headerHeight, left: 0, bottom: 0, right: 0)
        cv.verticalScrollIndicatorInsets = UIEdgeInsets(top: Metrics.headerHeight, left: 0, bottom: 0, right: 0)
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self
        cv.selfSizingInvalidation = .disabled
        cv.isPrefetchingEnabled = true
        cv.register(MessageCell.self, forCellWithReuseIdentifier: MessageCell.reuseID)
        cv.register(WelcomeView.self, forSupplementaryViewOfKind: ChatLayout.welcomeKind, withReuseIdentifier: WelcomeView.reuseID)
        cv.accessibilityIdentifier = "room"
        view.addSubview(cv)
        view.addSubview(header)
        view.addSubview(composer)

        var jc = UIButton.Configuration.filled()
        jc.image = UIImage(systemName: "arrow.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        jc.baseBackgroundColor = Theme.inverted
        jc.baseForegroundColor = Theme.invertedText
        jc.cornerStyle = .capsule
        jumpButton.configuration = jc
        jumpButton.accessibilityLabel = "Jump to bottom"
        jumpButton.accessibilityIdentifier = "jumpToBottom"
        jumpButton.isHidden = true
        jumpButton.addTarget(self, action: #selector(jumpToBottomTapped), for: .touchUpInside)
        view.addSubview(jumpButton)

        if benchmark {
            let bar = DebugBar()
            bar.onAction = { [weak self] name, event in self?.debugAction(name, event: event) }
            view.addSubview(bar)
            debugBar = bar
        }

        // A system text size change arrives inside UIKit's trait pass: re-lay out on the next turn instead.
        // "Text size +" applies its own change synchronously (see stepTextSize).
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: ChatViewController, _) in
            DispatchQueue.main.async { vc.textSizeDidChange() }
        }
        type = TypeScale(category: traitCollection.preferredContentSizeCategory)
        store.waitUntilReady()
    }

    private var listFrame: CGRect {
        let b = view.bounds, safe = view.safeAreaInsets
        return CGRect(x: safe.left, y: 0, width: b.width - safe.left - safe.right, height: composerTop - Metrics.listBottomGap)
    }

    private var composerTop: CGFloat {
        let b = view.bounds
        if debugBar != nil {
            let h = DebugBar.height(for: b.width)
            return b.height - view.safeAreaInsets.bottom - h - 8 - Metrics.composerHeight
        }
        return b.height - Metrics.composerBottomGap - Metrics.composerHeight
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds, safe = view.safeAreaInsets
        header.frame = CGRect(x: 0, y: 0, width: b.width, height: Metrics.headerHeight)
        composer.frame = CGRect(x: safe.left, y: composerTop, width: b.width - safe.left - safe.right, height: Metrics.composerHeight)
        if let bar = debugBar {
            let h = DebugBar.height(for: b.width)
            bar.frame = CGRect(x: 0, y: b.height - safe.bottom - h, width: b.width, height: h + safe.bottom)
        }
        let lf = listFrame
        jumpButton.frame = CGRect(x: lf.maxX - 14 - 40, y: lf.maxY - 40 - 8, width: 40, height: 40)

        guard lf != cv.frame else { return }
        if !didInitialLoad {
            cv.frame = lf
            guard lf.width > 0 else { return }
            didInitialLoad = true
            loadLatest()
            finishTiming(from: launchStart)
            if Probe.autoStream {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.startStream() }
            }
            if Probe.autoJump {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    Probe.runJumps(jump: { self?.jump(to: 2500) }, back: { self?.loadLatest() })
                }
            }
            return
        }
        let anchor = rotationAnchor ?? captureAnchor()
        rotationAnchor = nil
        let widthChanged = lf.width != cv.frame.width
        cv.frame = lf
        if widthChanged {
            relayoutAll(anchor)
        } else {
            restore(anchor)
        }
        updateChrome()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        rotationAnchor = captureAnchor()
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.rotationAnchor = nil
            self?.updateChrome(force: true)
        }
    }

    // MARK: Measuring

    private var measurer: Measurer {
        if let m = measurerCache, m.width == cv.bounds.width, m.type == type { return m }
        let store = self.store
        let people = People(name: { store.user($0)?.name ?? "Unknown" }, color: { Theme.avatarColor(for: $0) })
        let m = Measurer(width: cv.bounds.width, type: type, people: people)
        measurerCache = m
        geos.removeAll()
        return m
    }

    /// Saved geometry for the row at `i`, measured once per message for the current width and text size.
    private func geo(at i: Int) -> RowGeo {
        let m = items[i]
        let ms = measurer
        let rev = store.revision(of: m.id)
        if let g = geos[m.id], g.revision == rev { return g }
        let g = ms.measure(RowContent(m), RowFlags(pres[i]), boosts: store.boosts(of: m), revision: rev)
        geos[m.id] = g
        return g
    }

    private func presentations(for page: [Message]) -> [MessagePresentation] {
        guard let first = page.first, let idx = store.index(of: first.id) else { return [] }
        return Grouping.presentations(of: page, previous: idx > 0 ? store.all[idx - 1] : nil,
                                      currentUserID: store.currentUserID)
    }

    // MARK: Geometry helpers

    private var minOffsetY: CGFloat { -Metrics.headerHeight }
    private var maxOffsetY: CGFloat { max(minOffsetY, layout.contentHeight - cv.bounds.height) }
    private var atLatest: Bool { items.last?.id == store.all.last?.id }

    private func isPinned() -> Bool {
        atLatest && layout.contentHeight - (cv.contentOffset.y + cv.bounds.height) <= 100
    }

    /// The anchor a relayout (rotation, text size) restored, kept while the reader has not moved, so a
    /// round trip (portrait, landscape, portrait) lands exactly where it started.
    private var sticky: (anchor: Anchor, offsetY: CGFloat, first: MessageID?, count: Int)?

    private func captureAnchor() -> Anchor {
        if let s = sticky, abs(s.offsetY - cv.contentOffset.y) < 0.5, s.first == items.first?.id, s.count == items.count {
            return s.anchor
        }
        sticky = nil
        let pinned = isPinned()
        let visTop = cv.contentOffset.y + Metrics.headerHeight
        guard !items.isEmpty, let i = layout.firstIndex(bottomBelow: visTop), i < items.count else {
            return Anchor(id: nil, dy: 0, pinned: pinned)
        }
        return Anchor(id: items[i].id, dy: layout.top(i) - visTop, pinned: pinned)
    }

    private func index(of id: MessageID) -> Int? {
        guard let first = items.first?.id else { return nil }
        let i = id - first
        return i >= 0 && i < items.count && items[i].id == id ? i : nil
    }

    private func targetY(_ a: Anchor) -> CGFloat? {
        if a.pinned && atLatest { return maxOffsetY }
        guard let id = a.id, let i = index(of: id) else { return nil }
        // If the row got shorter than the part that was hidden, keep a sliver of it on screen.
        let dy = max(a.dy, -(layout.height(i) - 1))
        return layout.top(i) - dy - Metrics.headerHeight
    }

    private func clamp(_ y: CGFloat) -> CGFloat {
        let s = view.window?.screen.scale ?? 3
        return (min(max(y, minOffsetY), maxOffsetY) * s).rounded() / s
    }

    /// Puts the list at `y` in one pass with no animation, and tells the layout so UIKit does not move it.
    private func applyOffset(_ y: CGFloat) {
        let y = clamp(y)
        layout.pendingOffset = CGPoint(x: 0, y: y)
        if cv.contentOffset.y != y { cv.contentOffset = CGPoint(x: 0, y: y) }
        cv.layoutIfNeeded()
        if cv.contentOffset.y != y { cv.contentOffset = CGPoint(x: 0, y: y) }
        layout.pendingOffset = nil
    }

    private func restore(_ a: Anchor) {
        if let y = targetY(a) { applyOffset(y) }
    }

    // MARK: Window changes

    private enum Placement { case bottom, top(MessageID) }

    private func replaceWindow(_ page: [Message], place: Placement) {
        var t = [CACurrentMediaTime()]
        items = page
        pres = presentations(for: page)
        geos.removeAll()
        let gs = items.indices.map { geo(at: $0) }
        t.append(CACurrentMediaTime())
        UIView.performWithoutAnimation {
            layout.setRows(heights: gs.map(\.height), gaps: gs.map(\.gapBefore),
                           welcome: items.first?.id == 1, welcomeHeight: WelcomeView.height)
            switch place {
            case .bottom: layout.pendingOffset = CGPoint(x: 0, y: clamp(maxOffsetY))
            case .top(let id): layout.pendingOffset = index(of: id).map { CGPoint(x: 0, y: clamp(layout.top($0) - Metrics.headerHeight)) }
            }
            cv.reloadData()
            #if OFFSET_FIRST
            // Spike arm: put the list at its final offset before the one layout pass, so cells are made once.
            if let y = layout.pendingOffset { cv.contentOffset = y }
            #endif
            cv.layoutIfNeeded()
            t.append(CACurrentMediaTime())
            switch place {
            case .bottom: applyOffset(maxOffsetY)
            case .top(let id): if let i = index(of: id) { applyOffset(layout.top(i) - Metrics.headerHeight) }
            }
        }
        t.append(CACurrentMediaTime())
        updateChrome()
        t.append(CACurrentMediaTime())
        if case .top = place, Probe.autoJump { Probe.phases("measure reload+layout offset chrome", t) }
    }

    private func loadLatest() {
        replaceWindow(Array(Windowing.lastPage(store.all)), place: .bottom)
    }

    private func jump(to id: MessageID) {
        let page = Array(Windowing.around(id, in: store.all, size: 20))
        guard !page.isEmpty else { return }
        replaceWindow(page, place: .top(id))
    }

    private func relayoutAll(_ anchor: Anchor) {
        geos.removeAll()
        guard !items.isEmpty else { return }
        let gs = items.indices.map { geo(at: $0) }
        UIView.performWithoutAnimation {
            layout.setRows(heights: gs.map(\.height), gaps: gs.map(\.gapBefore),
                           welcome: items.first?.id == 1, welcomeHeight: WelcomeView.height)
            layout.pendingOffset = targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
            cv.reloadData()
            cv.layoutIfNeeded()
            restore(anchor)
        }
        sticky = (anchor, cv.contentOffset.y, items.first?.id, items.count)
    }

    @discardableResult
    private func loadOlder() -> Bool {
        guard let first = items.first, let idx = store.index(of: first.id), idx > 0 else { return false }
        let page = Array(Windowing.page(before: first.id, in: store.all))
        guard !page.isEmpty else { return false }
        var anchor = captureAnchor()
        anchor.pinned = false
        let newPres = presentations(for: page)
        UIView.performWithoutAnimation {
            cv.performBatchUpdates {
                items.insert(contentsOf: page, at: 0)
                pres.insert(contentsOf: newPres, at: 0)
                let gs = (0..<page.count).map { geo(at: $0) }
                layout.prepend(heights: gs.map(\.height), gaps: gs.map(\.gapBefore),
                               welcome: items[0].id == 1, welcomeHeight: WelcomeView.height)
                layout.pendingOffset = targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
                cv.insertItems(at: (0..<page.count).map { IndexPath(item: $0, section: 0) })
            }
            restore(anchor)
        }
        if items.count > maxLoaded + 20 { trimBottom(to: maxLoaded) }
        updateChrome()
        return true
    }

    private func loadNewer() {
        guard !atLatest, let last = items.last else { return }
        let page = Array(Windowing.page(after: last.id, in: store.all))
        guard !page.isEmpty else { return }
        let anchor = captureAnchor()
        var p = presentations(for: [last] + page)
        p.removeFirst()
        UIView.performWithoutAnimation {
            cv.performBatchUpdates {
                let start = items.count
                items += page
                pres += p
                let gs = (start..<items.count).map { geo(at: $0) }
                layout.append(heights: gs.map(\.height), gaps: gs.map(\.gapBefore))
                layout.pendingOffset = targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
                cv.insertItems(at: (start..<items.count).map { IndexPath(item: $0, section: 0) })
            }
            restore(anchor)
        }
        if items.count > maxLoaded + 20 { trimTop(to: maxLoaded) }
        updateChrome()
    }

    /// Drops the oldest rows as a step of its own: data, reloadData, final offset, no animation.
    private func trimTop(to count: Int) {
        let n = items.count - count
        guard n > 0 else { return }
        let tt = CACurrentMediaTime()
        defer { Probe.trimSeconds += CACurrentMediaTime() - tt; Probe.trims += 1 }
        let anchor = captureAnchor()
        for m in items[0..<n] { geos[m.id] = nil }
        items.removeFirst(n)
        pres.removeFirst(n)
        UIView.performWithoutAnimation {
            layout.removeFirst(n, welcome: items.first?.id == 1, welcomeHeight: WelcomeView.height)
            layout.pendingOffset = targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
            cv.reloadData()
            #if NO_FORCED_LAYOUT
            if let y = layout.pendingOffset { cv.contentOffset = y }
            #else
            #if OFFSET_FIRST
            if let y = layout.pendingOffset { cv.contentOffset = y }
            #endif
            cv.layoutIfNeeded()
            restore(anchor)
            #endif
        }
    }

    private func trimBottom(to count: Int) {
        let n = items.count - count
        guard n > 0 else { return }
        var anchor = captureAnchor()
        anchor.pinned = false
        for m in items[(items.count - n)...] { geos[m.id] = nil }
        items.removeLast(n)
        pres.removeLast(n)
        UIView.performWithoutAnimation {
            layout.removeLast(n)
            layout.pendingOffset = targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
            cv.reloadData()
            cv.layoutIfNeeded()
            restore(anchor)
        }
    }

    /// A loaded message changed (new boosts): re-measure that row only, keep the pin or the reader's place.
    private func rowChanged(_ i: Int) {
        let anchor = captureAnchor()
        Probe.updates += 1
        UIView.performWithoutAnimation {
            cv.performBatchUpdates {
                let g = geo(at: i)
                layout.update(i, height: g.height, gap: g.gapBefore)
                layout.pendingOffset = targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
                cv.reconfigureItems(at: [IndexPath(item: i, section: 0)])
            }
            restore(anchor)
        }
    }

    // MARK: Live updates

    private func appendLive(_ m: Message) {
        let wasLatest = atLatest
        let pinned = isPinned()
        store.append(m)
        guard wasLatest, let prev = items.last else {
            updateChrome()
            return
        }
        if pinned && items.count >= maxLoaded + 20 { trimTop(to: maxLoaded - 1) }
        let p = Grouping.presentation(of: m, after: prev, currentUserID: store.currentUserID)
        Probe.updates += 1
        UIView.performWithoutAnimation {
            cv.performBatchUpdates {
                items.append(m)
                pres.append(p)
                let g = geo(at: items.count - 1)
                layout.append(heights: [g.height], gaps: [g.gapBefore])
                if pinned { layout.pendingOffset = CGPoint(x: 0, y: clamp(maxOffsetY)) }
                cv.insertItems(at: [IndexPath(item: items.count - 1, section: 0)])
            }
            if pinned { applyOffset(maxOffsetY) }
        }
        updateChrome()
    }

    private func addBoost(_ b: BoostItem, to id: MessageID) {
        store.addBoost(b, to: id)
        if let i = index(of: id) { rowChanged(i) }
        updateChrome()
    }

    private func startStream() {
        guard streamTask == nil, !streamFinished else { return }
        let feed = FakeLiveFeed(dataset: store.dataset)
        Probe.streamStarted()
        streamTask = Task { @MainActor [weak self] in
            for await event in feed.play() {
                guard let self else { return }
                #if COALESCE_TIMER || COALESCE_RUNLOOP
                self.enqueue(event)
                continue
                #endif
                switch event {
                case .message(let m): self.appendLive(m)
                case .boost(let id, let b): self.addBoost(BoostItem(boosterID: b.boosterID, content: b.content), to: id)
                case .typingStarted, .typingStopped: break
                }
            }
            #if COALESCE_TIMER || COALESCE_RUNLOOP
            self?.flush()
            #endif
            Probe.streamDone()
            self?.streamFinished = true
            self?.streamTask = nil
            self?.debugBar?.doneLabel.isHidden = false
            self?.updateChrome()
        }
    }

    // MARK: Spike arms: coalesced live updates

    private var chromeScheduled = false
    private var pending: [FeedEvent] = []
    private var flushScheduled = false

    private func enqueue(_ e: FeedEvent) {
        pending.append(e)
        guard !flushScheduled else { return }
        flushScheduled = true
        #if COALESCE_TIMER
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.flush() }
        #else
        DispatchQueue.main.async { [weak self] in self?.flush() }
        #endif
    }

    /// Applies every pending message and boost as one batch update, then the chrome once.
    private func flush() {
        flushScheduled = false
        let events = pending
        pending.removeAll()
        guard !events.isEmpty else { return }
        let wasLatest = atLatest
        let pinned = isPinned()
        var fresh: [Message] = []
        var changed = Set<MessageID>()
        for e in events {
            switch e {
            case .message(let m):
                store.append(m)
                if wasLatest { fresh.append(m) }
            case .boost(let id, let b):
                store.addBoost(BoostItem(boosterID: b.boosterID, content: b.content), to: id)
                changed.insert(id)
            case .typingStarted, .typingStopped: break
            }
        }
        guard wasLatest, !items.isEmpty else {
            for id in changed { if let i = index(of: id) { rowChanged(i) } }
            updateChrome()
            return
        }
        if pinned && items.count + fresh.count > maxLoaded + 20 { trimTop(to: max(1, maxLoaded - fresh.count)) }
        let anchor = captureAnchor()
        Probe.updates += 1
        UIView.performWithoutAnimation {
            cv.performBatchUpdates {
                var reconf: [IndexPath] = []
                for id in changed {
                    guard let i = index(of: id) else { continue }
                    let g = geo(at: i)
                    layout.update(i, height: g.height, gap: g.gapBefore)
                    reconf.append(IndexPath(item: i, section: 0))
                }
                let start = items.count
                var hs: [CGFloat] = [], gs: [CGFloat] = []
                for m in fresh {
                    let p = Grouping.presentation(of: m, after: items[items.count - 1], currentUserID: store.currentUserID)
                    items.append(m)
                    pres.append(p)
                    let g = geo(at: items.count - 1)
                    hs.append(g.height)
                    gs.append(g.gapBefore)
                }
                if !fresh.isEmpty {
                    layout.append(heights: hs, gaps: gs)
                    cv.insertItems(at: (start..<items.count).map { IndexPath(item: $0, section: 0) })
                }
                if !reconf.isEmpty { cv.reconfigureItems(at: reconf) }
                layout.pendingOffset = pinned ? CGPoint(x: 0, y: clamp(maxOffsetY))
                    : targetY(anchor).map { CGPoint(x: 0, y: clamp($0)) }
            }
            #if NO_FORCED_LAYOUT
            // Set the final offset and let the next display pass lay the list out once.
            let y = pinned ? clamp(maxOffsetY) : (targetY(anchor).map { clamp($0) } ?? cv.contentOffset.y)
            layout.pendingOffset = CGPoint(x: 0, y: y)
            if cv.contentOffset.y != y { cv.contentOffset = CGPoint(x: 0, y: y) }
            #else
            if pinned { applyOffset(maxOffsetY) } else { restore(anchor) }
            #endif
        }
        updateChrome()
    }

    private func boostBurst() {
        guard let newest = store.all.last?.id else { return }
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        for k in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(k)) { [weak self] in
                self?.addBoost(BoostItem(boosterID: 2 + k, content: emoji[k]), to: newest)
            }
        }
    }

    // MARK: Text size

    private static let sizes: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
    ]

    private func textSizeDidChange() {
        let t = TypeScale(category: traitCollection.preferredContentSizeCategory)
        guard t != type, didInitialLoad else { type = t; return }
        let anchor = captureAnchor()
        type = t
        relayoutAll(anchor)
        updateChrome()
    }

    private func stepTextSize() {
        let current = traitCollection.preferredContentSizeCategory
        if let i = Self.sizes.firstIndex(of: current), i + 1 < Self.sizes.count {
            traitOverrides.preferredContentSizeCategory = Self.sizes[i + 1]
        } else {
            traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
        }
        updateTraitsIfNeeded()
        textSizeDidChange()
    }

    // MARK: Debug bar

    private func debugAction(_ name: String, event: UIEvent?) {
        let t0 = event?.timestamp ?? CACurrentMediaTime()
        switch name {
        case "Reset":
            if traitOverrides.contains(UITraitPreferredContentSizeCategory.self) {
                traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
                updateTraitsIfNeeded()
            }
            type = TypeScale(category: traitCollection.preferredContentSizeCategory)
            loadLatest()
            finishTiming(from: t0)
        case "Jump to 2500":
            jump(to: 2500)
            finishTiming(from: t0)
        case "Load older":
            loadOlder()
            finishTiming(from: t0)
        case "Text size +":
            stepTextSize()
            finishTiming(from: t0)
        case "Start stream":
            startStream()
        case "Boost burst":
            boostBurst()
        default:
            break
        }
    }

    private func finishTiming(from t0: CFTimeInterval) {
        timingStart = t0
        if timingLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(timingTick(_:)))
            link.add(to: .main, forMode: .common)
            timingLink = link
        }
    }

    @objc private func timingTick(_ link: CADisplayLink) {
        link.invalidate()
        timingLink = nil
        if let t0 = timingStart {
            lastMs = max(0, Int((CACurrentMediaTime() - t0) * 1000))
            timingStart = nil
        }
        updateChrome(force: true)
    }

    private func stateText() -> String {
        let first = items.first?.id ?? 0, last = items.last?.id ?? 0
        let visTop = cv.contentOffset.y + Metrics.headerHeight
        var top = 0
        var y: CGFloat = 0
        if let i = layout.firstIndex(bottomBelow: visTop), i < items.count {
            top = items[i].id
            y = layout.top(i) - visTop
        }
        var ys = String(format: "%.1f", y)
        if ys == "-0.0" { ys = "0.0" }
        return "first \(first) last \(last) loaded \(items.count) pinned \(isPinned() ? "yes" : "no") top \(top) y \(ys) ms \(lastMs)"
    }

    /// Jump button and state label. While a scroll is moving the label waits for it to stop.
    private func updateChrome(force: Bool = false) {
        guard didInitialLoad else { return }
        #if CHROME_THROTTLE
        // Spike arm: while the stream runs, chrome (jump button, state label) is refreshed at most every 0.1 s.
        if streamTask != nil && !force {
            if !chromeScheduled {
                chromeScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.chromeScheduled = false
                    self?.updateChrome(force: true)
                }
            }
            return
        }
        #endif
        jumpButton.isHidden = isPinned()
        guard let bar = debugBar else { return }
        if timingStart != nil && !force { return }   // the pending tap's frame will update it
        if !force && (cv.isDragging || cv.isDecelerating) { return }
        let s = stateText()
        if bar.stateLabel.text != s { bar.stateLabel.text = s }
    }

    @objc private func jumpToBottomTapped() {
        if atLatest { applyOffset(maxOffsetY) } else { loadLatest() }
        updateChrome()
    }

    // MARK: Data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MessageCell.reuseID, for: indexPath) as! MessageCell
        cell.delegate = self
        cell.configure(geo(at: indexPath.item))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: WelcomeView.reuseID, for: indexPath)
    }

    func replyAction() -> UIAction {
        UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }
    }

    // MARK: Scrolling

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard didInitialLoad, !items.isEmpty else { return }
        let y = scrollView.contentOffset.y
        if y - minOffsetY < 400, !olderScheduled, items[0].id > 1, scrollView.isTracking || scrollView.isDecelerating {
            olderScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.loadOlder()
                self.olderScheduled = false
            }
        }
        if maxOffsetY - y < 400, !newerScheduled, !atLatest, scrollView.isTracking || scrollView.isDecelerating {
            newerScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.loadNewer()
                self.newerScheduled = false
            }
        }
        let pinned = isPinned()
        if jumpButton.isHidden != pinned { jumpButton.isHidden = pinned }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateChrome() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateChrome() }
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { updateChrome() }
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { updateChrome() }
}
