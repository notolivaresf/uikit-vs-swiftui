import SwiftUI

struct WelcomeCard: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .body) private var fontSize = 16.0

    var body: some View {
        VStack(spacing: 16) {
            CampfireMark()
                .frame(width: 69, height: 69)
                .padding(.top, -40)
                .padding(.bottom, 20)
            VStack(spacing: 2) {
                Text("Welcome to Campfire").bold()
                Text("To invite people to chat, share the join link below.")
                    .multilineTextAlignment(.center).lineSpacing(3.3).padding(.vertical, 1.65)
            }
            .font(.system(size: fontSize))
            Label("http://127.0.0.1:3055/join/GwHG-HbZN", systemImage: "person.badge.plus.fill")
                .font(.system(size: fontSize))
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(CampfireStyle.background(scheme), in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(CampfireStyle.border(scheme)))
            HStack(spacing: 10) {
                CircleControl(title: "QR code", symbol: "qrcode.viewfinder")
                CircleControl(title: "Copy invite", symbol: "doc.on.clipboard")
                CircleControl(title: "Share invite", symbol: "square.and.arrow.up")
            }
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)
        .background(CampfireStyle.bubble(scheme), in: .rect(cornerRadius: 10.56))
        .overlay(alignment: .topLeading) {
            Button(action: {}) {
                Text("🌎").font(.system(size: 16))
                    .frame(width: 42, height: 42)
                    .background(CampfireStyle.background(scheme), in: .circle)
                    .overlay(Circle().strokeBorder(CampfireStyle.border(scheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Room access")
            .padding(16)
        }
        .padding(.horizontal, 14.01)
        .padding(.top, 100)
    }
}
