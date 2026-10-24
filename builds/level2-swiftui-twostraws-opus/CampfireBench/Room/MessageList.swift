import SwiftUI

enum RoomCoordinates {
    static let content = "room-content"
}

/// The scrolling list of loaded rows. Geometry and phase changes go to the scroller, which keeps the
/// reader's place.
struct MessageList: View {
    let store: RoomStore
    let scroller: RoomScroller
    let selection: SelectionModel

    var body: some View {
        ScrollView {
            MessageListContent(store: store, scroller: scroller)
        }
        .scrollPosition(scroller.positionBinding)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, new in
            scroller.geometryChanged(new)
        }
        .onScrollPhaseChange { _, new in
            scroller.phaseChanged(to: new)
        }
        .simultaneousGesture(TapGesture().onEnded { selection.clear() })
        .selectionMenuOverlay(selection)
        .accessibilityIdentifier("room.messages")
    }
}

private struct MessageListContent: View {
    let store: RoomStore
    let scroller: RoomScroller
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            if store.isAtRoomStart {
                WelcomeCard()
            }
            ForEach(RowChunk.chunks(of: store.rows)) { chunk in
                RowChunkView(chunk: chunk, scroller: scroller)
                    .equatable()
            }
        }
        .padding(.bottom, 16)
        .environment(\.metrics, Metrics(dynamicTypeSize: typeSize))
        .coordinateSpace(.named(RoomCoordinates.content))
    }
}

/// Rows grouped by message id (20 per group) so a new message or boost only re-lays out its own group;
/// the others keep their cached layout.
struct RowChunk: Identifiable, Equatable {
    static let size = 20

    let id: Int
    let rows: ArraySlice<RowModel>

    static func chunks(of rows: [RowModel]) -> [RowChunk] {
        var out: [RowChunk] = []
        var start = rows.startIndex
        while start < rows.endIndex {
            let key = rows[start].id / size
            var end = start + 1
            while end < rows.endIndex && rows[end].id / size == key { end += 1 }
            out.append(RowChunk(id: key, rows: rows[start..<end]))
            start = end
        }
        return out
    }
}

private struct RowChunkView: View, Equatable {
    let chunk: RowChunk
    let scroller: RoomScroller

    nonisolated static func == (lhs: RowChunkView, rhs: RowChunkView) -> Bool { lhs.chunk == rhs.chunk }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(chunk.rows) { row in
                MessageRow(row: row)
                    .equatable()
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(RoomCoordinates.content))
                    } action: { frame in
                        scroller.rowFrameChanged(row.id, frame)
                    }
                    .onScrollVisibilityChange(threshold: 0.001) { isVisible in
                        scroller.rowVisibilityChanged(row.id, isVisible)
                    }
                    .onDisappear { scroller.rowRemoved(row.id) }
                    .padding(.top, row.presentation.isThreaded ? Metrics.threadedGap : Metrics.rowGap)
                    .id(row.id)
            }
        }
    }
}
