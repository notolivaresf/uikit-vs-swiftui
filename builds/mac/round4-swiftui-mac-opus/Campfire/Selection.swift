import SwiftUI
import Observation
import os
import CampfireKit

/// A place in the room's text: a message, one of its selectable parts (paragraph run, code block, file name),
/// and a UTF-16 offset into that part's string (the unit Text.Layout uses).
struct TextPos: Comparable, Hashable {
    var message: MessageID
    var part: Int
    var offset: Int

    static func < (a: TextPos, b: TextPos) -> Bool {
        (a.message, a.part, a.offset) < (b.message, b.part, b.offset)
    }
}

struct PartKey: Hashable {
    let message: MessageID
    let part: Int
}

/// Text selection across the whole room, like a document: drag from any text to any other, double-click a
/// word, triple-click a paragraph, Command-C. (SwiftUI's own text selection stops at one Text and takes over
/// the right-click menu, so the room does its own.)
@MainActor
@Observable
final class SelectionModel {
    private(set) var anchor: TextPos?
    private(set) var focus: TextPos?

    @ObservationIgnored private var parts: [PartKey: PartEntry] = [:]
    @ObservationIgnored private var lastClick: (time: TimeInterval, pos: TextPos, count: Int)?
    @ObservationIgnored private var dragging = false
    @ObservationIgnored weak var store: ChatStore?

    final class PartEntry {
        var frame: CGRect = .zero
        let layout = LayoutBox()
        var string: String = ""
    }

    var hasSelection: Bool {
        guard let anchor, let focus else { return false }
        return anchor != focus
    }

    var ordered: (TextPos, TextPos)? {
        guard let anchor, let focus, anchor != focus else { return nil }
        return anchor < focus ? (anchor, focus) : (focus, anchor)
    }

    /// The selected UTF-16 range inside one part, if any.
    func range(in key: PartKey, length: Int) -> Range<Int>? {
        guard let (a, b) = ordered else { return nil }
        let start = TextPos(message: key.message, part: key.part, offset: 0)
        let end = TextPos(message: key.message, part: key.part, offset: length)
        guard b > start, a < end else { return nil }
        let lo = a > start ? a.offset : 0
        let hi = b < end ? b.offset : length
        return lo < hi ? lo..<hi : nil
    }

    func set(anchor a: TextPos, focus f: TextPos) {
        anchor = a
        focus = f
    }

    func clear() {
        if anchor != nil { anchor = nil }
        if focus != nil { focus = nil }
    }

    // MARK: Registry of the parts on screen

    func entry(for key: PartKey) -> PartEntry {
        if let e = parts[key] { return e }
        let e = PartEntry()
        parts[key] = e
        return e
    }

    func remove(_ key: PartKey) { parts[key] = nil }

    /// The part under a point in window coordinates, or the nearest one on the way.
    private func hit(_ point: CGPoint) -> TextPos? {
        var best: (key: PartKey, entry: PartEntry, distance: CGFloat)?
        for (key, e) in parts where e.frame.width > 0 {
            let f = e.frame
            let dy = point.y < f.minY ? f.minY - point.y : (point.y > f.maxY ? point.y - f.maxY : 0)
            let dx = point.x < f.minX ? f.minX - point.x : (point.x > f.maxX ? point.x - f.maxX : 0)
            let d = dy * 10_000 + dx
            if best == nil || d < best!.distance { best = (key, e, d) }
        }
        guard let best else { return nil }
        let f = best.entry.frame
        let local = CGPoint(x: point.x - f.minX, y: point.y - f.minY)
        let length = best.entry.string.utf16.count
        let offset: Int
        if local.y < 0 { offset = 0 } else if local.y > f.height { offset = length } else {
            offset = best.entry.layout.offset(at: local, length: length)
        }
        return TextPos(message: best.key.message, part: best.key.part, offset: offset)
    }

    // MARK: Mouse

    func mouseDown(at point: CGPoint, time: TimeInterval) {
        guard let pos = hit(point) else { return }
        dragging = false
        var count = 1
        if let last = lastClick, time - last.time < 0.45, last.pos.message == pos.message, last.pos.part == pos.part,
           abs(last.pos.offset - pos.offset) <= 2 {
            count = last.count % 3 + 1
        }
        lastClick = (time, pos, count)
        switch count {
        case 2: selectWord(at: pos)
        case 3: selectPart(at: pos)
        default:
            anchor = pos
            focus = pos
        }
    }

