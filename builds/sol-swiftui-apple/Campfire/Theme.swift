import SwiftUI
import CampfireKit

struct RoomColors {
    let dark: Bool
    var background: Color { dark ? .black : .white }
    var text: Color { dark ? .white : .black }
    var bubble: Color { Color(hex: dark ? 0x222222 : 0xF3F2EE) }
    var border: Color { Color(hex: dark ? 0x2E2E2E : 0xE5E4E1) }
    var outline: Color { Color(hex: dark ? 0x555555 : 0xAFAEAA) }
    var red: Color { Color(hex: dark ? 0xFF7563 : 0xBE1600) }
    var mention: Color { red.opacity(dark ? 0.2 : 0.1) }
    var link: Color { Color(hex: dark ? 0x43ABFF : 0x0066EF) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
    init(rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255,
                  blue: Double(rgb.b) / 255, opacity: 1)
    }
}

enum AvatarPalette {
    static let colors: [UInt32] = [0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C,
        0xBF1B1B, 0x736B1E, 0xD07B53, 0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C,
        0x7C956B, 0x5D618F, 0x3B3633, 0x67695E]
    static func color(_ id: Int) -> Color {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0) }
        }
        return Color(hex: colors[Int(~crc) % colors.count])
    }
}

struct Avatar: View {
    let id: Int
    let initial: String
    var size: CGFloat = 35.27

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.455, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AvatarPalette.color(id), in: Circle())
            .accessibilityHidden(true)
    }
}
