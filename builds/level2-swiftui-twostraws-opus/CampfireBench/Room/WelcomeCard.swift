import SwiftUI

/// The card at the very top of the room, above the first message.
struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 85)
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    HStack {
                        Button {} label: {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: 0x2E9BE6), Color(hex: 0x3DBE5A))
                                .symbolRenderingMode(.palette)
                                .frame(width: Metrics.headerButton, height: Metrics.headerButton)
                                .background(Circle().fill(Palette.background))
                                .overlay(Circle().strokeBorder(Palette.borderDarker, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Room visibility")
                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    Text("Welcome to Campfire")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.top, 21)
                    Text("To invite people to chat, share the join link below.")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3.3)
                        .padding(.horizontal, 18)
                        .padding(.top, 2)
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 18))
                        Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN")
                            .font(.system(size: 16))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 39)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.borderDarker, lineWidth: 1))
                    .padding(.horizontal, 15)
                    .padding(.top, 21)
                    HStack(spacing: 11) {
                        CircleButton(systemImage: "qrcode", label: "QR code", iconSize: 20, weight: .medium)
                        CircleButton(systemImage: "doc.on.clipboard", label: "Copy join link", iconSize: 19, weight: .medium)
                        CircleButton(systemImage: "square.and.arrow.up", label: "Share join link", iconSize: 19, weight: .medium)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 9)
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Metrics.bubbleRadius).fill(Palette.bubble))
                .padding(.top, 24)
                CampfireLogo()
            }
            .padding(.horizontal, Metrics.screenPaddingX)
        }
        .padding(.bottom, 2.6)
        .dynamicTypeSize(.large)
    }
}
