import SwiftUI
import class UIKit.UIPasteboard

struct SelectionActiveKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct GlyphHit: Equatable, Sendable {
    let index: Int
    let rect: CGRect
}

/// TextRenderer exposes glyph geometry without accessing the platform's text views.
private final class GlyphMap: @unchecked Sendable {
    private let lock = NSLock()
    private var value: [GlyphHit] = []
    func write(_ hits: [GlyphHit]) { lock.lock(); value = hits; lock.unlock() }
    func read() -> [GlyphHit] { lock.lock(); defer { lock.unlock() }; return value }
}

struct InlineAvatarTag: TextAttribute {
    let color: Color
    let initial: String
}

private func drawAvatar(_ avatar: InlineAvatarTag, in bounds: CGRect, context: inout GraphicsContext) {
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let circle = CGRect(x: center.x - 8.8, y: center.y - 8.8, width: 17.6, height: 17.6)
    context.fill(Path(ellipseIn: circle), with: .color(avatar.color))
    context.draw(Text(avatar.initial).font(.system(size: 9.4, weight: .bold)).foregroundColor(.white), at: center)
}

private struct InlineAvatarRenderer: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if let avatar = run[InlineAvatarTag.self] {
                    drawAvatar(avatar, in: run.typographicBounds.rect, context: &context)
                } else { context.draw(run) }
            }
        }
    }
}

private struct SelectionRenderer: TextRenderer {
    let map: GlyphMap
    let selection: Range<Int>?
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let runs = layout.flatMap { $0 }
        guard let first = runs.flatMap(\.characterIndices).min() else { return }
        var hits: [GlyphHit] = []
        for run in runs {
            for slice in run {
                let indices = slice.characterIndices
                guard !indices.isEmpty else { continue }
                let rect = slice.typographicBounds.rect
                for (part, character) in indices.enumerated() {
                    let index = first.distance(to: character)
                    let width = rect.width / CGFloat(indices.count)
                    let partRect = CGRect(x: rect.minX + CGFloat(part) * width, y: rect.minY, width: width, height: rect.height)
                    hits.append(GlyphHit(index: index, rect: partRect))
                    if selection?.contains(index) == true {
                        context.fill(Path(partRect.insetBy(dx: 0, dy: -1)), with: .color(.blue.opacity(0.24)))
                    }
                }
                if let avatar = slice[InlineAvatarTag.self] {
                    drawAvatar(avatar, in: rect, context: &context)
                } else { context.draw(slice) }
            }
        }
        map.write(hits)
    }
}

/// Native SwiftUI Text on iPhone offers whole-value copying. This adds range handles with
/// SwiftUI gestures and TextRenderer, retaining normal ScrollView gestures until a long press.
struct SelectableMessageText: View {
    let text: Text
    let plain: String
    var inlineAvatars = false
    @State private var map = GlyphMap()
    @State private var selection: Range<Int>?
    @State private var selecting = false
    @State private var handleOrigin: CGPoint?
    @State private var showMenu = false
    @State private var hits: [GlyphHit] = []
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            if selecting { text.textRenderer(SelectionRenderer(map: map, selection: selection)) }
            else if inlineAvatars { text.textRenderer(InlineAvatarRenderer()) }
            else { text }
        }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 12) {
                selecting = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(16))
                    hits = map.read()
                    guard !hits.isEmpty else { return }
                    selection = 0..<characterCount
                    showMenu = true
                }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
                guard selecting else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(16))
                    hits = map.read()
                }
            }
            .overlay(alignment: .topLeading) { selectionControls }
            .preference(key: SelectionActiveKey.self, value: selection != nil)
            .accessibilityAction(named: "Copy") { UIPasteboard.general.string = plain }
            .accessibilityAction(named: "Reply") { }
            .onChange(of: plain) { _, _ in selection = nil; showMenu = false; selecting = false }
    }

    @ViewBuilder private var selectionControls: some View {
        if let selected = selection, !selected.isEmpty,
           let start = hits.first(where: { $0.index >= selected.lowerBound }),
           let end = hits.last(where: { $0.index < selected.upperBound }) {
            handle(at: CGPoint(x: start.rect.minX, y: start.rect.minY), height: start.rect.height, leading: true)
            handle(at: CGPoint(x: end.rect.maxX, y: end.rect.minY), height: end.rect.height, leading: false)
            if showMenu {
                HStack(spacing: 0) {
                    Button("Copy") {
                        UIPasteboard.general.string = selectedString(selected)
                        selection = nil; showMenu = false; selecting = false
                    }
                    .padding(.horizontal, 13)
                    Divider().frame(height: 20)
                    Button("Reply") { }
                        .padding(.horizontal, 13)
                    Divider().frame(height: 20)
                    Button { selection = nil; showMenu = false; selecting = false } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    }.padding(.horizontal, 10).accessibilityLabel("Dismiss selection")
                }
                .buttonStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(scheme == .dark ? .white : .black)
                .frame(height: 38)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.12), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                .offset(x: max(0, min(start.rect.minX, 90)), y: start.rect.maxY + 10)
                .accessibilityIdentifier("text-context-menu")
            }
        }
    }

    private func handle(at point: CGPoint, height: CGFloat, leading: Bool) -> some View {
        ZStack(alignment: leading ? .top : .bottom) {
            Rectangle().fill(.blue).frame(width: 2, height: height + 4)
            Circle().fill(.blue).frame(width: 10, height: 10).offset(y: leading ? -5 : 5)
        }
        .frame(width: 30, height: height + 20)
        .contentShape(Rectangle())
        .offset(x: point.x - 15, y: point.y - 10)
        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { drag in
            hits = map.read()
            guard let range = selection else { return }
            if handleOrigin == nil { handleOrigin = point }
            let origin = handleOrigin ?? point
            let index = nearest(CGPoint(x: origin.x + drag.translation.width, y: origin.y + height / 2 + drag.translation.height))
            if leading {
                let lastStart = boundaries.last(where: { $0 < range.upperBound }) ?? 0
                selection = min(index, lastStart)..<range.upperBound
            } else { selection = range.lowerBound..<min(characterCount, max(nextBoundary(after: range.lowerBound), nextBoundary(after: index))) }
            showMenu = false
        }.onEnded { _ in showMenu = true; handleOrigin = nil })
        .accessibilityLabel(leading ? "Selection start" : "Selection end")
        .accessibilityIdentifier(leading ? "selection-start" : "selection-end")
    }

    private var characterCount: Int { plain.utf16.count }
    private func nearest(_ point: CGPoint) -> Int {
        let hit = hits.min { a, b in
            distance(point, a.rect) < distance(point, b.rect)
        }
        let offset = min(max(0, hit?.index ?? 0), max(0, characterCount - 1))
        return boundaries.last(where: { $0 <= offset }) ?? 0
    }
    private var boundaries: [Int] {
        var result = [0], offset = 0
        for character in plain { offset += String(character).utf16.count; result.append(offset) }
        return result
    }
    private func nextBoundary(after index: Int) -> Int {
        boundaries.first(where: { $0 > index }) ?? characterCount
    }
    private func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let vertical = max(rect.minY - point.y, point.y - rect.maxY, 0)
        let horizontal = max(rect.minX - point.x, point.x - rect.maxX, 0)
        return vertical * vertical * 16 + horizontal * horizontal
    }
    private func selectedString(_ range: Range<Int>) -> String {
        String(decoding: Array(plain.utf16)[range], as: UTF16.self).replacingOccurrences(of: "\u{2003} ", with: "")
    }
}
