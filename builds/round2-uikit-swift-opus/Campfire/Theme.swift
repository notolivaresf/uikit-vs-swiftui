import UIKit

/// Campfire's colours, from Fixtures/constants.json. Every colour is dynamic (light and dark).
enum Palette {
    static func dynamic(_ light: UInt32, _ dark: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: alpha) : UIColor(hex: light, alpha: alpha) }
    }

    static let background = dynamic(0xFFFFFF, 0x000000)
    static let text = dynamic(0x000000, 0xFFFFFF)
    static let textHalf = dynamic(0x000000, 0xFFFFFF, alpha: 0.5)
    static let bubble = dynamic(0xF3F2EE, 0x222222)
    static let border = dynamic(0xF3F2EE, 0x222222)
    static let borderDark = dynamic(0xE5E4E1, 0x2E2E2E)
    static let borderDarker = dynamic(0xAFAEAA, 0x555555)
    static let boostPill = dynamic(0xFFFFFF, 0x000000)
    static let codeBox = dynamic(0xFFFFFF, 0x000000)
    static let link = dynamic(0x0066EF, 0x43ABFF)
    static let mentionedBubble = UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(red: 255 / 255, green: 117 / 255, blue: 99 / 255, alpha: 0.20)
            : UIColor(red: 190 / 255, green: 22 / 255, blue: 0, alpha: 0.10)
    }
    static let bellRing = UIColor(hex: 0xFF6A0D)

    static let codeKeyword = dynamic(0xD73A49, 0xFF7B72)
    static let codeEntity = dynamic(0x6F42C1, 0xD2A8FF)
    static let codeConstant = dynamic(0x005CC5, 0x79C0FF)
    static let codeString = dynamic(0x032F62, 0x79C0FF)
    static let codeComment = dynamic(0x6A737D, 0x8B949E)

    static let avatarColors: [UIColor] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { UIColor(hex: $0) }

    /// Campfire picks `crc32(user id) % 18`.
    static func avatarColor(for userID: Int) -> UIColor {
        avatarColors[Int(CRC32.checksum(String(userID)) % UInt32(avatarColors.count))]
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func checksum(_ string: String) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in string.utf8 { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

/// Sizes in points, measured from Campfire at 393 pt wide (constants.json and the screenshots).
enum Metrics {
    static let screenPaddingX: CGFloat = 14.01
    static let avatarSize: CGFloat = 35.27
    static let avatarRing: CGFloat = 2.33
    static let bubbleX: CGFloat = 40.8
    static let bubbleRightInset: CGFloat = 14.0
    static let bubblePadX: CGFloat = 15.12
    static let bubbleRadius: CGFloat = 10.56
    static let rowTopPad: CGFloat = 1.59
    static let rowBottomPad: CGFloat = 1.6
    static let rowGap: CGFloat = 21.28
    static let threadedRowMarginTop: CGFloat = -22.48
    /// From the bubble top to the top of the author line box.
    static let headerTop: CGFloat = 11.46
    /// Below the last line of text to the bubble bottom.
    static let bubbleBottomPad: CGFloat = 11.72
    /// Campfire's glyphs sit this much lower in their line box than a centred line (measured).
    static let glyphNudge: CGFloat = 1.3
    static let timeToDotsGap: CGFloat = 11.8
    static let dotsWidth: CGFloat = 17
    static let dotSize: CGFloat = 4.67

    static let separatorPillTop: CGFloat = 17.02
    static let separatorPillPadY: CGFloat = 8.5
    static let separatorPillPadX: CGFloat = 20.3
    static let separatorMarginBottom: CGFloat = 17.02
    static let separatorLine: CGFloat = 2

    static let imageWidth: CGFloat = 300
    static let imageTopGap: CGFloat = 12.64
    static let imageInset: CGFloat = 1

    static let codeBoxRadius: CGFloat = 6.4
    static let codePad: CGFloat = 12.8
    static let codeBoxInsetX: CGFloat = 16.4
    static let codeBoxGapTop: CGFloat = 1.64
    static let codeBoxBottomPad: CGFloat = 12.05

    static let fileBlockHeight: CGFloat = 37.2
    static let fileBottomPad: CGFloat = 8.44

    static let boostHeight: CGFloat = 28.64
    static let boostMarginTop: CGFloat = 4
    static let boostGap: CGFloat = 5
    static let boostRowGap: CGFloat = 4
    static let boostAvatar: CGFloat = 22.33
    static let boostPadLeft: CGFloat = 2.33
    static let boostAvatarGap: CGFloat = 4
    static let boostPadRight: CGFloat = 8
    static let imageBoostInsetX: CGFloat = 10
    static let imageBoostBottomPad: CGFloat = 8.1

    static let mentionAvatar: CGFloat = 17

    /// Visible header height below the safe area (the gradient ends here).
    static let headerHeight: CGFloat = 58
    static let composerHeight: CGFloat = 90
}

/// Fonts scale with Dynamic Type from Campfire's sizes at the default ("Large") text size.
struct TypeScale: Equatable {
    let category: UIContentSizeCategory
    let factor: CGFloat

    init(category: UIContentSizeCategory) {
        self.category = category
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        factor = UIFontMetrics(forTextStyle: .body).scaledValue(for: 1000, compatibleWith: traits) / 1000
    }

    func size(_ points: CGFloat) -> CGFloat { (points * factor * 100).rounded() / 100 }

    func system(_ points: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size(points), weight: weight)
    }

    func mono(_ points: CGFloat) -> UIFont { .monospacedSystemFont(ofSize: size(points), weight: .regular) }

    var body: UIFont { system(16) }
    var bodyLine: CGFloat { size(22.4) }
    var meta: UIFont { system(12.8) }
    var metaBold: UIFont { system(12.8, .bold) }
    var metaLine: CGFloat { size(19.2) }
    var separator: UIFont { system(12.8, .semibold) }
    var separatorLine: CGFloat { size(17.92) }
    var emoji: UIFont { system(38.4) }
    var emojiLine: CGFloat { size(53.76) }
    var code: UIFont { mono(12.8) }
    var codeLine: CGFloat { size(17.92) }
    var mention: UIFont { system(16, .semibold) }
    var boostEmoji: UIFont { system(17.6) }
    var boostText: UIFont { system(12.8) }
}

/// Paragraph attributes that give a CSS-style fixed line height (see `glyphShift` for the vertical position).
enum LineBox {
    static func attributes(font: UIFont, lineHeight: CGFloat, color: UIColor,
                           alignment: NSTextAlignment = .natural, breakMode: NSLineBreakMode = .byWordWrapping) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight
        p.maximumLineHeight = lineHeight
        p.alignment = alignment
        p.lineBreakMode = breakMode
        return [.font: font, .foregroundColor: color, .paragraphStyle: p]
    }

    /// TextKit 1 puts a fixed-height line's extra space above the glyphs; CSS splits it above and below.
    /// Text views are moved up by this much so glyphs sit where Campfire draws them.
    static func glyphShift(font: UIFont, lineHeight: CGFloat) -> CGFloat {
        (lineHeight - (font.ascender - font.descender)) / 2
    }
}
