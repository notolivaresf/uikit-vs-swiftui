import AppKit

// Colours, sizes and fonts from Fixtures/constants.json (measured from ONCE Campfire at 393 × 852).

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func dynamic(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.isDark ? dark : light }
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32, alpha: CGFloat = 1) -> NSColor {
        dynamic(NSColor(hex: light, alpha: alpha), NSColor(hex: dark, alpha: alpha))
    }
}

enum Palette {
    static let background = NSColor.dynamic(0xFFFFFF, 0x000000)
    static let text = NSColor.dynamic(0x000000, 0xFFFFFF)
    static let dimText = NSColor.dynamic(0x000000, 0xFFFFFF, alpha: 0.5)
    static let bubble = NSColor.dynamic(0xF3F2EE, 0x222222)
    static let border = NSColor.dynamic(0xF3F2EE, 0x222222)
    static let borderDark = NSColor.dynamic(0xE5E4E1, 0x2E2E2E)
    static let borderDarker = NSColor.dynamic(0xAFAEAA, 0x555555)
    static let mentionBubble = NSColor.dynamic(NSColor(srgbRed: 190 / 255, green: 22 / 255, blue: 0, alpha: 0.10),
                                               NSColor(srgbRed: 1, green: 117 / 255, blue: 99 / 255, alpha: 0.20))
    static let codeBox = NSColor.dynamic(0xFFFFFF, 0x000000)
    static let boostPill = NSColor.dynamic(0xFFFFFF, 0x000000)
    static let codeKeyword = NSColor.dynamic(0xD73A49, 0xFF7B72)
    static let codeEntity = NSColor.dynamic(0x6F42C1, 0xD2A8FF)
    static let codeConstant = NSColor.dynamic(0x005CC5, 0x79C0FF)
    static let codeString = NSColor.dynamic(0x032F62, 0x79C0FF)
    static let codeComment = NSColor.dynamic(0x6A737D, 0x8B949E)
    static let alert = NSColor(hex: 0xFF6A0D)
    /// "General" pill and send button: black on light, white on dark.
    static let strong = NSColor.dynamic(0x000000, 0xFFFFFF)
    static let onStrong = NSColor.dynamic(0xFFFFFF, 0x000000)

    static let avatarPalette: [NSColor] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { NSColor(hex: $0) }

