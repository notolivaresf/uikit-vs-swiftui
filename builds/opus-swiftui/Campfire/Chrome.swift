import SwiftUI

// MARK: - Header

/// Room name pill, room menu, notification bell (with Campfire's orange alert ring) and the sidebar menu.
/// Floats over the list; the background fades from the page colour to clear.
struct HeaderView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Text("General")
                .font(.system(size: 17.6, weight: .bold))
                .foregroundStyle(palette.background)
                .frame(width: 97, height: Theme.headerButton)
                .background(RoundedRectangle(cornerRadius: 10.5).fill(palette.text))
                .accessibilityAddTraits(.isHeader)
            CircleButton(label: "Room settings") { DotsGlyph(diameter: 5.6, spacing: 3.2) }
                .padding(.leading, 6)
            CircleButton(label: "Notifications") { BellAlertGlyph() }
                .overlay(Circle().strokeBorder(Theme.alertOrange, lineWidth: 2.67).padding(-3))
                .padding(.leading, 5)
            Spacer(minLength: 0)
            CircleButton(label: "Menu") { MenuGlyph() }
                .padding(.trailing, 1)
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.top, 8)
        .frame(height: Theme.headerHeight, alignment: .top)
        .background(alignment: .top) {
            // Solid for the first 12 pt (and the status bar above), then fading to clear at the header bottom.
            VStack(spacing: 0) {
                palette.background
                    .frame(height: 12)
                    .background(palette.background.ignoresSafeArea(edges: .top))
                LinearGradient(colors: [palette.background, palette.background.opacity(0)], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
        }
    }
}

struct CircleButton<Glyph: View>: View {
    let label: String
    var size: CGFloat = Theme.headerButton
    @ViewBuilder let glyph: () -> Glyph
    @Environment(\.palette) private var palette

    var body: some View {
        Button {} label: {
            glyph()
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

struct DotsGlyph: View {
    var diameter: CGFloat
    var spacing: CGFloat
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { _ in Circle().frame(width: diameter, height: diameter) }
        }
    }
}

struct MenuGlyph: View {
    var body: some View {
        VStack(spacing: 4.6) {
            ForEach(0..<3, id: \.self) { _ in Capsule().frame(width: 19, height: 2.4) }
        }
    }
}

/// A bell sliced by a warning triangle.
struct BellAlertGlyph: View {
    @Environment(\.palette) private var palette
    var body: some View {
        ZStack {
            Image(systemName: "bell.fill")
                .font(.system(size: 17, weight: .bold))
                .offset(x: -2.5, y: -1.5)
            // The triangle's page-coloured outline cuts the bell, like Campfire's icon.
            Image(systemName: "triangle.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(palette.background)
                .offset(x: 4.5, y: 3.6)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .offset(x: 4.5, y: 4.5)
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Composer

/// Search button and the message field with attach and send (drawn, inert).
struct ComposerView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            CircleButton(label: "Search") {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .bold))
            }
            HStack(spacing: 0) {
                Image(systemName: "message")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 24)
                    .padding(.leading, 13)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .semibold))
                    .accessibilityLabel("Attach")
                    .padding(.trailing, 18)
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.background)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(palette.text))
                    .padding(.trailing, 4)
                    .accessibilityLabel("Send")
            }
            .foregroundStyle(palette.text)
            .frame(height: Theme.headerButton)
            .background(Capsule().fill(palette.background))
            .overlay(Capsule().strokeBorder(palette.borderDarker, lineWidth: 1))
        }
        .padding(.horizontal, Theme.screenPaddingX)
    }
}

// MARK: - Welcome card

/// Campfire's empty-room card, shown above the very first message.
struct WelcomeCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale
    @Environment(\.listWidth) private var listWidth

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Welcome to Campfire")
                    .font(.system(size: scale(16), weight: .bold))
                Text(verbatim: LineBreaker.greedy("To invite people to chat, share the join link below.",
                                                  width: listWidth - 2 * Theme.screenPaddingX - 40, fontSize: scale(16)))
                    .font(.system(size: scale(16)))
                    .cssLineHeight(scale(22.4), fontSize: scale(16))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.text)
            .padding(.horizontal, 20)
            .padding(.top, 78)
            HStack(spacing: 0) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 17))
                    .frame(width: 22)
                    .padding(.leading, 16)
                Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN")
                    .font(.system(size: scale(16)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.leading, 6)
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.text)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.background))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.borderDarker, lineWidth: 1))
            .padding(.horizontal, 15.3)
            .padding(.top, 17.67)
            HStack(spacing: 10.6) {
                CircleButton(label: "QR code", size: 41.6) { Image(systemName: "qrcode.viewfinder").font(.system(size: 19, weight: .semibold)) }
                CircleButton(label: "Copy link", size: 41.6) { Image(systemName: "list.clipboard").font(.system(size: 19, weight: .semibold)) }
                CircleButton(label: "Share", size: 41.6) { Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold)) }
            }
            .padding(.top, 16.7)
            .padding(.trailing, 10)
            .padding(.bottom, 10.7)
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.bubble))
        .overlay(alignment: .topLeading) {
            CircleButton(label: "Room visibility") { Text("🌏").font(.system(size: 14)) }
                .padding(.leading, 16)
                .padding(.top, 16)
        }
        .overlay(alignment: .top) {
            CampfireLogo()
                .frame(width: 69, height: 69)
                .offset(y: -24)
        }
        .padding(.top, 24)
        .padding(.horizontal, Theme.screenPaddingX)
    }
}

/// The Campfire app icon: a purple tile with a bright scribble.
struct CampfireLogo: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(LinearGradient(colors: [Color(rgb: 0x6E1A7A), Color(rgb: 0x2A0A2E)], startPoint: .top, endPoint: .bottom))
            .overlay {
                Canvas { ctx, size in
                    let colors: [Color] = [Color(rgb: 0xFF2D7A), Color(rgb: 0xFF4D4D), Color(rgb: 0xFF7A1A),
                                           Color(rgb: 0xFFB000), Color(rgb: 0xFFFFFF), Color(rgb: 0x3FA9FF)]
                    for i in 0..<9 {
                        let t = CGFloat(i) / 8
                        var p = Path()
                        p.move(to: CGPoint(x: size.width * (0.28 + 0.36 * t), y: size.height * (0.2 + 0.05 * t)))
                        p.addLine(to: CGPoint(x: size.width * (0.22 + 0.4 * t), y: size.height * (0.62 + 0.1 * t)))
                        ctx.stroke(p, with: .color(colors[i % colors.count]), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                }
                .rotationEffect(.degrees(-30))
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Debug bar

/// Benchmark controls, shown with `-uvsBenchmark YES`.
struct DebugBar: View {
    let typeSize: DynamicTypeSize
    @Environment(RoomStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                bar("Reset") { store.debugReset() }
                bar("Jump to 2500") { store.debugJump() }
                bar("Load older") { store.debugLoadOlder() }
                bar("Start stream") { store.startStream() }
            }
            .frame(height: 22)
            HStack(spacing: 6) {
                bar("Text size +") { store.debugTextSizeUp(current: typeSize) }
                bar("Boost burst") { store.boostBurst() }
                if store.streamDone {
                    Text("Stream done")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityIdentifier("streamDone")
                }
            }
            .frame(height: 22)
            Text(store.debugLabel)
                .font(.system(size: 10.5, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 14, alignment: .leading)
                .accessibilityIdentifier("debugState")
        }
        .dynamicTypeSize(.large)
        .foregroundStyle(palette.text)
        .padding(.horizontal, Theme.screenPaddingX)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bar(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .accessibilityIdentifier(title)
    }
}
