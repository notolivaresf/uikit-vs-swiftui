import SwiftUI

/// Round outlined icon button used in the header, composer and welcome card. Drawn only.
struct CircleIconButton<Icon: View>: View {
    var size: CGFloat = Metrics.headerButton
    var label: String
    @ViewBuilder var icon: Icon
    @Environment(\.palette) private var palette

    var body: some View {
        Button {} label: {
            icon
                .foregroundStyle(palette.text)
                .frame(width: size, height: size)
                .background(Circle().fill(palette.background))
                .overlay(Circle().strokeBorder(palette.borderDarker, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Campfire's room header: room name pill, room menu, notifications and the sidebar button, floating over
/// the top of the messages with a fade.
struct HeaderBar: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Button {} label: {
                Text(verbatim: "General")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(palette.background)
                    .frame(width: 97, height: Metrics.headerButton)
                    .background(RoundedRectangle(cornerRadius: 10.56).fill(palette.text))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("General")
            CircleIconButton(label: "Room options") {
                Image(systemName: "ellipsis").font(.system(size: 19, weight: .black))
            }
            .padding(.leading, 6)
            CircleIconButton(label: "Notifications") {
                BellAlertIcon()
            }
            .overlay(Circle().strokeBorder(palette.alert, lineWidth: 3).padding(-3))
            .padding(.leading, 5)
            Spacer(minLength: 0)
            CircleIconButton(label: "Rooms") {
                Image(systemName: "line.3.horizontal").font(.system(size: 21, weight: .bold))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: Metrics.headerHeight)
        .background {
            LinearGradient(stops: [
                .init(color: palette.background, location: 0),
                .init(color: palette.background, location: 0.2),
                .init(color: palette.background.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
        }
    }
}

struct BellAlertIcon: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 17, weight: .semibold))
            .rotationEffect(.degrees(-28))
            .offset(x: -2, y: -1)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(palette.background, palette.text)
                    .background(
                        Image(systemName: "triangle.fill").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.background)
                    )
                    .offset(x: 6, y: 4)
            }
    }
}

/// The message composer. Drawn only: nothing is typed or sent.
struct ComposerBar: View {
    var bottomPadding: CGFloat = 24
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            CircleIconButton(label: "Search") {
                Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .bold))
            }
            HStack(spacing: 0) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 19, weight: .medium))
                    .padding(.leading, 13)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button {} label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 19, weight: .medium))
                        .rotationEffect(.degrees(0))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach")
                .padding(.trailing, 4)
                Button {} label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(palette.background)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(palette.text))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
                .padding(.trailing, 4)
            }
            .foregroundStyle(palette.text)
            .frame(height: Metrics.headerButton)
            .background(Capsule().fill(palette.background))
            .overlay(Capsule().strokeBorder(palette.borderDarker, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Composer")
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.top, 24)
        .padding(.bottom, bottomPadding)
        .background(palette.background)
    }
}

/// The card at the very top of the room (shown once the first message is loaded).
struct WelcomeCard: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    CircleIconButton(size: 41.4, label: "Room visibility") {
                        Text(verbatim: "🌏").font(.system(size: 14))
                    }
                    Spacer()
                }
                .padding(.leading, 16.3)
                .padding(.top, 17.3)
                Text(verbatim: "Welcome to Campfire")
                    .font(.system(size: 17.6, weight: .bold))
                    .padding(.top, 19)
                Text(verbatim: "To invite people to chat, share the join link below.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .cssLineHeight(fontSize: 16, lineHeight: 23)
                    .padding(.horizontal, 20)
                HStack(spacing: 0) {
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 17))
                        .frame(width: 26)
                    Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN")
                        .font(.system(size: 16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.leading, 9)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .frame(height: 39.7)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.background))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.borderDarker, lineWidth: 1))
                .padding(.horizontal, 15.4)
                .padding(.top, 14.7)
                HStack(spacing: 11) {
                    CircleIconButton(size: 41.8, label: "QR code") {
                        Image(systemName: "qrcode").font(.system(size: 19))
                    }
                    CircleIconButton(size: 41.8, label: "Copy link") {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 18))
                    }
                    CircleIconButton(size: 41.8, label: "Share link") {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .medium))
                    }
                }
                .padding(.top, 16.6)
                .padding(.bottom, 11.3)
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.bubble))
            .overlay(alignment: .top) {
                CampfireIcon()
                    .frame(width: 69, height: 69)
                    .offset(y: -23.7)
            }
            .padding(.top, 23.7)
        }
        .padding(.horizontal, Metrics.screenPaddingX)
        .padding(.top, 85)
        .padding(.bottom, 2.7)
    }
}

/// The Campfire app icon: flame strokes on a purple tile.
struct CampfireIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x7A1C77), Color(hex: 0x3A0838)], startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
            .overlay {
                ZStack {
                    ForEach(0..<7, id: \.self) { i in
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0xFF2D6F), Color(hex: 0xFF8A00), Color(hex: 0x9ED8FF)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 3.4, height: 30 - CGFloat(abs(i - 3)) * 3)
                            .rotationEffect(.degrees(-40))
                            .offset(x: CGFloat(i - 3) * 4.2, y: CGFloat(i - 3) * 1.2)
                    }
                }
            }
            .accessibilityHidden(true)
    }
}
