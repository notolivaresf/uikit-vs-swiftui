import SwiftUI

struct BenchmarkBar: View {
    let label: String
    let streamDone: Bool
    let reset: () -> Void
    let jump: () -> Void
    let older: () -> Void
    let stream: () -> Void
    let textSize: () -> Void
    let boosts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Button("Reset", action: reset)
                Button("Jump to 2500", action: jump)
                Button("Load older", action: older)
                Button("Start stream", action: stream)
            }
            HStack(spacing: 12) {
                Button("Text size +", action: textSize)
                Button("Boost burst", action: boosts)
                if streamDone { Text("Stream done").accessibilityIdentifier("streamDone") }
            }
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(2)
                .accessibilityIdentifier("benchmarkState")
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.055))
        .dynamicTypeSize(.large)
    }
}
