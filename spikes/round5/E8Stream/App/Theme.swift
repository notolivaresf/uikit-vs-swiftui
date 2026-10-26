import UIKit

/// Colours and fixed sizes from Fixtures/constants.json (CSS px = pt).
enum Theme {
    static func hex(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        let l = hex(light), d = hex(dark)
        return UIColor { $0.userInterfaceStyle == .dark ? d : l }
    }

    static let background = dynamic(0xFFFFFF, 0x000000)
    static let text = dynamic(0x000000, 0xFFFFFF)
    static let dimText = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.5) : UIColor(white: 0, alpha: 0.5) }
    static let bubble = dynamic(0xF3F2EE, 0x222222)
    static let borderDark = dynamic(0xE5E4E1, 0x2E2E2E)
    static let borderDarker = dynamic(0xAFAEAA, 0x555555)
    /// Campfire red at 10% (light) / 20% (dark), composited over the page background.
    static let mentionBubble = dynamic(0xF9E8E6, 0x331714)
    static let pillBackground = dynamic(0xFFFFFF, 0x000000)
    static let codeBox = dynamic(0xFFFFFF, 0x000000)
    static let codeKeyword = dynamic(0xD73A49, 0xFF7B72)
    static let codeEntity = dynamic(0x6F42C1, 0xD2A8FF)
    static let codeConstant = dynamic(0x005CC5, 0x79C0FF)
    static let codeString = dynamic(0x032F62, 0x79C0FF)
    static let codeComment = dynamic(0x6A737D, 0x8B949E)
    static let link = dynamic(0x0066EF, 0x43ABFF)
    static let alertOrange = hex(0xFF6A0D)
    /// Inverted button: black in light mode, white in dark.
    static let inverted = dynamic(0x000000, 0xFFFFFF)
    static let invertedText = dynamic(0xFFFFFF, 0x000000)

    static let palette: [UIColor] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { hex($0) }

    private static var avatarColors: [Int: UIColor] = [:]

    /// Campfire: crc32(user id as a string) % 18.
    static func avatarColor(for userID: Int) -> UIColor {
        if let c = avatarColors[userID] { return c }
        let c = palette[Int(crc32(Array(String(userID).utf8)) % UInt32(palette.count))]
        avatarColors[userID] = c
        return c
    }

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in bytes {
            c ^= UInt32(b)
            for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        }
        return ~c
    }
}

/// Fixed geometry (does not follow Dynamic Type).
enum Metrics {
    static let screenPadding: CGFloat = 14.01
    static let avatar: CGFloat = 35.27
    static let avatarRing: CGFloat = 2
    static let bubbleLeft: CGFloat = 40.8
    static let bubbleRightInset: CGFloat = 14.0
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePadX: CGFloat = 15.12
    static let bubblePadY: CGFloat = 10.56
    static let bubbleBottomMargin: CGFloat = 1.6
    static let rowTopInset: CGFloat = 1.59
    static let threadedTopInset: CGFloat = 0.39
    static let rowGap: CGFloat = 21.28
    static let metaToBody: CGFloat = 2.76
    static let separatorTop: CGFloat = 17.02
    static let separatorBottom: CGFloat = 16.87
    static let separatorPadY: CGFloat = 8.5
    static let separatorPadX: CGFloat = 23.5
    static let imageMax: CGFloat = 300
    static let codeRadius: CGFloat = 6.4
    static let codePad: CGFloat = 12.8
    static let pillGap: CGFloat = 4
    static let pillAvatar: CGFloat = 23
    static let dotsWidth: CGFloat = 16
    static let headerHeight: CGFloat = 58
    static let composerHeight: CGFloat = 42
    static let composerBottomGap: CGFloat = 24
    static let listBottomGap: CGFloat = 24
}

/// Fonts and line heights for one Dynamic Type size. Body is 16 pt at the default (Large) size.
struct TypeScale: Equatable {
    let category: UIContentSizeCategory
    let s: CGFloat

    init(category: UIContentSizeCategory) {
        self.category = category
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        s = UIFontMetrics(forTextStyle: .body).scaledValue(for: 16, compatibleWith: traits) / 16
    }

    static func == (a: TypeScale, b: TypeScale) -> Bool { a.category == b.category }

    var body: UIFont { .systemFont(ofSize: 16 * s) }
    var bodyLine: CGFloat { 22.4 * s }
    var mention: UIFont { .systemFont(ofSize: 16 * s, weight: .semibold) }
    var author: UIFont { .systemFont(ofSize: 12.8 * s, weight: .bold) }
    var meta: UIFont { .systemFont(ofSize: 12.8 * s) }
    var metaLine: CGFloat { 19.2 * s }
    var separator: UIFont { .systemFont(ofSize: 12.8 * s, weight: .semibold) }
    var separatorLine: CGFloat { 17.92 * s }
    var emoji: UIFont { .systemFont(ofSize: 38.4 * s) }
    var emojiLine: CGFloat { 53.76 * s }
    var code: UIFont { .monospacedSystemFont(ofSize: 12.8 * s, weight: .regular) }
    var codeLine: CGFloat { 17.92 * s }
    var boostEmoji: UIFont { .systemFont(ofSize: 13.2 * s) }   // Apple Color Emoji advance ≈ 1.24 em; the browser draws 17.6 px wide
    var boostText: UIFont { .systemFont(ofSize: 12.8 * s) }
    var pillHeight: CGFloat { 28.64 * s }
    var fileLine: CGFloat { max(33.92, 22.4 * s + 11.52) }
}
