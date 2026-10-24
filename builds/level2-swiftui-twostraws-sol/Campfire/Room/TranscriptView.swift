import SwiftUI

struct TranscriptView: View {
    let store: RoomStore
    @Bindable var scroll: RoomScrollState
    let older: () -> Void
    let newer: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if store.items.first?.id == 1 { WelcomeCard().padding(.bottom, 24) }
                ForEach(store.items) { item in
                    MessageCell(item: item).equatable()
                }
            }
            .scrollTargetLayout()
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("transcript")
        .coordinateSpace(name: "transcriptViewport")
        .scrollPosition($scroll.position)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onPreferenceChange(RowFramesKey.self, perform: scroll.layoutChanged)
        .onScrollGeometryChange(for: ViewportMetrics.self, of: ViewportMetrics.init) { _, metrics in
            scroll.geometryChanged(metrics)
            if scroll.userScrolling && metrics.offset <= 1 { older() }
            if scroll.userScrolling && metrics.contentHeight - metrics.size.height - metrics.offset <= 1 { newer() }
        }
        .onScrollPhaseChange { _, phase in scroll.scrollPhaseChanged(phase) }
    }
}
