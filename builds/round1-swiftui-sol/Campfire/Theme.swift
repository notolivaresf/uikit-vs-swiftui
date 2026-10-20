import SwiftUI
import CampfireKit

struct RoomTheme {
    let scheme: ColorScheme
    var background: Color { scheme == .dark ? .black : .white }
    var text: Color { scheme == .dark ? .white : .black }
    var bubble: Color { Color(hex: scheme == .dark ? 0x222222 : 0xF3F2EE) }
    var border: Color { Color(hex: scheme == .dark ? 0x2E2E2E : 0xE5E4E1) }
    var outline: Color { Color(hex: scheme == .dark ? 0x555555 : 0xAFAEAA) }
    var red: Color { Color(hex: scheme == .dark ? 0xFF7563 : 0xBE1600) }
    var mention: Color { red.opacity(scheme == .dark ? 0.2 : 0.1) }
    var keyword: Color { Color(hex: scheme == .dark ? 0xFF7B72 : 0xD73A49) }
    var entity: Color { Color(hex: scheme == .dark ? 0xD2A8FF : 0x6F42C1) }
    var string: Color { Color(hex: scheme == .dark ? 0x79C0FF : 0x032F62) }
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

enum RoomDates {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "h:mm a"
        return f
    }()
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()
}

struct Avatar: View {
    let user: User
    var size: CGFloat = 35.27
    static let palette: [UInt32] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C,
        0xBF1B1B, 0x736B1E, 0xD07B53, 0x736356, 0xAD1D1D, 0xBF7C2A,
        0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E
    ]
    static func color(_ id: Int) -> Color {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return Color(hex: palette[Int(~crc) % palette.count])
    }
    var body: some View {
        Text(String(user.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Self.color(user.id), in: Circle())
            .accessibilityHidden(true)
    }
}

/// The proposal is the entire strip width; children keep their intrinsic width and wrap as pills.
struct BoostFlow: Layout {
    var gap: CGFloat = 6.4
    var rowGap: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 320, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in layout.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                 proposal: ProposedViewSize(layout.sizes[index]))
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint], sizes: [CGSize]) {
        var points: [CGPoint] = [], sizes: [CGSize] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, usedWidth: CGFloat = 0
        for child in subviews {
            let size = child.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width { x = 0; y += lineHeight + rowGap; lineHeight = 0 }
            points.append(CGPoint(x: x, y: y)); sizes.append(size)
            x += size.width + gap
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, x - gap)
        }
        return (CGSize(width: min(width, usedWidth), height: y + lineHeight), points, sizes)
    }
}

/// CSS fit-content uses the available width once text wraps. Text's own ideal width
/// shrinks to its longest rendered line, so keep that distinction explicit for bubbles.
struct BubbleSizing: Layout {
    var width: CGFloat?
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let target: CGFloat
        if let width { target = width }
        else {
            let natural = content.sizeThatFits(.unspecified)
            target = min(proposal.width ?? natural.width, natural.width)
        }
        let fitted = content.sizeThatFits(ProposedViewSize(width: target, height: nil))
        return CGSize(width: target, height: fitted.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}
