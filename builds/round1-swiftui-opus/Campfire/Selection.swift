import SwiftUI

/// Long-press selection for message text, built on SwiftUI's TextRenderer (no UIKit text views).
///
/// A long press on a message selects its text and shows a Copy / Reply menu. Drag the handles to select any range;
/// Copy puts exactly that range on the pasteboard. Tapping elsewhere ends the selection; scrolling keeps working.

struct SelectionID: Hashable {
    let messageID: Int
    /// Which text of the message (body, code block, file name).
    let part: Int
}

/// One selectable unit (a character, or an inline image) and what it contributes to a copy.
struct TextPiece {
    let text: Text
    let copy: String
}

@MainActor @Observable
final class SelectionModel {
    struct Current: Equatable {
        let id: SelectionID
        var range: Range<Int>
        let copies: [String]
    }

    private(set) var current: Current?
    /// Bumped on every new selection so the menu can re-appear.
    private(set) var serial = 0

    func isSelecting(message id: Int) -> Bool { current?.id.messageID == id }

    func begin(_ id: SelectionID, copies: [String]) {
        current = Current(id: id, range: 0..<copies.count, copies: copies)
        serial &+= 1
    }

    /// A long press on a message without text: menu only.
    func beginMenuOnly(message id: Int) {
        current = Current(id: SelectionID(messageID: id, part: -1), range: 0..<0, copies: [])
        serial &+= 1
    }

    func setRange(_ range: Range<Int>) {
        guard var c = current, range != c.range else { return }
        c.range = range
        current = c
    }

    func clear() {
        if current != nil { current = nil }
    }

    var selectedText: String {
        guard let c = current, !c.range.isEmpty else { return "" }
        return c.copies[c.range].joined()
    }
}

/// Marks each piece of a selectable Text with its index, so the renderer can find every character's glyphs.
struct PieceIndex: TextAttribute {
    let index: Int
}

/// Where each piece was drawn, filled in by the renderer and read by the drag gesture.
final class PieceGeometry {
    var rects: [Int: CGRect] = [:]
    var lineBoxes: [(rect: CGRect, first: Int, last: Int)] = []

    /// Index of the piece boundary nearest to `point` (0...count).
    func boundary(near point: CGPoint, count: Int) -> Int? {
        guard !lineBoxes.isEmpty else { return nil }
        let line = lineBoxes.min { a, b in distance(point.y, a.rect) < distance(point.y, b.rect) }!
        var best = line.first, bestDistance = CGFloat.infinity
        for i in line.first...line.last {
            guard let r = rects[i] else { continue }
            for (edge, boundary) in [(r.minX, i), (r.maxX, i + 1)] where abs(point.x - edge) < bestDistance {
                bestDistance = abs(point.x - edge)
                best = boundary
            }
        }
        return min(max(best, 0), count)
    }

    private func distance(_ y: CGFloat, _ r: CGRect) -> CGFloat {
        y < r.minY ? r.minY - y : y > r.maxY ? y - r.maxY : 0
    }
}

/// Draws the text, the selection highlight under it and the two drag handles.
struct SelectionRenderer: TextRenderer {
    let range: Range<Int>
    let highlight: Color
    let handle: Color
    let geometry: PieceGeometry

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        var rects: [Int: CGRect] = [:]
        var lines: [(rect: CGRect, first: Int, last: Int)] = []
        for line in layout {
            let box = line.typographicBounds.rect
            var first = Int.max, last = Int.min
            for run in line {
                guard let index = run[PieceIndex.self]?.index else { continue }
                // Stretch each piece to the full line box so highlights join up like the system's.
                let r = run.typographicBounds.rect
                let full = CGRect(x: r.minX, y: box.minY, width: r.width, height: box.height)
                rects[index] = rects[index].map { $0.union(full) } ?? full
                first = min(first, index)
                last = max(last, index)
            }
            if first <= last { lines.append((box, first, last)) }
        }
        geometry.rects = rects
        geometry.lineBoxes = lines

        if !range.isEmpty {
            for line in lines {
                let lo = max(range.lowerBound, line.first), hi = min(range.upperBound - 1, line.last)
                guard lo <= hi, let a = rects[lo], let b = rects[hi] else { continue }
                ctx.fill(Path(CGRect(x: a.minX, y: line.rect.minY, width: b.maxX - a.minX, height: line.rect.height)),
                         with: .color(highlight))
            }
        }
        for line in layout { ctx.draw(line) }

        if !range.isEmpty, let start = rects[range.lowerBound], let end = rects[range.upperBound - 1] {
            drawHandle(&ctx, x: start.minX, top: start.minY, bottom: start.maxY, knobOnTop: true)
            drawHandle(&ctx, x: end.maxX, top: end.minY, bottom: end.maxY, knobOnTop: false)
        }
    }

    private func drawHandle(_ ctx: inout GraphicsContext, x: CGFloat, top: CGFloat, bottom: CGFloat, knobOnTop: Bool) {
        ctx.fill(Path(CGRect(x: x - 1, y: top, width: 2, height: bottom - top)), with: .color(handle))
        let knob = CGRect(x: x - 5, y: knobOnTop ? top - 9 : bottom - 1, width: 10, height: 10)
        ctx.fill(Path(ellipseIn: knob), with: .color(handle))
    }
}

