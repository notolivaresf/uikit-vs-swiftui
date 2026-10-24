import SwiftUI

/// Campfire's app icon, drawn: bright scribbled strokes on a deep purple tile.
struct CampfireLogo: View {
    var size: CGFloat = 69

    private static let strokes: [(Color, CGFloat, CGFloat)] = [
        (Color(hex: 0xFF2D6F), -0.30, -0.16), (Color(hex: 0xFF3B4E), -0.22, -0.08), (Color(hex: 0xFF6A2B), -0.14, 0.0),
        (Color(hex: 0xFF9A1F), -0.06, 0.06), (Color(hex: 0xFFC83A), 0.02, 0.1), (Color(hex: 0xF5F0FF), 0.1, 0.12),
        (Color(hex: 0x7FB8FF), 0.18, 0.1), (Color(hex: 0x4E7BFF), 0.26, 0.04),
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2)
            .fill(LinearGradient(colors: [Color(hex: 0x7A1C74), Color(hex: 0x3A0A36)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                ZStack {
                    ForEach(Array(Self.strokes.enumerated()), id: \.offset) { _, stroke in
                        Capsule()
                            .fill(stroke.0)
                            .frame(width: size * 0.07, height: size * 0.5)
                            .rotationEffect(.degrees(-35))
                            .offset(x: size * stroke.1, y: size * stroke.2)
                    }
                }
                .offset(x: size * 0.02, y: -size * 0.02)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
