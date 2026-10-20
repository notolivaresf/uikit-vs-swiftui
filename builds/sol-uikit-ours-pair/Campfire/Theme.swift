import UIKit
import CampfireKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    convenience init(rgb: RGB) {
        self.init(red: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: 1)
    }
}

@MainActor
enum Theme {
    static let background = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
    static let text = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    static let bubble = UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? 0x222222 : 0xF3F2EE) }
    static let border = UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? 0x2E2E2E : 0xE5E4E1) }
    static let outline = UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? 0x555555 : 0xAFAEAA) }
    static let mention = UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? 0xFF7563 : 0xBE1600)
            .withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.2 : 0.1)
    }
    static let palette: [UInt32] = [0xAF2E1B,0xCC6324,0x3B4B59,0xBFA07A,0xED8008,0xED3F1C,
        0xBF1B1B,0x736B1E,0xD07B53,0x736356,0xAD1D1D,0xBF7C2A,0xC09C6F,0x698F9C,
        0x7C956B,0x5D618F,0x3B3633,0x67695E]
    static func avatar(_ id: Int) -> UIColor {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 }
        }
        return UIColor(hex: palette[Int(~crc) % palette.count])
    }
    static func font(_ size: CGFloat, weight: UIFont.Weight = .regular, scale: CGFloat = 1) -> UIFont {
        .systemFont(ofSize: size * scale, weight: weight)
    }
    static func symbol(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }
    static func attributed(_ text: String, size: CGFloat, line: CGFloat, scale: CGFloat,
                           weight: UIFont.Weight = .regular, color: UIColor? = nil, mono: Bool = false) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = line * scale
        paragraph.maximumLineHeight = line * scale
        return NSAttributedString(string: text, attributes: [
            .font: mono ? (UIFont(name: "Menlo-Regular", size: size * scale) ?? UIFont.monospacedSystemFont(ofSize: size * scale, weight: weight)) : font(size, weight: weight, scale: scale),
            .foregroundColor: color ?? Theme.text, .paragraphStyle: paragraph
        ])
    }
}

@MainActor
final class AvatarView: UILabel {
    init() {
        super.init(frame: .zero)
        textAlignment = .center
        textColor = .white
        clipsToBounds = true
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func show(id: Int, name: String, size: CGFloat, fontSize: CGFloat) {
        backgroundColor = Theme.avatar(id)
        text = name.first.map(String.init)?.uppercased()
        font = .systemFont(ofSize: fontSize, weight: .semibold)
        layer.cornerRadius = size / 2
    }
}
