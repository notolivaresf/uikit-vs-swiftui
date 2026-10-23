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
    private let header = RoomHeader()
    private let composer = ComposerView()
    private let debugBar = UIView()
    private let stateLabel = UILabel()
    private let streamDone = UILabel()
    private let jumpButton = UIButton(type: .custom)
    private var debugButtons: [UIButton] = []
    private let rowsLayout = RoomRowsLayout()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var history: [Message] = []
    private var dataset: Dataset?
    private var overlays: [Int: Message] = [:]
    private var debugBoosts: [Int: [RoomBoost]] = [:]
    private var pendingDebugBoosts: [(Int, RoomBoost)] = []
    private var users: [Int: User] = [:]
    private(set) var loaded: [Int] = []
    private var rowIDs: [Int] = []
    private var rowLayouts: [Int: MessageLayout] = [:]
    private var following: [Int: Int] = [:]
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
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: rowsLayout)
        collectionView.backgroundColor = Theme.background
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.selfSizingInvalidation = .disabled
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
            let result = await initialRoomData.value
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

    private func rebuildLayouts(changed: Set<Int>, all: Bool, inserted: [Int], removed: [Int],
                                removedCount: Int, prepend: Bool) -> Set<Int> {
        guard currentWidth > 0 else { return [] }
        let previousFirst = rowIDs.first == 0 ? rowIDs.dropFirst().first : rowIDs.first
        let previousLast = rowIDs.last
        let hadWelcome = rowIDs.first == 0
        let hasWelcome = loaded.first == 1
        var candidates = Set(inserted).union(changed)
        if all {
            rowIDs = (hasWelcome ? [0] : []) + loaded
            rowLayouts.removeAll(keepingCapacity: true)
            following.removeAll(keepingCapacity: true)
            for (i, id) in loaded.enumerated() where i + 1 < loaded.count { following[id] = loaded[i + 1] }
            candidates = Set(loaded)
        } else {
            for id in removed { rowLayouts.removeValue(forKey: id); following.removeValue(forKey: id) }
            if prepend {
                if removedCount > 0 { rowIDs.removeLast(removedCount) }
                if !inserted.isEmpty { rowIDs.insert(contentsOf: inserted, at: hadWelcome ? 1 : 0) }
                if hasWelcome && !hadWelcome { rowIDs.insert(0, at: 0) }
            } else {
                let count = removedCount + (hadWelcome && !hasWelcome ? 1 : 0)
                if count > 0 { rowIDs.removeFirst(count) }
                if !inserted.isEmpty { rowIDs.append(contentsOf: inserted) }
            }
            for (i, id) in inserted.enumerated() {
                following[id] = i + 1 < inserted.count ? inserted[i + 1] : prepend ? previousFirst : nil
            }
            if !prepend, let first = inserted.first, let previousLast, rowLayouts[previousLast] != nil {
                following[previousLast] = first
            }
            if let last = loaded.last { following.removeValue(forKey: last) }
        }
        let added = Set(inserted)
        var dirty = Set<Int>()
        for id in candidates where all || added.contains(id) || rowLayouts[id] != nil {
            guard let m = message(id) else { continue }
            rowLayouts[id] = MessageLayout(message: m, previous: message(id - 1), next: following[id].flatMap { message($0) }, users: users,
                                           width: currentWidth, scale: scale, extraBoosts: debugBoosts[id] ?? [])
            dirty.insert(id)
        }
        for id in Set([previousLast, loaded.last].compactMap { $0 }) where !dirty.contains(id) && rowLayouts[id] != nil {
            rowLayouts[id]?.updateFollowing(following[id].flatMap { message($0) })
            dirty.insert(id)
        }
        return dirty
    }

    private func render(anchor: Anchor, replace: Bool = false, changed: [Int] = [], reconfigureAll: Bool = false,
                        inserted: [Int] = [], removed: [Int] = [], prepend: Bool = false,
                        completion: (() -> Void)? = nil) {
        guard !loaded.isEmpty else { completion?(); return }
        isApplying = true
        let interval = signposter.beginInterval("Layout update")
        let hadWelcome = rowIDs.first == 0
        let removedSet = Set(removed)
        let additions = inserted.filter { !removedSet.contains($0) }
        var deletions = removed.filter { dataSource.indexPath(for: $0) != nil }
        let removedCount = deletions.count
        if hadWelcome, loaded.first != 1 { deletions.insert(0, at: 0) }
        let dirty = rebuildLayouts(changed: Set(changed), all: replace || reconfigureAll, inserted: additions,
                                   removed: removed, removedCount: removedCount, prepend: prepend)
        let hasWelcome = rowIDs.first == 0
        let newItems = (hasWelcome && !hadWelcome ? [0] : []) + additions
        func height(_ id: Int) -> CGFloat {
            id == 0 ? WelcomeCell.height(width: currentWidth, scale: scale) : rowLayouts[id]?.height ?? 80
        }
        if replace || reconfigureAll {
            rowsLayout.setRows(heights: rowIDs.map(height), width: currentWidth)
        } else {
            if prepend {
                rowsLayout.removeLastRows(deletions.count)
                rowsLayout.prependRows(newItems.map(height))
            } else {
                rowsLayout.removeFirstRows(deletions.count)
                rowsLayout.appendRows(newItems.map(height))
            }
            let shift = prepend ? newItems.count : -deletions.count
            for id in dirty {
                guard let path = dataSource.indexPath(for: id), let row = rowLayouts[id] else { continue }
                let index = path.item + shift
                if index >= 0 && index < rowIDs.count { rowsLayout.setHeight(row.height, at: index) }
            }
            rowsLayout.finishUpdates(width: currentWidth)
        }
        let updates = (reconfigureAll ? rowIDs : changed).filter {
            dataSource.indexPath(for: $0) != nil && ($0 == 0 ? hasWelcome : rowLayouts[$0] != nil)
        }
        let done = { [weak self] in
            guard let self else { return }
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
            self.restore(anchor)
            self.collectionView.layoutIfNeeded()
            self.restore(anchor)
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
        var snapshot = replace ? NSDiffableDataSourceSnapshot<Int, Int>() : dataSource.snapshot()
        if replace {
            snapshot.appendSections([0]); snapshot.appendItems(rowIDs, toSection: 0)
        } else {
            if !deletions.isEmpty { snapshot.deleteItems(deletions) }
            if !newItems.isEmpty {
                if prepend && newItems.count < rowIDs.count { snapshot.insertItems(newItems, beforeItem: rowIDs[newItems.count]) }
                else { snapshot.appendItems(newItems, toSection: 0) }
            }
        }
        if !updates.isEmpty { snapshot.reconfigureItems(updates) }
        if replace { dataSource.applySnapshotUsingReloadData(snapshot, completion: done) }
        else { dataSource.apply(snapshot, animatingDifferences: false, completion: done) }
    }

    private var isPinned: Bool {
        collectionView.contentSize.height - collectionView.contentOffset.y - collectionView.bounds.height <= 100
    }
    private func captureAnchor() -> Anchor {
        guard collectionView != nil else { return Anchor(id: nil, y: 0, pinned: true) }
        let offset = collectionView.contentOffset.y
        let visible = (rowsLayout.layoutAttributesForElements(in: collectionView.bounds) ?? []).compactMap { attributes -> (Int, CGRect)? in
            let frame = attributes.frame
            guard let id = dataSource.itemIdentifier(for: attributes.indexPath), id > 0,
                  min(frame.maxY, frame.minY + (rowLayouts[id]?.messageHeight ?? frame.height)) > offset + 0.0001 else { return nil }
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
                  let frame = rowsLayout.layoutAttributesForItem(at: ip)?.frame {
            if abs(anchor.y) < 0.0001 {
                collectionView.scrollToItem(at: ip, at: .top, animated: false)
                return
            }
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
        let pageInput = (max(1, first - Windowing.pageSize)...first).compactMap { message($0) }
        let page = Windowing.page(before: first, in: pageInput).map(\.id)
        guard !page.isEmpty else {
            if let started = tapStarted { elapsedMS = Int((CACurrentMediaTime() - started) * 1000); tapStarted = nil }
            updateState(); return
        }
        loaded.insert(contentsOf: page, at: 0)
        var removed: [Int] = []
        if loaded.count > Windowing.maxLoaded,
           let anchorID = anchor.id, let index = loaded.firstIndex(of: anchorID), index < Windowing.maxLoaded - 40 {
            let count = min(loaded.count - Windowing.maxLoaded, Windowing.pageSize * 2)
            removed = Array(loaded.suffix(count)); loaded.removeLast(count)
        }
        // Paging always preserves the row being read, including when the whole page was visible.
        render(anchor: Anchor(id: anchor.id, y: anchor.y, pinned: false), inserted: page, removed: removed, prepend: true)
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
        var inserted: [Int] = []
        var removed: [Int] = []
        for (id, boost) in pendingDebugBoosts { debugBoosts[id, default: []].append(boost); changed.insert(id) }
        pendingDebugBoosts.removeAll()
        for event in events {
            switch event {
            case .message(let m):
                guard m.id > history.count else { continue }
                history.append(m); loaded.append(m.id)
                inserted.append(m.id)
                if !anchor.pinned { hasUnread = true }
            case .boost(let id, let boost):
                guard var m = message(id) else { continue }
                m.boosts.append(boost); overlays[id] = m; changed.insert(id)
            case .typingStarted, .typingStopped: break
            }
        }
        if !inserted.isEmpty, anchor.pinned, loaded.count > Windowing.maxLoaded {
            // A large history window shrinks in bounded batches instead of
            // turning one incoming message into thousands of row removals.
            let count = min(loaded.count - Windowing.maxLoaded, max(Windowing.pageSize, inserted.count))
            removed = Array(loaded.prefix(count)); loaded.removeFirst(count)
        }
        if !inserted.isEmpty || !removed.isEmpty || changed.contains(where: { rowLayouts[$0] != nil }) {
            render(anchor: anchor, changed: Array(changed), inserted: inserted, removed: removed)
        }
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
