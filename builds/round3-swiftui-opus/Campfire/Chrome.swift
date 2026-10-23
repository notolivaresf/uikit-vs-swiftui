import SwiftUI

/// Round outlined button used in the header, composer and welcome card. Drawn only; does nothing.
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let palette: Palette
    var size: CGFloat = 42
    var iconSize: CGFloat = 19
    var weight: Font.Weight = .bold

    var body: some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: weight))
                .foregroundStyle(palette.text)
                .frame(width: size, height: size)
                .background(palette.background, in: Circle())
                .overlay(Circle().strokeBorder(palette.borderDarker, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// "General" pill, more, notifications and menu; rows fade out underneath it.
struct RoomHeader: View {
    let palette: Palette

    var body: some View {
        HStack(spacing: 0) {
            Button {} label: {
                Text(verbatim: "General")
                    .font(.system(size: 17.6, weight: .heavy))
                    .foregroundStyle(palette.background)
                    .frame(width: 96.5, height: 42)
                    .background(palette.text, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("General")
            CircleIconButton(systemName: "ellipsis", label: "Room settings", palette: palette, iconSize: 18, weight: .black)
                .padding(.leading, 6.5)
            Button {} label: {
                BellIcon(palette: palette)
                    .frame(width: 42, height: 42)
                    .background(palette.background, in: Circle())
                    .overlay(Circle().strokeBorder(palette.borderDarker, lineWidth: 1))
                    .padding(3)
                    .overlay(Circle().strokeBorder(Color(hex: 0xFF6A0D), lineWidth: 3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
            .padding(.leading, 2)
            Spacer(minLength: 0)
            CircleIconButton(systemName: "line.3.horizontal", label: "Menu", palette: palette, iconSize: 20, weight: .bold)
                .padding(.trailing, 11)
        }
        .padding(.leading, 10)
        .padding(.top, 5)  // the bell's 3 pt ring makes the row 48 tall; the pills sit at 8
        .frame(height: Metrics.headerHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(stops: [
                .init(color: palette.background, location: 0),
                .init(color: palette.background, location: Metrics.headerSolid / Metrics.headerHeight),
                .init(color: palette.background.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
        }
    }
}

struct BellIcon: View {
    let palette: Palette

    var body: some View {
        ZStack {
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .bold))
                .rotationEffect(.degrees(-25))
                .offset(x: -2, y: -1)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(palette.text)
                .background(
                    Image(systemName: "triangle.fill").font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(palette.background)
                )
                .offset(x: 5, y: 5)
        }
        .foregroundStyle(palette.text)
    }
}

/// Search button and the message composer. Drawn only.
struct Composer: View {
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            CircleIconButton(systemName: "magnifyingglass", label: "Search", palette: palette, iconSize: 20, weight: .heavy)
            HStack(spacing: 0) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 19, weight: .semibold))
                    .scaleEffect(x: -1, y: 1)
                    .padding(.leading, 13)
                    .accessibilityHidden(true)
                Text(verbatim: "")
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Message")
                Button {} label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 19, weight: .semibold))
                        .rotationEffect(.degrees(45))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach")
                .padding(.trailing, 12)
                Button {} label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(palette.background)
                        .frame(width: 34, height: 34)
                        .background(palette.text, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
                .padding(.trailing, 4)
            }
            .foregroundStyle(palette.text)
            .frame(height: Metrics.composerHeight)
            .overlay(Capsule().strokeBorder(palette.borderDarker, lineWidth: 1))
        }
        .padding(.horizontal, Metrics.screenPaddingX)
    }
}

struct JumpToBottomButton: View {
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
                .frame(width: 42, height: 42)
                .background(palette.background, in: Circle())
                .overlay(Circle().strokeBorder(palette.borderDarker, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to bottom")
        .accessibilityIdentifier("jump-to-bottom")
    }
}

/// Shown above the first message of the room.
struct WelcomeCard: View {
    let palette: Palette
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "Welcome to Campfire")
                .font(.system(size: FontSize.body * scale, weight: .bold))
                .padding(.top, 76.8)
            Text(verbatim: "To invite people to chat, share the join link below.")
                .font(.system(size: FontSize.body * scale))
                .lineSpacing((FontSize.bodyLine - TypeScale.naturalLineHeight(FontSize.body)) * scale)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
            HStack(spacing: 0) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 17))
                    .frame(width: 42)
                Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN")
                    .font(.system(size: FontSize.body * scale))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 8)
            }
            .frame(height: 40)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.borderDarker, lineWidth: 1))
            .padding(.horizontal, 15)
            .padding(.top, 25)
            HStack(spacing: 10) {
                CircleIconButton(systemName: "qrcode", label: "QR code", palette: palette, iconSize: 20, weight: .semibold)
                CircleIconButton(systemName: "list.clipboard", label: "Copy join link", palette: palette, iconSize: 19, weight: .semibold)
                CircleIconButton(systemName: "square.and.arrow.up", label: "Share join link", palette: palette, iconSize: 19, weight: .semibold)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity)
        .background(palette.bubble, in: RoundedRectangle(cornerRadius: Metrics.bubbleRadius))
        .overlay(alignment: .topLeading) {
            ZStack {
                Circle().fill(palette.background)
                Circle().strokeBorder(palette.borderDarker, lineWidth: 1)
                Text(verbatim: "🌎").font(.system(size: 15))
            }
            .frame(width: 42, height: 42)
            .padding(.leading, 16)
            .padding(.top, 16)
        }
        .overlay(alignment: .top) {
            CampfireLogo()
                .frame(width: 69, height: 69)
                .offset(y: -24)
        }
        .padding(.horizontal, Metrics.screenPaddingX)
        .padding(.top, 167)
        .padding(.bottom, 1.3)
    }
}

/// Approximation of Campfire's app icon: purple tile with a bundle of bright strokes.
struct CampfireLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(RadialGradient(colors: [Color(hex: 0x7A2280), Color(hex: 0x2E0A33)],
                                     center: .topLeading, startRadius: 4, endRadius: 90))
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xE3075E), Color(hex: 0xF89150), Color(hex: 0xEEC22F), Color(hex: 0x6FB7FF)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 3.2, height: 34 - CGFloat(abs(i - 3)) * 4)
                    .offset(x: CGFloat(i - 3) * 4.6)
            }
            .rotationEffect(.degrees(-35))
        }
        .accessibilityHidden(true)
    }
}

/// Benchmark controls, shown with `-uvsBenchmark YES`.
struct DebugBar: View {
    let model: RoomModel
    let palette: Palette

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                button("Reset") { model.reset() }
                button("Jump to 2500") { model.jump(to: 2500) }
                button("Load older") { model.debugLoadOlder() }
                button("Start stream") { model.startStream() }
            }
            HStack(spacing: 4) {
                button("Text size +") { model.increaseTextSize() }
                button("Boost burst") { model.boostBurst() }
                if model.streamDone {
                    Text(verbatim: "Stream done")
                        .accessibilityIdentifier("stream-done")
                }
            }
            .frame(height: 26)
            Text(verbatim: model.stateLabel)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 16)
                .accessibilityIdentifier("state")
        }
        .frame(height: 84)
        .font(.system(size: 11))
        .dynamicTypeSize(.large)
        .foregroundStyle(palette.text)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(palette.bubble)
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(palette.background, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
