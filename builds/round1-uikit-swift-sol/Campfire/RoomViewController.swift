import UIKit
import CampfireKit

struct ViewportAnchor {
    let messageID: MessageID?
    let y: CGFloat
    let pinned: Bool
}

final class RoomViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    let dataset: Dataset
    private let users: [Int: User]
    private(set) var all: [Message]
    private(set) var loaded: [Message]
    let roomLayout = RoomLayout()
    private(set) lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: roomLayout)
    private let header = RoomHeader()
    private let composer = ComposerView()
    private let benchmark = BenchmarkBar()
    private let jump = UIButton(type: .custom)
    private let isBenchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
    private var category: UIContentSizeCategory = .large
    private var defaultCategory: UIContentSizeCategory = .large
    private var categoryOverride = false
    private var cache: [Int: MessageMetrics] = [:]
    private var cachedWidth: CGFloat = 0
    private var extraBoosts: [Int: [DisplayBoost]] = [:]
    private var streamTask: Task<Void, Never>?
    private var burstTask: Task<Void, Never>?
    private var streamRunning = false
    private var unseenMessages = false
    private var updating = false
    private var loadingOlder = false
    private var rotationAnchor: ViewportAnchor?
    private var pendingMeasurement: CFTimeInterval? = applicationStartTime
    private var milliseconds = 0
    private var reportScheduled = false
    private var didInitialLayout = false
    private var renderedIDs: [Int] = []

    init(dataset: Dataset) {
        self.dataset = dataset
        users = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
        all = dataset.messages
        loaded = Array(Windowing.lastPage(dataset.messages))
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = Style.background
        category = traitCollection.preferredContentSizeCategory; defaultCategory = category
        collection.backgroundColor = Style.background
        collection.contentInsetAdjustmentBehavior = .never
        collection.alwaysBounceVertical = true
        collection.dataSource = self; collection.delegate = self
        collection.register(MessageCell.self, forCellWithReuseIdentifier: "message")
        collection.register(WelcomeCell.self, forCellWithReuseIdentifier: "welcome")
        collection.accessibilityIdentifier = "room.messages"
        for v in [collection, header, composer] { view.addSubview(v) }
        if isBenchmark {
            view.addSubview(benchmark)
            benchmark.action = { [weak self] name in self?.handleDebugAction(name) }
        }
        jump.setTitle("↓  Jump to bottom", for: .normal)
        jump.setTitleColor(Style.background, for: .normal); jump.backgroundColor = Style.text
        jump.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        jump.layer.cornerRadius = 18; jump.isHidden = true
        jump.accessibilityIdentifier = "Jump to bottom"
        jump.addAction(UIAction { [weak self] _ in self?.jumpToBottom() }, for: .touchUpInside)
        view.addSubview(jump)
        NotificationCenter.default.addObserver(self, selector: #selector(systemTextSizeChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let horizontal = view.bounds.width > view.bounds.height
        let left = horizontal ? view.safeAreaInsets.left : 0
        let right = horizontal ? view.safeAreaInsets.right : 0
        let w = view.bounds.width - left - right
        let top: CGFloat = 58 + (isBenchmark ? 110 : 0)
        let footer: CGFloat = horizontal ? 70 : 90
        let newFrame = CGRect(x: left, y: top, width: w, height: max(40, view.bounds.height-top-footer))
        let changed = collection.frame.size != newFrame.size
        let anchor = rotationAnchor ?? (didInitialLayout ? captureAnchor() : ViewportAnchor(messageID: nil, y: 0, pinned: true))
        header.frame = CGRect(x: left, y: 0, width: w, height: 58)
        benchmark.frame = CGRect(x: left, y: 58, width: w, height: 110)
        composer.frame = CGRect(x: left, y: view.bounds.height-footer, width: w, height: footer)
        updating = true
        collection.frame = newFrame
        updating = false
        jump.frame = CGRect(x: view.bounds.midX-81, y: collection.frame.maxY-48, width: 162, height: 36)
        if changed || !didInitialLayout {
            didInitialLayout = true
            rebuild(anchor: anchor)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        rotationAnchor = captureAnchor()
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in self?.view.setNeedsLayout(); self?.view.layoutIfNeeded() }) { [weak self] _ in
            guard let self else { return }
            if let anchor = self.rotationAnchor { self.restore(anchor) }
            self.rotationAnchor = nil
            self.updateState()
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { loaded.count + (roomLayout.showsWelcome ? 1 : 0) }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if roomLayout.showsWelcome && indexPath.item == 0 { return collectionView.dequeueReusableCell(withReuseIdentifier: "welcome", for: indexPath) }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "message", for: indexPath) as! MessageCell
        cell.configure(roomLayout.metrics[indexPath.item - (roomLayout.showsWelcome ? 1 : 0)], users: users)
        return cell
    }

    var bottomOffset: CGFloat { max(0, roomLayout.collectionViewContentSize.height - collection.bounds.height) }
    var isPinned: Bool { bottomOffset - collection.contentOffset.y <= 100 }

    func captureAnchor() -> ViewportAnchor {
        let offset = collection.contentOffset.y
        for i in loaded.indices {
            guard roomLayout.metrics.indices.contains(i) else { break }
            let frame = roomLayout.frame(forMessageAt: i)
            if frame.minY + roomLayout.metrics[i].bubble.maxY > offset + 0.2 && frame.minY < offset + collection.bounds.height {
                return ViewportAnchor(messageID: loaded[i].id, y: frame.minY-offset, pinned: isPinned)
            }
        }
        return ViewportAnchor(messageID: nil, y: 0, pinned: isPinned)
    }

    private func restore(_ anchor: ViewportAnchor) {
        updating = true
        if anchor.pinned {
            collection.contentOffset = CGPoint(x: 0, y: bottomOffset)
        } else if let id = anchor.messageID, let i = loaded.firstIndex(where: { $0.id == id }) {
            let y = roomLayout.frame(forMessageAt: i).minY - anchor.y
            collection.contentOffset = CGPoint(x: 0, y: max(0, min(bottomOffset, y)))
        }
        collection.layoutIfNeeded()
        updating = false
    }

    private func rebuild(anchor: ViewportAnchor, target: MessageID? = nil) {
        guard collection.bounds.width > 0 else { return }
        updating = true
        let width = collection.bounds.width
        if abs(cachedWidth-width) > 0.01 { cache.removeAll(keepingCapacity: true); cachedWidth = width }
        let previousMetrics = Dictionary(uniqueKeysWithValues: roomLayout.metrics.map { ($0.message.id, $0) })
        let previousWidth = roomLayout.width
        let metrics = loaded.map { message -> MessageMetrics in
            let previous: Message? = message.id > 1 && all.indices.contains(message.id-2) ? all[message.id-2] : nil
            let boosts = message.boosts.map(DisplayBoost.init) + (extraBoosts[message.id] ?? [])
            if let cached = cache[message.id], cached.category == category, cached.boosts == boosts { return cached }
            let result = MessageMetrics.make(message: message, previous: previous, users: users, width: width, category: category, boosts: boosts)
            cache[message.id] = result
            return result
        }
        let ids = Set(loaded.map(\.id))
        cache = cache.filter { ids.contains($0.key) }
        let welcomeHeight: CGFloat = loaded.first?.id == 1 ? 401 : 0
        let nextIDs = (welcomeHeight > 0 ? [0] : []) + loaded.map(\.id)
        let oldIDs = renderedIDs
        let oldSet = Set(oldIDs), newSet = Set(nextIDs)
        let deletes = oldIDs.enumerated().filter { !newSet.contains($0.element) }.map { IndexPath(item: $0.offset, section: 0) }
        let inserts = nextIDs.enumerated().filter { !oldSet.contains($0.element) }.map { IndexPath(item: $0.offset, section: 0) }
        renderedIDs = nextIDs
        UIView.performWithoutAnimation {
            if oldIDs.isEmpty || oldSet.isDisjoint(with: newSet) || previousWidth != width {
                roomLayout.rebuild(metrics: metrics, width: width, welcomeHeight: welcomeHeight)
                collection.reloadData()
            } else if !deletes.isEmpty || !inserts.isEmpty {
                collection.performBatchUpdates {
                    roomLayout.rebuild(metrics: metrics, width: width, welcomeHeight: welcomeHeight)
                    collection.deleteItems(at: deletes)
                    collection.insertItems(at: inserts)
                }
            } else {
                roomLayout.rebuild(metrics: metrics, width: width, welcomeHeight: welcomeHeight)
            }
            collection.layoutIfNeeded()
            for path in collection.indexPathsForVisibleItems {
                let i = path.item - (roomLayout.showsWelcome ? 1 : 0)
                guard metrics.indices.contains(i), let cell = collection.cellForItem(at: path) as? MessageCell else { continue }
                let m = metrics[i]
                if let old = previousMetrics[m.message.id], old.category != m.category || old.boosts != m.boosts || previousWidth != width {
                    cell.configure(m, users: users)
                }
            }
            if let target, let i = loaded.firstIndex(where: { $0.id == target }) {
                collection.contentOffset = CGPoint(x: 0, y: roomLayout.frame(forMessageAt: i).minY)
                collection.layoutIfNeeded()
            } else { restore(anchor) }
        }
        updating = false
        updateState()
        scheduleMeasurement()
    }

    private func scheduleMeasurement() {
        guard pendingMeasurement != nil, !reportScheduled else { return }
        reportScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.collection.layoutIfNeeded()
            if let start = self.pendingMeasurement { self.milliseconds = Int((CACurrentMediaTime()-start)*1000); self.pendingMeasurement = nil }
            self.reportScheduled = false
            self.updateState()
        }
    }

    private func updateState() {
        guard didInitialLayout else { return }
        let anchor = captureAnchor()
        benchmark.state.text = String(format: "first %d last %d loaded %d pinned %@ top %d y %.1f ms %d", loaded.first?.id ?? 0, loaded.last?.id ?? 0, loaded.count, isPinned ? "yes" : "no", anchor.messageID ?? 0, anchor.y, milliseconds)
        jump.isHidden = !unseenMessages || isPinned && loaded.last?.id == all.last?.id
        if isPinned && loaded.last?.id == all.last?.id { unseenMessages = false }
    }

    func loadOlder() {
        guard !loadingOlder, let first = loaded.first, first.id > 1 else { scheduleMeasurement(); return }
        loadingOlder = true
        let anchor = captureAnchor()
        let page = Array(Windowing.page(before: first.id, in: all))
        loaded.insert(contentsOf: page, at: 0)
        // Preserve every visible row while trimming the opposite end of an older-history window.
        if loaded.count > Windowing.maxLoaded {
            let anchorIndex = loaded.firstIndex(where: { $0.id == anchor.messageID }) ?? loaded.count-1
            if !anchor.pinned && anchorIndex < Windowing.maxLoaded-20 {
                loaded = Array(loaded.prefix(Windowing.maxLoaded))
            } else {
                loaded.removeFirst(loaded.count-Windowing.maxLoaded)
            }
        }
        rebuild(anchor: anchor)
        loadingOlder = false
    }

    func loadNewerHistory() {
        guard !loadingOlder, let last = loaded.last, last.id < (all.last?.id ?? 0) else { return }
        loadingOlder = true
        let anchor = captureAnchor()
        loaded.append(contentsOf: Windowing.page(after: last.id, in: all))
        if loaded.count > Windowing.maxLoaded,
           let id = anchor.messageID, let i = loaded.firstIndex(where: { $0.id == id }), i > 60 {
            loaded.removeFirst(min(loaded.count-Windowing.maxLoaded, i-1))
        }
        // Paging forward is history navigation, so the previous row remains at the same offset.
        rebuild(anchor: ViewportAnchor(messageID: anchor.messageID, y: anchor.y, pinned: false))
        loadingOlder = false
    }

    private func jumpToBottom() {
        if rotationAnchor != nil { rotationAnchor = ViewportAnchor(messageID: nil, y: 0, pinned: true) }
        loaded = Array(Windowing.lastPage(all))
        unseenMessages = false
        rebuild(anchor: ViewportAnchor(messageID: nil, y: 0, pinned: true))
    }

    func handleDebugAction(_ action: String) {
        if action != "Boost burst" && action != "Start stream" { pendingMeasurement = CACurrentMediaTime() }
        view.layoutIfNeeded()
        switch action {
        case "Reset":
            if rotationAnchor != nil { rotationAnchor = ViewportAnchor(messageID: nil, y: 0, pinned: true) }
            streamTask?.cancel(); streamTask = nil; burstTask?.cancel(); burstTask = nil
            streamRunning = false; benchmark.done.isHidden = true
            all = dataset.messages; loaded = Array(Windowing.lastPage(all))
            extraBoosts.removeAll(); cache.removeAll(); unseenMessages = false
            categoryOverride = false; category = defaultCategory
            rebuild(anchor: ViewportAnchor(messageID: nil, y: 0, pinned: true))
        case "Jump to 2500":
            if rotationAnchor != nil { rotationAnchor = ViewportAnchor(messageID: 2500, y: 0, pinned: false) }
            loaded = Array(Windowing.around(2500, in: all))
            rebuild(anchor: ViewportAnchor(messageID: 2500, y: 0, pinned: false), target: 2500)
        case "Load older": loadOlder()
        case "Start stream": startStream()
        case "Text size +":
            let anchor = captureAnchor()
            let i = Style.categories.firstIndex(of: category) ?? 3
            category = i == Style.categories.count-1 ? defaultCategory : Style.categories[i+1]
            categoryOverride = true
            rebuild(anchor: anchor)
        case "Boost burst": boostBurst()
        default: break
        }
    }

    @objc private func systemTextSizeChanged(_ notification: Notification) {
        guard !categoryOverride else { return }
        let anchor = captureAnchor()
        category = notification.userInfo?[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory ?? traitCollection.preferredContentSizeCategory
        defaultCategory = category
        rebuild(anchor: anchor)
    }

    private func startStream() {
        guard !streamRunning, all.last?.id == dataset.messages.last?.id else { return }
        streamRunning = true; benchmark.done.isHidden = true
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard !Task.isCancelled, let self else { return }
                self.receive(event)
            }
            guard !Task.isCancelled, let self else { return }
            self.streamRunning = false; self.benchmark.done.isHidden = false; self.updateState()
        }
    }

    func receive(_ event: FeedEvent) {
        let anchor = captureAnchor()
        switch event {
        case .message(let message):
            let previousNewest = all.last?.id
            guard !all.contains(where: { $0.id == message.id }) else { return }
            all.append(message)
            if loaded.last?.id == previousNewest {
                // If more than a full window has accumulated below a reader, keep their window
                // intact. The live messages are still retained in `all` for the jump button.
                if loaded.count < Windowing.maxLoaded || anchor.pinned {
                    loaded.append(message)
                    if loaded.count > Windowing.maxLoaded { loaded.removeFirst(loaded.count-Windowing.maxLoaded) }
                }
            }
            if !anchor.pinned || loaded.last?.id != message.id { unseenMessages = true }
            rebuild(anchor: anchor)
        case .boost(let id, let boost):
            if let index = all.firstIndex(where: { $0.id == id }) { all[index].boosts.append(boost) }
            if let index = loaded.firstIndex(where: { $0.id == id }) {
                loaded[index].boosts.append(boost)
                rebuild(anchor: anchor)
            }
        case .typingStarted, .typingStopped: break
        }
    }

    private func boostBurst() {
        guard let id = all.last?.id else { return }
        burstTask?.cancel()
        burstTask = Task { [weak self] in
            let contents = ["👍", "🎉", "🔥", "❤️", "😂"]
            for (i, content) in contents.enumerated() {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                let anchor = self.captureAnchor()
                self.extraBoosts[id, default: []].append(DisplayBoost(id: 2_000_000 + (self.extraBoosts[id]?.count ?? 0), userID: i+2, content: content))
                if self.loaded.contains(where: { $0.id == id }) { self.rebuild(anchor: anchor) }
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !updating else { return }
        updateState()
        if scrollView.isDragging || scrollView.isDecelerating {
            if scrollView.contentOffset.y < 80 { loadOlder() }
            else if bottomOffset-scrollView.contentOffset.y < 80 { loadNewerHistory() }
        }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateState() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { updateState() } }
}
