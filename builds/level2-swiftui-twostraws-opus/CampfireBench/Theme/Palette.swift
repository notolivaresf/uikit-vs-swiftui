import SwiftUI

/// Campfire's colours. Adaptive ones live in the asset catalog with a dark variant.
enum Palette {
    static let background = Color("Background")
    static let ink = Color("Ink")
    static let bubble = Color("Bubble")
    static let borderDark = Color("BorderDark")
    static let borderDarker = Color("BorderDarker")
    static let link = Color("Link")
    static let mentionBubble = Color("MentionBubble")
    static let codeKeyword = Color("CodeKeyword")
    static let codeEntity = Color("CodeEntity")
    static let codeConstant = Color("CodeConstant")
    static let codeString = Color("CodeString")
    static let codeComment = Color("CodeComment")

    /// The orange ring around the notifications bell in the room header.
    static let bellRing = Color(hex: 0xFF6A0D)

    /// Campfire's avatar palette, picked by `crc32(user id) % 18`.
    static let avatars: [Color] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
        0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E,
    ].map { Color(hex: $0) }

    static func avatar(for userID: Int) -> Color {
        avatars[Int(CRC32.checksum(String(userID)) % UInt32(avatars.count))]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
