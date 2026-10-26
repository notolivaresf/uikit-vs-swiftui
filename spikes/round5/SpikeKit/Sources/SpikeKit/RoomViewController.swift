import UIKit
import CampfireKit

public enum PrependAnchor: String {
    /// (a) remember the top visible row and its offset, put it back after the insert.
    case topRow
    /// (b) add the inserted rows' total height to the scroll offset.
    case offsetDelta
    /// (c) the layout keeps its own anchor while it inserts (custom collection layout only).
    case layoutAnchor
}

/// The room screen both spikes share: debug bar, state label, stream, jump, load older, text size. It owns the data
/// and the pinning; the list view itself comes from the adapter.
public final class RoomViewController: UIViewController, RoomDataProviding {
    private let adapter: ListAdapter
    private let model: RoomModel
    private let bar = DebugBar()
    private let heights = HeightStore()
    public var prependAnchor: PrependAnchor = .topRow
    private var started = false
    private var streamTask: Task<Void, Never>?
    private var feed: FakeLiveFeed?
    private var lastWidth: CGFloat = 0

    static let categories: [UIContentSizeCategory] = [.large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                                      .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                                                      .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge]

    public init(adapter: ListAdapter) {
        self.adapter = adapter
        self.model = RoomModel()
        super.init(nibName: nil, bundle: nil)
        adapter.data = self
    }
    public required init?(coder: NSCoder) { fatalError() }

    // MARK: RoomDataProviding

    public var itemCount: Int { model.items.count }
    public var style: RowStyle { RowStyle(width: adapter.scrollView.bounds.width, category: model.category) }
    public func savedHeight(at index: Int) -> CGFloat { heights.height(for: model.items[index], users: model.users, style: style) }
    public func measuredHeight(at index: Int) -> CGFloat { HeightStore.measure(model.items[index], users: model.users, style: style) }
    public func configure(_ row: RowView, at index: Int) { row.configure(model.items[index], users: model.users, style: style) }
    public func messageID(at index: Int) -> Int { model.items[index].message.id }
    public func listDidScroll() { refreshLabel() }
    public var measureCount: Int { heights.measureCount }

