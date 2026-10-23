import SwiftUI

/// Benchmark controls, shown when launched with `-uvsBenchmark YES`.
struct DebugBar: View {
    let model: RoomModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                button("Reset") { model.reset() }
                button("Jump to 2500") { model.jump(to: 2500) }
                button("Load older") { model.loadOlderTapped() }
                button("Start stream") { model.startStream() }
                button("Text size +") { model.textSizeUp() }
                button("Boost burst") { model.boostBurst() }
            }
            HStack(spacing: 8) {
                Text(verbatim: model.stateLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("debug-state")
                    .accessibilityLabel(model.stateLabel)
                if model.streamDone {
                    Text(verbatim: "Stream done")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityIdentifier("stream-done")
                }
            }
            // Fixed height: the label changing must never resize the room above it.
            .frame(height: 16)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .dynamicTypeSize(.large)
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.gray.opacity(0.25)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(title)
    }
}
