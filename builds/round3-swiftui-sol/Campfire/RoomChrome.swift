import SwiftUI

struct RoomHeader: View {
    let title: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        HStack(spacing: 6) {
            Button {} label: {
                Text(title).font(.system(size: 16, weight: .bold))
                    .foregroundStyle(colors.background)
                    .frame(width: 97, height: 42)
                    .background(colors.text, in: RoundedRectangle(cornerRadius: 8))
            }
            ChromeCircle(symbol: "ellipsis", label: "Room options")
            ChromeCircle(symbol: "bell.badge.fill", label: "Notifications")
                .overlay(Circle().stroke(.orange, lineWidth: 2.5).padding(-2))
            Spacer(minLength: 0)
            ChromeCircle(symbol: "line.3.horizontal", label: "Menu")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(colors.background)
    }
}

struct ChromeCircle: View {
    let symbol: String
    let label: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        Button {} label: {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .bold))
                .frame(width: 42, height: 42)
                .background(colors.background, in: Circle())
                .overlay(Circle().stroke(colors.outline, lineWidth: 1))
        }
        .accessibilityLabel(label)
        .buttonStyle(.plain)
    }
}

struct RoomComposer: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        HStack(spacing: 10) {
            ChromeCircle(symbol: "magnifyingglass", label: "Search")
            HStack(spacing: 12) {
                ComposerBubble().stroke(lineWidth: 1.8).frame(width: 22, height: 22)
                Spacer()
                Image(systemName: "paperclip").font(.system(size: 23))
                Image(systemName: "arrow.up").font(.system(size: 23, weight: .bold))
                    .foregroundStyle(colors.background)
                    .frame(width: 34, height: 34)
                    .background(colors.text, in: Circle())
            }
            .padding(.leading, 13)
            .padding(.trailing, 4)
            .frame(height: 41)
            .overlay(Capsule().stroke(colors.outline, lineWidth: 1))
            .accessibilityLabel("Message composer")
        }
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(colors.background)
    }
}

struct WelcomeCard: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        VStack(spacing: 0) {
            HStack {
                ChromeCircle(symbol: "globe.americas.fill", label: "Public room")
                    .foregroundStyle(.green)
                Spacer()
            }
            .padding(.top, 16)
            Spacer().frame(height: 20)
            Text("Welcome to Campfire").font(.system(size: 16, weight: .bold))
            Text("To invite people to chat, share the join link below.")
                .font(.system(size: 16)).multilineTextAlignment(.center).lineSpacing(3)
            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus.fill")
                Text("http://127.0.0.1:3055/join/GwHG-HbZN").lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(.system(size: 16))
            .padding(12)
            .background(colors.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.outline, lineWidth: 1))
            .padding(.top, 18)
            HStack(spacing: 10) {
                ChromeCircle(symbol: "qrcode.viewfinder", label: "Join QR code")
                ChromeCircle(symbol: "doc.on.clipboard", label: "Copy join link")
                ChromeCircle(symbol: "square.and.arrow.up", label: "Share join link")
            }
            .padding(.top, 16)
            .padding(.bottom, 11)
        }
        .padding(.horizontal, 16)
        .background(colors.bubble, in: RoundedRectangle(cornerRadius: 10.56))
        .overlay(alignment: .top) {
            CampfireMark().offset(y: -24)
        }
        .padding(.horizontal, 14)
        .padding(.top, 109)
        .padding(.bottom, 23)
    }
}

struct CampfireMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [Color(hex: 0x711B80), Color(hex: 0x210726)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "flame.fill")
                .font(.system(size: 43))
                .foregroundStyle(LinearGradient(colors: [.pink, .red, .orange, .yellow, .cyan], startPoint: .top, endPoint: .bottom))
        }
        .frame(width: 69, height: 69)
    }
}

private struct ComposerBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 2, y: 18))
        p.addCurve(to: CGPoint(x: 2, y: 6), control1: CGPoint(x: -1, y: 14), control2: CGPoint(x: -1, y: 9))
        p.addCurve(to: CGPoint(x: 20, y: 6), control1: CGPoint(x: 5, y: -1), control2: CGPoint(x: 18, y: 1))
        p.addCurve(to: CGPoint(x: 8, y: 19), control1: CGPoint(x: 25, y: 12), control2: CGPoint(x: 17, y: 19))
        p.addLine(to: CGPoint(x: 1, y: 22))
        p.addLine(to: CGPoint(x: 2, y: 18))
        return p
    }
}