    /// Campfire picks crc32(user id) % 18.
    static func avatarColor(for userID: Int) -> NSColor {
        avatarPalette[Int(crc32(Array(String(userID).utf8)) % UInt32(avatarPalette.count))]
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

enum Metrics {
    static let screenPaddingX: CGFloat = 14.01
    static let avatarSize: CGFloat = 35.27
    static let avatarRing: CGFloat = 2
    static let bubbleLeft: CGFloat = 40.8
    static let bubbleRightInset: CGFloat = 14.0
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePadTop: CGFloat = 10.56
    static let bubblePadBottom: CGFloat = 11.32
    static let bubblePadX: CGFloat = 15.12
    static let headerToBody: CGFloat = 2.0
    static let gapBetweenRows: CGFloat = 21.28
    static let threadedMarginTop: CGFloat = -22.48
    static let bubbleTopInRow: CGFloat = 1.59
    static let bubbleBottomMargin: CGFloat = 1.6
    static let separatorTop: CGFloat = 17.02
    static let separatorBottom: CGFloat = 16.87
    static let separatorPadX: CGFloat = 23.5
    static let separatorPadY: CGFloat = 8.5
    static let separatorLine: CGFloat = 2
    static let imageMaxWidth: CGFloat = 300
    static let imageInset: CGFloat = 1
    static let imageTopExtra: CGFloat = 14.24
    static let codePadding: CGFloat = 12.8
    static let codeRadius: CGFloat = 6.4
    static let dotsGap: CGFloat = 12.6
    static let dotsWidth: CGFloat = 16.5
    static let dotsTrail: CGFloat = 14
    static let headerHeight: CGFloat = 58
    static let composerHeight: CGFloat = 90
    static let welcomeHeight: CGFloat = 380.3
}

/// Fonts and line heights at one of the app's text sizes.
struct Typography {
    static let scales: [CGFloat] = [1.0, 1.125, 1.25, 1.375, 1.5, 1.75]

    let scale: CGFloat
    let body: NSFont
    let mention: NSFont
    let meta: NSFont
    let metaBold: NSFont
    let separator: NSFont
    let code: NSFont
    let emoji: NSFont
    let boostText: NSFont
    let boostEmoji: NSFont
    let bodyLineHeight: CGFloat
    let metaLineHeight: CGFloat
    let separatorLineHeight: CGFloat
    let codeLineHeight: CGFloat
    let emojiLineHeight: CGFloat
    let boostHeight: CGFloat
    let mentionAvatar: CGFloat

    init(scale s: CGFloat) {
        scale = s
        body = .systemFont(ofSize: 16 * s)
        mention = .systemFont(ofSize: 16 * s, weight: .semibold)
        meta = .systemFont(ofSize: 12.8 * s)
        metaBold = .systemFont(ofSize: 12.8 * s, weight: .bold)
        separator = .systemFont(ofSize: 12.8 * s, weight: .semibold)
        code = .monospacedSystemFont(ofSize: 12.8 * s, weight: .regular)
        emoji = .systemFont(ofSize: 38.4 * s)
        boostText = .systemFont(ofSize: 12.8 * s)
        boostEmoji = .systemFont(ofSize: 17.6 * s)
        bodyLineHeight = 22.4 * s
        metaLineHeight = 19.2 * s
        separatorLineHeight = 17.92 * s
        codeLineHeight = 17.92 * s
        emojiLineHeight = 53.76 * s
        boostHeight = 28.64 * s
        mentionAvatar = 17.6 * s
    }
}

extension NSFont {
    /// Natural height of one line of this font (what NSString drawing uses).
    var lineBoxHeight: CGFloat { ascender - descender + leading }
}

/// SF Symbols tinted with a concrete colour, cached per appearance.
enum Symbols {
    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) -> NSImage? {
        let resolved = color.usingColorSpace(.sRGB) ?? color
        let key = "\(name)|\(size)|\(weight.rawValue)|\(resolved.redComponent),\(resolved.greenComponent),\(resolved.blueComponent),\(resolved.alphaComponent)"
        if let hit = cache[key] { return hit }
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [resolved]))
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        cache[key] = img
        return img
    }

    /// Draws a symbol centred on `center`.
    static func draw(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor, center: CGPoint) {
        guard let img = image(name, size: size, weight: weight, color: color) else { return }
        let s = img.size
        img.draw(in: CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height),
                 from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
}

enum Draw {
    static func circle(_ rect: CGRect, fill: NSColor) {
        fill.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    static func ring(_ rect: CGRect, stroke: NSColor, width: CGFloat = 1) {
        stroke.setStroke()
        let p = NSBezierPath(ovalIn: rect.insetBy(dx: width / 2, dy: width / 2))
        p.lineWidth = width
        p.stroke()
    }

    /// Round avatar with a white bold initial.
    static func avatar(_ rect: CGRect, color: NSColor, initial: String, fontSize: CGFloat) {
        circle(rect, fill: color)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let str = NSAttributedString(string: initial, attributes: [.font: font, .foregroundColor: NSColor.white])
        let size = str.size()
        str.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - font.lineBoxHeight / 2 + 0.2))
    }

    /// Campfire's "•••" actions glyph: three dots in a `Metrics.dotsWidth` wide box.
    static func dots(at origin: CGPoint, height: CGFloat, color: NSColor, scale: CGFloat) {
        let d = 4.4 * scale
        let step = 6.05 * scale
        color.setFill()
        for i in 0..<3 {
            NSBezierPath(ovalIn: CGRect(x: origin.x + CGFloat(i) * step, y: origin.y + (height - d) / 2,
                                        width: d, height: d)).fill()
        }
    }
}

func initial(of name: String) -> String {
    name.first.map { String($0).uppercased() } ?? "?"
}
