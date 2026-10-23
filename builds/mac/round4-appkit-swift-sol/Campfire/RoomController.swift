import AppKit
import CampfireKit

final class RoomDocument: FlippedView {
    override func draw(_ dirtyRect: NSRect) { Style.background.setFill(); dirtyRect.fill() }
}
final class RoomRoot: FlippedView {
    var onResize: (() -> Void)?
    override func layout() { super.layout(); onResize?() }
    override func draw(_ dirtyRect: NSRect) { Style.background.setFill(); dirtyRect.fill() }
}
final class RoomController: NSViewController {
    let dataset: Dataset
    let users: [Int: User]
    var all: [Message]
    var loaded: [Message]
    var layouts: [RowLayout] = []
    var frames: [NSRect] = []
    var rowViews: [Int: MessageRow] = [:]
    let root = RoomRoot()
    let document = RoomDocument()
    let scroll = NSScrollView()
    let header = HeaderView()
    let composer = ComposerView()
    let debug = FlippedView()
    let state = Style.label("", size: 10)
    let done = Style.label("", size: 11)
    let jump = NSButton(title: "↓ Jump to bottom", target: nil, action: nil)
    var buttons: [NSButton] = []
    let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
    var scaleStep = 0
    var rebuilding = false
    var lastWidth: CGFloat = 0
    var lastViewportHeight: CGFloat = 0
    var lastMS = 0
    var clickStart: TimeInterval?
    var streamTask: Task<Void, Never>?
    var burstTimers: [Timer] = []
    var extraBoosts: [Int: [DisplayBoost]] = [:]
    var welcome: WelcomeView?
    var initialLayout = true
    var layoutCache: [Int: RowLayout] = [:]
    var cacheWidth: CGFloat = 0
    var cacheScale: Int = -1

