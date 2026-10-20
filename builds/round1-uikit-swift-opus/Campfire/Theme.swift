import UIKit
import CampfireKit

// Colours, fonts and sizes measured from ONCE Campfire (see Fixtures/constants.json). 1 CSS px = 1 pt.

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    convenience init(_ rgb: RGB) {
        self.init(red: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: 1)
    }

    static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

enum Colors {
    static let background = UIColor.dynamic(.white, .black)
    static let text = UIColor.dynamic(.black, .white)
    static let dimText = UIColor.dynamic(UIColor(white: 0, alpha: 0.5), UIColor(white: 1, alpha: 0.5))
    static let bubble = UIColor.dynamic(UIColor(hex: 0xF3F2EE), UIColor(hex: 0x222222))
    static let borderDark = UIColor.dynamic(UIColor(hex: 0xE5E4E1), UIColor(hex: 0x2E2E2E))
    static let borderDarker = UIColor.dynamic(UIColor(hex: 0xAFAEAA), UIColor(hex: 0x555555))
    /// Campfire red (#BE1600 / #FF7563) at 10% light, 20% dark, over the page background.
    static let mentionBubble = UIColor.dynamic(
        UIColor(red: (0.1 * 190 + 0.9 * 255) / 255, green: (0.1 * 22 + 0.9 * 255) / 255, blue: (0.9 * 255) / 255, alpha: 1),
        UIColor(red: 0.2 * 255 / 255, green: 0.2 * 117 / 255, blue: 0.2 * 99 / 255, alpha: 1))
    static let orange = UIColor(hex: 0xFF6A0D)
    static let codeBox = UIColor.dynamic(.white, .black)
    static let codeKeyword = UIColor.dynamic(UIColor(hex: 0xD73A49), UIColor(hex: 0xFF7B72))
    static let codeEntity = UIColor.dynamic(UIColor(hex: 0x6F42C1), UIColor(hex: 0xD2A8FF))
    static let codeConstant = UIColor.dynamic(UIColor(hex: 0x005CC5), UIColor(hex: 0x79C0FF))
    static let codeString = UIColor.dynamic(UIColor(hex: 0x032F62), UIColor(hex: 0x79C0FF))
    static let codeComment = UIColor.dynamic(UIColor(hex: 0x6A737D), UIColor(hex: 0x8B949E))

    static let avatarPalette: [UIColor] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { UIColor(hex: $0) }

    /// Campfire: AVATAR_COLORS[Zlib.crc32(user.to_param) % 18].
    static func avatar(_ id: UserID) -> UIColor {
        avatarPalette[Int(CRC32.checksum(Array(String(id).utf8)) % UInt32(avatarPalette.count))]
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in bytes { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return ~c
    }
}

/// Fixed geometry (does not follow Dynamic Type).
enum K {
    static let screenPadX: CGFloat = 14.01
    static let avatar: CGFloat = 35.27
    static let avatarRing: CGFloat = 2.33
    static let bubbleX: CGFloat = 40.8
    static let mineMinX: CGFloat = 64.23
    static let bubblePadX: CGFloat = 15.12
    static let bubblePadTop: CGFloat = 10.56
    static let bubbleRadius: CGFloat = 10.56
    static let bubbleTopInRow: CGFloat = 1.59
    static let bubbleBottomMargin: CGFloat = 1.6
    static let rowGap: CGFloat = 21.28
    static let threadedGap: CGFloat = 21.28 - 22.48
    static let dotsGap: CGFloat = 13
    static let dotsWidth: CGFloat = 17
    static let dotsTrailing: CGFloat = 27
    static let dayMarginY: CGFloat = 17.02
    static let dayPadX: CGFloat = 23.5
    static let dayPadY: CGFloat = 8.5
    static let dayLine: CGFloat = 2
    static let imageMaxWidth: CGFloat = 300
    static let imageInset: CGFloat = 1
    static let codeRadius: CGFloat = 6.4
    static let codePad: CGFloat = 12.8
    static let codeInsetX: CGFloat = 0.9
    static let blockGap: CGFloat = 6.4
    static let boostHeight: CGFloat = 28.64
    static let boostAvatar: CGFloat = 23.67
    static let boostGapX: CGFloat = 5
    static let boostGapY: CGFloat = 4
    static let headerHeight: CGFloat = 58
    static let composerHeight: CGFloat = 42
    static let composerGapAbove: CGFloat = 23.7
}

/// Text sizes follow Dynamic Type: everything typographic is scaled by `s` (1 at the default Large size).
struct Metrics {
    let category: UIContentSizeCategory
    let s: CGFloat
    let body: UIFont
    let mention: UIFont
    let meta: UIFont
    let metaBold: UIFont
    let code: UIFont
    let emoji: UIFont
    let day: UIFont
    let boostEmoji: UIFont
    let boostText: UIFont
    let bodyLine: CGFloat
    let metaLine: CGFloat
    let codeLine: CGFloat
    let emojiLine: CGFloat
    let dayLine: CGFloat

