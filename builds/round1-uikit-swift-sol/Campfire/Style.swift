import UIKit
import CampfireKit

enum Style {
    static func color(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
    static let background = color(0xFFFFFF, 0x000000)
    static let text = color(0x000000, 0xFFFFFF)
    static let bubble = color(0xF3F2EE, 0x222222)
    static let border = color(0xE5E4E1, 0x2E2E2E)
    static let outline = color(0xAFAEAA, 0x555555)
    static let red = color(0xBE1600, 0xFF7563)
    static let mention = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: 0xFF7563).withAlphaComponent(0.2)
            : UIColor(hex: 0xBE1600).withAlphaComponent(0.1)
    }
    static let palette: [UInt32] = [0xAF2E1B,0xCC6324,0x3B4B59,0xBFA07A,0xED8008,0xED3F1C,0xBF1B1B,0x736B1E,0xD07B53,0x736356,0xAD1D1D,0xBF7C2A,0xC09C6F,0x698F9C,0x7C956B,0x5D618F,0x3B3633,0x67695E]

    // Campfire uses CRC32 of the user's decimal id, modulo its 18-color palette.
    static func avatarColor(_ id: UserID) -> UIColor {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 }
        }
        return UIColor(hex: palette[Int(~crc) % palette.count])
    }

    static func font(_ size: CGFloat, weight: UIFont.Weight = .regular, category: UIContentSizeCategory) -> UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: weight), compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
    }

    static func scale(_ category: UIContentSizeCategory) -> CGFloat { font(16, category: category).pointSize / 16 }

    static let categories: [UIContentSizeCategory] = [.extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge, .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge]
    static let time: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "h:mm a"; return f
    }()
    static let day: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "MMMM d, yyyy"; return f
    }()
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
    }
    convenience init(rgb: RGB) { self.init(red: CGFloat(rgb.r)/255, green: CGFloat(rgb.g)/255, blue: CGFloat(rgb.b)/255, alpha: 1) }
}

struct DisplayBoost: Equatable {
    let id: Int
    let userID: UserID
    let content: String
    init(_ boost: Boost) { id = boost.id; userID = boost.boosterID; content = boost.content }
    init(id: Int, userID: UserID, content: String) { self.id = id; self.userID = userID; self.content = content }
}

final class AvatarView: UIView {
    private let initial = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(initial); initial.textAlignment = .center; initial.textColor = .white
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func configure(user: User?, id: Int, size: CGFloat, bordered: Bool = false) {
        backgroundColor = Style.avatarColor(id)
        initial.text = user.map { String($0.name.prefix(1)).uppercased() } ?? "?"
        initial.font = .systemFont(ofSize: size * 0.46, weight: .bold)
        layer.borderWidth = 0
        layer.shadowOpacity = bordered ? 1 : 0
        layer.shadowRadius = 0; layer.shadowOffset = .zero
        layer.shadowColor = Style.background.resolvedColor(with: traitCollection).cgColor
    }
    override func layoutSubviews() {
        super.layoutSubviews(); layer.cornerRadius = bounds.width/2; initial.frame = bounds
        layer.shadowPath = UIBezierPath(ovalIn: bounds.insetBy(dx: -2, dy: -2)).cgPath
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        layer.shadowColor = Style.background.resolvedColor(with: traitCollection).cgColor
    }
}
