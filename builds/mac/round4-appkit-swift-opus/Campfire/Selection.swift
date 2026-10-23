import AppKit
import CampfireKit

/// A place in the room's text: message, text piece within the row, character within the piece.
struct TextPosition: Comparable {
    let id: MessageID
    let piece: Int
    let index: Int

    static func < (a: TextPosition, b: TextPosition) -> Bool {
        (a.id, a.piece, a.index) < (b.id, b.piece, b.index)
    }
}

/// Selection across rows, like text in a document: a single-click drag anywhere in the room selects from where it
/// started to where the mouse is, across messages, scrolling when the mouse leaves the room. Shown with a
/// temporary background in each text view; double and triple clicks use the text view's own word/line selection.
extension RoomDocumentView {
    var selectionRange: (lo: TextPosition, hi: TextPosition)? {
        guard let a = selectionAnchor, let h = selectionHead, a != h else { return nil }
        return a < h ? (a, h) : (h, a)
    }

    /// The selected characters of one text piece, if any.
    func selectedRange(id: MessageID, piece: Int, length: Int) -> NSRange? {
        guard let (lo, hi) = selectionRange else { return nil }
        let start = TextPosition(id: id, piece: piece, index: 0)
        let end = TextPosition(id: id, piece: piece, index: length)
        guard hi > start, lo < end else { return nil }
        let s = lo > start ? lo.index : 0
        let e = hi < end ? hi.index : length
        return e > s ? NSRange(location: s, length: e - s) : nil
    }

    func clearSelection() {
        guard selectionAnchor != nil else { return }
        selectionAnchor = nil
        selectionHead = nil
        applySelectionToVisibleRows()
    }

    func selectedText() -> String {
        guard let (lo, hi) = selectionRange, let c = controller else { return "" }
        var rows: [String] = []
        for item in c.items where item.message.id >= lo.id && item.message.id <= hi.id {
            var parts: [String] = []
            for (k, piece) in item.layout.texts.enumerated() {
                let ns = piece.string.string as NSString
                if let r = selectedRange(id: item.message.id, piece: k, length: ns.length) { parts.append(ns.substring(with: r)) }
            }
            if !parts.isEmpty { rows.append(parts.joined(separator: "\n")) }
        }
        return rows.joined(separator: "\n").replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    /// Text position under a document point: the nearest row, then the piece and character.
    func textPosition(at p: CGPoint) -> TextPosition? {
        guard let c = controller, !c.items.isEmpty else { return nil }
        let i = min(c.rowIndex(containingY: p.y), c.items.count - 1)
        let item = c.items[i]
        let id = item.message.id
        let texts = item.layout.texts
        guard !texts.isEmpty else { return TextPosition(id: id, piece: 0, index: 0) }
        let localY = p.y - item.y
        for (k, piece) in texts.enumerated() where localY < piece.frame.maxY {
            if localY < piece.frame.minY { return TextPosition(id: id, piece: k, index: 0) }
            var index = 0
            if let tv = rowView(for: id)?.textView(at: k) {
                index = tv.characterIndexForInsertion(at: tv.convert(p, from: self))
            }
            return TextPosition(id: id, piece: k, index: min(index, piece.string.length))
        }
        return TextPosition(id: id, piece: texts.count - 1, index: texts[texts.count - 1].string.length)
    }

    func applySelectionToVisibleRows() {
        for v in subviews { (v as? RowView)?.applySelection() }
    }

    func trackSelection(with event: NSEvent) {
        guard let window, let c = controller else { return }
        BodyTextView.clearNativeSelection()
        window.makeFirstResponder(self)
        let start = textPosition(at: convert(event.locationInWindow, from: nil))
        selectionAnchor = start
        selectionHead = start
        applySelectionToVisibleRows()

        NSEvent.startPeriodicEvents(afterDelay: 0.1, withPeriod: 0.05)
        defer { NSEvent.stopPeriodicEvents() }
        var last = event
        while let e = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .periodic]) {
            if e.type == .leftMouseUp { break }
            if e.type == .leftMouseDragged { last = e }
            let p = convert(last.locationInWindow, from: nil)
            if e.type == .periodic { c.autoscrollForSelection(toward: p.y) }
            if let pos = textPosition(at: convert(last.locationInWindow, from: nil)), pos != selectionHead {
                selectionHead = pos
                applySelectionToVisibleRows()
            }
        }
    }

    override func mouseDown(with event: NSEvent) { trackSelection(with: event) }

    @objc func copy(_ sender: Any?) {
        let text = selectedText()
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc override func selectAll(_ sender: Any?) {
        guard let c = controller, let first = c.items.first, let last = c.items.last else { return }
        selectionAnchor = TextPosition(id: first.message.id, piece: 0, index: 0)
        selectionHead = TextPosition(id: last.message.id, piece: Int.max / 2, index: 0)
        applySelectionToVisibleRows()
    }

    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(copy(_:)) { return selectionRange != nil }
        return true
    }
}
