import CampfireKit
import SwiftUI

/// Shown with `-uvsBenchmark YES`: drives the benchmark and shows the room's state.
struct DebugBar: View {
    let store: RoomStore
    let monitor: BenchmarkMonitor
    let textSize: TextSizeSetting
    /// The text size the room is using now.
    let currentTextSize: DynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                button("Reset") {
                    let relayout = textSize.override != nil || store.rows.last?.id != store.newestMessageID
                        || store.rows.count != Windowing.pageSize
                    textSize.override = nil
                    monitor.begin(needsLayout: relayout) { [store] in
                        store.scroller.isPinned && store.rows.last.map { store.scroller.hasFrame(for: $0.id) } == true
                    }
                    store.showNewest()
                }
                button("Jump to 2500") {
                    monitor.begin { [store] in store.scroller.hasFrame(for: 2500) }
                    store.jump(to: 2500)
                }
                button("Load older") {
                    let loaded = store.loadOlder()
                    monitor.begin(needsLayout: loaded)
                }
                button("Start stream") { store.startStream() }
                button("Text size +") {
                    monitor.begin(needsLayout: true)
                    textSize.step(from: currentTextSize)
                }
                button("Boost burst") { store.boostBurst() }
                if store.streamState == .done {
                    Text("Stream done")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("debug.streamDone")
                }
            }
            Text(monitor.label)
                .font(.system(size: 10.5).monospacedDigit())
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("debug.state")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bubble)
        .dynamicTypeSize(.large)
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Palette.ink)
            .accessibilityIdentifier("debug.\(title)")
    }
}
