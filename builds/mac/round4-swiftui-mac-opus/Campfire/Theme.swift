import SwiftUI
import CoreText
import CampfireKit

// Colours, fonts and sizes measured from ONCE Campfire (see Fixtures/constants.json).

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

struct Theme: Equatable {
    let dark: Bool

    init(_ scheme: ColorScheme) { dark = scheme == .dark }

    var background: Color { dark ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF) }
    var text: Color { dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x000000) }
    var bubble: Color { dark ? Color(hex: 0x222222) : Color(hex: 0xF3F2EE) }
    var border: Color { dark ? Color(hex: 0x222222) : Color(hex: 0xF3F2EE) }
    var borderDark: Color { dark ? Color(hex: 0x2E2E2E) : Color(hex: 0xE5E4E1) }
    var borderDarker: Color { dark ? Color(hex: 0x555555) : Color(hex: 0xAFAEAA) }
    var link: Color { dark ? Color(hex: 0x43ABFF) : Color(hex: 0x0066EF) }
    var negative: Color { dark ? Color(hex: 0xFF7563) : Color(hex: 0xBE1600) }
    var boostPill: Color { background }
    var codeBox: Color { background }
    var mentionedBubble: Color {
        dark ? Color(.sRGB, red: 255 / 255, green: 117 / 255, blue: 99 / 255, opacity: 0.20)
             : Color(.sRGB, red: 190 / 255, green: 22 / 255, blue: 0, opacity: 0.10)
    }
    var codeKeyword: Color { dark ? Color(hex: 0xFF7B72) : Color(hex: 0xD73A49) }
    var codeEntity: Color { dark ? Color(hex: 0xD2A8FF) : Color(hex: 0x6F42C1) }
    var codeConstant: Color { dark ? Color(hex: 0x79C0FF) : Color(hex: 0x005CC5) }
    var codeString: Color { dark ? Color(hex: 0x79C0FF) : Color(hex: 0x032F62) }
    var codeComment: Color { dark ? Color(hex: 0x8B949E) : Color(hex: 0x6A737D) }
    var selection: Color { dark ? Color(hex: 0x2C5172) : Color(hex: 0x9BC1F1) }
    /// The bell button's ring in the header.
    var alert: Color { Color(hex: 0xF7720F) }
}

