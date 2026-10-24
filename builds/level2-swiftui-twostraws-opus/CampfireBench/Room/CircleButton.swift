import SwiftUI

/// Campfire's round, outlined icon button. Drawn only: the action does nothing.
struct CircleButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = Metrics.headerButton
    var iconSize: CGFloat = 19
    var weight: Font.Weight = .bold

    var body: some View {
        Button {} label: {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: weight))
                .foregroundStyle(Palette.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(Palette.background))
                .overlay(Circle().strokeBorder(Palette.borderDarker, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
