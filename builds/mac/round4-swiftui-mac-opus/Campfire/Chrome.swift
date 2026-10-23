import SwiftUI

/// A round, outlined icon button as Campfire draws them (drawn only; it does nothing).
struct CircleIconButton<Icon: View>: View {
    let label: String
    let theme: Theme
    var diameter: CGFloat = Metrics.headerButton
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button {} label: {
            icon()
                .foregroundStyle(theme.text)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(theme.background))
                .overlay(Circle().strokeBorder(theme.borderDarker, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Room header: room name pill, room menu, notifications bell, sidebar menu. It floats over the messages
/// on a fade of the page colour.
struct HeaderBar: View {
    let roomName: String
    let theme: Theme

    var body: some View {
        HStack(spacing: 0) {
            Button {} label: {
                Text(roomName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.background)
                    .offset(y: 0.6)
                    .frame(width: 96.7, height: Metrics.headerButton)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.text))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(roomName)
            .padding(.leading, 10)

            CircleIconButton(label: "Room settings", theme: theme) {
                HStack(spacing: 2.05) {
                    ForEach(0..<3, id: \.self) { _ in Circle().frame(width: 5.3, height: 5.3) }
                }
            }
            .padding(.leading, 6.3)

            CircleIconButton(label: "Notifications", theme: theme) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .rotationEffect(.degrees(-22))
                        .offset(x: -3.5, y: -1.5)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.background)
                        .offset(x: 4.5, y: 3.5)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13.5, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(theme.background, theme.text)
                        .offset(x: 4.5, y: 4)
                }
            }
            .padding(3)
            .overlay(Circle().strokeBorder(theme.alert, lineWidth: 3))
            .padding(.leading, 2.3)

            Spacer(minLength: 8)

            CircleIconButton(label: "Menu", theme: theme) {
                VStack(spacing: 4.37) {
                    ForEach(0..<3, id: \.self) { _ in Capsule().frame(width: 19, height: 2.3) }
                }
            }
            .padding(.trailing, 11.3)
        }
        .frame(height: Metrics.headerHeight)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            LinearGradient(stops: [.init(color: theme.background, location: 0),
                                   .init(color: theme.background, location: 11.0 / 58),
                                   .init(color: theme.background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 58)
                .allowsHitTesting(false)
        }
    }
}

/// The composer: search, message field, attach, send. Drawn only.
struct ComposerBar: View {
    let theme: Theme

    var body: some View {
        HStack(spacing: 0) {
            CircleIconButton(label: "Search", theme: theme) {
                Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .bold))
            }
            .padding(.leading, 14)

            HStack(spacing: 0) {
                Image(systemName: "message")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(theme.text)
                    .padding(.leading, 13)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button {} label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(theme.text)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach")
                .padding(.trailing, 12.5)
                Button {} label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(theme.background)
                        .frame(width: 33.7, height: 33.7)
                        .background(Circle().fill(theme.text))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
                .padding(.trailing, 5)
            }
            .frame(height: Metrics.headerButton)
            .background(Capsule().fill(theme.background))
            .overlay(Capsule().strokeBorder(theme.borderDarker, lineWidth: 1))
            .padding(.leading, 10.3)
            .padding(.trailing, 14.3)
        }
        .padding(.top, 24)
        .frame(height: Metrics.composerArea, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(theme.background)
    }
}

/// Shown above the very first message of the room.
struct WelcomeCard: View {
    let theme: Theme

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HStack {
                    CircleIconButton(label: "Room access", theme: theme) {
                        ZStack {
                            Circle().fill(Color(hex: 0x3D7BD9)).frame(width: 17, height: 17)
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: 0x4CAF50))
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 16)

                VStack(spacing: 0) {
                    Text("Welcome to Campfire").font(.system(size: 16, weight: .bold))
                        .cssLineHeight(23, fontSize: 16, shift: 1.85)
                    Text("To invite people to chat, share the join link\nbelow.")
                        .font(.system(size: 16))
                        .cssLineHeight(23, fontSize: 16, shift: 1.85)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.text)
                .padding(.horizontal, 16)
                .padding(.top, 18.3)

                HStack(spacing: 9) {
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 17))
                    Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN")
                        .font(.system(size: 16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(theme.text)
                .padding(.horizontal, 14)
                .frame(height: 39.3)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.background))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.borderDarker, lineWidth: 1))
                .padding(.horizontal, 15.4)
                .padding(.top, 18)

                HStack(spacing: 10.3) {
                    CircleIconButton(label: "QR code", theme: theme) {
                        Image(systemName: "qrcode").font(.system(size: 19, weight: .semibold))
                    }
                    CircleIconButton(label: "Copy link", theme: theme) {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 18, weight: .semibold))
                    }
                    CircleIconButton(label: "Share", theme: theme) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold))
                    }
                }
                .padding(.top, 16.7)
                .padding(.bottom, 10.3)
                .offset(x: -5)
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.bubble))
            .padding(.top, 23.6)

            CampfireLogo()
                .frame(width: 69, height: 68.7)
        }
        .padding(.horizontal, Metrics.screenPaddingX)
    }
}

/// Campfire's app icon: a dark purple tile with a sheaf of warm-to-cool strokes.
struct CampfireLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RadialGradient(colors: [Color(hex: 0x8A1D7E), Color(hex: 0x3A0838)],
                                     center: .init(x: 0.35, y: 0.25), startRadius: 2, endRadius: 75))
            Canvas { ctx, size in
                let colors: [Color] = [Color(hex: 0xFF2D8A), Color(hex: 0xFF3B5C), Color(hex: 0xFF5A36),
                                       Color(hex: 0xFF7A22), Color(hex: 0xFF9A1F), Color(hex: 0xFFC04A),
                                       Color(hex: 0xFFE7B0), Color(hex: 0xB7E3FF), Color(hex: 0x5AA8FF),
                                       Color(hex: 0x7B5CFF)]
                let w = size.width, h = size.height
                for (i, c) in colors.enumerated() {
                    let t = CGFloat(i) - CGFloat(colors.count - 1) / 2
                    let dx = t * w * 0.045, dy = -t * h * 0.03
                    var path = Path()
                    path.move(to: CGPoint(x: w * 0.36 + dx, y: h * 0.27 + dy))
                    path.addCurve(to: CGPoint(x: w * 0.66 + dx, y: h * 0.74 + dy),
                                  control1: CGPoint(x: w * 0.40 + dx, y: h * 0.52 + dy),
                                  control2: CGPoint(x: w * 0.62 + dx, y: h * 0.48 + dy))
                    ctx.stroke(path, with: .color(c), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
