import SwiftUI
import CampfireKit

enum CampfireStyle {
    static let screenPadding = 14.01
    static let avatarSize = 35.27
    static let bubbleLeading = 40.8
    static let bubbleRadius = 10.56
    static let paddingX = 15.12
    static let paddingY = 10.56
    static let rowGap = 21.28
    static let palette: [UInt32] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C,
        0xBF1B1B, 0x736B1E, 0xD07B53, 0x736356, 0xAD1D1D, 0xBF7C2A,
        0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E
    ]

    static func color(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }

    static func color(_ rgb: RGB) -> Color {
        Color(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255,
              blue: Double(rgb.b) / 255, opacity: 1)
    }

    static func background(_ scheme: ColorScheme) -> Color { scheme == .dark ? .black : .white }
    static func bubble(_ scheme: ColorScheme) -> Color { color(scheme == .dark ? 0x222222 : 0xF3F2EE) }
    static func border(_ scheme: ColorScheme) -> Color { color(scheme == .dark ? 0x555555 : 0xAFAEAA) }
    static func pillBorder(_ scheme: ColorScheme) -> Color { color(scheme == .dark ? 0x2E2E2E : 0xE5E4E1) }
    static func mention(_ scheme: ColorScheme) -> Color {
        color(scheme == .dark ? 0xFF7563 : 0xBE1600).opacity(scheme == .dark ? 0.2 : 0.1)
    }

    // Campfire's avatar palette is indexed by the CRC32 of the decimal user ID.
    static func avatarColor(_ id: UserID) -> Color {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xEDB88320 : 0) }
        }
        return color(palette[Int(crc ^ 0xFFFFFFFF) % palette.count])
    }

    static let utc = TimeZone(secondsFromGMT: 0) ?? .gmt
    static let timeFormat = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: Grouping.calendar, timeZone: utc)
        .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
    static let dayFormat = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: Grouping.calendar, timeZone: utc)
        .month(.wide).day().year()
}
