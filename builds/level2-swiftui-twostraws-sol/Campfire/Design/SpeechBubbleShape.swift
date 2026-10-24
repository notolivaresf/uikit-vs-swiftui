import SwiftUI

struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.2, y: h * 0.73))
        path.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.31),
                      control1: CGPoint(x: -w * 0.06, y: h * 0.59), control2: CGPoint(x: -w * 0.03, y: h * 0.39))
        path.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.42),
                      control1: CGPoint(x: w * 0.27, y: -h * 0.02), control2: CGPoint(x: w, y: h * 0.07))
        path.addCurve(to: CGPoint(x: w * 0.32, y: h * 0.79),
                      control1: CGPoint(x: w * 0.96, y: h * 0.73), control2: CGPoint(x: w * 0.55, y: h * 0.87))
        path.addLine(to: CGPoint(x: w * 0.11, y: h * 0.96))
        path.closeSubpath()
        return path
    }
}