    func mouseDragged(to point: CGPoint) {
        guard anchor != nil, let pos = hit(point) else { return }
        if (lastClick?.count ?? 1) > 1 && !dragging { anchor = ordered?.0 ?? anchor }
        dragging = true
        if focus != pos { focus = pos }
    }

    private func selectWord(at pos: TextPos) {
        guard let e = parts[PartKey(message: pos.message, part: pos.part)] else { return }
        let ns = e.string as NSString
        var found: NSRange?
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { _, range, _, stop in
            if range.location <= pos.offset && pos.offset < NSMaxRange(range) || NSMaxRange(range) == pos.offset && found == nil && pos.offset == ns.length {
                found = range
                stop.pointee = true
            }
        }
        let r = found ?? NSRange(location: pos.offset, length: 0)
        anchor = TextPos(message: pos.message, part: pos.part, offset: r.location)
        focus = TextPos(message: pos.message, part: pos.part, offset: NSMaxRange(r))
    }

    private func selectPart(at pos: TextPos) {
        guard let e = parts[PartKey(message: pos.message, part: pos.part)] else { return }
        anchor = TextPos(message: pos.message, part: pos.part, offset: 0)
        focus = TextPos(message: pos.message, part: pos.part, offset: e.string.utf16.count)
    }

    // MARK: Copy

    /// The selected text, across messages; parts of one message are joined by newlines, messages by blank lines.
    var selectedText: String? {
        guard let (a, b) = ordered, let store else { return nil }
        var pieces: [String] = []
        for row in store.rows where row.id >= a.message && row.id <= b.message {
            let strings = SelectableParts.strings(of: row.message, store: store)
            var messagePieces: [String] = []
            for (n, s) in strings.enumerated() {
                let key = PartKey(message: row.id, part: n)
                guard let r = range(in: key, length: s.utf16.count) else { continue }
                let u = Array(s.utf16)[r]
                messagePieces.append(String(decoding: u, as: UTF16.self))
            }
            if !messagePieces.isEmpty { pieces.append(messagePieces.joined(separator: "\n")) }
        }
        let text = pieces.joined(separator: "\n\n").replacingOccurrences(of: "\u{FFFC}", with: "")
        return text.isEmpty ? nil : text
    }

    /// Everything loaded, first message to last.
    func selectAll() {
        guard let store, let first = store.rows.first, let last = store.rows.last else { return }
        let lastParts = SelectableParts.strings(of: last.message, store: store)
        anchor = TextPos(message: first.id, part: 0, offset: 0)
        focus = TextPos(message: last.id, part: max(0, lastParts.count - 1), offset: lastParts.last?.utf16.count ?? 0)
    }

    func copy() {
        if let text = selectedText { Clipboard.copy(text) }
    }
}

/// Holds the last layout SwiftUI drew for a part, for hit-testing the mouse.
final class LayoutBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    private var _lines: [LineInfo] = []

    struct LineInfo {
        var top: CGFloat
        var bottom: CGFloat
        var slices: [(minX: CGFloat, maxX: CGFloat, start: Int, end: Int)]
    }

    var lines: [LineInfo] {
        get { lock.withLock { _lines } }
        set { lock.withLock { _lines = newValue } }
    }

    func offset(at p: CGPoint, length: Int) -> Int {
        let lines = self.lines
        guard !lines.isEmpty else { return 0 }
        var index = lines.count - 1
        for (i, line) in lines.enumerated() {
            let next = i + 1 < lines.count ? lines[i + 1].top : .infinity
            if p.y < (line.bottom + next) / 2 || i == lines.count - 1 { index = i; break }
        }
        let line = lines[index]
        let lineEnd = index + 1 < lines.count ? (lines[index + 1].slices.first?.start ?? length) : length
        for s in line.slices {
            if p.x < (s.minX + s.maxX) / 2 { return s.start }
            if p.x < s.maxX { return s.end }
        }
        // Past the end of a wrapped line: before its trailing space, like a text view.
        if index + 1 < lines.count, let last = line.slices.last { return min(lineEnd, max(last.end, last.start)) }
        return lineEnd
    }
}

