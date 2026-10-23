import SwiftUI

struct RoomHeader: View {
    let name: String
    let theme: RoomTheme
    var body: some View {
        HStack(spacing: 6) {
            Button {} label: {
                Text(name).font(.system(size: 16, weight: .bold))
                    .frame(width: 97.3, height: 42)
                    .background(theme.text, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(theme.background)
            }
            .accessibilityLabel(name)
            circle("ellipsis", label: "Room options", size: 22, weight: .heavy)
            Button {} label: {
                ZStack {
                    Image(systemName: "bell.fill").font(.system(size: 20)).offset(x: -2, y: -1)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 17)).offset(x: 5, y: 5)
                }
                .frame(width: 42, height: 42)
                .background(theme.background, in: Circle())
                .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
                .overlay { Circle().stroke(.orange, lineWidth: 2.6).padding(-2) }
            }.accessibilityLabel("Notifications")
            Spacer(minLength: 0)
            Button {} label: {
                MenuLines().stroke(theme.text, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 18.5, height: 13.5)
                    .frame(width: 42, height: 42)
                    .background(theme.background, in: Circle())
                    .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
            }.accessibilityLabel("Menu")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .frame(height: 42)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .foregroundStyle(theme.text)
        .background {
            LinearGradient(stops: [.init(color: theme.background, location: 0),
                                   .init(color: theme.background.opacity(0.98), location: 0.45),
                                   .init(color: theme.background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .contentShape(Rectangle())
    }
    private func circle(_ symbol: String, label: String, size: CGFloat, weight: Font.Weight) -> some View {
        Button {} label: {
            Image(systemName: symbol).font(.system(size: size, weight: weight))
                .frame(width: 42, height: 42)
                .background(theme.background, in: Circle())
                .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
        }
        .accessibilityLabel(label)
    }
}

struct RoomComposer: View {
    let theme: RoomTheme
    var body: some View {
        HStack(spacing: 10) {
            Button {} label: {
                Image(systemName: "magnifyingglass").font(.system(size: 25, weight: .bold))
                    .frame(width: 42, height: 42)
                    .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
            }
            .accessibilityLabel("Search")
            HStack(spacing: 0) {
                Button {} label: { SpeechBubble().stroke(theme.text, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round)).frame(width: 23, height: 21).frame(width: 46, height: 42) }
                    .accessibilityLabel("Message composer")
                Spacer(minLength: 0)
                Button {} label: { Image(systemName: "paperclip").font(.system(size: 23)).frame(width: 42, height: 42) }
                    .accessibilityLabel("Attach file")
                Button {} label: {
                    Image(systemName: "arrow.up").font(.system(size: 19.5, weight: .heavy))
                        .frame(width: 34, height: 34)
                        .background(theme.text, in: Circle())
                        .foregroundStyle(theme.background)
                }
                .accessibilityLabel("Send message")
                .padding(.trailing, 5)
            }
            .overlay { Capsule().strokeBorder(theme.outline, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.text)
        .padding(.horizontal, 14.01)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(theme.background)
    }
}

struct WelcomeCard: View {
    let theme: RoomTheme
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                roundButton("globe.americas.fill", label: "Public room")
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 21)
            Text("Welcome to Campfire").font(.system(size: 16, weight: .bold))
            ViewThatFits(in: .horizontal) {
                Text("To invite people to chat, share the join link below.").fixedSize()
                Text("To invite people to chat, share the join link\nbelow.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 16)).lineSpacing(3.3)
            .multilineTextAlignment(.center)
            .padding(.top, 3)
            HStack(spacing: 9) {
                Image(systemName: "person.badge.plus.fill")
                Text(verbatim: "http://127.0.0.1:3055/join/GwHG-HbZN").lineLimit(1).minimumScaleFactor(0.6)
            }
            .font(.system(size: 16))
            .padding(.horizontal, 12).frame(height: 40)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(theme.outline, lineWidth: 1) }
            .padding(.top, 18)
            HStack(spacing: 10) {
                roundButton("qrcode.viewfinder", label: "Join QR code")
                roundButton("doc.on.clipboard", label: "Copy join link")
                roundButton("square.and.arrow.up", label: "Share join link")
            }
            .offset(x: -5.3)
            .padding(.top, 16).padding(.bottom, 11)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(theme.bubble, in: RoundedRectangle(cornerRadius: 10.56))
        .overlay(alignment: .top) { CampfireMark().frame(width: 69, height: 69).offset(y: -24) }
        .padding(.horizontal, 14.01)
        .padding(.top, 107)
        .padding(.bottom, 23)
        .foregroundStyle(theme.text)
    }
    private func roundButton(_ symbol: String, label: String) -> some View {
        Button {} label: {
            Group {
                if symbol == "globe.americas.fill" {
                    Text("🌎").font(.system(size: 16))
                } else {
                    Image(systemName: symbol).font(.system(size: 20))
                }
            }
                .frame(width: 42, height: 42)
                .background(theme.background, in: Circle())
                .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct CampfireMark: View {
    var body: some View {
        Canvas { context, size in
            let colors: [Color] = [.pink, .red, .orange, .yellow, .cyan, .blue]
            let strokes: [(CGPoint, CGPoint)] = [
                (.init(x: 35, y: 15), .init(x: 51, y: 36)),
                (.init(x: 31, y: 20), .init(x: 53, y: 43)),
                (.init(x: 25, y: 20), .init(x: 51, y: 49)),
                (.init(x: 22, y: 16), .init(x: 49, y: 52)),
                (.init(x: 21, y: 23), .init(x: 45, y: 55)),
                (.init(x: 20, y: 29), .init(x: 41, y: 55)),
                (.init(x: 17, y: 31), .init(x: 38, y: 55)),
                (.init(x: 18, y: 40), .init(x: 32, y: 54)),
                (.init(x: 23, y: 48), .init(x: 29, y: 54))
            ]
            for (start, end) in strokes {
                var path = Path()
                path.move(to: start)
                path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 - 1.5, y: (start.y + end.y) / 2 + 2))
                context.stroke(path.offsetBy(dx: 0.8, dy: 1.5), with: .color(.black.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                context.stroke(path, with: .linearGradient(Gradient(colors: colors),
                    startPoint: CGPoint(x: 25, y: 18), endPoint: CGPoint(x: 45, y: 55)),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        }
        .background(LinearGradient(colors: [Color(hex: 0x6D207C), Color(hex: 0x230D2C)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}

struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        p.move(to: point(0.23, 0.76))
        p.addCurve(to: point(0.08, 0.40), control1: point(0, 0.65), control2: point(0, 0.49))
        p.addCurve(to: point(0.52, 0.06), control1: point(0.08, 0.18), control2: point(0.26, 0.06))
        p.addCurve(to: point(0.96, 0.44), control1: point(0.80, 0.06), control2: point(0.96, 0.23))
        p.addCurve(to: point(0.45, 0.84), control1: point(0.96, 0.72), control2: point(0.73, 0.86))
        p.addLine(to: point(0.15, 1))
        p.closeSubpath()
        return p
    }
}

struct MenuLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for fraction: CGFloat in [0, 0.5, 1] {
            let y = rect.minY + rect.height * fraction
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}
