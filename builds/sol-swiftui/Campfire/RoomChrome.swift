import SwiftUI

struct RoomHeader: View {
    let name: String
    @Environment(\.colorScheme) private var scheme
    private var theme: RoomTheme { RoomTheme(scheme: scheme) }
    var body: some View {
        HStack(spacing: 6.4) {
            Button { } label: {
                Text(name).font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.background)
                    .frame(width: 97.2, height: 42)
                    .background(theme.text, in: RoundedRectangle(cornerRadius: 8))
            }
            ringButton("ellipsis", label: "Room options")
            ringButton("bell.badge.fill", label: "Notifications")
                .overlay { Circle().strokeBorder(Color(hex: 0xFF7512), lineWidth: 2.7).padding(-2.7) }
            Spacer(minLength: 0)
            ringButton("line.3.horizontal", label: "Menu")
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.text)
        .padding(.leading, 10)
        .padding(.trailing, 10.99)
        .padding(.vertical, 8)
        .frame(height: 58)
        .background {
            LinearGradient(stops: [.init(color: theme.background, location: 0.15),
                                   .init(color: theme.background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room-header")
    }
    private func ringButton(_ icon: String, label: String) -> some View {
        Button { } label: {
            Image(systemName: icon == "bell.badge.fill" ? "bell.fill" : icon)
                .font(.system(size: icon == "line.3.horizontal" ? 25 : 22, weight: .bold))
                .overlay(alignment: .bottomTrailing) {
                    if icon == "bell.badge.fill" {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 17))
                            .background(theme.background, in: Circle())
                            .offset(x: 4, y: 3)
                    }
                }
                .frame(width: 42, height: 42)
                .background(theme.background, in: Circle())
                .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
        }.accessibilityLabel(label)
    }
}

struct RoomComposer: View {
    @Environment(\.colorScheme) private var scheme
    private var theme: RoomTheme { RoomTheme(scheme: scheme) }
    var body: some View {
        HStack(spacing: 10) {
            Button { } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 25, weight: .bold))
                    .frame(width: 42, height: 42)
                    .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
            }.accessibilityLabel("Search")
            HStack(spacing: 14) {
                Image(systemName: "bubble.left").font(.system(size: 24))
                    .accessibilityLabel("Message composer")
                Spacer(minLength: 0)
                Button { } label: { Image(systemName: "paperclip").font(.system(size: 23)) }
                    .accessibilityLabel("Attach file")
                Button { } label: {
                    Image(systemName: "arrow.up").font(.system(size: 23, weight: .bold))
                        .foregroundStyle(theme.background)
                        .frame(width: 34, height: 34).background(theme.text, in: Circle())
                }.accessibilityLabel("Send")
            }
            .padding(.leading, 14).padding(.trailing, 5)
            .frame(height: 42)
            .overlay { Capsule().strokeBorder(theme.outline, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.text)
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(theme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composer")
    }
}

struct WelcomeCard: View {
    @Environment(\.colorScheme) private var scheme
    private var theme: RoomTheme { RoomTheme(scheme: scheme) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                circle("globe.americas.fill")
                Spacer()
            }.padding(.bottom, 21)
            Text("Welcome to Campfire").fontWeight(.bold).frame(height: 22.4, alignment: .top)
            Text("To invite people to chat, share the join link below.")
                .multilineTextAlignment(.center).lineSpacing(3.3)
                .padding(.bottom, 3.3)
                .padding(.bottom, 14.1)
            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus.fill")
                Text("http://127.0.0.1:3055/join/GwHG-HbZN").lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(theme.outline, lineWidth: 1) }
            HStack(spacing: 10) {
                circle("qrcode.viewfinder")
                circle("document.on.clipboard")
                circle("square.and.arrow.up")
            }.padding(.top, 16)
        }
        .font(.system(size: 16))
        .padding(.horizontal, 15.6)
        .padding(.top, 16)
        .padding(.bottom, 10.5)
        .background(theme.bubble, in: RoundedRectangle(cornerRadius: 10.56))
        .overlay(alignment: .top) {
            CampfireMark().frame(width: 69.12, height: 69.12).offset(y: -24)
        }
        .padding(.top, 109)
        .padding(.bottom, 22.9)
    }
    private func circle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 21, weight: .semibold))
            .frame(width: 42, height: 42)
            .background(theme.background, in: Circle())
            .overlay { Circle().strokeBorder(theme.outline, lineWidth: 1) }
    }
}

/// A small SwiftUI drawing keeps the welcome mark crisp at every display scale.
struct CampfireMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [Color(hex: 0x751681), Color(hex: 0x220A2A)], startPoint: .top, endPoint: .bottom))
            Canvas { context, size in
                let colors: [Color] = [.pink, .red, .orange, .yellow, .cyan]
                for i in 0..<13 {
                    var path = Path()
                    let x = size.width * (0.3 + Double(i) * 0.028)
                    let y = size.height * (0.25 + Double(i % 3) * 0.025)
                    path.move(to: CGPoint(x: x, y: y))
                    path.addCurve(to: CGPoint(x: x + 9, y: size.height * 0.76),
                                  control1: CGPoint(x: x + 40, y: y + 48),
                                  control2: CGPoint(x: x - 15, y: y + 20))
                    context.stroke(path, with: .color(colors[min(4, i / 3)]), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
    }
}