    // MARK: Setup

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let sv = adapter.scrollView
        sv.contentInsetAdjustmentBehavior = .never
        sv.backgroundColor = .systemBackground
        view.addSubview(sv)
        view.addSubview(bar)
        bar.onTap = { [weak self] in self?.handle($0) }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top
        bar.frame = CGRect(x: 0, y: top, width: view.bounds.width, height: DebugBar.height)
        let listTop = top + DebugBar.height
        let listFrame = CGRect(x: 0, y: listTop, width: view.bounds.width, height: view.bounds.height - listTop)
        if adapter.scrollView.frame != listFrame { adapter.scrollView.frame = listFrame }
        if adapter.scrollView.contentInset.bottom != view.safeAreaInsets.bottom { adapter.scrollView.contentInset.bottom = view.safeAreaInsets.bottom }
        if !started {
            started = true
            lastWidth = view.bounds.width
            adapter.reloadAll()
            adapter.scrollView.layoutIfNeeded()
            adapter.scrollView.scrollToBottomNow()
            adapter.scrollView.layoutIfNeeded()
            bar.finishTap()
            refreshLabel()
            DispatchQueue.main.async { [weak self] in self?.prepareFeed() }
            if CommandLine.arguments.contains("-uvsAutoStream") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.startStream() }
            }
        }
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let anchor = captureAnchor()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            self.heights.invalidateAll()
            self.adapter.heightsChanged()
            self.restore(anchor)
            self.refreshLabel()
        }
    }

    // MARK: Place keeping

    private enum Anchor { case bottom, row(id: MessageID, y: CGFloat) }

    private func captureAnchor(forceRow: Bool = false) -> Anchor {
        let sv = adapter.scrollView
        if sv.isPinnedToBottom && !forceRow { return .bottom }
        guard let r = adapter.visibleTopRow() else { return .bottom }
        return .row(id: model.items[r].message.id, y: adapter.rowFrame(r).minY - sv.contentOffset.y)
    }

    private func restore(_ a: Anchor) {
        let sv = adapter.scrollView
        sv.layoutIfNeeded()
        switch a {
        case .bottom: sv.scrollToBottomNow(); sv.layoutIfNeeded()
        case .row(let id, let y): if let i = model.index(ofID: id) { scroll(toRow: i, y: y) }
        }
    }

    /// Puts row `index` with its top `y` points under the list's top. Works from the row frames the list gives and
    /// looks again after laying out, so estimated frames settle on the real ones.
    public func scroll(toRow index: Int, y: CGFloat) {
        let sv = adapter.scrollView
        for _ in 0..<4 {
            sv.layoutIfNeeded()
            let target = min(max(adapter.rowFrame(index).minY - y, -sv.contentInset.top), sv.maxOffsetY)
            if abs(sv.contentOffset.y - target) < 0.25 { return }
            sv.setContentOffset(CGPoint(x: 0, y: target), animated: false)
        }
        sv.layoutIfNeeded()
    }

    // MARK: Debug bar actions

    private func handle(_ title: String) {
        switch title {
        case "Reset": reset()
        case "Jump to 2500": jump(to: 2_500)
        case "Load older": loadOlder()
        case "Start stream": startStream()
        case "Text size +": bumpTextSize()
        case "Boost burst": boostBurst()
        default: break
        }
    }

    private func reset() {
        let changed = model.category != .large
        model.category = .large
        model.loadLast()
        if changed { heights.invalidateAll() }
        adapter.reloadAll()
        adapter.scrollView.layoutIfNeeded()
        adapter.scrollView.scrollToBottomNow()
        adapter.scrollView.layoutIfNeeded()
        bar.finishTap(); refreshLabel()
    }

    private func jump(to id: Int) {
        model.load(around: id)
        adapter.reloadAll()
        if let i = model.index(ofID: id) { scroll(toRow: i, y: 0) }
        bar.finishTap(); refreshLabel()
    }

    private func loadOlder() {
        let anchor = captureAnchor(forceRow: true)
        let (n, changed) = model.loadOlder()
        guard n > 0 else { bar.finishTap(); return }
        if let changed { heights.invalidate(changed); adapter.heightInvalidated(id: changed) }
        applyPrepend(n, anchor: anchor)
        bar.finishTap(); refreshLabel()
    }

    /// The variable of E3: how the place is kept when `n` rows arrive above.
    private func applyPrepend(_ n: Int, anchor: Anchor) {
        let sv = adapter.scrollView
        switch prependAnchor {
        case .topRow:
            adapter.rowsPrepended(n)
            restore(anchor)
        case .offsetDelta:
            var added: CGFloat = 0
            for i in 0..<n { added += savedHeight(at: i) }
            let before = sv.contentOffset.y
            adapter.rowsPrepended(n)
            sv.layoutIfNeeded()
            sv.setContentOffset(CGPoint(x: 0, y: before + added), animated: false)
            sv.layoutIfNeeded()
        case .layoutAnchor:
            adapter.rowsPrepended(n)
            sv.layoutIfNeeded()
        }
    }

    private func bumpTextSize() {
        let anchor = captureAnchor()
        let i = Self.categories.firstIndex(of: model.category) ?? 0
        model.category = Self.categories[(i + 1) % Self.categories.count]
        heights.invalidateAll()
        adapter.heightsChanged()
        restore(anchor)
        bar.finishTap(); refreshLabel()
    }

    // MARK: Stream

    private func prepareFeed() {
        if feed == nil { feed = FakeLiveFeed(dataset: model.dataset) }
    }

    private func startStream() {
        guard streamTask == nil else { return }
        prepareFeed()
        guard let feed else { return }
        streamTask = Task { @MainActor [weak self] in
            for await event in feed.play() {
                self?.apply(event)
            }
            self?.bar.streamDone.isHidden = false
        }
    }

    /// One live event, applied the moment it arrives.
    private func apply(_ event: FeedEvent) {
        let sv = adapter.scrollView
        switch event {
        case .message(let m):
            guard model.atLiveEdge else { return }
            let pinned = sv.isPinnedToBottom
            model.append(m)
            adapter.rowsAppended(1)
            if pinned { sv.layoutIfNeeded(); sv.scrollToBottomNow() }
            refreshLabel()
        case .boost(let id, let b):
            changeRow(model.addBoost(to: id, b), id: id)
        case .typingStarted, .typingStopped:
            break
        }
    }

    private func changeRow(_ index: Int?, id: MessageID) {
        guard let index else { return }
        let sv = adapter.scrollView
        let pinned = sv.isPinnedToBottom
        heights.invalidate(id)
        adapter.heightInvalidated(id: id)
        adapter.rowChanged(index)
        if pinned { sv.layoutIfNeeded(); sv.scrollToBottomNow() }
        refreshLabel()
    }

    private func boostBurst() {
        // Boost has no public initialiser, so the burst reuses boosts the data already holds.
        let pool = Array(model.dataset.messages.suffix(Windowing.pageSize).flatMap(\.boosts).prefix(5))
        Task { @MainActor [weak self] in
            for k in 0..<5 {
                guard let self, let last = self.model.items.last?.message.id else { return }
                self.changeRow(self.model.addBoost(to: last, pool[k % pool.count]), id: last)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    // MARK: State label

    private func refreshLabel() {
        let sv = adapter.scrollView
        var s = DebugBar.State()
        s.first = model.firstID; s.last = model.lastID; s.loaded = model.items.count
        s.pinned = sv.isPinnedToBottom
        if let r = adapter.visibleTopRow() {
            s.top = model.items[r].message.id
            s.y = adapter.rowFrame(r).minY - sv.contentOffset.y
        }
        bar.show(s)
    }
}
