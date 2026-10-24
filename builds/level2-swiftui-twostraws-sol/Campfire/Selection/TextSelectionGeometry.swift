import SwiftUI

enum TextSelectionGeometry {
    static func glyphs(layouts: [Text.LayoutKey.AnchoredLayout], geometry: GeometryProxy,
                       text: String) -> [SelectionGlyph] {
        var result: [SelectionGlyph] = []
        let boundaries = utf16Boundaries(text)
        for anchored in layouts {
            let origin = geometry[anchored.origin]
            let indices = anchored.layout.flatMap { $0.flatMap(\.characterIndices) }
            guard let first = indices.min() else { continue }
            for line in anchored.layout {
                for run in line {
                    for slice in run {
                        guard let index = slice.characterIndices.first else { continue }
                        let offset = first.distance(to: index)
                        let lower = boundaries.last { $0 <= offset } ?? 0
                        let upper = boundaries.first { $0 > offset } ?? text.utf16.count
                        var rect = slice.typographicBounds.rect
                        rect.origin.x += origin.x
                        rect.origin.y += origin.y
                        result.append(SelectionGlyph(id: result.count, range: lower..<upper, rect: rect))
                    }
                }
            }
        }
        return result
    }

    static func utf16Boundaries(_ text: String) -> [Int] {
        var result = [0], offset = 0
        for character in text { offset += String(character).utf16.count; result.append(offset) }
        return result
    }

    static func substring(_ text: String, range: Range<Int>) -> String {
        let boundaries = utf16Boundaries(text)
        let lower = boundaries.last { $0 <= range.lowerBound } ?? 0
        let upper = boundaries.first { $0 >= range.upperBound } ?? text.utf16.count
        let start = String.Index(utf16Offset: lower, in: text)
        let end = String.Index(utf16Offset: upper, in: text)
        return String(text[start..<end])
    }

    static func closestGlyph(to point: CGPoint, in glyphs: [SelectionGlyph]) -> SelectionGlyph? {
        glyphs.min {
            distance(point, to: $0.rect) < distance(point, to: $1.rect)
        }
    }

    private static func distance(_ point: CGPoint, to rect: CGRect) -> Double {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy * 4
    }
}
