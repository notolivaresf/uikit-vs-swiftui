import UIKit
import CampfireKit

enum Style {
    static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) }
    }
    static let background = adaptive(0xFFFFFF, 0x000000)
    static let text = adaptive(0x000000, 0xFFFFFF)
    static let bubble = adaptive(0xF3F2EE, 0x222222)
    static let border = adaptive(0xE5E4E1, 0x2E2E2E)
    static let outline = adaptive(0xAFAEAA, 0x555555)
    static let red = adaptive(0xBE1600, 0xFF7563)
    static let mention = UIColor { traits in
        traits.userInterfaceStyle == .dark ? color(0xFF7563).withAlphaComponent(0.2) : color(0xBE1600).withAlphaComponent(0.1)
    }
    static let palette: [UInt32] = [0xAF2E1B,0xCC6324,0x3B4B59,0xBFA07A,0xED8008,0xED3F1C,0xBF1B1B,0x736B1E,0xD07B53,0x736356,0xAD1D1D,0xBF7C2A,0xC09C6F,0x698F9C,0x7C956B,0x5D618F,0x3B3633,0x67695E]
    static func avatar(_ id: Int) -> UIColor {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xEDB8_8320 : 0) }
        }
        return color(palette[Int(~crc) % palette.count])
    }
    static func rgb(_ rgb: RGB) -> UIColor { UIColor(red: CGFloat(rgb.r)/255, green: CGFloat(rgb.g)/255, blue: CGFloat(rgb.b)/255, alpha: 1) }
    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular, scale: CGFloat = 1) -> UIFont { .systemFont(ofSize: size * scale, weight: weight) }
    static func paragraph(_ lineHeight: CGFloat, scale: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight * scale
        p.maximumLineHeight = lineHeight * scale
        return p
    }
    static func button(_ symbol: String, size: CGFloat = 22) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(CampfireIcons.image(symbol, size: size) ?? UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)), for: .normal)
        b.tintColor = text
        b.backgroundColor = background
        b.layer.borderWidth = 1
        b.layer.cornerRadius = 21
        return b
    }
}

final class AvatarView: UIView {
    private var initial = "?"
    private var fill = UIColor.clear
    private var initialFont = Style.font(16, .bold)
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.shadowOffset = .zero
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError() }
    func show(id: Int, name: String, small: Bool = false) {
        initial = String(name.prefix(1)).uppercased()
        fill = Style.avatar(id)
        initialFont = Style.font(small ? 12.8 : 16, .bold)
        layer.shadowColor = Style.background.resolvedColor(with: traitCollection).cgColor
        setNeedsDisplay()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(ovalIn: bounds.insetBy(dx: -2.5, dy: -2.5)).cgPath
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        fill.setFill(); UIBezierPath(ovalIn: bounds).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: initialFont, .foregroundColor: UIColor.white]
        let text = initial as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: bounds.midX-size.width/2, y: bounds.midY-size.height/2), withAttributes: attributes)
    }
}
