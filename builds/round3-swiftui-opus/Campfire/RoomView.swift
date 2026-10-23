import SwiftUI

struct RoomView: View {
    let model: RoomModel
    let showsDebugBar: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let palette = Palette.forScheme(colorScheme)
        let scale = TypeScale.factor(for: typeSize)
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if model.isLoaded {
                    MessageList(model: model, palette: palette, scale: scale)
                }
                RoomHeader(palette: palette)
                if model.showsJumpButton {
                    JumpToBottomButton(palette: palette) { model.jumpToBottom() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, Metrics.screenPaddingX)
                        .padding(.bottom, 12)
                }
            }
            Composer(palette: palette)
                .padding(.top, Metrics.composerGap)
                .padding(.bottom, showsDebugBar ? 8 : 0)
            if showsDebugBar {
                DebugBar(model: model, palette: palette)
            }
        }
        .background(palette.background)
        .overlay(alignment: .top) {
            // Covers the status bar, which the scroll view reaches under.
            GeometryReader { geo in
                palette.background
                    .frame(height: geo.safeAreaInsets.top)
                    .offset(y: -geo.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct MessageList: View {
    let model: RoomModel
    let palette: Palette
    let scale: CGFloat
    @State private var position = ScrollPosition(idType: Int.self)
    @State private var alternate = false

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if model.showsWelcome {
                    WelcomeCard(palette: palette, scale: scale)
                }
                ForEach(model.rows) { row in
                    let selection = model.selection?.rowID == row.id ? model.selection : nil
                    MessageRow(row: row, palette: palette, scale: scale, selection: selection, model: model)
                        .equatable()
                        .zIndex(selection == nil ? 0 : 1)
                }
            }
            .coordinateSpace(.named(MessageRow.contentSpace))
            // A tap away from the selected message ends the selection; taps on it go to its text.
            .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                if !model.selectionContains(tap.location) { model.clearSelection() }
            }, isEnabled: model.selection != nil)
            .padding(.bottom, 2)
        }
        .scrollPosition($position)
        .onChange(of: model.scrollRequest) { _, request in
            guard let request else { return }
            // ScrollPosition is a value: asking for the one it already holds (the bottom edge again, the same
            // y again after the content moved) changes nothing and does not scroll. Alternate so every
            // request is new.
            alternate.toggle()
            if let id = request.rowID {
                let x = alternate ? 0.5 : 0.5001  // any x: the list only scrolls vertically
                position.scrollTo(id: id, anchor: UnitPoint(x: x, y: 0))
            } else if let y = request.y {
                position.scrollTo(y: alternate ? y : y + 0.001)
            } else {
                let toBottom = {
                    if alternate || model.rows.isEmpty {
                        position.scrollTo(edge: .bottom)
                    } else {
                        // The newest row's bottom on the bottom edge: the next pass finishes at the edge.
                        position.scrollTo(id: model.rows[model.rows.count - 1].id, anchor: UnitPoint(x: 0.5001, y: 1))
                    }
                }
                if request.animated {
                    withAnimation(.easeOut(duration: 0.25)) { toBottom() }
                } else {
                    toBottom()
                }
            }
        }
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(model.sizeAnchor, for: .sizeChanges)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
            ScrollMetrics(offsetY: geo.contentOffset.y, contentHeight: geo.contentSize.height,
                          containerHeight: geo.containerSize.height, containerWidth: geo.containerSize.width,
                          insetTop: geo.contentInsets.top, insetBottom: geo.contentInsets.bottom)
        } action: { _, new in
            model.scrollMetricsChanged(new)
        }
        .onScrollPhaseChange { _, phase in
            model.scrollPhaseChanged(phase)
        }
    }
}