/// A Text that can be range-selected after a long press.
struct SelectableText: View {
    let id: SelectionID
    /// The Text as normally drawn.
    let normal: Text
    /// The same text split into pieces; only built while selecting.
    let pieces: () -> [TextPiece]

    @Environment(SelectionModel.self) private var selection
    @Environment(\.palette) private var palette
    @State private var geometry = PieceGeometry()
    @State private var draggingStart: Bool?

    var body: some View {
        if let current = selection.current, current.id == id {
            let parts = pieces()
            parts.enumerated().reduce(Text(verbatim: "")) { text, item in
                text + item.element.text.customAttribute(PieceIndex(index: item.offset))
            }
            .textRenderer(SelectionRenderer(range: current.range, highlight: palette.selected,
                                            handle: palette.link, geometry: geometry))
            .gesture(handleDrag(count: parts.count, current: current))
        } else {
            normal
                .onLongPressGesture(minimumDuration: 0.45) {
                    selection.begin(id, copies: pieces().map(\.copy))
                }
        }
    }

    /// Dragging moves whichever end of the selection is nearer to where the drag began.
    private func handleDrag(count: Int, current: SelectionModel.Current) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let boundary = geometry.boundary(near: value.location, count: count) else { return }
                let range = selection.current?.range ?? current.range
                let movingStart: Bool
                if let d = draggingStart {
                    movingStart = d
                } else {
                    let startBoundary = geometry.boundary(near: value.startLocation, count: count) ?? 0
                    movingStart = abs(startBoundary - range.lowerBound) < abs(startBoundary - range.upperBound)
                    draggingStart = movingStart
                }
                if movingStart {
                    selection.setRange(min(boundary, range.upperBound - 1)..<range.upperBound)
                } else {
                    selection.setRange(range.lowerBound..<max(boundary, range.lowerBound + 1))
                }
            }
            .onEnded { _ in draggingStart = nil }
    }
}

extension TextPiece {
    /// One piece per character, styled by `style`.
    static func characters(of string: String, style: (Text) -> Text = { $0 }) -> [TextPiece] {
        string.map { ch in
            let s = String(ch)
            return TextPiece(text: style(Text(verbatim: s)), copy: s == "\u{2028}" ? " " : s)
        }
    }

    /// One piece per character of an attributed string, keeping each run's colour.
    static func characters(of attributed: AttributedString) -> [TextPiece] {
        var out: [TextPiece] = []
        for run in attributed.runs {
            let color = run.foregroundColor
            for ch in String(attributed[run.range].characters) {
                var text = Text(verbatim: String(ch))
                if let color { text = text.foregroundColor(color) }
                out.append(TextPiece(text: text, copy: String(ch)))
            }
        }
        return out
    }
}

/// Where the selected message's bubble is, so the menu can float above every row.
struct SelectionAnchor {
    let bounds: Anchor<CGRect>
    let isMine: Bool
    let copy: String
}

struct SelectionAnchorKey: PreferenceKey {
    static let defaultValue: SelectionAnchor? = nil
    static func reduce(value: inout SelectionAnchor?, nextValue: () -> SelectionAnchor?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Shows the Copy / Reply menu above (or, near the top, below) the selected bubble.
    func selectionMenuOverlay(topInset: CGFloat) -> some View {
        overlayPreferenceValue(SelectionAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    let rect = proxy[anchor.bounds]
                    let above = rect.minY - 48 > topInset
                    SelectionMenu(fallbackCopy: anchor.copy)
                        .position(x: anchor.isMine ? rect.maxX - 70 : rect.minX + 70,
                                  y: above ? rect.minY - 26 : min(rect.maxY + 26, proxy.size.height - 26))
                }
            }
        }
    }
}

/// The floating Copy / Reply menu over a selected message.
struct SelectionMenu: View {
    @Environment(SelectionModel.self) private var selection
    @Environment(\.palette) private var palette
    let fallbackCopy: String

    var body: some View {
        HStack(spacing: 0) {
            Button {
                let text = selection.selectedText
                Pasteboard.copy(text.isEmpty ? fallbackCopy : text)
                selection.clear()
            } label: {
                Text("Copy").padding(.horizontal, 16).frame(height: 38)
            }
            Rectangle().fill(palette.text.opacity(0.15)).frame(width: 1, height: 22)
            Button {
                selection.clear()
            } label: {
                Text("Reply").padding(.horizontal, 16).frame(height: 38)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(palette.text)
        .background(Capsule().fill(palette.background))
        .overlay(Capsule().strokeBorder(palette.borderDark, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .dynamicTypeSize(.large)
        .fixedSize()
    }
}