    init(category: UIContentSizeCategory) {
        self.category = category
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let s = UIFontMetrics(forTextStyle: .body).scaledValue(for: 16, compatibleWith: traits) / 16
        self.s = s
        body = .systemFont(ofSize: 16 * s)
        mention = .systemFont(ofSize: 16 * s, weight: .semibold)
        meta = .systemFont(ofSize: 12.8 * s)
        metaBold = .systemFont(ofSize: 12.8 * s, weight: .bold)
        code = .monospacedSystemFont(ofSize: 12.8 * s, weight: .regular)
        emoji = .systemFont(ofSize: 38.4 * s)
        day = .systemFont(ofSize: 12.8 * s, weight: .semibold)
        boostEmoji = .systemFont(ofSize: 17.6 * s)
        boostText = .systemFont(ofSize: 12.8 * s)
        bodyLine = 22.4 * s
        metaLine = 19.2 * s
        codeLine = 17.92 * s
        emojiLine = 53.76 * s
        dayLine = 17.92 * s
    }

    /// Baseline of a CSS line box: half-leading above the font's ascent.
    static func cssBaseline(_ f: UIFont, _ lineHeight: CGFloat) -> CGFloat {
        (lineHeight - (f.ascender - f.descender)) / 2 + f.ascender
    }

    var headerTop: CGFloat { K.bubblePadTop + 1.6 }
    var headerBaseline: CGFloat { headerTop + Metrics.cssBaseline(meta, metaLine) }
    var contentTop: CGFloat { headerTop + metaLine + 1.36 }
    var imageTop: CGFloat { headerTop + metaLine + 12.64 }
    var dayPillHeight: CGFloat { K.dayPadY * 2 + dayLine }
    var dayBlockHeight: CGFloat { K.dayMarginY * 2 + dayPillHeight }
    var boostHeight: CGFloat { max(K.boostHeight, K.boostHeight - 17.6 + 22 * s) }
    var boostAvatar: CGFloat { K.boostAvatar }
    var fileLineHeight: CGFloat { max(34, 22.4 * s + 11.6) }
}

enum Formatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "h:mm a"
        return f
    }()

    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    static func fileSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// A view whose layer border follows a dynamic colour across light and dark mode.
class BorderedView: UIView {
    var borderColor: UIColor = Colors.borderDarker { didSet { applyBorder() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: BorderedView, _) in self.applyBorder() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyBorder() {
        layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor
    }
}

extension NSAttributedString {
    var isEmojiText: Bool {
        string.unicodeScalars.first?.properties.isEmojiPresentation ?? false
    }
}

func singleLineWidth(_ s: String, _ font: UIFont) -> CGFloat {
    ceil((s as NSString).size(withAttributes: [.font: font]).width)
}
