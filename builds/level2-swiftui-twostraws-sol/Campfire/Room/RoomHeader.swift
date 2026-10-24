import SwiftUI

struct RoomHeader: View {
    @Environment(\.colorScheme) private var scheme
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {}) {
                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CampfireStyle.background(scheme))
                    .frame(width: 97, height: 42)
                    .background(.primary, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            CircleControl(title: "Room options", symbol: "ellipsis")
            NotificationControl()
            Spacer(minLength: 4)
            CircleControl(title: "Menu", symbol: "line.3.horizontal")
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(CampfireStyle.background(scheme))
        .accessibilityElement(children: .contain)
    }
}
