import UIKit
import CampfireKit

final class BenchmarkButton: UIButton {
    var action: ((TimeInterval) -> Void)?
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let inside = touch.map { bounds.contains($0.location(in: self)) } ?? false
        super.endTracking(touch, with: event)
        if inside { action?(touch?.timestamp ?? ProcessInfo.processInfo.systemUptime) }
    }
}

final class RoomViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private struct Anchor { let id: Int; let y: CGFloat; let pinned: Bool }
    private let header = RoomHeader()
    private let composer = ComposerView()
    private let debugBar = UIView()
    private let stateLabel = UILabel()
    private let streamLabel = UILabel()
    private let jumpButton = UIButton(type: .system)
    private let layout = ChatLayout()
    private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let measurer = MessageMeasurer()
    private var dataset: Dataset?
    private var all: [Message] = []
    private var loaded: [Message] = []
    private var geometries: [Int: MessageGeometry] = [:]
    private var users: [Int: User] = [:]
    private var welcome = false
    private var ready = false
    private var updating = false
    private var loadingOlder = false
    private var lastWidth: CGFloat = 0
    private var lastHeight: CGFloat = 0
    private var rotationAnchor: Anchor?
    private var debugButtons: [BenchmarkButton] = []
    private let benchmark = ProcessInfo.processInfo.arguments.contains("-uvsBenchmark")
    private var textStep = 0
    private var initialCategory: UIContentSizeCategory = .large
    private let categories: [UIContentSizeCategory] = [.extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge, .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge]
    private var measuredMilliseconds = 0
    private var timingStart: TimeInterval?
    private var timingLink: CADisplayLink?
    private var pendingEvents: [FeedEvent] = []
    private var feedTask: Task<Void, Never>?
    private var flushTimer: Timer?
    private var streamFinished = false
    private var boostTask: Task<Void, Never>?
    private var burstBoosts: [Boost] = []
    fileprivate var frameLink: CADisplayLink?
    fileprivate var nextTurnScheduled = false
    fileprivate var idleFrames = 0
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Style.background
        initialCategory = traitCollection.preferredContentSizeCategory
        collection.backgroundColor = Style.background
        collection.dataSource = self; collection.delegate = self
        collection.contentInsetAdjustmentBehavior = .never
        #if PREFETCH_ON
        collection.isPrefetchingEnabled = true
        #else
        collection.isPrefetchingEnabled = false
        #endif
        collection.prefetchDataSource = self
        collection.selfSizingInvalidation = .disabled
        collection.alwaysBounceVertical = true
        collection.keyboardDismissMode = .interactive
        collection.accessibilityIdentifier = "messages"
        collection.showsVerticalScrollIndicator = true
        let registrations: [(String, AnyClass)] = [("text",MessageCell.self),("code",CodeCell.self),("image",ImageCell.self),("file",FileCell.self),("textBoost",BoostCell.self),("codeBoost",CodeBoostCell.self),("imageBoost",ImageBoostCell.self),("fileBoost",FileBoostCell.self)]
        #if ONE_CELL
        collection.register(MessageCell.self, forCellWithReuseIdentifier: "message")
        #else
        for registration in registrations { collection.register(registration.1, forCellWithReuseIdentifier: registration.0) }
        #endif
        collection.register(WelcomeCell.self, forCellWithReuseIdentifier: "welcome")
        [collection, header, composer, jumpButton].forEach(view.addSubview)
        jumpButton.setTitle("↓  Jump to bottom", for: .normal)
        jumpButton.titleLabel?.font = Style.font(13, .semibold)
        jumpButton.backgroundColor = Style.text; jumpButton.setTitleColor(Style.background, for: .normal)
        jumpButton.layer.cornerRadius = 18
        jumpButton.accessibilityIdentifier = "jump-bottom"
        jumpButton.addTarget(self, action: #selector(jumpToBottom), for: .touchUpInside)
        jumpButton.isHidden = true
        if benchmark { buildDebugBar() }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: RoomViewController, _: UITraitCollection) in
            self.textStep = 0
            self.initialCategory = self.traitCollection.preferredContentSizeCategory
            self.remeasure(anchor: self.captureAnchor())
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: RoomViewController, _: UITraitCollection) in
            self.collection.reloadData()
            self.header.setNeedsLayout(); self.composer.setNeedsLayout()
        }
        Task { [weak self] in
            let data = await initialDataset.value
            guard let self else { return }
            self.dataset = data; self.all = data.messages
            self.users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
            self.measurer.users = self.users
            let emojis = ["👍", "🎉", "🔥", "❤️", "😂"]
            self.burstBoosts = (2...6).compactMap { id in
                data.messages.lazy.flatMap(\.boosts).first { $0.boosterID == id && $0.content == emojis[id-2] }
            }
            self.ready = true
            self.reset(timing: launchInstant)
            self.startProbe()
            if let value = self.argument("-uvsJumpTo"), let id = Int(value) { self.jump(to: id, timing: nil) }
        }
    }
    private func argument(_ key: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: key), i+1 < a.count else { return nil }
        return a[i+1]
    }
    private func buildDebugBar() {
        view.addSubview(debugBar)
        debugBar.backgroundColor = Style.background
        let titles = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]
        for (i, title) in titles.enumerated() {
            let b = BenchmarkButton(type: .system)
            b.setTitle(title, for: .normal); b.titleLabel?.font = Style.font(11, .semibold)
            b.backgroundColor = Style.bubble; b.tintColor = Style.text; b.layer.cornerRadius = 6
            b.accessibilityIdentifier = title
            b.action = { [weak self] timestamp in
                guard let self, self.ready, !self.updating else { return }
                switch i {
                case 0: self.reset(timing: timestamp)
                case 1: self.jump(to: 2500, timing: timestamp)
                case 2: self.loadOlder(timing: timestamp)
                case 3: self.startStream()
                case 4: self.increaseText(timing: timestamp)
                default: self.boostBurst()
                }
            }
            debugBar.addSubview(b); debugButtons.append(b)
        }
        stateLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        stateLabel.textColor = Style.text
        stateLabel.numberOfLines = 2
        stateLabel.accessibilityIdentifier = "benchmark-state"
        streamLabel.font = Style.font(10, .semibold); streamLabel.textColor = Style.text
        streamLabel.accessibilityIdentifier = "stream-status"
        debugBar.addSubview(stateLabel); debugBar.addSubview(streamLabel)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        let oldAnchor = ready && lastWidth > 0 && (lastWidth != width || lastHeight != view.bounds.height) ? (rotationAnchor ?? captureAnchor()) : nil
        header.frame = CGRect(x: 0, y: 0, width: width, height: 58)
        let debugHeight: CGFloat = benchmark ? 91 : 0
        debugBar.frame = CGRect(x: 0, y: 58, width: width, height: debugHeight)
        if benchmark {
            let buttonWidth = (width - 28)/3
            for (i, b) in debugButtons.enumerated() {
                b.frame = CGRect(x: 8 + CGFloat(i%3)*(buttonWidth+6), y: CGFloat(i/3)*27, width: buttonWidth, height: 24)
            }
            stateLabel.frame = CGRect(x: 8, y: 55, width: width-16, height: 25)
            streamLabel.frame = CGRect(x: 8, y: 79, width: width-16, height: 12)
        }
        composer.frame = CGRect(x: 0, y: view.bounds.height-90, width: width, height: 90)
        collection.frame = CGRect(x: 0, y: header.frame.maxY+debugHeight, width: width, height: max(0, composer.frame.minY-header.frame.maxY-debugHeight))
        jumpButton.frame = CGRect(x: width/2-77, y: composer.frame.minY-44, width: 154, height: 36)
        if ready && lastWidth != width {
            lastWidth = width; lastHeight = view.bounds.height
            remeasure(anchor: oldAnchor)
        } else if ready, let oldAnchor {
            restore(oldAnchor)
        }
        lastWidth = width; lastHeight = view.bounds.height
        rotationAnchor = nil
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        rotationAnchor = captureAnchor()
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.updateState() }
    }
    private var bottom: CGFloat { max(0, layout.collectionViewContentSize.height - collection.bounds.height) }
    private var isPinned: Bool { bottom - collection.contentOffset.y <= 100 }
    private var scale: CGFloat {
        let baseIndex = categories.firstIndex(of: initialCategory) ?? 3
        let index = (baseIndex + textStep) % categories.count
        return UIFontMetrics(forTextStyle: .body).scaledValue(for: 16, compatibleWith: UITraitCollection(preferredContentSizeCategory: categories[index])) / 16
    }
    private func previous(to message: Message) -> Message? {
        // Generated IDs are contiguous, including messages delivered by the live stream.
        let index = message.id - 2
        return all.indices.contains(index) ? all[index] : nil
    }
    private func measure(_ messages: [Message]) -> [LayoutRow] {
        messages.map { message in
            let g = measurer.geometry(message, previous: previous(to: message))
            geometries[message.id] = g
            return LayoutRow(id: message.id, height: g.height, threaded: g.presentation.isThreaded)
        }
    }
    private func rebuildRows() {
        welcome = loaded.first?.id == 1
        var rows = measure(loaded)
        Probe.mark("measure \(loaded.count)")
        if welcome { rows.insert(LayoutRow(id: 0, height: 380, threaded: false), at: 0) }
        layout.replace(rows, width: collection.bounds.width)
        Probe.mark("layout-rows")
    }
    private func captureAnchor() -> Anchor? {
        guard !loaded.isEmpty, let i = layout.topIndex(at: collection.contentOffset.y) else { return nil }
        let rowIndex = layout.rows[i].id == 0 ? min(i+1,layout.rows.count-1) : i
        let row = layout.rows[rowIndex]
        return Anchor(id: row.id, y: layout.attributes[rowIndex].frame.minY - collection.contentOffset.y, pinned: isPinned)
    }
    private func restore(_ anchor: Anchor?, forceBottom: Bool = false) {
        let y: CGFloat
        if forceBottom || anchor?.pinned == true { y = bottom }
        else if let anchor, let frame = layout.frame(id: anchor.id) { y = frame.minY-anchor.y }
        else { y = collection.contentOffset.y }
        let target = CGPoint(x: 0, y: min(bottom, max(0, (y*3).rounded()/3)))
        layout.forcedOffset = target
        collection.setContentOffset(target, animated: false)
    }
    private func finishMutation(timing: TimeInterval? = nil) {
        Probe.mark("pre-layout")
        collection.layoutIfNeeded()
        Probe.mark("layoutIfNeeded")
        if let offset = layout.forcedOffset { collection.setContentOffset(offset, animated: false) }
        layout.forcedOffset = nil
        updating = false
        updateState()
        if let timing { scheduleTiming(from: timing) }
    }
    private func reset(timing: TimeInterval) {
        feedTask?.cancel(); feedTask = nil; flushTimer?.invalidate(); flushTimer = nil
        boostTask?.cancel(); boostTask = nil
        pendingEvents.removeAll(); streamFinished = false; streamLabel.text = nil
        guard let dataset else { return }
        all = dataset.messages
        textStep = 0; initialCategory = traitCollection.preferredContentSizeCategory
        measurer.scale = scale; measurer.width = collection.bounds.width
        measurer.clear(); geometries.removeAll(keepingCapacity: true)
        loaded = Array(Windowing.lastPage(all))
        updating = true
        UIView.performWithoutAnimation {
            rebuildRows()
            layout.forcedOffset = CGPoint(x: 0, y: bottom)
            collection.reloadData()
            restore(nil, forceBottom: true)
            finishMutation(timing: timing)
        }
    }
    private func jump(to id: Int, timing: TimeInterval?) {
        guard !all.isEmpty else { return }
        updating = true
        #if JUMP20
        loaded = Array(Windowing.around(id, in: all, size: 20))
        #else
        loaded = Array(Windowing.around(id, in: all))
        #endif
        measurer.clear(); geometries.removeAll(keepingCapacity: true)
        UIView.performWithoutAnimation {
            rebuildRows()
            let y = layout.frame(id: id)?.minY ?? 0
            layout.forcedOffset = CGPoint(x: 0, y: min(bottom, y))
            collection.reloadData()
            collection.setContentOffset(layout.forcedOffset!, animated: false)
            Probe.mark("reload+offset")
            finishMutation(timing: timing)
        }
    }
    private func loadOlder(timing: TimeInterval?) {
        guard !loadingOlder, !updating, let first = loaded.first else { return }
        let page = Array(Windowing.page(before: first.id, in: all))
        guard !page.isEmpty else { if let timing { scheduleTiming(from: timing) }; return }
        loadingOlder = true; updating = true
        let anchor = captureAnchor()
        let oldWelcome = welcome
        let lastVisibleID = layout.topIndex(at: collection.contentOffset.y + collection.bounds.height - 0.01).map { layout.rows[$0].id } ?? loaded.last?.id
        loaded.insert(contentsOf: page, at: 0)
        // Trim separately from insertion. Prefer the page around the reader over far-away newer rows.
        let mustTrim = loaded.count > Windowing.maxLoaded
        if mustTrim {
            let overflow = loaded.count-Windowing.maxLoaded
            let visibleEnd = loaded.firstIndex(where: { $0.id == lastVisibleID }) ?? loaded.count-1
            let trimBelow = min(overflow, loaded.count-visibleEnd-1)
            if trimBelow > 0 { loaded.removeLast(trimBelow) }
            // A debug tap can request history while the reader is still at the bottom.
            // Never evict their visible rows merely to retain a distant history page.
            if overflow > trimBelow { loaded.removeFirst(overflow-trimBelow) }
        }
        UIView.performWithoutAnimation {
            if mustTrim || oldWelcome != (loaded.first?.id == 1) {
                rebuildRows()
                restore(anchor)
                collection.reloadData()
            } else {
                layout.prepend(measure(page))
                Probe.mark("measure-page")
                restore(anchor)
                collection.performBatchUpdates { collection.insertItems(at: (0..<page.count).map { IndexPath(item: $0, section: 0) }) }
                Probe.mark("batch-insert")
            }
            restore(anchor)
            finishMutation(timing: timing)
        }
        retainWindow()
        loadingOlder = false
    }
    private func retainWindow() {
        let ids = Set(loaded.map(\.id))
        measurer.retain(ids)
        geometries = geometries.filter { ids.contains($0.key) }
    }
    private func increaseText(timing: TimeInterval) {
        let anchor = captureAnchor()
        let baseIndex = categories.firstIndex(of: initialCategory) ?? 3
        textStep += 1
        if baseIndex + textStep >= categories.count { textStep = 0 }
        remeasure(anchor: anchor, timing: timing)
    }
    private func remeasure(anchor: Anchor?, timing: TimeInterval? = nil) {
        guard ready else { return }
        updating = true
        measurer.width = collection.bounds.width; measurer.scale = scale
        measurer.clear(); geometries.removeAll(keepingCapacity: true)
        UIView.performWithoutAnimation {
            rebuildRows(); restore(anchor)
            collection.reloadData(); restore(anchor)
            Probe.mark("reload+restore")
            finishMutation(timing: timing)
        }
    }
    @objc private func jumpToBottom() {
        guard let last = loaded.last else { return }
        if last.id != all.last?.id { loaded = Array(Windowing.lastPage(all)); measurer.clear(); geometries.removeAll(); rebuildRows(); collection.reloadData() }
        restore(nil, forceBottom: true); finishMutation()
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { loaded.count + (welcome ? 1 : 0) }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if welcome && indexPath.item == 0 { return collectionView.dequeueReusableCell(withReuseIdentifier: "welcome", for: indexPath) }
        let message = loaded[indexPath.item - (welcome ? 1 : 0)]
        var kind = "text"
        if let attachment = message.attachment {
            switch attachment { case .image: kind = "image"; case .file: kind = "file" }
        } else if message.blocks.contains(where: { if case .code = $0 { return true }; return false }) { kind = "code" }
        if !message.boosts.isEmpty { kind += "Boost" }
        #if ONE_CELL
        kind = "message"
        #endif
        Probe.cells += 1
        if let f = layout.layoutAttributesForItem(at: indexPath)?.frame, !f.intersects(collectionView.bounds) { Probe.offscreenCells += 1 }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kind, for: indexPath) as! MessageCell
        if let g = geometries[message.id] { cell.configure(g, user: users[message.creatorID], scale: scale) }
        return cell
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard ready, !updating else { return }
        if !scrollView.isDragging && !scrollView.isDecelerating { updateState() }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { scrollingStopped() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { scrollingStopped() }
    private func scrollingStopped() {
        updateState()
        if collection.contentOffset.y < 120 { loadOlder(timing: nil) }
        else if bottom - collection.contentOffset.y < 120, loaded.last?.id != all.last?.id { loadNewer() }
    }
    private func updateState() {
        guard ready else { return }
        var id = loaded.first?.id ?? 0
        var y: CGFloat = 0
        if let i = layout.topIndex(at: collection.contentOffset.y) {
            let index = layout.rows[i].id == 0 ? min(i+1,layout.rows.count-1) : i
            id = layout.rows[index].id; y = layout.attributes[index].frame.minY-collection.contentOffset.y
        }
        stateLabel.text = String(format: "first %d last %d loaded %d pinned %@ top %d y %.1f ms %d", loaded.first?.id ?? 0, loaded.last?.id ?? 0, loaded.count, isPinned ? "yes" : "no", id, y, measuredMilliseconds)
        jumpButton.isHidden = isPinned && loaded.last?.id == all.last?.id
    }
    private func scheduleTiming(from start: TimeInterval) {
        timingLink?.invalidate(); timingStart = start
        let link = CADisplayLink(target: self, selector: #selector(timingFrame(_:)))
        link.add(to: .main, forMode: .common); timingLink = link
    }
    @objc private func timingFrame(_ link: CADisplayLink) {
        guard let start = timingStart else { return }
        measuredMilliseconds = max(0, Int((CACurrentMediaTime() - start)*1000))
        updateState(); link.invalidate(); timingLink = nil; timingStart = nil
    }
    private func startStream() {
        guard feedTask == nil, let dataset else { return }
        streamFinished = false; streamLabel.text = "Streaming…"
        #if !FLUSH_PERMSG && !FLUSH_NEXTTURN && !FLUSH_FRAME
        flushTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.flushEvents() }
        #endif
        let feed = FakeLiveFeed(dataset: dataset, messagesPerSecond: Probe.feedRate, duration: 30)
        Probe.streamStarted()
        feedTask = Task { [weak self] in
            for await event in feed.play() {
                guard !Task.isCancelled else { return }
                if case .message(let m) = event { Probe.arrive(m.id) }
                self?.pendingEvents.append(event)
                self?.eventArrived()
            }
            guard !Task.isCancelled, let self else { return }
            self.flushEvents()
            self.streamFinished = true; self.streamLabel.text = "Stream done"
            self.flushTimer?.invalidate(); self.flushTimer = nil
            self.frameLink?.invalidate(); self.frameLink = nil
            Probe.streamDone()
            // Keep the task as a completed marker so a second tap cannot replay duplicate IDs.
        }
    }
    private func flushEvents() {
        guard !updating, !pendingEvents.isEmpty else { return }
        let events = pendingEvents; pendingEvents.removeAll(keepingCapacity: true)
        let anchor = captureAnchor()
        let oldLast = loaded.last?.id
        var appended: [Message] = []
        var changed: Set<Int> = []
        for event in events {
            switch event {
            case .message(let message):
                guard message.id > (all.last?.id ?? 0) else { continue }
                all.append(message)
                if oldLast == message.id - appended.count - 1 { appended.append(message) }
            case .boost(let id, let boost):
                if let i = loaded.firstIndex(where: { $0.id == id }) { loaded[i].boosts.append(boost); changed.insert(id) }
                if let i = appended.firstIndex(where: { $0.id == id }) { appended[i].boosts.append(boost) }
                if all.indices.contains(id-1) { all[id-1].boosts.append(boost) }
            case .typingStarted, .typingStopped: break
            }
        }
        applyLive(appended: appended, changed: changed, anchor: anchor)
    }
    private func applyLive(appended: [Message], changed: Set<Int>, anchor: Anchor?) {
        guard !appended.isEmpty || !changed.isEmpty else { updateState(); return }
        updating = true
        UIView.performWithoutAnimation {
            // Trimming must complete before the insertion batch begins.
            #if TRIM_BATCH
            if loaded.count + appended.count > Windowing.maxLoaded, anchor?.pinned == true {
                trimAndAppendInOneBatch(appended: appended, changed: changed, anchor: anchor)
                return
            }
            #else
            if loaded.count + appended.count > Windowing.maxLoaded, anchor?.pinned == true {
                let t = CACurrentMediaTime()
                loaded.removeFirst(min(loaded.count-1, loaded.count + appended.count - Windowing.maxLoaded))
                welcome = false; rebuildRows(); restore(anchor)
                collection.reloadData(); collection.layoutIfNeeded(); restore(anchor)
                Probe.trims += 1; Probe.trimSeconds += CACurrentMediaTime() - t
            }
            #endif
            // Keep the active reader's bounded window if streaming outgrows its capacity.
            let additions = Array(appended.prefix(max(0, Windowing.maxLoaded - loaded.count)))
            let start = loaded.count + (welcome ? 1 : 0)
            var changedPaths: [IndexPath] = []
            var replacementPaths: [IndexPath] = []
            for id in changed {
                guard let i = loaded.firstIndex(where: { $0.id == id }) else { continue }
                let needsBoostStrip = geometries[id]?.boosts.isEmpty == true
                measurer.discard(id)
                let row = measure([loaded[i]])[0]
                layout.update(row)
                let path = IndexPath(item: i + (welcome ? 1 : 0), section: 0)
                if needsBoostStrip { replacementPaths.append(path) } else { changedPaths.append(path) }
            }
            if !additions.isEmpty {
                loaded.append(contentsOf: additions)
                layout.append(measure(additions))
            }
            restore(anchor)
            collection.performBatchUpdates {
                if !additions.isEmpty { collection.insertItems(at: (start..<(start+additions.count)).map { IndexPath(item: $0, section: 0) }) }
                if !changedPaths.isEmpty { collection.reconfigureItems(at: changedPaths) }
                if !replacementPaths.isEmpty { collection.reloadItems(at: replacementPaths) }
            }
            restore(anchor); finishMutation()
            Probe.updates += 1
            Probe.applied(additions.map(\.id))
        }
        retainWindow()
    }
    private func loadNewer() {
        guard let last = loaded.last, !updating else { return }
        let page = Array(Windowing.page(after: last.id, in: all))
        guard !page.isEmpty else { return }
        let anchor = captureAnchor()
        applyLive(appended: page, changed: [], anchor: anchor)
    }
    private func boostBurst() {
        guard boostTask == nil, let id = all.last?.id else { return }
        let boosts = burstBoosts
        boostTask = Task { [weak self] in
            for boost in boosts {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                self.pendingEvents.append(.boost(messageID: id, boost))
                self.flushEvents()
            }
            self?.boostTask = nil
        }
    }
}

