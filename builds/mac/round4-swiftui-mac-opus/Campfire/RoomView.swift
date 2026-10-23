import SwiftUI
import QuartzCore
import CampfireKit

/// The single room: optional debug bar, header floating over the messages, composer.
struct RoomView: View {
    let store: ChatStore
    @Bindable var engine: ScrollEngine
    let showDebugBar: Bool
    let launchStart: CFTimeInterval

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = Theme(scheme)
        VStack(spacing: 0) {
            if showDebugBar {
                DebugBar(store: store, engine: engine)
            }
            ZStack(alignment: .top) {
                MessageList(store: store, engine: engine, theme: theme, launchStart: launchStart)
                HeaderBar(roomName: store.roomName, theme: theme)
                if !engine.pinned {
                    JumpToBottomButton(theme: theme) { engine.jumpToBottom() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }
            }
            .clipped()
            ComposerBar(theme: theme)
        }
        .background(theme.background)
    }
}

private struct MessageList: View {
    let store: ChatStore
    @Bindable var engine: ScrollEngine
    let theme: Theme
    let launchStart: CFTimeInterval
    @State private var position = ScrollPosition()
    @Environment(SelectionModel.self) private var selection

    var body: some View {
        let metrics = Metrics(s: store.textScale)
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if !store.hasOlder {
                        WelcomeCard(theme: theme)
                            .padding(.top, 143.4)
                            .padding(.bottom, 23.5)
                    } else {
                        Color.clear.frame(height: Metrics.headerHeight)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { engine.leadHeight = $0 }
                let slice = engine.liveSlice()
                let firstID = store.rows.first?.id
                Color.clear.frame(height: slice.above)
                ForEach(slice.rows) { row in
                    let isFirst = row.id == firstID
                    MessageRow(row: row, metrics: metrics, theme: theme, isFirst: isFirst, store: store)
                        .equatable()
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(MessageList.space))
                        } action: { frame in
                            engine.rowFrameChanged(row.id, frame)
                        }
                        .onAppear { engine.rowAppeared(row.id) }
                        .onDisappear { engine.rowDisappeared(row.id) }
                        .padding(.top, MessageRow.gap(for: row, isFirst: isFirst, metrics: metrics))
                        .id(row.id)
                }
                Color.clear.frame(height: slice.below)
            }
            .coordinateSpace(.named(MessageList.space))
            .background {
                // A click on empty space ends the selection, as in a document.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selection.clear() }
                    .accessibilityHidden(true)
            }
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(engine.sizeAnchor, for: .sizeChanges)
        .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { old, new in
            engine.geometryChanged(from: old, to: new)
        }
        .onScrollPhaseChange { _, new in engine.phaseChanged(to: new) }
        .onChange(of: store.textSizeStep) { _, _ in engine.restore() }
        .onAppear {
            let position = $position
            // ScrollPosition ignores a request equal to the one it already holds, so every request is made
            // unique (alternating by an imperceptible amount); a repeated correction is then never dropped.
            var flip = false
            engine.scroller = { command in
                flip.toggle()
                switch command {
                case .bottom:
                    if flip { position.wrappedValue.scrollTo(edge: .bottom) }
                    else { position.wrappedValue.scrollTo(y: engine.bottomOffset) }
                case .offset(let y):
                    position.wrappedValue.scrollTo(y: y + (flip ? 0.001 : 0))
                case .row(let id, let a):
                    position.wrappedValue.scrollTo(id: id, anchor: UnitPoint(x: 0, y: a + (flip ? 1e-5 : 0)))
                }
            }
            engine.beginMeasure(at: launchStart, expectLayout: true, requireRows: true)
        }
    }

    nonisolated static let space = "room-content"
}

private struct JumpToBottomButton: View {
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.background)
                .frame(width: 41.7, height: 41.7)
                .background(Circle().fill(theme.text))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to bottom")
    }
}
