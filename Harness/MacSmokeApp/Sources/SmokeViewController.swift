import AppKit
import CampfireKit

/// Throwaway Mac app that only proves the Round 4 benchmark harness works. It fulfils the debug-bar contract in
/// PROMPT-mac.md with a plain table and nothing else; it looks nothing like Campfire on purpose and is never a
/// starting point for a build. Right-click shows Copy and Reply; message text is selectable, so both
/// capability checks have something to find.
final class SmokeViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    private let dataset = FakeData.generate(size: .k50)
    private var loaded: [Message] = []
    private let table = SelectableTableView()
    private let scroll = NSScrollView()
    private let stateLabel = NSTextField(labelWithString: "")
    private let doneLabel = NSTextField(labelWithString: "Stream done")
    private var streamTask: Task<Void, Never>?
    private var burstTask: Task<Void, Never>?
    private var pinned = true
    private var lastMs = 0
    private var tapTime: CFTimeInterval?
    private var programmatic = 0
    private var anchor: (id: Int, y: CGFloat)?
    private let sizes: [CGFloat] = [13, 15, 17, 20, 24]
    private var sizeIndex = 0
    private var font: NSFont { .systemFont(ofSize: sizes[sizeIndex]) }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 393, height: 852))
        let titles: [(String, Selector)] = [("Reset", #selector(reset)), ("Jump to 2500", #selector(jump)),
                                            ("Load older", #selector(older)), ("Start stream", #selector(startStream)),
                                            ("Text size +", #selector(textSize)), ("Boost burst", #selector(boostBurst))]
        let buttons = titles.map { NSButton(title: $0.0, target: self, action: $0.1) }
        let rows = stride(from: 0, to: buttons.count, by: 3).map { i -> NSStackView in
            let r = NSStackView(views: Array(buttons[i..<i + 3])); r.distribution = .fillEqually; r.spacing = 6
            return r
        }
        stateLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        stateLabel.lineBreakMode = .byTruncatingTail
        doneLabel.isHidden = true
        let bar = NSStackView(views: rows + [stateLabel, doneLabel])
        bar.orientation = .vertical; bar.alignment = .leading; bar.spacing = 4
        bar.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: .init("m"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.dataSource = self; table.delegate = self
        table.style = .plain
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.rowHeight = rowHeight
        let menu = NSMenu(); menu.delegate = self
        menu.addItem(withTitle: "Copy", action: #selector(copyRow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reply", action: #selector(reply), keyEquivalent: "").target = self
        table.menu = menu
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.postsFrameChangedNotifications = true
        scroll.contentView.postsBoundsChangedNotifications = true
        view.addSubview(bar); view.addSubview(scroll)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stateLabel.widthAnchor.constraint(equalTo: bar.widthAnchor),
            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(resized), name: NSView.frameDidChangeNotification, object: scroll)
        loaded = Array(Windowing.lastPage(dataset.messages))
        table.reloadData()
    }

    /// The window is on screen: lay out, put the room at the bottom, and report the launch time.
    func windowShown() {
        view.layoutSubtreeIfNeeded()
        scrollToBottom()
        view.window?.displayIfNeeded()
        lastMs = Int((CACurrentMediaTime() - launchStart) * 1000)
        updateState()
    }

    private var rowHeight: CGFloat { ceil(font.boundingRectForFont.height * 2 + 8) }

    // MARK: state label

    private func finishTap() {
        view.layoutSubtreeIfNeeded()
        view.window?.displayIfNeeded()
        if let t = tapTime { lastMs = Int((CACurrentMediaTime() - t) * 1000) }
        tapTime = nil
        updateState()
    }

    private var isAtBottom: Bool {
        let visible = scroll.contentView.bounds
        return visible.maxY >= table.frame.height - 100
    }

    private func topRow() -> (id: Int, y: CGFloat)? {
        let visible = scroll.contentView.bounds
        let range = table.rows(in: visible)
        guard range.length > 0, range.location < loaded.count else { return nil }
        var i = range.location
        while i < loaded.count, table.rect(ofRow: i).maxY <= visible.minY { i += 1 }
        guard i < loaded.count else { return nil }
        return (loaded[i].id, table.rect(ofRow: i).minY - visible.minY)
    }

    private func updateState() {
        let top = topRow()
        anchor = top
        let y = String(format: "%.1f", top?.y ?? 0)
        stateLabel.stringValue = "first \(loaded.first?.id ?? 0) last \(loaded.last?.id ?? 0) loaded \(loaded.count) pinned \(pinned ? "yes" : "no") top \(top?.id ?? 0) y \(y) ms \(lastMs)"
    }

    /// A user scroll: the room is pinned when it ends within 100 pt of the bottom.
    @objc private func scrolled() {
        guard programmatic == 0 else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(scrollSettled), object: nil)
        perform(#selector(scrollSettled), with: nil, afterDelay: 0.15)
    }

    @objc private func scrollSettled() { pinned = isAtBottom; updateState() }

    /// Window resize: stay pinned, or keep the row at the top where it was.
    @objc private func resized() {
        let a = anchor
        if pinned { scrollToBottom() } else if let a { restore(id: a.id, y: a.y) }
        updateState()
    }

    private func programmatically(_ body: () -> Void) {
        programmatic += 1; body(); programmatic -= 1
    }

    private func scrollToBottom() {
        programmatically {
            table.layoutSubtreeIfNeeded()
            if !loaded.isEmpty { table.scrollRowToVisible(loaded.count - 1) }
        }
    }

    /// Keeps message `id`'s top at `y` below the header.
    private func restore(id: Int, y: CGFloat) {
        guard let i = loaded.firstIndex(where: { $0.id == id }) else { return }
        programmatically {
            table.layoutSubtreeIfNeeded()
            scroll.contentView.scroll(to: NSPoint(x: 0, y: table.rect(ofRow: i).minY - y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    // MARK: actions (an NSButton's action runs on mouse up)

    @objc private func reset() {
        tapTime = CACurrentMediaTime()
        streamTask?.cancel(); burstTask?.cancel()
        doneLabel.isHidden = true
        sizeIndex = 0
        table.rowHeight = rowHeight
        loaded = Array(Windowing.lastPage(dataset.messages))
        table.reloadData()
        scrollToBottom()
        pinned = true
        finishTap()
    }

    @objc private func jump() {
        tapTime = CACurrentMediaTime()
        loaded = Array(Windowing.around(2_500, in: dataset.messages))
        table.reloadData()
        if let i = loaded.firstIndex(where: { $0.id == 2_500 }) {
            programmatically {
                table.layoutSubtreeIfNeeded()
                scroll.contentView.scroll(to: NSPoint(x: 0, y: table.rect(ofRow: i).minY))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
        }
        pinned = false
        finishTap()
    }

    @objc private func older() {
        tapTime = CACurrentMediaTime()
        guard let first = loaded.first else { return }
        let a = topRow()
        let page = Array(Windowing.page(before: first.id, in: dataset.messages))
        guard !page.isEmpty else { finishTap(); return }
        loaded = page + loaded
        table.reloadData()
        if let a { restore(id: a.id, y: a.y) }
        pinned = isAtBottom
        finishTap()
    }

    @objc private func textSize() {
        tapTime = CACurrentMediaTime()
        let a = topRow()
        sizeIndex = (sizeIndex + 1) % sizes.count
        table.rowHeight = rowHeight
        table.reloadData()
        if pinned { scrollToBottom() } else if let a { restore(id: a.id, y: a.y) }
        finishTap()
    }

    @objc private func boostBurst() {
        burstTask?.cancel()
        burstTask = Task { @MainActor in
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
                if !self.loaded.isEmpty {
                    self.table.reloadData(forRowIndexes: [self.loaded.count - 1], columnIndexes: [0])
                    if self.pinned { self.scrollToBottom() }
                }
                self.updateState()
            }
        }
    }

    @objc private func startStream() {
        streamTask?.cancel()
        doneLabel.isHidden = true
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { @MainActor in
            for await event in feed.play() {
                guard case .message(let m) = event else { continue }
                let wasPinned = self.pinned
                self.loaded.append(m)
                self.table.insertRows(at: [self.loaded.count - 1], withAnimation: [])
                if wasPinned { self.scrollToBottom() }
                self.updateState()
            }
            if !Task.isCancelled { self.doneLabel.isHidden = false }
        }
    }

    @objc private func copyRow() {
        let row = table.clickedRow
        guard row >= 0, row < loaded.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(loaded[row].plainText, forType: .string)
    }

    @objc private func reply() {}

    // MARK: table

    func numberOfRows(in tableView: NSTableView) -> Int { loaded.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField) ?? {
            let f = NSTextField(wrappingLabelWithString: "")
            f.identifier = id
            f.isSelectable = true
            f.maximumNumberOfLines = 2
            f.lineBreakMode = .byTruncatingTail
            return f
        }()
        let m = loaded[row]
        field.font = font
        field.stringValue = "#\(m.id) " + m.plainText + (m.boosts.isEmpty ? "" : "  " + m.boosts.map(\.content).joined(separator: " "))
        return field
    }
}

/// A table whose text fields take the click, so message text can be selected (double-click, drag) and copied.
final class SelectableTableView: NSTableView {
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool { true }
}
