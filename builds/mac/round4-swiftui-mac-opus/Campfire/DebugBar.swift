import SwiftUI
import QuartzCore

/// Shown with `-uvsBenchmark YES`: commands for the benchmark and the room's state in one label.
struct DebugBar: View {
    let store: ChatStore
    let engine: ScrollEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                Button("Reset") { timed { engine.reset() } }
                Button("Jump to 2500") { timed { engine.jump(to: 2500) } }
                Button("Load older") { timed { engine.loadOlderKeepingPlace() } }
                Button("Start stream") { store.startStream() }
                Button("Text size +") {
                    timed {
                        engine.captureAnchor()
                        store.increaseTextSize()
                    }
                }
                Button("Boost burst") { store.boostBurst() }
                if store.streamDone {
                    Text("Stream done")
                        .font(.system(size: 11))
                        .padding(.horizontal, 2)
                        .frame(height: 20)
                }
            }
            .controlSize(.small)
            Text(engine.stateLabel)
                .font(.system(size: 11).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 14, alignment: .leading)
                .accessibilityLabel(engine.stateLabel)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private func timed(_ work: () -> Void) {
        engine.measured(start: CACurrentMediaTime(), work)
    }
}
