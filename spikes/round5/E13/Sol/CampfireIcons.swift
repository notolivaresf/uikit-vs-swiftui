import UIKit

/// Small vector glyphs use Campfire's rounded silhouettes instead of SF Symbols' differing bounds.
enum CampfireIcons {
    static func image(_ name: String, size: CGFloat) -> UIImage? {
        let supported = ["magnifyingglass", "bubble", "arrow.up", "line.3.horizontal", "ellipsis", "bell.badge.fill", "face.smiling", "paperclip"]
        guard supported.contains(name) else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
            let c = context.cgContext
            c.scaleBy(x: size/24, y: size/24)
            UIColor.black.setStroke(); UIColor.black.setFill()
            func stroke(_ points: [CGPoint], width: CGFloat = 2.7) {
                let p = UIBezierPath(); p.lineWidth = width; p.lineCapStyle = .round; p.lineJoinStyle = .round
                if let first = points.first { p.move(to: first) }
                for point in points.dropFirst() { p.addLine(to: point) }; p.stroke()
            }
            switch name {
            case "magnifyingglass":
                let p = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 15, height: 15)); p.lineWidth = 3; p.stroke()
                stroke([CGPoint(x: 15.5,y: 15.5),CGPoint(x: 21.5,y: 21.5)], width: 3.5)
            case "bubble":
                let p = UIBezierPath(); p.lineWidth = 2; p.lineJoinStyle = .round
                p.move(to: CGPoint(x: 12,y: 2)); p.addCurve(to: CGPoint(x: 22,y: 10.4), controlPoint1: CGPoint(x: 18,y: 2), controlPoint2: CGPoint(x: 22,y: 5.4))
                p.addCurve(to: CGPoint(x: 10,y: 19), controlPoint1: CGPoint(x: 22,y: 16), controlPoint2: CGPoint(x: 16,y: 20))
                p.addLine(to: CGPoint(x: 3,y: 23)); p.addLine(to: CGPoint(x: 4.5,y: 16))
                p.addCurve(to: CGPoint(x: 12,y: 2), controlPoint1: CGPoint(x: -3,y: 9), controlPoint2: CGPoint(x: 4,y: 2)); p.close(); p.stroke()
            case "arrow.up":
                stroke([CGPoint(x: 12,y: 20),CGPoint(x: 12,y: 5)], width: 3.5)
                stroke([CGPoint(x: 6,y: 11),CGPoint(x: 12,y: 5),CGPoint(x: 18,y: 11)], width: 3.5)
            case "line.3.horizontal":
                for y in [CGFloat(5),12,19] { stroke([CGPoint(x: 3,y: y),CGPoint(x: 21,y: y)], width: 2.8) }
            case "ellipsis":
                for x in [CGFloat(4.5),12,19.5] { UIBezierPath(ovalIn: CGRect(x: x-2.6,y: 9.4,width: 5.2,height: 5.2)).fill() }
            case "bell.badge.fill":
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 2,y: 18)); p.addCurve(to: CGPoint(x: 5,y: 9), controlPoint1: CGPoint(x: 5,y: 17), controlPoint2: CGPoint(x: 4,y: 13))
                p.addCurve(to: CGPoint(x: 17,y: 7), controlPoint1: CGPoint(x: 6,y: 2), controlPoint2: CGPoint(x: 14,y: 2)); p.addLine(to: CGPoint(x: 15,y: 19)); p.addLine(to: CGPoint(x: 2,y: 19)); p.close(); p.fill()
                stroke([CGPoint(x: 10,y: 1.5),CGPoint(x: 10,y: 4)], width: 1.7)
                let triangle = UIBezierPath(); triangle.lineJoinStyle = .round; triangle.lineWidth = 3
                triangle.move(to: CGPoint(x: 16,y: 8)); triangle.addLine(to: CGPoint(x: 23,y: 21)); triangle.addLine(to: CGPoint(x: 9,y: 21)); triangle.close()
                c.setBlendMode(.clear); triangle.stroke()
                c.setBlendMode(.normal); triangle.fill()
                c.setBlendMode(.clear)
                stroke([CGPoint(x: 16,y: 12),CGPoint(x: 16,y: 16)], width: 1.7)
                UIBezierPath(ovalIn: CGRect(x: 15.2,y: 18,width: 1.6,height: 1.6)).fill()
                c.setBlendMode(.normal)
            case "paperclip":
                c.translateBy(x: 12, y: 12); c.rotate(by: .pi/4); c.translateBy(x: -12, y: -12)
                let p = UIBezierPath(); p.lineWidth = 2.2; p.lineCapStyle = .round; p.lineJoinStyle = .round
                p.move(to: CGPoint(x: 9,y: 16)); p.addLine(to: CGPoint(x: 9,y: 7))
                p.addCurve(to: CGPoint(x: 15,y: 7), controlPoint1: CGPoint(x: 9,y: 3), controlPoint2: CGPoint(x: 15,y: 3))
                p.addLine(to: CGPoint(x: 15,y: 18))
                p.addCurve(to: CGPoint(x: 5,y: 18), controlPoint1: CGPoint(x: 15,y: 25), controlPoint2: CGPoint(x: 5,y: 25))
                p.addLine(to: CGPoint(x: 5,y: 8))
                p.addCurve(to: CGPoint(x: 19,y: 8), controlPoint1: CGPoint(x: 5,y: -1), controlPoint2: CGPoint(x: 19,y: -1))
                p.addLine(to: CGPoint(x: 19,y: 16)); p.stroke()
            case "face.smiling":
                let p = UIBezierPath(ovalIn: CGRect(x: 2,y: 2,width: 18,height: 18)); p.lineWidth = 1.8; p.stroke()
                for x in [CGFloat(7),14] { UIBezierPath(ovalIn: CGRect(x: x,y: 7,width: 2.4,height: 2.4)).fill() }
                let smile = UIBezierPath(); smile.move(to: CGPoint(x: 6,y: 13)); smile.addQuadCurve(to: CGPoint(x: 15,y: 14), controlPoint: CGPoint(x: 10,y: 19)); smile.lineWidth = 1.8; smile.stroke()
                stroke([CGPoint(x: 19,y: 15),CGPoint(x: 19,y: 23)],width: 1.8)
                stroke([CGPoint(x: 15,y: 19),CGPoint(x: 23,y: 19)],width: 1.8)
            default: break
            }
        }.withRenderingMode(.alwaysTemplate)
    }
}
