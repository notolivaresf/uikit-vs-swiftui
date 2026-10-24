import CampfireKit
import SwiftUI

/// Message text that can be selected: a long press selects the block and shows the Copy / Reply menu,
/// then the handles pick any range. Scrolling keeps working everywhere else.
struct SelectableText: View {
    let messageID: MessageID
    let block: Int
    let text: Text
    let plain: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    var ratio: CGFloat = FontRatio.system

    @Environment(SelectionModel.self) private var selection

    var body: some View {
        let base = text
            .foregroundStyle(Palette.ink)
            .lineHeight(lineHeight, fontSize: fontSize, ratio: ratio)
            .fixedSize(horizontal: false, vertical: true)
        // Only the selected block reads its text layout; the others stay plain `Text`.
        Group {
            if selection.isActive(messageID: messageID, block: block) {
                base
                    .backgroundPreferenceValue(Text.LayoutKey.self) { layouts in
                        if let first = layouts.first {
                            GeometryReader { proxy in
                                let hit = TextHitTesting(layout: first.layout, origin: proxy[first.origin],
                                                         length: plain.utf16.count)
                                ForEach(Array(hit.rects(for: selection.range).enumerated()), id: \.offset) { _, rect in
                                    Rectangle()
                                        .fill(Palette.link.opacity(0.22))
                                        .frame(width: rect.width, height: rect.height)
                                        .offset(x: rect.minX, y: rect.minY)
                                }
                            }
                        }
                    }
                    .overlayPreferenceValue(Text.LayoutKey.self) { layouts in
                        if let first = layouts.first {
                            GeometryReader { proxy in
                                let hit = TextHitTesting(layout: first.layout, origin: proxy[first.origin],
                                                         length: plain.utf16.count)
                                SelectionHandles(hit: hit, selection: selection)
                            }
                        }
                    }
            } else {
                base
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.45) {
            selection.selectAll(messageID: messageID, block: block, plain: plain)
        }
        .accessibilityAction(named: "Select text") {
            selection.selectAll(messageID: messageID, block: block, plain: plain)
        }
    }
}

/// The two drag handles at the ends of the selection.
private struct SelectionHandles: View {
    let hit: TextHitTesting
    let selection: SelectionModel

    var body: some View {
        let rects = hit.rects(for: selection.range)
        ZStack(alignment: .topLeading) {
            Color.clear
            if let first = rects.first, let last = rects.last {
                handle(at: CGPoint(x: first.minX, y: first.minY), height: first.height, knobOnTop: true) { point in
                    let offset = hit.offset(at: point)
                    selection.range = min(offset, selection.range.upperBound - 1)..<selection.range.upperBound
                }
                handle(at: CGPoint(x: last.maxX, y: last.minY), height: last.height, knobOnTop: false) { point in
                    let offset = hit.offset(at: point)
                    selection.range = selection.range.lowerBound..<max(offset, selection.range.lowerBound + 1)
                }
            }
        }
        .coordinateSpace(.named(Self.space))
    }

    private static let space = "selection-handles"

    private func handle(at point: CGPoint, height: CGFloat, knobOnTop: Bool,
                        onDrag: @escaping (CGPoint) -> Void) -> some View {
        VStack(spacing: 0) {
            if knobOnTop { Circle().frame(width: 10, height: 10) }
            Rectangle().frame(width: 2, height: height)
            if !knobOnTop { Circle().frame(width: 10, height: 10) }
        }
        .foregroundStyle(Palette.link)
        .frame(width: 32, height: height + 30)
        .contentShape(Rectangle())
        .offset(x: point.x - 16, y: point.y - (knobOnTop ? 25 : 5))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                .onChanged { value in
                    // Aim at the middle of the line the finger is on, not the knob.
                    onDrag(CGPoint(x: value.location.x, y: value.location.y + (knobOnTop ? height / 2 : -height / 2)))
                }
        )
        .accessibilityHidden(true)
    }
}
