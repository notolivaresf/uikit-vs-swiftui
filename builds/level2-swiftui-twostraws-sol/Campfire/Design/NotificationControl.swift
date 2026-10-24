import SwiftUI

struct NotificationControl: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: {}) {
            ZStack {
                Circle().fill(CampfireStyle.background(scheme))
                Image(systemName: "bell.fill").font(.system(size: 21)).offset(x: -3, y: -2)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .background(CampfireStyle.background(scheme), in: .circle)
                    .offset(x: 3, y: 3)
            }
            .frame(width: 42, height: 42)
            .overlay(Circle().strokeBorder(CampfireStyle.border(scheme), lineWidth: 1))
            .overlay(Circle().strokeBorder(CampfireStyle.color(0xFF7516), lineWidth: 2.5).padding(-2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }
}
