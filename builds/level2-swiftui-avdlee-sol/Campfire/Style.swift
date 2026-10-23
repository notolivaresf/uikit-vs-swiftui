import SwiftUI
import CampfireKit

// Values transcribed from Fixtures/constants.json. Fixtures are never read at runtime.
enum CampfireStyle {
    static let screenPadding = 14.01
    static let avatar = 35.27
    static let bubbleInset = 26.79
    static let bubbleRadius = 10.56
    static let bubbleX = 15.12
    static let bubbleY = 10.56
    static let rowGap = 21.28
    static let palette: [UInt32] = [
        0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C,
        0xBF1B1B, 0x736B1E, 0xD07B53, 0x736356, 0xAD1D1D, 0xBF7C2A,
        0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E
    ]

    static func avatarColor(_ id: Int) -> Color {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in String(id).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 }
        }
        return Color(hex: palette[Int(~crc) % palette.count])
    }
}

struct RoomColors {
    let dark: Bool
    init(_ scheme: ColorScheme) { dark = scheme == .dark }
    var background: Color { dark ? .black : .white }
    var text: Color { dark ? .white : .black }
    var bubble: Color { Color(hex: dark ? 0x222222 : 0xF3F2EE) }
    var border: Color { Color(hex: dark ? 0x2E2E2E : 0xE5E4E1) }
    var strongBorder: Color { Color(hex: dark ? 0x555555 : 0xAFAEAA) }
    var red: Color { Color(hex: dark ? 0xFF7563 : 0xBE1600) }
    var mention: Color { red.opacity(dark ? 0.2 : 0.1) }
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

struct InitialAvatar: View {
    let user: User
    var size: CGFloat = CampfireStyle.avatar
    private var initial: AttributedString {
        var value = AttributedString(String(user.name.prefix(1)))
        value.foregroundColor = .white
        return value
    }
    var body: some View {
        Canvas { context, bounds in
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: bounds)),
                         with: .color(CampfireStyle.avatarColor(user.id)))
            var text = context.resolve(Text(initial).font(.system(size: size * 0.46, weight: .bold)))
            text.shading = .color(.white)
            context.draw(text, at: CGPoint(x: bounds.width / 2, y: bounds.height / 2))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(user.name)
    }
}

struct InertIcon: View {
    let symbol: String
    let label: String
    var size: CGFloat = 42
    @Environment(\.colorScheme) private var scheme
    private var glyph: CampfireGlyph.Kind? {
        switch symbol {
        case "ellipsis": .options
        case "line.3.horizontal": .menu
        case "magnifyingglass": .search
        case "qrcode.viewfinder": .qrcode
        case "doc.on.clipboard": .clipboard
        case "square.and.arrow.up": .sharelarge
        default: nil
        }
    }
    var body: some View {
        let colors = RoomColors(scheme)
        Button {} label: {
            Group {
                if let glyph { CampfireGlyph(kind: glyph) }
                else { Image(systemName: symbol).font(.system(size: size * 0.47, weight: .semibold)) }
            }
                .frame(width: size, height: size)
                .background(colors.background, in: Circle())
                .overlay(Circle().strokeBorder(colors.strongBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A line-wrapping boost strip; every child keeps its own stable boost identity.
struct BoostFlow: Layout {
    var spacing: CGFloat = 5.2
    struct Arrangement {
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }
    func arrange(_ subviews: Subviews, width: CGFloat) -> Arrangement {
        var result = Arrangement()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            result.frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            result.size.width = max(result.size.width, x - spacing)
        }
        result.size.height = y + lineHeight
        return result
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 340).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews, width: bounds.width)
        for (view, frame) in zip(subviews, arrangement.frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(frame.size))
        }
    }
}

/// CSS fit-content behavior: short messages hug their contents; wrapping messages use the full
/// available width instead of shrinking to the longest rendered line.
struct BubbleFit: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let natural = content.sizeThatFits(.unspecified)
        let width = min(natural.width, proposal.width ?? natural.width)
        return CGSize(width: width, height: content.sizeThatFits(.init(width: width, height: nil)).height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

struct AddBoostButton: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = RoomColors(scheme)
        Button {} label: {
            CampfireGlyph(kind: .boost).frame(width: 20, height: 20)
                .frame(width: 28.64, height: 28.64)
                .background(colors.background, in: Circle())
                .overlay(Circle().strokeBorder(colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add boost")
    }
}

struct CampfireGlyph: View {
    enum Kind: String { case document, download, share, boost, bubble, notification, options, menu, search, paperclip, arrow, qrcode, clipboard, sharelarge, person, more }
    let kind: Kind
    @Environment(\.colorScheme) private var scheme
    private var size: CGSize {
        switch kind {
        case .notification: CGSize(width: 21.00000000, height: 20.66666667)
        case .options: CGSize(width: 21.00000000, height: 6.00000000)
        case .menu: CGSize(width: 19.66666667, height: 16.66666667)
        case .search: CGSize(width: 21.00000000, height: 20.66666667)
        case .bubble: CGSize(width: 22.66666667, height: 21.00000000)
        case .paperclip: CGSize(width: 20.66666667, height: 18.66666667)
        case .arrow: CGSize(width: 12.33333333, height: 13.33333333)
        case .qrcode: CGSize(width: 20.00000000, height: 20.66666667)
        case .clipboard: CGSize(width: 20.33333333, height: 20.66666667)
        case .sharelarge: CGSize(width: 14.00000000, height: 20.66666667)
        case .share: CGSize(width: 12.00000000, height: 17.33333333)
        case .document: CGSize(width: 18.66666667, height: 22.66666667)
        case .download: CGSize(width: 16.66666667, height: 17.33333333)
        case .boost: CGSize(width: 14.66666667, height: 14.33333333)
        case .person: CGSize(width: 16.66666667, height: 20.66666667)
        case .more: CGSize(width: 16.66666667, height: 5.33333333)
        }
    }
    var body: some View {
        Image("Glyph-" + kind.rawValue)
            .renderingMode(.template)
            .resizable()
            .frame(width: size.width, height: size.height)
            .foregroundStyle(kind == .arrow ? RoomColors(scheme).background : RoomColors(scheme).text)
            .accessibilityHidden(true)
    }
}