// MARK: - E13 probe and arms

extension RoomViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        Probe.prefetchCalls += indexPaths.count
    }

    /// Called for every feed event, right after it is queued.
    private func eventArrived() {
        #if FLUSH_PERMSG
        flushEvents()
        #elseif FLUSH_NEXTTURN
        guard !nextTurnScheduled else { return }
        nextTurnScheduled = true
        DispatchQueue.main.async { [weak self] in self?.nextTurnScheduled = false; self?.flushEvents() }
        #elseif FLUSH_FRAME
        // Leading edge: idle list applies at once; while changes keep arriving, at most once per frame.
        if frameLink == nil {
            flushEvents()
            idleFrames = 0
            let link = CADisplayLink(target: self, selector: #selector(frameFlush(_:)))
            link.add(to: .main, forMode: .common)
            frameLink = link
        }
        #endif
    }

    @objc private func frameFlush(_ link: CADisplayLink) {
        if pendingEvents.isEmpty {
            idleFrames += 1
            if idleFrames >= 2 { link.invalidate(); frameLink = nil }
        } else {
            idleFrames = 0
            flushEvents()
        }
    }

    /// TRIM_BATCH: delete the oldest rows and insert the new ones in one batch update.
    /// Deletes use positions before the update, inserts positions after it.
    private func trimAndAppendInOneBatch(appended: [Message], changed: Set<Int>, anchor: Anchor?) {
        let t = CACurrentMediaTime()
        let k = min(loaded.count - 1, loaded.count + appended.count - Windowing.maxLoaded)
        let oldItems = loaded.count + (welcome ? 1 : 0)
        let removedItems = k + (welcome ? 1 : 0)
        loaded.removeFirst(k)
        for id in changed { measurer.discard(id) }
        loaded.append(contentsOf: appended)
        rebuildRows()
        restore(anchor)
        let insertStart = oldItems - removedItems
        collection.performBatchUpdates {
            collection.deleteItems(at: (0..<removedItems).map { IndexPath(item: $0, section: 0) })
            collection.insertItems(at: (insertStart..<(insertStart + appended.count)).map { IndexPath(item: $0, section: 0) })
        }
        let changedPaths = changed.compactMap { id in loaded.firstIndex(where: { $0.id == id }) }
            .filter { $0 < loaded.count - appended.count }
            .map { IndexPath(item: $0, section: 0) }
        if !changedPaths.isEmpty { collection.reloadItems(at: changedPaths) }
        restore(anchor); finishMutation()
        Probe.trims += 1; Probe.trimSeconds += CACurrentMediaTime() - t
        Probe.updates += 1
        Probe.applied(appended.map(\.id))
        retainWindow()
    }

    private func startProbe() {
        Probe.sayMemory("first-content")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if Probe.autoJump {
                Probe.timed("JUMPMS", setup: { self.reset(timing: 0) }, action: { self.jump(to: 2500, timing: nil) })
            } else if Probe.autoOlder {
                Probe.timed("OLDERMS", setup: { self.reset(timing: 0) }, action: { self.loadOlder(timing: nil) })
            } else if Probe.autoTextBottom {
                Probe.timed("TEXTBMS", setup: { self.reset(timing: 0) }, action: { self.increaseText(timing: 0) })
            } else if Probe.autoTextMid {
                Probe.timed("TEXTMMS", setup: { self.reset(timing: 0); self.jump(to: 2500, timing: nil) }, action: { self.increaseText(timing: 0) })
            } else if Probe.autoStream {
                self.startStream()
            } else if Probe.autoFling {
                self.runFling()
            } else if Probe.autoCallback {
                self.runCallbackProbe()
            }
        }
    }

    /// Scroll up 40 pt per frame for 8 s (about 2,400 pt/s), loading older pages near the top.
    private func runFling() {
        var frames = 0
        Probe.runFling { [weak self] in
            guard let self else { return false }
            frames += 1
            if frames > 480 { return false }
            var y = self.collection.contentOffset.y - 40
            if y < 0 { y = 0 }
            self.collection.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            if self.collection.contentOffset.y < 1500, !self.updating { self.loadOlder(timing: nil) }
            return true
        }
    }

    /// S1: does UIKit ask the layout for targetContentOffset(forProposedContentOffset:) on these paths?
    private func runCallbackProbe() {
        func topRow() -> String {
            guard let i = layout.topIndex(at: collection.contentOffset.y) else { return "none" }
            return "\(layout.rows[i].id)@\(String(format: "%.1f", layout.attributes[i].frame.minY - collection.contentOffset.y))"
        }
        func step(_ name: String, _ body: () -> Void) {
            layout.forcedOffset = nil
            let before = topRow()
            let y0 = collection.contentOffset.y
            Probe.targetCalls = 0
            body()
            Probe.say(String(format: "CALLBACK %@ calls %d offset %.1f -> %.1f top %@ -> %@", name, Probe.targetCalls, y0, collection.contentOffset.y, before, topRow()))
        }
        func newText() {
            textStep += 1
            measurer.scale = scale; measurer.clear(); geometries.removeAll()
            rebuildRows()  // replaces the rows and calls invalidateLayout()
        }
        let places: [(String, () -> Void)] = [("bottom", { self.reset(timing: 0) }), ("mid", { self.reset(timing: 0); self.jump(to: 2500, timing: nil) })]
        for (place, setup) in places {
            setup(); collection.layoutIfNeeded()
            step("\(place) invalidate+layoutIfNeeded (no change)") { layout.invalidateLayout(); collection.layoutIfNeeded() }
            setup(); collection.layoutIfNeeded()
            step("\(place) text change, invalidate+layoutIfNeeded") { UIView.performWithoutAnimation { newText(); collection.layoutIfNeeded() } }
            setup(); collection.layoutIfNeeded()
            step("\(place) text change, reloadData+layoutIfNeeded") { UIView.performWithoutAnimation { newText(); collection.reloadData(); collection.layoutIfNeeded() } }
            setup(); collection.layoutIfNeeded()
            step("\(place) text change, empty performBatchUpdates") { UIView.performWithoutAnimation { newText(); collection.performBatchUpdates({}); collection.layoutIfNeeded() } }
            setup(); collection.layoutIfNeeded()
            step("\(place) text change, invalidateLayout() in performBatchUpdates") { UIView.performWithoutAnimation { collection.performBatchUpdates({ newText() }); collection.layoutIfNeeded() } }
        }
        Probe.say("CALLBACK done")
    }
}