    init() {
        dataset = FakeData.generate(size: .k50)
        users = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
        all = dataset.messages; loaded = Array(Windowing.lastPage(dataset.messages))
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        view = root
        scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay; scroll.autohidesScrollers = true
        scroll.drawsBackground = true; scroll.backgroundColor = Style.background
        scroll.borderType = .noBorder; scroll.documentView = document
        scroll.contentView.postsBoundsChangedNotifications = true
        root.addSubview(scroll); root.addSubview(header); root.addSubview(composer)
        jump.target = self; jump.action = #selector(jumpBottom); jump.bezelStyle = .rounded; jump.isHidden = true; root.addSubview(jump)
        if benchmark { setupDebug(); root.addSubview(debug) }
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        root.onResize = { [weak self] in self?.resizeRoom() }
    }
    func setupDebug() {
        let specs: [(String, Selector)] = [("Reset", #selector(reset)), ("Jump to 2500", #selector(jump2500)), ("Load older", #selector(loadOlderClick)), ("Start stream", #selector(startStream)), ("Text size +", #selector(textSize)), ("Boost burst", #selector(boostBurst))]
        for (title, action) in specs {
            let b = NSButton(title: title, target: self, action: action); b.font = .systemFont(ofSize: 11); b.bezelStyle = .rounded; b.setAccessibilityLabel(title); b.setAccessibilityElement(true); b.setAccessibilityRole(.button); debug.addSubview(b); buttons.append(b)
        }
        state.maximumNumberOfLines = 2; state.lineBreakMode = .byWordWrapping
        state.setAccessibilityIdentifier("room-state"); debug.addSubview(state); debug.addSubview(done)
    }
    func debugHeight(width: CGFloat) -> CGFloat {
        guard benchmark else { return 0 }
        var x: CGFloat = 6; var y: CGFloat = 3
        for b in buttons {
            let w = b.intrinsicContentSize.width
            if x + w > width - 6 { x = 6; y += 26 }
            b.frame = NSRect(x: x, y: y, width: w, height: 24); x += w + 4
        }
        done.frame = NSRect(x: x + 2, y: y + 4, width: max(0, width - x - 8), height: 18)
        state.frame = NSRect(x: 7, y: y + 29, width: width - 14, height: 29)
        return y + 61
    }
    func resizeRoom() {
        guard root.bounds.width > 0 else { return }
        let w = root.bounds.width; let h = root.bounds.height
        let pinned = initialLayout || isPinned
        let anchor = topAnchor()
        let dh = debugHeight(width: w)
        debug.frame = NSRect(x: 0, y: 0, width: w, height: dh)
        header.frame = NSRect(x: 0, y: dh, width: w, height: 58)
        scroll.frame = NSRect(x: 0, y: dh + 58, width: w, height: max(100, h - dh - 58 - 90))
        composer.frame = NSRect(x: 0, y: h - 90, width: w, height: 90)
        jump.frame = NSRect(x: (w - 154) / 2, y: h - 127, width: 154, height: 28)
        if abs(lastWidth - w) > 0.01 || initialLayout {
            lastWidth = w
            rebuild(anchor: anchor, pinned: pinned)
        } else if abs(lastViewportHeight - scroll.contentSize.height) > 0.01 {
            restore(anchor: anchor, pinned: pinned); updateVisible(); updateState()
        }
        lastViewportHeight = scroll.contentSize.height
        if initialLayout {
            initialLayout = false
            root.layoutSubtreeIfNeeded(); root.displayIfNeeded()
            lastMS = Int((ProcessInfo.processInfo.systemUptime - launchTime) * 1000); updateState()
        }
    }
    var isPinned: Bool { document.frame.height - scroll.contentView.bounds.maxY <= 100.01 }
    func topAnchor() -> (id: Int, y: CGFloat)? {
        let y = scroll.contentView.bounds.minY
        guard let i = frames.indices.first(where: { frames[$0].maxY > y + 0.01 && ($0 + 1 == frames.count || frames[$0 + 1].minY > y + 0.01) }), loaded.indices.contains(i) else { return nil }
        return (loaded[i].id, frames[i].minY - y)
    }
    func previous(for message: Message) -> Message? {
        if message.id > 1, message.id - 2 < all.count { return all[message.id - 2] }
        return nil
    }
    func rebuild(anchor: (id: Int, y: CGFloat)?, pinned: Bool) {
        rebuilding = true

        welcome?.removeFromSuperview(); welcome = nil
        let w = scroll.contentSize.width
        if abs(cacheWidth - w) > 0.01 || cacheScale != scaleStep {
            layoutCache.removeAll(); cacheWidth = w; cacheScale = scaleStep
            rowViews.values.forEach { $0.removeFromSuperview() }; rowViews.removeAll()
        }
        layouts = loaded.map { message in
            if let cached = layoutCache[message.id], cached.message == message { return cached }
            let l = RowLayout(message: message, previous: previous(for: message), users: users, width: w, scale: 1 + CGFloat(scaleStep) * 0.125, extraBoosts: extraBoosts[message.id] ?? [])
            if let row = rowViews[message.id], row.layout.message.blocks == message.blocks && row.layout.message.attachment == message.attachment {
                row.layout = l; row.needsDisplay = true
            } else { rowViews.removeValue(forKey: message.id)?.removeFromSuperview() }
            layoutCache[message.id] = l
            return l
        }
        let retained = Set(loaded.map(\.id))
        layoutCache = layoutCache.filter { retained.contains($0.key) }
        var y: CGFloat = 0
        if loaded.first?.id == 1 {
            let v = WelcomeView(frame: NSRect(x: 0, y: 0, width: w, height: 401)); document.addSubview(v); welcome = v; y = 401
        }
        frames = []
        for (index, l) in layouts.enumerated() {
            if index > 0 { y += l.presentation.isThreaded ? -1.2 : 21.28 }
            frames.append(NSRect(x: 0, y: y, width: w, height: l.height)); y += l.height
        }
        document.frame = NSRect(x: 0, y: 0, width: w, height: max(y + 2, scroll.contentSize.height))
        restore(anchor: anchor, pinned: pinned)
        rebuilding = false
        updateVisible(); finishClick(); updateState()
    }
    func restore(anchor: (id: Int, y: CGFloat)?, pinned: Bool) {
        let target: CGFloat
        if pinned { target = max(0, document.frame.height - scroll.contentSize.height) }
        else if let a = anchor, let i = loaded.firstIndex(where: { $0.id == a.id }) { target = frames[i].minY - a.y }
        else { target = scroll.contentView.bounds.minY }
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, min(target, document.frame.height - scroll.contentSize.height))))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
    func updateVisible() {
        let visible = scroll.contentView.bounds.insetBy(dx: 0, dy: -120)
        var needed = Set<Int>()
        for (i, frame) in frames.enumerated() where frame.intersects(visible) {
            let id = loaded[i].id; needed.insert(id)
            if let row = rowViews[id] { row.frame = frame }
            else { let row = MessageRow(layout: layouts[i], users: users, width: frame.width); row.frame = frame; document.addSubview(row); rowViews[id] = row }
        }
        for id in Array(rowViews.keys) where !needed.contains(id) { rowViews.removeValue(forKey: id)?.removeFromSuperview() }
        jump.isHidden = isPinned && loaded.last?.id == all.last?.id
    }
    @objc func scrolled() {
        guard !rebuilding && !initialLayout else { return }
        updateVisible(); updateState()
        if scroll.contentView.bounds.minY <= 0.5, (loaded.first?.id ?? 1) > 1 { loadOlder() }
    }
    func finishClick() {
        guard let start = clickStart else { return }
        root.layoutSubtreeIfNeeded(); root.displayIfNeeded()
        lastMS = Int((ProcessInfo.processInfo.systemUptime - start) * 1000); clickStart = nil
    }
    func updateState() {
        let a = topAnchor()
        let text = "first \(loaded.first?.id ?? 0) last \(loaded.last?.id ?? 0) loaded \(loaded.count) pinned \(isPinned ? "yes" : "no") top \(a?.id ?? 0) y \(String(format: "%.1f", a?.y ?? 0)) ms \(lastMS)"
        state.stringValue = text; state.setAccessibilityLabel(text)
    }
    func beginClick() { clickStart = ProcessInfo.processInfo.systemUptime }
    @objc func reset() {
        beginClick(); streamTask?.cancel(); streamTask = nil; burstTimers.forEach { $0.invalidate() }; burstTimers = []
        all = dataset.messages; loaded = Array(Windowing.lastPage(all)); extraBoosts = [:]; layoutCache = [:]; rowViews.values.forEach { $0.removeFromSuperview() }; rowViews = [:]; scaleStep = 0; done.stringValue = ""
        rebuild(anchor: nil, pinned: true)
    }
    @objc func jump2500() {
        beginClick(); loaded = Array(Windowing.around(2500, in: all))
        rebuild(anchor: (2500, 0), pinned: false)
    }
    @objc func loadOlderClick() { beginClick(); loadOlder() }
    func loadOlder() {
        guard let first = loaded.first else { return }
        let anchor = topAnchor()
        let older = Windowing.page(before: first.id, in: all)
        guard !older.isEmpty else { finishClick(); updateState(); return }
        loaded.insert(contentsOf: older, at: 0)
        if loaded.count > Windowing.maxLoaded { loaded.removeLast(loaded.count - Windowing.maxLoaded) }
        rebuild(anchor: anchor, pinned: false)
    }
    @objc func textSize() {
        beginClick(); let anchor = topAnchor(); let pinned = isPinned
        scaleStep = (scaleStep + 1) % 5; rebuild(anchor: anchor, pinned: pinned)
    }
    @objc func defaultTextSize() {
        let anchor = topAnchor(); let pinned = isPinned
        scaleStep = 0; rebuild(anchor: anchor, pinned: pinned)
    }
    @objc func jumpBottom() {
        if loaded.last?.id != all.last?.id { loaded = Array(Windowing.lastPage(all)); rebuild(anchor: nil, pinned: true) }
        else { rebuilding = true; restore(anchor: nil, pinned: true); rebuilding = false; updateVisible(); updateState() }
    }
    @objc func startStream() {
        guard streamTask == nil else { return }
        done.stringValue = ""
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { @MainActor [weak self] in
            for await event in feed.play() {
                guard !Task.isCancelled, let self else { break }
                self.receive(event)
            }
            guard !Task.isCancelled, let self else { return }
            self.done.stringValue = "Stream done"; self.done.setAccessibilityLabel("Stream done"); self.streamTask = nil
        }
    }
    func receive(_ event: FeedEvent) {
        let pinned = isPinned; let anchor = topAnchor()
        switch event {
        case .message(let message):
            guard message.id > (all.last?.id ?? 0) else { return }
            all.append(message)
            // An older history window remains contiguous until the user returns to the live edge.
            if loaded.last?.id == message.id - 1 {
                if loaded.count < Windowing.maxLoaded || pinned || (anchor.flatMap { a in loaded.firstIndex(where: { $0.id == a.id }) } ?? 0) > 40 {
                    loaded.append(message)
                    if loaded.count > Windowing.maxLoaded { loaded.removeFirst(loaded.count - Windowing.maxLoaded) }
                    rebuild(anchor: anchor, pinned: pinned)
                } else { jump.isHidden = false }
            } else { jump.isHidden = false }
        case .boost(let id, let boost):
            if let i = all.firstIndex(where: { $0.id == id }) { all[i].boosts.append(boost) }
            if let i = loaded.firstIndex(where: { $0.id == id }) { loaded[i].boosts.append(boost); rebuild(anchor: anchor, pinned: pinned) }
        case .typingStarted, .typingStopped: break
        }
    }
    @objc func boostBurst() {
        guard let id = all.last?.id else { return }
        for (i, content) in ["👍", "🎉", "🔥", "❤️", "😂"].enumerated() {
            let timer = Timer(timeInterval: Double(i + 1) * 0.2, repeats: false) { [weak self] _ in
                guard let self else { return }
                let pinned = self.isPinned; let anchor = self.topAnchor()
                self.layoutCache.removeValue(forKey: id)
                self.extraBoosts[id, default: []].append(DisplayBoost(boosterID: i + 2, content: content))
                self.rebuild(anchor: anchor, pinned: pinned)
            }
            RunLoop.main.add(timer, forMode: .common)
            burstTimers.append(timer)
        }
    }
}
