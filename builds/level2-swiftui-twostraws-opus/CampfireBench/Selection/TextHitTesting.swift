import SwiftUI

/// Maps between points and character offsets in a laid-out `Text`.
struct TextHitTesting {
    let layout: Text.Layout
    /// Where the layout's origin sits in the caller's coordinate space.
    let origin: CGPoint
    /// UTF-16 length of the plain string the layout shows.
    let length: Int

    struct Glyph {
        let rect: CGRect
        let index: Int
        let line: Int
    }

    var glyphs: [Glyph] {
        // Character indices are opaque; the first glyph of a laid-out text is its first character, so
        // offsets are distances from the smallest index.
        var base: Text.Layout.CharacterIndex?
        for line in layout {
            for run in line {
                if let first = run.characterIndices.min() { base = base.map { min($0, first) } ?? first }
            }
        }
        guard let base else { return [] }
        var out: [Glyph] = []
        for (lineIndex, line) in layout.enumerated() {
            let lineBounds = line.typographicBounds
            for run in line {
                for i in run.indices {
                    let slice = run[i]
                    guard let characterIndex = slice.characterIndices.first else { continue }
                    let index = base.distance(to: characterIndex)
                    let bounds = slice.typographicBounds
                    let rect = CGRect(x: bounds.origin.x + origin.x,
                                      y: lineBounds.origin.y - lineBounds.ascent + origin.y,
                                      width: bounds.width,
                                      height: lineBounds.ascent + lineBounds.descent)
                    out.append(Glyph(rect: rect, index: index, line: lineIndex))
                }
            }
        }
        return out.sorted { $0.index < $1.index }
    }

    /// The caret offset nearest to a point.
    func offset(at point: CGPoint) -> Int {
        let all = glyphs
        guard !all.isEmpty else { return 0 }
        // Nearest line by vertical distance.
        let lines = Dictionary(grouping: all, by: \.line)
        let line = lines.min { a, b in
            distance(point.y, a.value[0].rect) < distance(point.y, b.value[0].rect)
        }!.value
        for glyph in line where point.x < glyph.rect.midX {
            return glyph.index
        }
        let last = line.last!
        if let next = all.first(where: { $0.index > last.index }) { return next.index }
        return length
    }

    /// Highlight rectangles for a range, one per line.
    func rects(for range: Range<Int>) -> [CGRect] {
        var byLine: [Int: CGRect] = [:]
        for glyph in glyphs where range.contains(glyph.index) {
            byLine[glyph.line] = byLine[glyph.line].map { $0.union(glyph.rect) } ?? glyph.rect
        }
        return byLine.keys.sorted().compactMap { byLine[$0] }
    }

    private func distance(_ y: CGFloat, _ rect: CGRect) -> CGFloat {
        if y < rect.minY { return rect.minY - y }
        if y > rect.maxY { return y - rect.maxY }
        return 0
    }
}
