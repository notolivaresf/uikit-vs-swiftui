import SwiftUI

/// Room name, options, notifications and the menu, over a fade so messages scroll softly beneath it.
struct RoomHeader: View {
    let roomName: String

    var body: some View {
        HStack(spacing: 6) {
            Button {} label: {
                Text(verbatim: roomName)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Palette.background)
                    .padding(.horizontal, 18)
                    .frame(minWidth: 97, minHeight: Metrics.headerButton)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.ink))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Room \(roomName)")

            CircleButton(systemImage: "ellipsis", label: "Room options", iconSize: 18, weight: .black)

            CircleButton(systemImage: "bell.slash.fill", label: "Notifications", iconSize: 17)
                .padding(4)
                .overlay(Circle().strokeBorder(Palette.bellRing, lineWidth: 3))
                .padding(.leading, -2)

            Spacer(minLength: 0)

            CircleButton(systemImage: "line.3.horizontal", label: "Menu", iconSize: 20)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .frame(height: Metrics.headerBarHeight, alignment: .top)
        .background {
            // Opaque under the status bar and the top of the header, then Campfire's fade to the messages.
            VStack(spacing: 0) {
                Palette.background
                LinearGradient(colors: [Palette.background, Palette.background.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 46)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
