import SwiftUI
import CoreText
import CampfireKit

struct RoomTheme {
    let dark: Bool
    var background: Color { dark ? .black : .white }
    var text: Color { dark ? .white : .black }
    var bubble: Color { Color(hex: dark ? 0x222222 : 0xF3F2EE) }
    var border: Color { Color(hex: dark ? 0x2E2E2E : 0xE5E4E1) }
    var outline: Color { Color(hex: dark ? 0x555555 : 0xAFAEAA) }
    var red: Color { Color(hex: dark ? 0xFF7563 : 0xBE1600) }
    var mention: Color { red.opacity(dark ? 0.20 : 0.10) }
    var keyword: Color { Color(hex: dark ? 0xFF7B72 : 0xD73A49) }
    var entity: Color { Color(hex: dark ? 0xD2A8FF : 0x6F42C1) }
    var string: Color { Color(hex: dark ? 0x79C0FF : 0x032F62) }
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

enum RoomFonts {
    static func nativeHeight(_ size: CGFloat, mono: Bool = false) -> CGFloat {
        let font = CTFontCreateWithName((mono ? "Menlo" : ".AppleSystemUIFont") as CFString, size, nil)
        return CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }
}

/// Explicit CSS-style line boxes, including the first and last line's leading.
struct LineText: View {
    let text: Text
    let size: CGFloat
    let lineHeight: CGFloat
    var mono = false
    var compactInlineImages = false
    var body: some View {
        let leading = max(0, lineHeight - RoomFonts.nativeHeight(size, mono: mono))
        text
            .font(mono ? .custom("Menlo", size: size) : .system(size: size))
            .lineSpacing(compactInlineImages ? 0 : leading)
            .padding(.vertical, leading / 2)
            .fixedSize(horizontal: false, vertical: true)
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
    var ring = false

    private var color: Color {
        let palette: [UInt32] = [0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C,
                                0xBF1B1B, 0x736B1E, 0xD07B53, 0x736356, 0xAD1D1D, 0xBF7C2A,
                                0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E]
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in String(user.id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xEDB8_8320 : 0) }
        }
        return Color(hex: palette[Int(~crc) % palette.count])
    }

    var body: some View {
        Text(String(user.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.454, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .overlay { if ring { Circle().strokeBorder(.background, lineWidth: 1.6) } }
            .accessibilityHidden(true)
    }
}

/// A wrapping layout for the boost strip; its final subview is always add-boost.
struct BoostFlow: Layout {
    var gap: CGFloat = 5.3
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, point) in layout.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                  anchor: .topLeading, proposal: .unspecified)
        }
    }
    private func arrangement(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let limit = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > limit { y += rowHeight + gap; x = 0; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            width = max(width, x + s.width)
            x += s.width + gap
            rowHeight = max(rowHeight, s.height)
        }
        return (CGSize(width: min(width, limit), height: y + rowHeight), points)
    }
}

@MainActor private enum MentionImageCache {
    static var images: [String: CGImage] = [:]
}
@MainActor enum MentionImages {
    static func image(user: User, scale: CGFloat) -> CGImage {
        let key = "\(user.id)-\(scale)"
        if let image = MentionImageCache.images[key] { return image }
        let renderer = ImageRenderer(content: Avatar(user: user, size: 18 * scale))
        renderer.scale = 3
        let image = renderer.cgImage!
        MentionImageCache.images[key] = image
        return image
    }
}

/// CSS fit-content keeps a wrapped bubble at its maximum width, rather than
/// shrinking it to the width of the longest line after wrapping.
struct BubbleWidth: Layout {
    let maximum: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        let ideal = view.sizeThatFits(.unspecified)
        let width = min(ideal.width, min(maximum, proposal.width ?? maximum))
        let fitted = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: fitted.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                             proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

extension MessagePresentation {
    var spacingBefore: CGFloat { isThreaded || isFirstOfDay ? 0 : 21.28 }
}
