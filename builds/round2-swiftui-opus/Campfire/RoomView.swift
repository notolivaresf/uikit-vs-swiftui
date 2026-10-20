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

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
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
            .padding(.bottom, 2)
        }
        .simultaneousGesture(TapGesture().onEnded { model.clearSelection() }, isEnabled: model.selection != nil)
        .scrollPosition($position)
        .onChange(of: model.scrollRequest) { _, request in
            guard let request else { return }
            if let y = request.y {
                position.scrollTo(y: y)
            } else {
                withAnimation(.easeOut(duration: 0.25)) { position.scrollTo(edge: .bottom) }
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
