import UIKit
import CampfireKit
import os

@MainActor
final class RoomViewController: UIViewController, UICollectionViewDelegate {
    struct Anchor {
        let id: Int?
        let y: CGFloat
        let pinned: Bool
    }
    struct LayoutKey: Hashable {
        let message: Message
        let extraBoosts: [RoomBoost]
        let threaded: Bool
        let firstDay: Bool
        let nextThreaded: Bool
        let width: CGFloat
        let scale: CGFloat
    }
    private let header = RoomHeader()
    private let composer = ComposerView()
    private let debugBar = UIView()
    private let stateLabel = UILabel()
    private let streamDone = UILabel()
    private let jumpButton = UIButton(type: .custom)
    private var debugButtons: [UIButton] = []
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var dataset: Dataset?
    private var history: [Message] = []
    private var overlays: [Int: Message] = [:]
    private var debugBoosts: [Int: [RoomBoost]] = [:]
    private var pendingDebugBoosts: [(Int, RoomBoost)] = []
    private var users: [Int: User] = [:]
    private(set) var loaded: [Int] = []
    private var sections: [Int] = []
    private var rowLayouts: [Int: MessageLayout] = [:]
    private var keys: [Int: LayoutKey] = [:]
    private var generationTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var boostTask: Task<Void, Never>?
    private var feed: FakeLiveFeed?
    private var pending: [FeedEvent] = []
    private var isApplying = false
    private var needsGeometryUpdate = false
    private var needsTextSizeUpdate = false
    private var isRestoring = false
    private var initialLayoutDone = false
    private var pagingRequested = false
    private var rotationAnchor: Anchor?
    private var currentWidth: CGFloat = 0
    private var scale: CGFloat = 1
    private var sizeIndex: Int?
    private var queuedJumpToBottom = false
    private var queuedDebugTap: UIButton?
    private var tapStarted: CFTimeInterval?
    private var elapsedMS = 0
    private var streamHasStarted = false
    private var hasUnread = false
    private let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
    private let categories: [UIContentSizeCategory] = [.extraSmall,.small,.medium,.large,.extraLarge,.extraExtraLarge,
        .extraExtraExtraLarge,.accessibilityMedium,.accessibilityLarge,.accessibilityExtraLarge,
        .accessibilityExtraExtraLarge,.accessibilityExtraExtraExtraLarge]
    private let signposter = OSSignposter(subsystem: "campfire.bench", category: "Room")
    override var prefersStatusBarHidden: Bool { true }
    deinit {
        generationTask?.cancel(); streamTask?.cancel(); flushTask?.cancel(); boostTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self, sectionIndex < self.sections.count else { return nil }
            let id = self.sections[sectionIndex]
            let height: CGFloat = id == 0 ? WelcomeCell.height(width: environment.container.effectiveContentSize.width, scale: self.scale) : self.rowLayouts[id]?.height ?? 80
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)), subitems: [item])
            return NSCollectionLayoutSection(group: group)
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = Theme.background
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .interactive
        collectionView.accessibilityIdentifier = "room-messages"
        view.addSubview(collectionView)
        view.addSubview(header); view.addSubview(composer)
        let registration = UICollectionView.CellRegistration<MessageCell, Int> { [weak self] cell, _, id in
            guard let self, let layout = self.rowLayouts[id] else { return }
            cell.show(layout, users: self.users)
        }
        let welcome = UICollectionView.CellRegistration<WelcomeCell, Int> { [weak self] cell, _, _ in cell.scale = self?.scale ?? 1; cell.setNeedsLayout() }
        dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collectionView) { list, indexPath, id in
            if id == 0 { return list.dequeueConfiguredReusableCell(using: welcome, for: indexPath, item: id) }
            return list.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
        setupDebugBar()
        jumpButton.setTitle("↓  Jump to bottom", for: .normal)
        jumpButton.titleLabel?.font = Theme.font(14, weight: .semibold)
        jumpButton.setTitleColor(Theme.background, for: .normal)
        jumpButton.backgroundColor = Theme.text; jumpButton.layer.cornerRadius = 18
        jumpButton.accessibilityIdentifier = "jump-to-bottom"
        jumpButton.addTarget(self, action: #selector(jumpToBottom), for: .touchUpInside)
        jumpButton.isHidden = true; view.addSubview(jumpButton)
        updateScale()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: RoomViewController, _: UITraitCollection) in
            guard self.sizeIndex == nil else { return }
            self.relayoutForTextSize()
        }
        generationTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                let dataset = FakeData.generate(size: .k50)
                return (dataset, FakeLiveFeed(dataset: dataset))
            }.value
            guard let self, !Task.isCancelled else { return }
            self.dataset = result.0; self.history = result.0.messages; self.feed = result.1
            self.users = Dictionary(uniqueKeysWithValues: result.0.users.map { ($0.id, $0) })
            self.loaded = Array(Windowing.lastPage(self.history).map(\.id))
            self.view.layoutIfNeeded()
            self.tapStarted = appLaunchTime
            self.render(anchor: Anchor(id: nil, y: 0, pinned: true), replace: true) {
                self.initialLayoutDone = true
            }
        }
    }

    private func setupDebugBar() {
        debugBar.backgroundColor = Theme.bubble
        debugBar.isHidden = !benchmark
        view.addSubview(debugBar)
        let labels = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]
        for (i, label) in labels.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(label, for: .normal); button.titleLabel?.font = Theme.font(12, weight: .semibold)
            button.tintColor = Theme.text; button.tag = i
            button.accessibilityIdentifier = "debug-\(i)"
            button.addTarget(self, action: #selector(debugTap(_:)), for: .touchUpInside)
            debugBar.addSubview(button); debugButtons.append(button)
        }
        stateLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        stateLabel.textColor = Theme.text; stateLabel.adjustsFontSizeToFitWidth = true; stateLabel.minimumScaleFactor = 0.65
        stateLabel.accessibilityIdentifier = "benchmark-state"
        debugBar.addSubview(stateLabel)
        streamDone.text = ""; streamDone.font = Theme.font(10, weight: .semibold); streamDone.textColor = Theme.text
        streamDone.accessibilityIdentifier = "stream-done"; debugBar.addSubview(streamDone)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width
        let safeX = max(view.safeAreaInsets.left, view.safeAreaInsets.right)
        let headerTop = view.bounds.width > view.bounds.height ? view.safeAreaInsets.top : 0
        header.frame = CGRect(x: safeX, y: headerTop, width: w - safeX * 2, height: 60)
        debugBar.frame = CGRect(x: safeX, y: header.frame.maxY, width: w - safeX * 2, height: benchmark ? 88 : 0)
        if benchmark {
            let bw = debugBar.bounds.width / 3
            for (i, b) in debugButtons.enumerated() {
                b.frame = CGRect(x: CGFloat(i % 3) * bw, y: CGFloat(i / 3) * 28, width: bw, height: 28)
            }
            streamDone.frame = CGRect(x: 8, y: 54, width: debugBar.bounds.width - 16, height: 13)
            stateLabel.frame = CGRect(x: 6, y: 67, width: debugBar.bounds.width - 12, height: 18)
        }
        let composerHeight: CGFloat = 90
        composer.frame = CGRect(x: safeX, y: view.bounds.height - composerHeight, width: w - safeX * 2, height: composerHeight)
        let collectionFrame = CGRect(x: safeX, y: debugBar.frame.maxY, width: w - safeX * 2,
                                     height: max(0, composer.frame.minY - debugBar.frame.maxY))
        let anchor = initialLayoutDone && !isApplying && currentWidth != collectionFrame.width ? (rotationAnchor ?? captureAnchor()) : nil
        collectionView.frame = collectionFrame
        jumpButton.frame = CGRect(x: w / 2 - 86, y: composer.frame.minY - 44, width: 172, height: 36)
        if currentWidth != collectionFrame.width {
            currentWidth = collectionFrame.width
            if !loaded.isEmpty, initialLayoutDone {
                if isApplying { needsGeometryUpdate = true }
                else if let anchor { render(anchor: anchor, reconfigureAll: true) }
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let anchor = captureAnchor()
        super.viewWillTransition(to: size, with: coordinator)
        rotationAnchor = anchor
        isRestoring = true
        coordinator.animate(alongsideTransition: { _ in
            self.view.setNeedsLayout(); self.view.layoutIfNeeded()
            self.collectionView.layoutIfNeeded()
            self.restore(anchor)
        }, completion: { _ in
            self.isRestoring = false
            self.rotationAnchor = nil
            self.restore(anchor)
            self.updateState()
            self.performQueuedTap()
        })
    }

    private func message(_ id: Int) -> Message? {
        if let override = overlays[id] { return override }
        guard id > 0, id <= history.count, history[id - 1].id == id else { return nil }
        return history[id - 1]
    }

    private func rebuildLayouts() {
        guard currentWidth > 0 else { return }
        sections = (loaded.first == 1 ? [0] : []) + loaded
        let kept = Set(loaded)
        rowLayouts = rowLayouts.filter { kept.contains($0.key) }
        keys = keys.filter { kept.contains($0.key) }
        for (i, id) in loaded.enumerated() {
            guard let m = message(id) else { continue }
            let previous = message(id - 1)
            let next = i + 1 < loaded.count ? message(loaded[i + 1]) : nil
            let p = Grouping.presentation(of: m, after: previous, currentUserID: 1)
            let nextThreaded = next.map { Grouping.presentation(of: $0, after: m, currentUserID: 1).isThreaded } ?? false
            let key = LayoutKey(message: m, extraBoosts: debugBoosts[id] ?? [], threaded: p.isThreaded, firstDay: p.isFirstOfDay,
                                nextThreaded: nextThreaded, width: currentWidth, scale: scale)
            if keys[id] != key {
                rowLayouts[id] = MessageLayout(message: m, previous: previous, next: next, users: users,
                                               width: currentWidth, scale: scale, extraBoosts: debugBoosts[id] ?? [])
                keys[id] = key
            }
        }
    }

    private func render(anchor: Anchor, replace: Bool = false, changed: [Int] = [], reconfigureAll: Bool = false,
                        completion: (() -> Void)? = nil) {
        guard !loaded.isEmpty else { completion?(); return }
        isApplying = true
        let interval = signposter.beginInterval("Layout update")
        rebuildLayouts()
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        for id in sections { snapshot.appendSections([id]); snapshot.appendItems([id], toSection: id) }
        let old = Set(dataSource.snapshot().itemIdentifiers)
        let updates = (reconfigureAll ? sections : changed).filter { old.contains($0) && sections.contains($0) }
        if !updates.isEmpty { snapshot.reconfigureItems(updates) }
        let done = { [weak self] in
            guard let self else { return }
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
            self.restore(anchor)
            self.collectionView.layoutIfNeeded()
            self.isApplying = false
            self.signposter.endInterval("Layout update", interval)
            if self.needsGeometryUpdate {
                self.needsGeometryUpdate = false
                self.render(anchor: self.rotationAnchor ?? anchor, reconfigureAll: true, completion: completion)
                return
            }
            completion?()
            if self.rotationAnchor == nil, self.queuedJumpToBottom || (self.queuedDebugTap != nil && self.queuedDebugTap?.tag != 3 && self.queuedDebugTap?.tag != 5) {
                self.performQueuedTap()
                return
            }
            // The measurement ends only after the updated rows have reached a layout pass.
            if let started = self.tapStarted {
                self.elapsedMS = Int((CACurrentMediaTime() - started) * 1000)
                self.tapStarted = nil
            }
            self.updateState()
            self.performQueuedTap()
            if self.pagingRequested, self.collectionView.contentOffset.y <= 1,
               !self.collectionView.isDragging, !self.collectionView.isDecelerating {
                self.pagingRequested = false; self.loadOlder()
            }
            if !self.pending.isEmpty || !self.pendingDebugBoosts.isEmpty { self.scheduleFlush() }
        }
        if replace { dataSource.applySnapshotUsingReloadData(snapshot, completion: done) }
        else { dataSource.apply(snapshot, animatingDifferences: false, completion: done) }
    }

    private var isPinned: Bool {
        collectionView.contentSize.height - collectionView.contentOffset.y - collectionView.bounds.height <= 100
    }
    private func captureAnchor() -> Anchor {
        guard collectionView != nil else { return Anchor(id: nil, y: 0, pinned: true) }
        let offset = collectionView.contentOffset.y
        let visible = collectionView.indexPathsForVisibleItems.compactMap { ip -> (Int, CGRect)? in
            guard let id = dataSource.itemIdentifier(for: ip), id > 0,
                  let frame = collectionView.layoutAttributesForItem(at: ip)?.frame,
                  frame.minY + (rowLayouts[id]?.messageHeight ?? frame.height) > offset else { return nil }
            return (id, frame)
        }.sorted { $0.1.minY < $1.1.minY }
        return Anchor(id: visible.first?.0, y: (visible.first?.1.minY ?? offset) - offset, pinned: isPinned)
    }
    private func restore(_ anchor: Anchor) {
        let wasRestoring = isRestoring; isRestoring = true
        defer { isRestoring = wasRestoring }
        let offset: CGFloat
        if anchor.pinned {
            offset = max(0, collectionView.contentSize.height - collectionView.bounds.height)
        } else if let id = anchor.id, let ip = dataSource.indexPath(for: id),
                  let frame = collectionView.layoutAttributesForItem(at: ip)?.frame {
            offset = frame.minY - anchor.y
        } else { return }
        if abs(collectionView.contentOffset.y - offset) > 0.01 {
            collectionView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        }
    }

    private func updateState() {
        guard initialLayoutDone || !loaded.isEmpty else { return }
        let anchor = captureAnchor()
        let y = abs(anchor.y) < 0.05 ? 0 : anchor.y
        stateLabel.text = String(format: "first %d last %d loaded %d pinned %@ top %d y %.1f ms %d",
                                 loaded.first ?? 0, loaded.last ?? 0, loaded.count, isPinned ? "yes" : "no", anchor.id ?? 0, y, elapsedMS)
        stateLabel.accessibilityLabel = stateLabel.text
        jumpButton.isHidden = !hasUnread || isPinned
        if isPinned { hasUnread = false }
    }

    @objc private func debugTap(_ sender: UIButton) {
        guard initialLayoutDone else { return }
        if sender.tag != 3 && sender.tag != 5 { tapStarted = CACurrentMediaTime() }
        if isApplying || rotationAnchor != nil { queuedDebugTap = sender; return }
        performDebugTap(sender)
    }
    private func performQueuedTap() {
        guard !isApplying, rotationAnchor == nil else { return }
        if queuedJumpToBottom { queuedJumpToBottom = false; jumpToBottom(); return }
        if needsTextSizeUpdate { needsTextSizeUpdate = false; relayoutForTextSize(); return }
        guard let sender = queuedDebugTap else { return }
        queuedDebugTap = nil
        performDebugTap(sender)
    }
    private func performDebugTap(_ sender: UIButton) {
        switch sender.tag {
        case 0: reset()
        case 1: jumpTo2500()
        case 2: loadOlder()
        case 3: startStream()
        case 4:
            let current = sizeIndex ?? categories.firstIndex(of: traitCollection.preferredContentSizeCategory) ?? 3
            sizeIndex = current + 1 < categories.count ? current + 1 : nil
            relayoutForTextSize()
        case 5: boostBurst()
        default: break
        }
    }

    private func updateScale() {
        let category = sizeIndex.map { categories[$0] } ?? traitCollection.preferredContentSizeCategory
        scale = UIFontMetrics(forTextStyle: .body).scaledValue(for: 16,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category)) / 16
    }
    private func relayoutForTextSize() {
        if isApplying || rotationAnchor != nil { needsTextSizeUpdate = true; return }
        guard !loaded.isEmpty else { updateScale(); return }
        let anchor = captureAnchor()
        updateScale()
        render(anchor: anchor, reconfigureAll: true)
    }

    private func reset() {
        streamTask?.cancel(); streamTask = nil
        flushTask?.cancel(); flushTask = nil; pending.removeAll(); pendingDebugBoosts.removeAll()
        boostTask?.cancel(); boostTask = nil
        history = dataset?.messages ?? history
        overlays.removeAll(); debugBoosts.removeAll(); streamHasStarted = false
        loaded = Array(Windowing.lastPage(history).map(\.id))
        sizeIndex = nil; updateScale(); hasUnread = false; queuedJumpToBottom = false
        streamDone.text = ""
        render(anchor: Anchor(id: nil, y: 0, pinned: true), replace: true, reconfigureAll: true)
    }

    private func jumpTo2500() {
        loaded = Windowing.around(2500, in: history).map(\.id)
        hasUnread = false
        render(anchor: Anchor(id: 2500, y: 0, pinned: false), replace: true)
    }

    private func loadOlder() {
        if isApplying { pagingRequested = true; return }
        guard let first = loaded.first else { return }
        let anchor = captureAnchor()
        let page = Windowing.page(before: first, in: history).map(\.id)
        guard !page.isEmpty else {
            if let started = tapStarted { elapsedMS = Int((CACurrentMediaTime() - started) * 1000); tapStarted = nil }
            updateState(); return
        }
        loaded.insert(contentsOf: page, at: 0)
        if loaded.count > Windowing.maxLoaded,
           let anchorID = anchor.id, let index = loaded.firstIndex(of: anchorID), index < Windowing.maxLoaded - 40 {
            loaded.removeLast(loaded.count - Windowing.maxLoaded)
        }
        // Paging always preserves the row being read, including when the whole page was visible.
        render(anchor: Anchor(id: anchor.id, y: anchor.y, pinned: false))
    }

    @objc private func jumpToBottom() {
        guard !isApplying, rotationAnchor == nil else { queuedJumpToBottom = true; return }
        hasUnread = false
        loaded = Windowing.lastPage(history).map(\.id)
        render(anchor: Anchor(id: nil, y: 0, pinned: true), replace: true)
    }

    private func startStream() {
        guard !streamHasStarted, let feed else { return }
        streamHasStarted = true; streamDone.text = ""
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard let self, !Task.isCancelled else { return }
                self.pending.append(event); self.scheduleFlush()
            }
            guard let self, !Task.isCancelled else { return }
            self.flushTask?.cancel(); self.flushTask = nil
            self.flushEvents()
            self.streamDone.text = "Stream done"
        }
    }
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard let self, !Task.isCancelled else { return }
            self.flushTask = nil
            self.flushEvents()
        }
    }
    private func flushEvents() {
        guard !isApplying, !collectionView.isDragging, !collectionView.isDecelerating else { scheduleFlush(); return }
        guard !pending.isEmpty || !pendingDebugBoosts.isEmpty else { return }
        let anchor = captureAnchor()
        let events = pending; pending.removeAll(keepingCapacity: true)
        var changed = Set<Int>()
        for (id, boost) in pendingDebugBoosts { debugBoosts[id, default: []].append(boost); changed.insert(id) }
        pendingDebugBoosts.removeAll()
        for event in events {
            switch event {
            case .message(let m):
                guard m.id > history.count else { continue }
                history.append(m); loaded.append(m.id)
                if !anchor.pinned { hasUnread = true }
            case .boost(let id, let boost):
                guard var m = message(id) else { continue }
                m.boosts.append(boost); overlays[id] = m; changed.insert(id)
            case .typingStarted, .typingStopped: break
            }
        }
        if anchor.pinned, loaded.count > Windowing.maxLoaded {
            loaded.removeFirst(loaded.count - Windowing.maxLoaded)
        }
        render(anchor: anchor, changed: Array(changed))
    }

    private func boostBurst() {
        guard let id = history.last?.id else { return }
        boostTask?.cancel()
        boostTask = Task { [weak self] in
            for (index, emoji) in ["👍","🎉","🔥","❤️","😂"].enumerated() {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }
                let boost = RoomBoost(id: 2_000_000 + (self.debugBoosts[id]?.count ?? 0), boosterID: index + 2, content: emoji)
                self.pendingDebugBoosts.append((id, boost)); self.scheduleFlush()
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard initialLayoutDone, !isApplying, !isRestoring else { return }
        if !scrollView.isDragging && !scrollView.isDecelerating { updateState() }
        if scrollView.contentOffset.y <= 0, scrollView.isDragging { pagingRequested = true }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { finishScrolling() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { finishScrolling() }
    private func finishScrolling() {
        updateState()
        if pagingRequested || collectionView.contentOffset.y <= 1 {
            pagingRequested = false
            loadOlder()
        }
    }
}
