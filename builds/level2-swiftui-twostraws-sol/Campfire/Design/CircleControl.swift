import SwiftUI

struct CircleControl: View {
    @Environment(\.colorScheme) private var scheme
    let title: LocalizedStringKey
    let symbol: String
    var size: Double = 42
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .font(.system(size: size * (size < 32 ? 0.6 : 0.47), weight: .semibold))
                .frame(width: size, height: size)
                .background(CampfireStyle.background(scheme), in: .circle)
                .overlay(Circle().strokeBorder(CampfireStyle.border(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
