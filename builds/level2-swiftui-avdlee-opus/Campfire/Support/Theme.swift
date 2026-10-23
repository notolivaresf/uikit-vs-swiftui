import SwiftUI
import CampfireKit

/// Campfire's colours (light and dark), from Fixtures/constants.json.
struct Palette: Equatable {
    let background: Color
    let text: Color
    let bubble: Color
    let borderDark: Color
    let borderDarker: Color
    let link: Color
    let negative: Color
    let boostBackground: Color
    let codeBackground: Color
    let codeKeyword: Color
    let codeEntity: Color
    let codeConstant: Color
    let codeString: Color
    let codeComment: Color
    let mentionedBubble: Color
    let alert: Color
    let isDark: Bool

    static let light = Palette(
        background: Color(hex: 0xFFFFFF), text: Color(hex: 0x000000), bubble: Color(hex: 0xF3F2EE),
        borderDark: Color(hex: 0xE5E4E1), borderDarker: Color(hex: 0xAFAEAA), link: Color(hex: 0x0066EF),
        negative: Color(hex: 0xBE1600), boostBackground: Color(hex: 0xFFFFFF), codeBackground: Color(hex: 0xFFFFFF),
        codeKeyword: Color(hex: 0xD73A49), codeEntity: Color(hex: 0x6F42C1), codeConstant: Color(hex: 0x005CC5),
        codeString: Color(hex: 0x032F62), codeComment: Color(hex: 0x6A737D),
        mentionedBubble: Color(.sRGB, red: 190 / 255, green: 22 / 255, blue: 0, opacity: 0.10),
        alert: Color(hex: 0xFF6A0D), isDark: false)

    static let dark = Palette(
        background: Color(hex: 0x000000), text: Color(hex: 0xFFFFFF), bubble: Color(hex: 0x222222),
        borderDark: Color(hex: 0x2E2E2E), borderDarker: Color(hex: 0x555555), link: Color(hex: 0x43ABFF),
        negative: Color(hex: 0xFF7563), boostBackground: Color(hex: 0x000000), codeBackground: Color(hex: 0x000000),
        codeKeyword: Color(hex: 0xFF7B72), codeEntity: Color(hex: 0xD2A8FF), codeConstant: Color(hex: 0x79C0FF),
        codeString: Color(hex: 0x79C0FF), codeComment: Color(hex: 0x8B949E),
        mentionedBubble: Color(.sRGB, red: 1, green: 117 / 255, blue: 99 / 255, opacity: 0.20),
        alert: Color(hex: 0xFF6A0D), isDark: true)

    static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }

    /// Campfire picks crc32(user id) % 18 from this list.
    static let avatarColors: [Color] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { Color(hex: $0) }

    static func avatarColor(for id: UserID) -> Color {
        avatarColors[Int(CRC32.checksum(String(id)) % UInt32(avatarColors.count))]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    init(_ rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255, opacity: 1)
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        return c
    }

    static func checksum(_ string: String) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in string.utf8 { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return ~c
    }
}

/// Layout numbers measured from Campfire (CSS px = pt).
enum Metrics {
    static let screenPaddingX: CGFloat = 14.01
    static let avatarSize: CGFloat = 35.27
    static let avatarRing: CGFloat = 2
    static let bubbleLeft: CGFloat = 40.8
    static let bubbleRightInset: CGFloat = 14.0
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePaddingY: CGFloat = 10.56
    static let bubblePaddingX: CGFloat = 15.12
    static let bubbleTopInRow: CGFloat = 1.59
    static let bubbleBottomMargin: CGFloat = 1.6
    static let rowGap: CGFloat = 21.28
    static let threadedMarginTop: CGFloat = -22.48
    static let metaToBody: CGFloat = 2.76
    static let imageMaxWidth: CGFloat = 300

    /// Space between a row and the one before it (threaded rows tuck up under their predecessor).
    static func gap(before row: RowData) -> CGFloat { row.isThreaded ? rowGap + threadedMarginTop : rowGap }

    static let headerHeight: CGFloat = 58
    static let headerButton: CGFloat = 42
    static let pinnedThreshold: CGFloat = 100
}

/// Font sizes follow Dynamic Type: Campfire's 16 px body is our default (Large) size and scales with the
/// same ratios as the system body style.
struct TypeScale: Equatable {
    let factor: CGFloat

    init(_ size: DynamicTypeSize) {
        let body: CGFloat = switch size {
        case .xSmall: 14
        case .small: 15
        case .medium: 16
        case .large: 17
        case .xLarge: 19
        case .xxLarge: 21
        case .xxxLarge: 23
        case .accessibility1: 28
        case .accessibility2: 33
        case .accessibility3: 40
        case .accessibility4: 47
        case .accessibility5: 53
        @unknown default: 17
        }
        factor = body / 17
    }

    func callAsFunction(_ value: CGFloat) -> CGFloat { (value * factor * 100).rounded() / 100 }
}

/// SF Pro's natural line height is about 1.1934 x its point size (UIFont.lineHeight); CSS line-height adds
/// half of the remaining leading above and below each line.
enum FontMetrics {
    static let sfLineHeightRatio: CGFloat = 1.1934
    static let monoLineHeightRatio: CGFloat = 1.1934
}

extension View {
    /// Gives text a CSS-style line height: extra leading split between lines and above/below the block.
    /// `raise` moves the glyphs up inside the line box (Chrome places SF Pro's baseline slightly higher than iOS).
    func cssLineHeight(fontSize: CGFloat, lineHeight: CGFloat, ratio: CGFloat = FontMetrics.sfLineHeightRatio,
                       raise: CGFloat = 0) -> some View {
        let leading = max(0, lineHeight - fontSize * ratio)
        return self.lineSpacing(leading)
            .padding(.top, leading / 2 - raise)
            .padding(.bottom, leading / 2 + raise)
    }
}
