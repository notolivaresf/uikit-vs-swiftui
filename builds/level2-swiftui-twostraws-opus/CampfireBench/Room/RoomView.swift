import SwiftUI

/// The single chat room: header, messages, composer, and the debug bar when benchmarking.
struct RoomView: View {
    let store: RoomStore
    let monitor: BenchmarkMonitor?
    let users: UserDirectory

    @State private var selection = SelectionModel()
    @State private var textSize = TextSizeSetting()
    @Environment(\.dynamicTypeSize) private var systemTypeSize

    var body: some View {
        let typeSize = textSize.override ?? systemTypeSize
        MessageList(store: store, scroller: store.scroller, selection: selection)
            .dynamicTypeSize(typeSize)
            .safeAreaInset(edge: .top, spacing: 0) {
                RoomHeader(roomName: store.roomName)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let monitor {
                        DebugBar(store: store, monitor: monitor, textSize: textSize, currentTextSize: typeSize)
                    }
                    ComposerBar()
                }
                .overlay(alignment: .topTrailing) {
                    if !store.scroller.isPinned {
                        JumpToBottomButton { store.showNewest() }
                            .padding(.trailing, Metrics.screenPaddingX)
                            .offset(y: -54)
                    }
                }
            }
            .background(Palette.background)
            .environment(selection)
            .environment(\.users, users)
            #if DEBUG
            .task { DebugScript.run(store: store, monitor: monitor, textSize: textSize) }
            #endif
    }
}
