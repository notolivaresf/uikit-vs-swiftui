import SwiftUI

struct RoomComposer: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            CircleControl(title: "Search", symbol: "magnifyingglass")
            HStack(spacing: 12) {
                Button(action: {}) {
                    SpeechBubbleShape().stroke(.primary, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                        .frame(width: 22, height: 22)
                }
                    .accessibilityLabel("Write a message")
                    .padding(.leading, 13)
                Spacer(minLength: 0)
                Button("Attach a file", systemImage: "paperclip") {}
                    .labelStyle(.iconOnly)
                    .font(.system(size: 22))
                Button(action: {}) {
                    Label("Send message", systemImage: "arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(CampfireStyle.background(scheme))
                        .frame(width: 34, height: 34)
                        .background(.primary, in: .circle)
                }
                .padding(.trailing, 4)
            }
            .frame(height: 42)
            .overlay(Capsule().strokeBorder(CampfireStyle.border(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14.01)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(CampfireStyle.background(scheme))
    }
}
