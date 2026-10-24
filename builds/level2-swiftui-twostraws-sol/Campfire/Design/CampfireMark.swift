import SwiftUI

struct CampfireMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 69
            context.scaleBy(x: scale, y: scale)
            for index in 0..<15 {
                let t = Double(index) / 14
                let x = 18 + t * 25
                let top = 16 + abs(t - 0.42) * 27
                let bottom = 55 - abs(t - 0.45) * 17
                var path = Path()
                path.move(to: CGPoint(x: x, y: top))
                path.addCurve(to: CGPoint(x: x + 5, y: bottom),
                              control1: CGPoint(x: x + 23, y: top + 28),
                              control2: CGPoint(x: x - 8, y: bottom - 10))
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [CampfireStyle.color(0xFF007E), .red, .orange, .yellow,
                                      CampfireStyle.color(t > 0.55 ? 0x79DCFF : 0xFFD326)]),
                    startPoint: CGPoint(x: 22, y: 19), endPoint: CGPoint(x: 44, y: 53)),
                               style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(.linearGradient(colors: [CampfireStyle.color(0x701F7E), CampfireStyle.color(0x210728)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}
