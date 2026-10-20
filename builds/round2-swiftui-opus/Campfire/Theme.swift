import SwiftUI

/// Sizes measured from ONCE Campfire (see Fixtures/constants.json). CSS px map 1:1 to points.
enum Metrics {
    static let screenPaddingX: CGFloat = 14.01
    static let avatarSize: CGFloat = 35.27
    static let avatarRing: CGFloat = 2.3
    static let bubbleLeft: CGFloat = 40.8
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePaddingY: CGFloat = 10.56
    static let bubblePaddingX: CGFloat = 15.12
    static let bubbleTopMargin: CGFloat = 1.59
    static let bubbleBottomMargin: CGFloat = 1.6
    /// Grid gap between two rows.
    static let rowGap: CGFloat = 21.28
    /// A threaded row starts 1.2 pt above the previous row's bottom edge (margin-top -22.48 over a 21.28 gap).
    static let threadedTopMargin: CGFloat = 0.39
    /// Campfire caps my bubble at 287.97 wide; a little slack keeps text that fits there on one line.
    static let mineMinLeft: CGFloat = 60
    static let headerLineHeight: CGFloat = 21.96

    static let separatorMarginY: CGFloat = 18.72
    static let separatorPadY: CGFloat = 6.8
    static let separatorPadX: CGFloat = 19.5
    static let separatorLine: CGFloat = 2

    static let imageWidth: CGFloat = 300
    static let codeRadius: CGFloat = 6.4
    static let codePadding: CGFloat = 12.8

    static let boostHeight: CGFloat = 28
    static let boostAvatar: CGFloat = 24
    static let boostMarginTop: CGFloat = 4
    static let imageBoostPaddingX: CGFloat = 10.2
    static let boostGap: CGFloat = 4

    /// Height of the room header (General pill and buttons); rows scroll under it and fade out.
    static let headerHeight: CGFloat = 56
    static let headerSolid: CGFloat = 14
    static let composerHeight: CGFloat = 42
    static let composerGap: CGFloat = 24
    static let composerBottom: CGFloat = 24
}

/// Font sizes at the default text size; everything is multiplied by `TypeScale.factor`.
enum FontSize {
    static let body: CGFloat = 16
    static let bodyLine: CGFloat = 22.4
    static let meta: CGFloat = 12.8
    static let separator: CGFloat = 12.8
    static let separatorLine: CGFloat = 17.92
    static let emojiOnly: CGFloat = 38.4
    static let emojiOnlyLine: CGFloat = 53.76
    static let code: CGFloat = 12.8
    static let codeLine: CGFloat = 17.92
    /// Boost pills measure about 13.6 pt for both emoji and text in the screenshots.
    static let boost: CGFloat = 13.6
}

/// Dynamic Type: Campfire's 16 pt body corresponds to iOS's 17 pt body at the default (large) size.
enum TypeScale {
    static func factor(for size: DynamicTypeSize) -> CGFloat {
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
        return body / 17
    }

    /// SF Pro's natural line height is about 1.193 times its point size.
    static func naturalLineHeight(_ size: CGFloat) -> CGFloat { size * 1.1931 }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Campfire's colours for one colour scheme.
struct Palette: Equatable {
    let background: Color
    let text: Color
    let bubble: Color
    let border: Color
    let borderDark: Color
    let borderDarker: Color
    let mentioned: Color
    let selected: Color
    let link: Color
    let codeBox: Color
    let codeKeyword: Color
    let codeEntity: Color
    let codeConstant: Color
    let codeString: Color
    let codeComment: Color

    static let light = Palette(
        background: Color(hex: 0xFFFFFF), text: Color(hex: 0x000000), bubble: Color(hex: 0xF3F2EE),
        border: Color(hex: 0xF3F2EE), borderDark: Color(hex: 0xE5E4E1), borderDarker: Color(hex: 0xAFAEAA),
        mentioned: Color(hex: 0xBE1600, opacity: 0.10), selected: Color(hex: 0x9BC1F1, opacity: 0.55),
        link: Color(hex: 0x0066EF), codeBox: Color(hex: 0xFFFFFF),
        codeKeyword: Color(hex: 0xD73A49), codeEntity: Color(hex: 0x6F42C1), codeConstant: Color(hex: 0x005CC5),
        codeString: Color(hex: 0x032F62), codeComment: Color(hex: 0x6A737D))

    static let dark = Palette(
        background: Color(hex: 0x000000), text: Color(hex: 0xFFFFFF), bubble: Color(hex: 0x222222),
        border: Color(hex: 0x222222), borderDark: Color(hex: 0x2E2E2E), borderDarker: Color(hex: 0x555555),
        mentioned: Color(hex: 0xFF7563, opacity: 0.20), selected: Color(hex: 0x2C5172, opacity: 0.9),
        link: Color(hex: 0x43ABFF), codeBox: Color(hex: 0x000000),
        codeKeyword: Color(hex: 0xFF7B72), codeEntity: Color(hex: 0xD2A8FF), codeConstant: Color(hex: 0x79C0FF),
        codeString: Color(hex: 0x79C0FF), codeComment: Color(hex: 0x8B949E))

    static func forScheme(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }
}

enum AvatarPalette {
    static let colors: [UInt32] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ]

    /// Campfire picks `crc32(user id) % 18`.
    static func index(for userID: Int) -> Int {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in String(userID).utf8 {
            c ^= UInt32(byte)
            for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        }
        return Int(~c % UInt32(colors.count))
    }

    static func color(for userID: Int) -> Color { Color(hex: colors[index(for: userID)]) }
}
