import SwiftUI

/// Colours and sizes measured from ONCE Campfire (see Fixtures/constants.json). CSS px map 1:1 to points.
enum Theme {
    static let alertOrange = Color(rgb: 0xFF6A0D)

    static let avatarPalette: [Color] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { Color(rgb: $0) }

    /// Campfire picks `crc32(user id) % 18`.
    static func avatarColor(for userID: Int) -> Color {
        avatarPalette[Int(CRC32.checksum(String(userID)) % UInt32(avatarPalette.count))]
    }

    // MARK: Sizes

    static let screenPaddingX: CGFloat = 14.01
    static let avatarSize: CGFloat = 35.27
    static let avatarRing: CGFloat = 2.5
    static let bubbleLeft: CGFloat = 40.8
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePaddingY: CGFloat = 10.56
    static let bubblePaddingX: CGFloat = 15.12
    static let bubbleTopInRow: CGFloat = 1.59
    static let bubbleBottomMargin: CGFloat = 1.6
    static let gapBetweenRows: CGFloat = 21.28
    static let threadedRowMarginTop: CGFloat = -22.48
    /// The meta line (name, time, menu) plus the gap under it.
    static let metaLineHeight: CGFloat = 19.2
    static let metaBlockHeight: CGFloat = 21.96

    static let imageMaxWidth: CGFloat = 300
    static let boostHeight: CGFloat = 28.64
    static let boostMarginTop: CGFloat = 4
    static let codeRadius: CGFloat = 6.4
    static let codePadding: CGFloat = 12.8

    static let headerButton: CGFloat = 42
    static let headerHeight: CGFloat = 58
}

/// Scales Campfire's rem-based type with Dynamic Type (16 pt body at the default size).
struct TypeScale: Equatable {
    var factor: CGFloat

    init(_ size: DynamicTypeSize) {
        // Ratios of the system body style (17 pt at Large).
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

    func callAsFunction(_ v: CGFloat) -> CGFloat { (v * factor * 100).rounded() / 100 }
}

private struct TypeScaleKey: EnvironmentKey {
    static let defaultValue = TypeScale(.large)
}

extension EnvironmentValues {
    var typeScale: TypeScale {
        get { self[TypeScaleKey.self] }
        set { self[TypeScaleKey.self] = newValue }
    }
}

/// SF Pro line metrics (ascender 0.952, descender 0.241 of the point size), used to give text a CSS line-height.
enum FontMetrics {
    static let naturalLineHeight: CGFloat = 1.193
    static let monoLineHeight: CGFloat = 1.193
}

extension View {
    /// Lays text out on CSS-style line boxes: `lineHeight` per line, glyphs centred in the box.
    func cssLineHeight(_ lineHeight: CGFloat, fontSize: CGFloat, natural: CGFloat = FontMetrics.naturalLineHeight) -> some View {
        let extra = max(0, lineHeight - fontSize * natural)
        return self.lineSpacing(extra).padding(.vertical, extra / 2)
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: 1)
    }

}

/// Campfire's colour tokens for one colour scheme. Resolved once at the root and read from the environment.
struct Palette: Equatable {
    var background, text, bubble, border, borderDark, borderDarker, link, negative, selected: Color
    /// Campfire red at 10% (light) / 20% (dark), painted over the page background.
    var mentionedBubble: Color
    var codeKeyword, codeEntity, codeConstant, codeString, codeComment: Color
    var isDark: Bool

    static let light = Palette(
        background: Color(rgb: 0xFFFFFF), text: Color(rgb: 0x000000), bubble: Color(rgb: 0xF3F2EE),
        border: Color(rgb: 0xF3F2EE), borderDark: Color(rgb: 0xE5E4E1), borderDarker: Color(rgb: 0xAFAEAA),
        link: Color(rgb: 0x0066EF), negative: Color(rgb: 0xBE1600), selected: Color(rgb: 0x9BC1F1).opacity(0.6),
        mentionedBubble: Color(rgb: 0xBE1600).opacity(0.10),
        codeKeyword: Color(rgb: 0xD73A49), codeEntity: Color(rgb: 0x6F42C1), codeConstant: Color(rgb: 0x005CC5),
        codeString: Color(rgb: 0x032F62), codeComment: Color(rgb: 0x6A737D), isDark: false)

    static let dark = Palette(
        background: Color(rgb: 0x000000), text: Color(rgb: 0xFFFFFF), bubble: Color(rgb: 0x222222),
        border: Color(rgb: 0x222222), borderDark: Color(rgb: 0x2E2E2E), borderDarker: Color(rgb: 0x555555),
        link: Color(rgb: 0x43ABFF), negative: Color(rgb: 0xFF7563), selected: Color(rgb: 0x2C5172),
        mentionedBubble: Color(rgb: 0xFF7563).opacity(0.20),
        codeKeyword: Color(rgb: 0xFF7B72), codeEntity: Color(rgb: 0xD2A8FF), codeConstant: Color(rgb: 0x79C0FF),
        codeString: Color(rgb: 0x79C0FF), codeComment: Color(rgb: 0x8B949E), isDark: true)

    static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        return c
    }

    static func checksum(_ s: String) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in s.utf8 { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return ~c
    }
}
