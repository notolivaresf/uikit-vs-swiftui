import UIKit
import CampfireKit

final class RoomViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let store = RoomStore()
    private lazy var builder = RowBuilder(users: store.dataset.users, currentUserID: store.dataset.currentUserID)
    private var metrics = Metrics(category: .large)
    private var rowWidth: CGFloat = 0
    private var cache: [MessageID: RowGeometry] = [:]
    private var rows: [RowGeometry] = []
    private let layout = RoomLayout()
    private var cv: UICollectionView!
    private let header = HeaderBar()
    private let composer = ComposerView()
    private let jumpButton = JumpButton()
    private var debugBar: DebugBar?

    /// What to hold still across a change: the bottom, or a row's top relative to the header's bottom edge.
    private enum Anchor { case pinned, row(MessageID, CGFloat) }
    private var anchor: Anchor = .pinned
    private var tracking = true
    private var didInitialLoad = false
    private var lastMs = 0
    private var feedTask: Task<Void, Never>?
    private var nextBoostID = 2_000_000

    private static let sizeCategories: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge,
    ]

    private var headerBottom: CGFloat { view.safeAreaInsets.top + K.headerHeight }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = Colors.background
        cv.contentInsetAdjustmentBehavior = .never
        cv.alwaysBounceVertical = true
        cv.autoresizingMask = []
        cv.dataSource = self
        cv.delegate = self
        cv.register(MessageCell.self, forCellWithReuseIdentifier: MessageCell.reuseID)
        cv.register(WelcomeView.self, forSupplementaryViewOfKind: RoomLayout.welcomeKind,
                    withReuseIdentifier: WelcomeView.reuseID)
        cv.accessibilityIdentifier = "room"
        view.addSubview(cv)
        view.addSubview(header)
        view.addSubview(composer)
        jumpButton.isHidden = true
        jumpButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(jumpToBottom)))
        view.addSubview(jumpButton)
        if UserDefaults.standard.bool(forKey: "uvsBenchmark") {
            let bar = DebugBar()
            bar.onTap = { [weak self] title, t in self?.debugTap(title, at: t) }
            view.addSubview(bar)
            debugBar = bar
        }
        // Test hook: open the room around a given message (e.g. 1 shows the welcome card).
        let start = UserDefaults.standard.integer(forKey: "uvsStartAt")
        if start > 0 { store.jump(to: start) } else { store.showNewest() }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: RoomViewController, _) in
            self.view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        let W = view.bounds.width, H = view.bounds.height
        header.safeTop = safe.top
        header.safeLeft = safe.left
        header.safeRight = safe.right
        header.frame = CGRect(x: 0, y: 0, width: W, height: headerBottom)
        var bottom = H - max(safe.bottom, 24)
        if let bar = debugBar {
            bar.frame = CGRect(x: safe.left, y: H - safe.bottom - DebugBar.height, width: W - safe.left - safe.right,
                               height: DebugBar.height + safe.bottom)
            bottom = bar.frame.minY - 8
        }
        composer.frame = CGRect(x: safe.left, y: bottom - K.composerHeight, width: W - safe.left - safe.right,
                                height: K.composerHeight)
        let cvFrame = CGRect(x: safe.left, y: 0, width: W - safe.left - safe.right,
                             height: composer.frame.minY - K.composerGapAbove)
        jumpButton.frame = CGRect(x: cvFrame.maxX - K.screenPadX - 42, y: cvFrame.maxY - 42 - 8, width: 42, height: 42)

        let category = traitCollection.preferredContentSizeCategory == .unspecified ? .large
            : traitCollection.preferredContentSizeCategory
        let rebuild = cvFrame.width != rowWidth || category != metrics.category
        let inset = UIEdgeInsets(top: headerBottom + K.rowGap, left: 0, bottom: 0, right: 0)
        guard rebuild || cv.frame != cvFrame || cv.contentInset != inset || !didInitialLoad else { return }

        let keep = anchor
        tracking = false
        UIView.performWithoutAnimation {
            if cv.frame != cvFrame { cv.frame = cvFrame }
            if cv.contentInset != inset { cv.contentInset = inset }
            if rebuild {
                rowWidth = cvFrame.width
                metrics = Metrics(category: category)
                cache.removeAll()
                rebuildRows()
                reload()
            }
            if didInitialLoad {
                restore(keep)
            } else if case let start = UserDefaults.standard.integer(forKey: "uvsStartAt"), start > 0 {
                if start == 1 { setOffset(minOffset) } else { restore(.row(start, 0)) }
            } else {
                restore(.pinned)
            }
            cv.layoutIfNeeded()
        }
        tracking = true
        anchor = captureAnchor()
        if !didInitialLoad {
            didInitialLoad = true
            measure(since: appLaunchTime)
        }
        updateChrome()
    }

    // MARK: Rows and layout

    private func geometry(at i: Int) -> RowGeometry {
        let m = store.all[i]
        if let g = cache[m.id] { return g }
        let g = builder.build(m, store.presentation(at: i), extraBoosts: store.localBoosts[m.id] ?? [], width: rowWidth, m: metrics)
        cache[m.id] = g
        return g
    }

    private func rebuildRows() {
        if cache.count > 2000 { cache.removeAll() }
        rows = (store.lo..<store.hi).map { geometry(at: $0) }
        applyLayout()
    }

    private func applyLayout() {
        let welcome = store.lo == 0
        var tops: [CGFloat] = []
        tops.reserveCapacity(rows.count)
        var y: CGFloat = welcome ? WelcomeView.height + K.rowGap : 0
        for (i, r) in rows.enumerated() {
            if i > 0 { y += r.isThreaded ? K.threadedGap : K.rowGap }
            tops.append(y)
            y += r.height
        }
        layout.update(tops: tops, heights: rows.map(\.height), contentHeight: y, welcome: welcome, width: rowWidth)
    }

    private func reload() {
        cv.reloadData()
        cv.layoutIfNeeded()
    }

    // MARK: Anchoring

    private var minOffset: CGFloat { -cv.contentInset.top }
    private var maxOffset: CGFloat { max(minOffset, layout.contentHeight - cv.bounds.height) }

    private func setOffset(_ y: CGFloat) {
        let clamped = min(max(y, minOffset), maxOffset)
        if cv.contentOffset.y != clamped { cv.contentOffset = CGPoint(x: 0, y: clamped) }
    }

    private var distanceFromBottom: CGFloat { layout.contentHeight - (cv.contentOffset.y + cv.bounds.height) }

    private var isPinned: Bool { store.includesNewest && distanceFromBottom <= 100 }

    /// Topmost row at least partly visible below the header, and its top's y from the header's bottom edge.
    private func topVisible() -> (index: Int, y: CGFloat)? {
        let line = cv.contentOffset.y + headerBottom - cv.frame.minY
        guard let i = layout.firstRow(below: line) else { return nil }
        return (i, layout.tops[i] - line)
    }

    private func captureAnchor() -> Anchor {
        if rows.isEmpty || isPinned { return .pinned }
        if let t = topVisible() { return .row(rows[t.index].messageID, t.y) }
        return .pinned
    }

    private func restore(_ a: Anchor) {
        switch a {
        case .pinned:
            setOffset(maxOffset)
        case .row(let id, let y):
            guard let i = store.index(of: id), i >= store.lo, i < store.hi else { return }
            setOffset(layout.tops[i - store.lo] - (headerBottom - cv.frame.minY) - y)
        }
    }

    /// Runs a programmatic change with scroll tracking off, then re-reads the anchor.
    private func change(_ body: () -> Void) {
        tracking = false
        UIView.performWithoutAnimation(body)
        tracking = true
        anchor = captureAnchor()
        updateChrome()
    }

    // MARK: Paging

    private func loadOlder() {
        guard store.lo > 0 else { return }
        let a = captureAnchor()
        change {
            store.loadOlder()
            rebuildRows()
            reload()
            restore(a)
            cv.layoutIfNeeded()
        }
    }

    private func loadNewer() {
        guard !store.includesNewest else { return }
        let a = captureAnchor()
        change {
            store.loadNewer()
            rebuildRows()
            reload()
            restore(a)
            cv.layoutIfNeeded()
        }
    }

    private func showNewest() {
        change {
            store.showNewest()
            rebuildRows()
            reload()
            restore(.pinned)
            cv.layoutIfNeeded()
        }
    }

    private func jump(to id: MessageID) {
        change {
            store.jump(to: id)
            rebuildRows()
            reload()
            guard let i = store.index(of: id) else { return }
            var target = layout.tops[i - store.lo] - (headerBottom - cv.frame.minY)
            // Make sure there is enough below to put the row at the top.
            while target > maxOffset && !store.includesNewest {
                store.loadNewer()
                rebuildRows()
                reload()
                target = layout.tops[i - store.lo] - (headerBottom - cv.frame.minY)
            }
            setOffset(target)
            cv.layoutIfNeeded()
        }
    }

    @objc private func jumpToBottom() {
        if store.includesNewest {
            change { setOffset(maxOffset); cv.layoutIfNeeded() }
        } else {
            showNewest()
        }
    }

    // MARK: Live updates

    private func receive(_ message: Message) {
        let a = captureAnchor()
        var pinned = false
        if case .pinned = a { pinned = true }
        guard store.append(message, canGrow: pinned) else { updateChrome(); return }
        change {
            rows.append(geometry(at: store.hi - 1))
            var trimmed = false
            if case .pinned = a, store.trimOldest() > 0 {
                trimmed = true
                rebuildRows()
            } else {
                applyLayout()
            }
            if trimmed {
                reload()
            } else {
                cv.performBatchUpdates { cv.insertItems(at: [IndexPath(item: rows.count - 1, section: 0)]) }
            }
            if case .pinned = a {
                if !cv.isTracking { restore(.pinned) }
            } else if trimmed {
                restore(a)
            }
            cv.layoutIfNeeded()
        }
    }

    private func receiveBoost(_ boost: Boost, to id: MessageID) {
        let a = captureAnchor()
        guard let i = store.addBoost(boost, to: id) else { return }
        rowChanged(at: i, id: id, anchor: a)
    }

    private func receiveLocalBoost(_ boost: BoostItem, to id: MessageID) {
        let a = captureAnchor()
        guard let i = store.addLocalBoost(boost, to: id) else { return }
        rowChanged(at: i, id: id, anchor: a)
    }

    private func rowChanged(at i: Int, id: MessageID, anchor a: Anchor) {
        cache[id] = nil
        guard i >= store.lo, i < store.hi else { return }
        change {
            rows[i - store.lo] = geometry(at: i)
            applyLayout()
            cv.reconfigureItems(at: [IndexPath(item: i - store.lo, section: 0)])
            cv.layoutIfNeeded()
            if case .pinned = a, cv.isTracking {
                // Leave a finger-held scroll alone.
            } else {
                restore(a)
            }
            cv.layoutIfNeeded()
        }
    }

    private func startStream() {
        guard feedTask == nil else { return }
        let feed = FakeLiveFeed(dataset: store.dataset)
        feedTask = Task { @MainActor [weak self] in
            for await event in feed.play() {
                guard let self else { return }
                switch event {
                case .message(let m): self.receive(m)
                case .boost(let id, let b): self.receiveBoost(b, to: id)
                case .typingStarted, .typingStopped: break
                }
            }
            self?.debugBar?.doneLabel.isHidden = false
        }
    }

    private func boostBurst() {
        guard let target = store.newestID else { return }
        let emoji = ["👍", "🎉", "🔥", "❤️", "😂"]
        for k in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200 * k)) { [weak self] in
                guard let self else { return }
                let b = BoostItem(id: self.nextBoostID, boosterID: 2 + k, content: emoji[k])
                self.nextBoostID += 1
                self.receiveLocalBoost(b, to: target)
            }
        }
    }

    // MARK: Text size

    private func stepTextSize() {
        let current = traitCollection.preferredContentSizeCategory
        let window = view.window
        if current == RoomViewController.sizeCategories.last {
            window?.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
        } else {
            let i = RoomViewController.sizeCategories.firstIndex(of: current) ?? 3
            window?.traitOverrides.preferredContentSizeCategory = RoomViewController.sizeCategories[i + 1]
        }
        applyTraitChangeNow()
    }

    private func resetTextSize() {
        if view.window?.traitOverrides.contains(UITraitPreferredContentSizeCategory.self) == true {
            view.window?.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            applyTraitChangeNow()
        }
    }

    private func applyTraitChangeNow() {
        anchor = captureAnchor()
        view.window?.updateTraitsIfNeeded()
        updateTraitsIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // MARK: Debug bar

    private func debugTap(_ title: String, at t: TimeInterval) {
        var timed = true
        switch title {
        case "Reset":
            resetTextSize()
            showNewest()
        case "Jump to 2500": jump(to: 2500)
        case "Load older": loadOlder()
        case "Start stream": startStream(); timed = false
        case "Text size +": stepTextSize()
        case "Boost burst": boostBurst(); timed = false
        default: timed = false
        }
        cv.layoutIfNeeded()
        if timed { measure(since: t) }
        updateDebugLabel()
    }

    /// Records whole milliseconds from `start` until the current layout is committed to the screen.
    private func measure(since start: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.lastMs = Int((CACurrentMediaTime() - start) * 1000)
            self.updateDebugLabel()
        }
        CATransaction.commit()
        lastMs = Int((CACurrentMediaTime() - start) * 1000)
        updateDebugLabel()
    }

    private func updateChrome() {
        jumpButton.isHidden = isPinned || rows.isEmpty
        updateDebugLabel()
    }

    private func updateDebugLabel() {
        guard let bar = debugBar, store.count > 0 else { return }
        var top = 0
        var y: CGFloat = 0
        if let t = topVisible() {
            top = rows[t.index].messageID
            y = t.y
        }
        if abs(y) < 0.05 { y = 0 }
        let text = "first \(store.all[store.lo].id) last \(store.all[store.hi - 1].id) loaded \(store.count) "
            + "pinned \(isPinned ? "yes" : "no") top \(top) y \(String(format: "%.1f", y)) ms \(lastMs)"
        if bar.stateLabel.text != text { bar.stateLabel.text = text }
    }

    // MARK: UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { rows.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MessageCell.reuseID, for: indexPath) as! MessageCell
        cell.configure(rows[indexPath.item], m: metrics)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: WelcomeView.reuseID, for: indexPath)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard tracking, didInitialLoad else { return }
        anchor = captureAnchor()
        let off = cv.contentOffset.y
        if store.lo > 0 && off - minOffset < 600 {
            loadOlder()
        } else if !store.includesNewest && distanceFromBottom < 600 {
            loadNewer()
        }
        updateChrome()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateChrome() }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateChrome() }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        anchor = captureAnchor()
        updateChrome()
    }
}

