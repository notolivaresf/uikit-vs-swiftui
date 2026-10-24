import SwiftUI

struct TextSelectionOverlay: View {
    let layouts: [Text.LayoutKey.AnchoredLayout]
    let geometry: GeometryProxy
    let text: String
    let selection: Range<Int>
    let update: (Range<Int>) -> Void
    let dismiss: () -> Void

    var body: some View {
        let glyphs = TextSelectionGeometry.glyphs(layouts: layouts, geometry: geometry, text: text)
        let selected = glyphs.filter { $0.range.overlaps(selection) }
        ZStack(alignment: .topLeading) {
            ForEach(selected) { glyph in
                Rectangle().fill(.blue.opacity(0.22))
                    .frame(width: max(1, glyph.rect.width), height: glyph.rect.height)
                    .offset(x: glyph.rect.minX, y: glyph.rect.minY)
                    .allowsHitTesting(false)
            }
            if let first = selected.min(by: { $0.range.lowerBound < $1.range.lowerBound }),
               let last = selected.max(by: { $0.range.upperBound < $1.range.upperBound }) {
                SelectionHandle(rect: first.rect, isStart: true)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("selection"))
                        .onChanged { value in
                            if let glyph = TextSelectionGeometry.closestGlyph(to: value.location, in: glyphs) {
                                update(min(glyph.range.lowerBound, selection.upperBound - 1)..<selection.upperBound)
                            }
                        })
                    .accessibilityLabel("Selection start")
                SelectionHandle(rect: last.rect, isStart: false)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("selection"))
                        .onChanged { value in
                            if let glyph = TextSelectionGeometry.closestGlyph(to: value.location, in: glyphs) {
                                update(selection.lowerBound..<max(selection.lowerBound + 1, glyph.range.upperBound))
                            }
                        })
                    .accessibilityLabel("Selection end")
                HStack(spacing: 12) {
                    Button("Copy") { Clipboard.copy(TextSelectionGeometry.substring(text, range: selection)); dismiss() }
                    Button("Reply", action: dismiss)
                    Button("Done", action: dismiss)
                }
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
                .padding(10)
                .background(.regularMaterial, in: .capsule)
                .offset(x: max(0, min(first.rect.minX, geometry.size.width - 180)),
                        y: geometry.frame(in: .named("transcriptViewport")).minY + first.rect.minY < 44
                        ? last.rect.maxY + 8 : first.rect.minY - 42)
            }
        }
        .coordinateSpace(name: "selection")
    }
}
