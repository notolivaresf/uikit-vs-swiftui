import AppKit
import CampfireKit

extension NSColor {
    convenience init(hex: String) {
        let n = UInt32(hex, radix: 16) ?? 0
        self.init(srgbRed: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
    }
    static func adaptive(_ light: String, _ dark: String) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light) }
    }
}
enum Style {
    static let background = NSColor.adaptive("FFFFFF", "000000")
    static let text = NSColor.adaptive("000000", "FFFFFF")
    static let bubble = NSColor.adaptive("F3F2EE", "222222")
    static let border = NSColor.adaptive("E5E4E1", "2E2E2E")
    static let outline = NSColor.adaptive("AFAEAA", "555555")
    static let red = NSColor.adaptive("BE1600", "FF7563")
    static let mention = NSColor(name: nil) { a in a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "FF7563").withAlphaComponent(0.2) : NSColor(hex: "BE1600").withAlphaComponent(0.1) }
    static let palette = ["AF2E1B","CC6324","3B4B59","BFA07A","ED8008","ED3F1C","BF1B1B","736B1E","D07B53","736356","AD1D1D","BF7C2A","C09C6F","698F9C","7C956B","5D618F","3B3633","67695E"]
    static func avatar(_ id: Int) -> NSColor {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in String(id).utf8 { crc ^= UInt32(byte); for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 } }
        return NSColor(hex: palette[Int(~crc) % palette.count])
    }
    static func attributes(size: CGFloat, line: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = text, mono: Bool = false) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle(); p.minimumLineHeight = line; p.maximumLineHeight = line
        return [.font: mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p]
    }
    static func measure(_ text: NSAttributedString, width: CGFloat) -> NSSize {
        guard text.length > 0 else { return .zero }
        let storage = NSTextStorage(attributedString: text)
        let manager = NSLayoutManager(); let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container); storage.addLayoutManager(manager); manager.ensureLayout(for: container)
        let rect = manager.usedRect(for: container)
        return NSSize(width: ceil(rect.width * 100) / 100, height: ceil(rect.height * 100) / 100)
    }
    static func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Style.text) -> NSTextField {
        let v = NSTextField(labelWithString: text); v.font = .systemFont(ofSize: size, weight: weight); v.textColor = color; v.setAccessibilityElement(true); v.setAccessibilityRole(.staticText); return v
    }
    static let time: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "h:mm a"; return f }()
    static let day: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "MMMM d, yyyy"; return f }()
}
class FlippedView: NSView { override var isFlipped: Bool { true } }
func fillRound(_ rect: NSRect, radius: CGFloat, color: NSColor) { color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill() }
func strokeRound(_ rect: NSRect, radius: CGFloat, color: NSColor, width: CGFloat = 1) { color.setStroke(); let p = NSBezierPath(roundedRect: rect.insetBy(dx: width / 2, dy: width / 2), xRadius: radius, yRadius: radius); p.lineWidth = width; p.stroke() }
func drawText(_ text: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Style.text, centered: Bool = false) {
    let p = NSMutableParagraphStyle(); p.alignment = centered ? .center : .left
    (text as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p])
}
func drawSymbol(_ name: String, in rect: NSRect, color: NSColor = Style.text, weight: NSFont.Weight = .regular) {
    guard let original = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: rect.height, weight: weight)) else { return }
    let factor = min(rect.width / original.size.width, rect.height / original.size.height)
    let size = NSSize(width: original.size.width * factor, height: original.size.height * factor)
    let image = NSImage(size: size, flipped: false) { r in
        original.draw(in: r); color.setFill(); r.fill(using: .sourceIn); return true
    }
    image.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
}