/// Draws a part's text with the selection behind it, and records the layout for hit-testing.
struct SelectionRenderer: TextRenderer {
    let selected: Range<Int>?
    let color: Color
    let box: LayoutBox
    let lineHeight: CGFloat

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        var lines: [LayoutBox.LineInfo] = []
        // Offsets are UTF-16 positions; the layout's first character is position 0.
        guard let base = layout.first?.first?.first?.characterIndices.first else { box.lines = []; return }
        for line in layout {
            let b = line.typographicBounds
            let mid = b.origin.y - (b.ascent - b.descent) / 2
            let top = mid - lineHeight / 2, bottom = mid + lineHeight / 2
            var slices: [(minX: CGFloat, maxX: CGFloat, start: Int, end: Int)] = []
            var highlight: (minX: CGFloat, maxX: CGFloat)?
            for run in line {
                for slice in run {
                    let r = slice.typographicBounds.rect
                    let indices = slice.characterIndices.map { base.distance(to: $0) }
                    guard let first = indices.min() else { continue }
                    let last = indices.max() ?? first
                    slices.append((r.minX, r.maxX, first, last + 1))
                    if let selected, selected.overlaps(first..<(last + 1)) {
                        highlight = (min(highlight?.minX ?? r.minX, r.minX), max(highlight?.maxX ?? r.maxX, r.maxX))
                    }
                }
            }
            if let h = highlight {
                ctx.fill(Path(CGRect(x: h.minX, y: top, width: h.maxX - h.minX, height: bottom - top)), with: .color(color))
            }
            slices.sort { $0.minX < $1.minX }
            // A slice's end is the next slice's start (covers surrogate pairs and combining marks).
            for i in slices.indices.dropLast() where slices[i + 1].start > slices[i].start {
                slices[i].end = slices[i + 1].start
            }
            lines.append(.init(top: top, bottom: bottom, slices: slices))
        }
        box.lines = lines
        for line in layout { ctx.draw(line) }
    }
}

/// One selectable piece of message text.
struct SelectableText: View {
    let key: PartKey
    let text: Text
    let string: String
    let lineHeight: CGFloat
    let theme: Theme
    @Environment(SelectionModel.self) private var selection
    @State private var pressed = false

    var body: some View {
        let entry = selection.entry(for: key)
        let _ = entry.string = string
        let range = selection.range(in: key, length: string.utf16.count)
        text
            .textRenderer(SelectionRenderer(selected: range, color: theme.selection, box: entry.layout,
                                            lineHeight: lineHeight))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { entry.frame = $0 }
            .onAppear { entry.string = string }
            .onDisappear { selection.remove(key) }
            .pointerStyle(.horizontalText)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !pressed {
                            pressed = true
                            selection.mouseDown(at: value.startLocation, time: value.time.timeIntervalSinceReferenceDate)
                        }
                        if hypot(value.translation.width, value.translation.height) > 2 {
                            selection.mouseDragged(to: value.location)
                        }
                    }
                    .onEnded { _ in pressed = false }
            )
    }
}

/// The selectable strings of a message, in the same order and UTF-16 layout as the views draw them.
enum SelectableParts {
    @MainActor
    static func strings(of message: Message, store: ChatStore) -> [String] {
        var out: [String] = []
        if case .image? = message.attachment {
            let caption = message.blocks.filter { if case .code = $0 { false } else { true } }
            if !caption.isEmpty { out.append(paragraph(caption, store: store)) }
            return out
        }
        if message.isEmojiOnly { return [message.plainText] }
        var run: [Block] = []
        for block in message.blocks {
            if case .code(_, let source) = block {
                if !run.isEmpty { out.append(paragraph(run, store: store)); run = [] }
                out.append(source)
            } else {
                run.append(block)
            }
        }
        if !run.isEmpty { out.append(paragraph(run, store: store)) }
        if case .file(let name, _)? = message.attachment { out.append(name) }
        return out
    }

    /// Text runs and mentions as one string: a mention is its avatar (one object character) and the name.
    @MainActor
    static func paragraph(_ blocks: [Block], store: ChatStore) -> String {
        var s = ""
        for block in blocks {
            switch block {
            case .text(let t): s += t
            case .mention(let id): s += "\u{FFFC}" + (store.user(id)?.name ?? "Unknown")
            case .code(_, let src): s += src
            }
        }
        return s
    }
}
