import SwiftUI

/// Campfire's compact file controls have different proportions from SF Symbols.
struct FileGlyph: View {
    enum Kind { case document, download, share }
    let kind: Kind
    let ink: Color
    let cutout: Color
    var body: some View {
        Canvas { context, _ in
            switch kind {
            case .document:
                var page = Path()
                page.move(to: CGPoint(x: 4, y: 0))
                page.addLine(to: CGPoint(x: 13, y: 0))
                page.addLine(to: CGPoint(x: 20, y: 7))
                page.addLine(to: CGPoint(x: 20, y: 20))
                page.addQuadCurve(to: CGPoint(x: 18, y: 22), control: CGPoint(x: 20, y: 22))
                page.addLine(to: CGPoint(x: 4, y: 22))
                page.addQuadCurve(to: CGPoint(x: 2, y: 20), control: CGPoint(x: 2, y: 22))
                page.addLine(to: CGPoint(x: 2, y: 2))
                page.addQuadCurve(to: CGPoint(x: 4, y: 0), control: CGPoint(x: 2, y: 0))
                context.fill(page, with: .color(ink))
                for (y, end) in [(9.5, 13.8), (13.2, 13.8), (16.9, 10.1)] {
                    var line = Path()
                    line.move(to: CGPoint(x: 5.6, y: y)); line.addLine(to: CGPoint(x: end, y: y))
                    context.stroke(line, with: .color(cutout), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            case .download:
                context.fill(Path(roundedRect: CGRect(x: 13.1, y: 2.67, width: 2.6, height: 10.2), cornerRadius: 1.3), with: .color(ink))
                var arrow = Path()
                arrow.move(to: CGPoint(x: 9.2, y: 10.5))
                arrow.addLine(to: CGPoint(x: 14.4, y: 15.7))
                arrow.addLine(to: CGPoint(x: 19.6, y: 10.5))
                arrow.closeSubpath()
                context.fill(arrow, with: .color(ink))
                var tray = Path()
                tray.move(to: CGPoint(x: 7.4, y: 14.3))
                tray.addLine(to: CGPoint(x: 7.4, y: 18.33))
                tray.addLine(to: CGPoint(x: 21.4, y: 18.33))
                tray.addLine(to: CGPoint(x: 21.4, y: 14.3))
                context.stroke(tray, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            case .share:
                var stem = Path()
                stem.move(to: CGPoint(x: 13.4, y: 3.57)); stem.addLine(to: CGPoint(x: 13.4, y: 12.2))
                stem.move(to: CGPoint(x: 10.2, y: 6.77)); stem.addLine(to: CGPoint(x: 13.4, y: 3.57))
                stem.addLine(to: CGPoint(x: 16.6, y: 6.77))
                context.stroke(stem, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                var box = Path()
                box.move(to: CGPoint(x: 10.8, y: 7.8)); box.addLine(to: CGPoint(x: 9.4, y: 7.8))
                box.addQuadCurve(to: CGPoint(x: 8.64, y: 8.6), control: CGPoint(x: 8.64, y: 7.8))
                box.addLine(to: CGPoint(x: 8.64, y: 17.63))
                box.addQuadCurve(to: CGPoint(x: 9.44, y: 18.43), control: CGPoint(x: 8.64, y: 18.43))
                box.addLine(to: CGPoint(x: 17.38, y: 18.43))
                box.addQuadCurve(to: CGPoint(x: 18.18, y: 17.63), control: CGPoint(x: 18.18, y: 18.43))
                box.addLine(to: CGPoint(x: 18.18, y: 8.6))
                box.addQuadCurve(to: CGPoint(x: 17.38, y: 7.8), control: CGPoint(x: 18.18, y: 7.8))
                box.addLine(to: CGPoint(x: 16, y: 7.8))
                context.stroke(box, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: kind == .document ? 20 : (kind == .download ? 32 : 30.2), height: 22)
        .accessibilityHidden(true)
    }
}
