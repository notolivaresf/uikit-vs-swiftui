import SwiftUI

/// The one text range selected in the room: which row, which text block in it, and the UTF-16 range.
struct MessageSelection: Equatable {
    let rowID: Int
    let part: Int
    var range: NSRange
}

/// Text that can show a selection highlight with draggable handles. SwiftUI's own `.textSelection`
/// only copies whole texts on iOS, so ranges are worked out from the laid-out `Text.Layout`.
struct SelectableText<Content: View>: View {
    let text: Content
    /// The characters as laid out (an inline image counts as one U+FFFC).
    let characters: String
    let selection: NSRange?
    let rowID: Int
    let part: Int
    let palette: Palette
    let model: RoomModel

    @State private var layout: Text.Layout?

    var body: some View {
        if let selection {
            text
                .background(alignment: .topLeading) {
                    if let layout {
                        SelectionGeometry(layout: layout, characters: characters).highlight(selection, color: palette.selected)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let layout {
                        SelectionHandles(geometry: SelectionGeometry(layout: layout, characters: characters), selection: selection,
                                         length: (characters as NSString).length, color: palette.link) { range in
                            model.updateSelection(range)
                        }
                    }
                }
                .onPreferenceChange(Text.LayoutKey.self) { layouts in
                    let new = layouts.first?.layout
                    Task { @MainActor in layout = new }
                }
        } else {
            text
        }
    }
}

/// Character geometry read from a `Text.Layout`.
struct SelectionGeometry {
    let layout: Text.Layout
    /// The laid-out characters; needed because layout character indices restart at every paragraph.
    let characters: String

    struct Glyph {
        let index: Int
        let rect: CGRect
        let line: Int
    }

    /// Every glyph with its offset into `characters` and a rect spanning its whole line box.
    var glyphs: [Glyph] {
        // UTF-16 offsets where each "\n"-separated paragraph starts.
        var starts = [0]
        for (i, unit) in characters.utf16.enumerated() where unit == 10 { starts.append(i + 1) }
        var out: [Glyph] = []
        var base: Text.Layout.CharacterIndex?
        var paragraph = 0
        var last: Int?
        var afterEmptyLine = false
        for (lineIndex, line) in layout.enumerated() {
            let lb = line.typographicBounds
            let top = lb.origin.y - lb.ascent
            let height = lb.ascent + lb.descent
            let slices = line.flatMap { run in run.map { $0 } }
            guard let firstIndex = slices.first?.characterIndices.first else {
                // An empty line is an empty paragraph of its own.
                if last != nil || afterEmptyLine { paragraph += 1 }
                last = nil
                afterEmptyLine = true
                continue
            }
            if base == nil { base = firstIndex }
            let firstOffset = base!.distance(to: firstIndex)
            if afterEmptyLine {
                paragraph += 1
                afterEmptyLine = false
            } else if let last, firstOffset < last {
                paragraph += 1
            }
            for slice in slices {
                guard let first = slice.characterIndices.first else { continue }
                let local = base!.distance(to: first)
                last = local
                let r = slice.typographicBounds.rect
                out.append(Glyph(index: starts[min(paragraph, starts.count - 1)] + local,
                                 rect: CGRect(x: r.minX, y: top, width: r.width, height: height), line: lineIndex))
            }
        }
        return out
    }

    func rects(for range: NSRange) -> [CGRect] {
        var byLine: [Int: CGRect] = [:]
        for g in glyphs where NSLocationInRange(g.index, range) {
            byLine[g.line] = byLine[g.line].map { $0.union(g.rect) } ?? g.rect
        }
        return byLine.keys.sorted().compactMap { byLine[$0] }
    }

    /// The caret offset nearest to a point.
    func offset(at point: CGPoint, length: Int) -> Int {
        let all = glyphs
        guard !all.isEmpty else { return 0 }
        let lines = Dictionary(grouping: all, by: \.line)
        let lineIndex = lines.keys.min { a, b in
            distance(point.y, lines[a]![0].rect) < distance(point.y, lines[b]![0].rect)
        } ?? 0
        let line = lines[lineIndex]!.sorted { $0.rect.minX < $1.rect.minX }
        for g in line where point.x < g.rect.midX { return g.index }
        return min(length, (line.last?.index ?? 0) + 1)
    }

    private func distance(_ y: CGFloat, _ r: CGRect) -> CGFloat {
        y < r.minY ? r.minY - y : (y > r.maxY ? y - r.maxY : 0)
    }

    func highlight(_ range: NSRange, color: Color) -> some View {
        let rects = rects(for: range)
        return Path { p in rects.forEach { p.addRect($0) } }
            .fill(color)
            .allowsHitTesting(false)
    }
}

/// Start and end handles; dragging either changes the range.
struct SelectionHandles: View {
    let geometry: SelectionGeometry
    let selection: NSRange
    let length: Int
    let color: Color
    let onChange: (NSRange) -> Void

    var body: some View {
        let rects = geometry.rects(for: selection)
        ZStack(alignment: .topLeading) {
            Color.clear
            if let first = rects.first, let last = rects.last {
                handle(top: true)
                    .position(x: first.minX, y: first.midY - 4)
                    .gesture(drag { point in
                        let start = min(geometry.offset(at: point, length: length), NSMaxRange(selection) - 1)
                        onChange(NSRange(location: max(0, start), length: NSMaxRange(selection) - max(0, start)))
                    })
                    .accessibilityLabel("Selection start")
                handle(top: false)
                    .frame(height: last.height + 10)
                    .position(x: last.maxX, y: last.midY + 4)
                    .gesture(drag { point in
                        let end = max(geometry.offset(at: point, length: length), selection.location + 1)
                        onChange(NSRange(location: selection.location, length: min(length, end) - selection.location))
                    })
                    .accessibilityLabel("Selection end")
            }
        }
    }

    private func handle(top: Bool) -> some View {
        VStack(spacing: 0) {
            if top { Circle().fill(color).frame(width: 10, height: 10) }
            Rectangle().fill(color).frame(width: 2, height: 24)
            if !top { Circle().fill(color).frame(width: 10, height: 10) }
        }
        .frame(width: 32, height: 44)
        .contentShape(Rectangle())
    }

    private func drag(_ update: @escaping (CGPoint) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(SelectionHandles.space))
            .onChanged { update($0.location) }
    }

    static let space = "selectable-text"
}

/// The long-press menu: Copy (the selected text) and Reply (does nothing).
struct SelectionMenu: View {
    let palette: Palette
    let onCopy: () -> Void
    let onReply: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item("Copy", systemImage: "doc.on.doc", action: onCopy)
            Rectangle().fill(palette.borderDarker.opacity(0.5)).frame(width: 1, height: 22)
            item("Reply", systemImage: "arrowshape.turn.up.left", action: onReply)
        }
        .background(palette.background, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.borderDark, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .fixedSize()
    }

    private func item(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
