import AppKit
import CampfireKit

/// Window content: debug bar (optional), header over the room, room, composer.
final class RootView: NSView {
    weak var controller: RoomController?
    override var isFlipped: Bool { true }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        controller?.layoutChrome()
    }
}

/// The room's scroll view. Captures the reading position right before a resize and restores it right after.
final class RoomScrollView: NSScrollView {
    weak var controller: RoomController?

    override func setFrameSize(_ newSize: NSSize) {
        guard let c = controller, newSize != frame.size else { return super.setFrameSize(newSize) }
        let anchor = c.captureAnchor()
        super.setFrameSize(newSize)
        c.scrollViewDidResize(anchor: anchor)
    }
}

/// The document: the welcome card at the very top of history, then the rows. Only rows near the visible area
/// have views; they are recycled as the room scrolls.
final class RoomDocumentView: NSView {
    weak var controller: RoomController?
    let welcome = WelcomeView()
    var selectionAnchor: TextPosition?
    var selectionHead: TextPosition?
    private var visibleRows: [MessageID: RowView] = [:]
    private var pool: [RowView] = []

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        welcome.isHidden = true
        addSubview(welcome)
    }

    required init?(coder: NSCoder) { fatalError() }

    func rowView(for id: MessageID) -> RowView? { visibleRows[id] }

    func removeAllRows() {
        for (_, v) in visibleRows { v.isHidden = true; pool.append(v) }
        visibleRows.removeAll()
    }

    /// Creates, places and recycles row views for the visible area (plus a margin).
    func tile() {
        guard let c = controller else { return }
        let visible = visibleRect.insetBy(dx: 0, dy: -600)
        let range = c.rowIndices(from: visible.minY, to: visible.maxY)
        var keep = Set<MessageID>()
        for i in range { keep.insert(c.items[i].message.id) }
        for (id, v) in visibleRows where !keep.contains(id) {
            v.isHidden = true
            pool.append(v)
            visibleRows[id] = nil
        }
        for i in range {
            let item = c.items[i]
            let id = item.message.id
            let v: RowView
            if let existing = visibleRows[id] {
                v = existing
            } else if let reused = pool.popLast() {
                v = reused
                v.isHidden = false
                visibleRows[id] = v
            } else {
                v = RowView(frame: .zero)
                v.controller = c
                v.document = self
                addSubview(v)
                visibleRows[id] = v
            }
            let frame = CGRect(x: 0, y: item.y, width: bounds.width, height: item.layout.height)
            if v.frame != frame { v.frame = frame }
            v.configure(id: id, layout: item.layout)
            v.applySelection()
        }
    }
}
