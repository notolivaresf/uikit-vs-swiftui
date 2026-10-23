import SwiftUI

struct RoomHeader: View {
    let name: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = RoomColors(scheme)
        HStack(spacing: 6) {
            Button {} label: {
                Canvas { context, bounds in
                    context.fill(Path(roundedRect: CGRect(origin: .zero, size: bounds), cornerRadius: 8),
                                 with: .color(colors.text))
                    var text = context.resolve(Text(name).font(.system(size: 16, weight: .bold)))
                    text.shading = .color(colors.background)
                    context.draw(text, at: CGPoint(x: bounds.width / 2, y: bounds.height / 2))
                }
                .frame(width: 97, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            InertIcon(symbol: "ellipsis", label: "Room options")
            Button {} label: {
                CampfireGlyph(kind: .notification).frame(width: 24, height: 24)
                    .frame(width: 42, height: 42)
                    .background(colors.background, in: Circle())
                    .overlay(Circle().strokeBorder(colors.strongBorder, lineWidth: 1))
            }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")
                .overlay(Circle().stroke(Color(hex: 0xFF7514), lineWidth: 2.5).padding(-2))
                .padding(.leading, -1)
            Spacer(minLength: 0)
            InertIcon(symbol: "line.3.horizontal", label: "Menu")
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background {
            LinearGradient(stops: [.init(color: colors.background, location: 0.2),
                                   .init(color: colors.background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }

    }
}

struct RoomComposer: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = RoomColors(scheme)
        HStack(spacing: 10.5) {
            InertIcon(symbol: "magnifyingglass", label: "Search")
            HStack(spacing: 18) {
                CampfireGlyph(kind: .bubble).frame(width: 24, height: 24)
                Spacer(minLength: 0)
                Button {} label: { CampfireGlyph(kind: .paperclip) }
                    .accessibilityLabel("Attach file")
                Button {} label: {
                    CampfireGlyph(kind: .arrow)
                        .foregroundStyle(colors.background)
                        .frame(width: 34, height: 34)
                        .background(colors.text, in: Circle())
                }
                .accessibilityLabel("Send message")
            }
            .padding(.leading, 13)
            .padding(.trailing, 4.6)
            .frame(height: 42)
            .overlay(Capsule().strokeBorder(colors.strongBorder, lineWidth: 1))
            .accessibilityLabel("Message composer")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(colors.background)
    }
}

struct WelcomeCard: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = RoomColors(scheme)
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                VStack(spacing: 16) {
                    HStack {
                        Button {} label: {
                            Image(scheme == .dark ? "PublicGlobeDark" : "PublicGlobe").frame(width: 42, height: 42)
                                .background(colors.background, in: Circle())
                                .overlay(Circle().strokeBorder(colors.strongBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain).accessibilityLabel("Public room")
                        Spacer()
                    }
                    VStack(spacing: 0) {
                        Text("Welcome to Campfire").bold().frame(minHeight: 22.4)
                        Text("To invite people to chat, share the join link\nbelow.")
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 1.65)
                    }
                    .font(.system(size: 16))
                    .lineSpacing(3.3)
                    .padding(.top, 4)
                    HStack(spacing: 10) {
                        CampfireGlyph(kind: .person)
                        Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN").lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, minHeight: 39)
                    .background(colors.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.strongBorder, lineWidth: 1))
                    HStack(spacing: 10) {
                        InertIcon(symbol: "qrcode.viewfinder", label: "Join QR code")
                        InertIcon(symbol: "doc.on.clipboard", label: "Copy join link")
                        InertIcon(symbol: "square.and.arrow.up", label: "Share join link")
                    }
                    .offset(x: -5.5)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10.56)
                .background(colors.bubble, in: RoundedRectangle(cornerRadius: 10.56))
                Image("CampfireMark").resizable().frame(width: 69, height: 69)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .accessibilityLabel("Campfire").offset(y: -24)
            }
            .padding(.top, 109)
        }
        .padding(.horizontal, 14.01)
        .padding(.bottom, 1)
        .frame(minHeight: 400, alignment: .top)
    }
}