enum AvatarPalette {
    static let colors: [UInt32] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ]

    /// Campfire picks crc32(user id) % 18.
    static func color(for id: UserID) -> Color {
        Color(hex: colors[Int(CRC32.of(String(id)) % UInt32(colors.count))])
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func of(_ string: String) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in string.utf8 { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

/// The app's own text sizes: the default and four larger steps.
enum TextSize {
    static let scales: [CGFloat] = [1.0, 1.125, 1.25, 1.375, 1.5]
}

/// Font metrics from Core Text so CSS line boxes (line-height) can be rebuilt on top of SwiftUI's Text.
struct FontMetrics {
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    var lineHeight: CGFloat { ascent + descent + leading }

    nonisolated(unsafe) private static var cache: [CGFloat: FontMetrics] = [:]

    static func system(_ size: CGFloat) -> FontMetrics {
        if let hit = cache[size] { return hit }
        let font = CTFontCreateUIFontForLanguage(.system, size, nil)!
        let m = FontMetrics(ascent: CTFontGetAscent(font), descent: CTFontGetDescent(font), leading: CTFontGetLeading(font))
        cache[size] = m
        return m
    }
}

/// Every size in the room, in points, at the app's current text size. Campfire sizes everything in rem,
/// so a larger text size scales the whole row, like zooming the root font size.
struct Metrics: Equatable {
    let s: CGFloat

    // Fixed chrome (not scaled).
    static let headerHeight: CGFloat = 57.6
    static let headerButton: CGFloat = 41.7
    static let composerArea: CGFloat = 90
    static let screenPaddingX: CGFloat = 14.01

    var screenPaddingX: CGFloat { Metrics.screenPaddingX }

    // Type.
    var bodySize: CGFloat { 16 * s }
    var bodyLine: CGFloat { 22.4 * s }
    var metaSize: CGFloat { 12.8 * s }
    var metaLine: CGFloat { 19.2 * s }
    var codeSize: CGFloat { 12.8 * s }
    var codeLine: CGFloat { 17.92 * s }
    var emojiSize: CGFloat { 38.4 * s }
    var emojiLine: CGFloat { 53.76 * s }
    var separatorSize: CGFloat { 12.8 * s }
    var separatorLine: CGFloat { 17.92 * s }

    // Row.
    var avatar: CGFloat { 35.27 * s }
    var avatarRing: CGFloat { 2 * s }
    /// Bubble's left edge measured from the avatar's left edge.
    var bubbleInsetFromAvatar: CGFloat { 26.79 * s }
    var bubbleRadius: CGFloat { 10.56 * s }
    var bubblePadX: CGFloat { 15.12 * s }
    var bubblePadY: CGFloat { 10.56 * s }
    var bubbleTop: CGFloat { 1.59 * s }
    var bubbleBottom: CGFloat { 1.6 * s }
    var rowGap: CGFloat { 21.28 * s }
    var threadedMarginTop: CGFloat { -22.48 * s }
    /// Distance from the bubble's top edge to the meta line's baseline.
    var metaBaseline: CGFloat { 26.7 * s }
    /// Distance from the bubble's top edge to the top of the first body line box.
    var bodyTop: CGFloat { 32.52 * s }
    /// Mine: the bubble's left edge never comes closer than this to the window's left edge (287.97 wide at 393).
    var mineLeftLimit: CGFloat { 64.23 * s }

    // Day separator.
    var separatorMarginY: CGFloat { 17.02 * s }
    var separatorPadY: CGFloat { 8.5 * s }
    var separatorPadX: CGFloat { 23.5 * s }
    var separatorLineThickness: CGFloat { 2 * s }

    // Image.
    var imageMaxWidth: CGFloat { 300 * s }
    var imageTop: CGFloat { 44 * s }

    // Code.
    var codeRadius: CGFloat { 6.4 * s }
    var codePadding: CGFloat { 12.8 * s }
    var codeBottomExtra: CGFloat { 1.97 * s }

    // Boosts.
    var boostHeight: CGFloat { 28.64 * s }
    var boostAvatar: CGFloat { 23.44 * s }
    var boostPadLeft: CGFloat { 1.6 * s }
    var boostPadRight: CGFloat { 7.5 * s }
    var boostInnerGap: CGFloat { 4 * s }
    var boostGap: CGFloat { 4.3 * s }
    var boostMarginTop: CGFloat { 4 * s }
    var boostEmojiSize: CGFloat { 17.6 * s }
    var boostTextSize: CGFloat { 12.8 * s }

    // Mentions.
    var mentionAvatar: CGFloat { 17.7 * s }
    var mentionSize: CGFloat { 16 * s }

    // File.
    var fileLine: CGFloat { 36.68 * s }
}

/// Rebuilds a CSS line box (`line-height`) on SwiftUI text: every line is exactly `lineHeight` tall with the
/// baseline where a browser puts it. `shift` is how far below SwiftUI's own exact-height baseline that is
/// (measured once per style at text size 1, then scaled).
struct CSSLineHeight: ViewModifier {
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let shift: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .lineHeight(.exact(points: lineHeight))
                .offset(y: shift)
        } else {
            let extra = max(0, lineHeight - FontMetrics.system(fontSize).lineHeight)
            content
                .lineSpacing(extra)
                .padding(.vertical, extra / 2)
        }
    }
}

extension View {
    func cssLineHeight(_ lineHeight: CGFloat, fontSize: CGFloat, shift: CGFloat) -> some View {
        modifier(CSSLineHeight(fontSize: fontSize, lineHeight: lineHeight, shift: shift))
    }
}
