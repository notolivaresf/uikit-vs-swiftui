import UIKit
import CampfireKit

/// Colours from Fixtures/constants.json (Campfire light and dark).
enum Palette {
    static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor { dynamic(rgb(light), rgb(dark)) }

    static let background = dynamic(0xFFFFFF, 0x000000)
    static let text = dynamic(0x000000, 0xFFFFFF)
    static let textHalf = dynamic(rgb(0x000000, 0.5), rgb(0xFFFFFF, 0.5))
    static let bubble = dynamic(0xF3F2EE, 0x222222)
    static let border = dynamic(0xF3F2EE, 0x222222)
    static let borderDark = dynamic(0xE5E4E1, 0x2E2E2E)
    static let borderDarker = dynamic(0xAFAEAA, 0x555555)
    static let link = dynamic(0x0066EF, 0x43ABFF)
    /// Campfire red at 10% over white (light) and 20% over black (dark), flattened so overlapping rows stay solid.
    static let mentionBubble = dynamic(UIColor(red: (255 * 0.9 + 190 * 0.1) / 255, green: (255 * 0.9 + 22 * 0.1) / 255,
                                               blue: (255 * 0.9) / 255, alpha: 1),
                                       UIColor(red: 255 * 0.2 / 255, green: 117 * 0.2 / 255, blue: 99 * 0.2 / 255, alpha: 1))
    static let codeKeyword = dynamic(0xD73A49, 0xFF7B72)
    static let codeEntity = dynamic(0x6F42C1, 0xD2A8FF)
    static let codeConstant = dynamic(0x005CC5, 0x79C0FF)
    static let codeString = dynamic(0x032F62, 0x79C0FF)
    static let codeComment = dynamic(0x6A737D, 0x8B949E)
    static let alertOrange = rgb(0xFF6A0D)

    static let avatarHex: [UInt32] = [0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
                                      0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E]
    private static var avatarCache: [Int: UIColor] = [:]

    /// Campfire: crc32(user id as text) % 18.
    static func avatar(_ userID: Int) -> UIColor {
        if let c = avatarCache[userID] { return c }
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in String(userID).utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        crc = ~crc
        let c = rgb(avatarHex[Int(crc % UInt32(avatarHex.count))])
        if avatarCache.count < 1000 { avatarCache[userID] = c }
        return c
    }
}

/// Fixed geometry from constants.json (points).
enum Geo {
    static let padX: CGFloat = 14.01
    static let avatar: CGFloat = 35.27
    static let avatarRing: CGFloat = 2
    static let bubbleLeft: CGFloat = 40.8
    static let bubbleRightInset: CGFloat = 14.0
    static let mineMinLeft: CGFloat = 64.23
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePadY: CGFloat = 10.56
    static let bubblePadX: CGFloat = 15.12
    static let rowTopToBubble: CGFloat = 1.59
    static let bubbleBottomMargin: CGFloat = 1.6
    static let rowGap: CGFloat = 21.28
    static let threadedGap: CGFloat = 21.28 - 22.48
    static let metaToBody: CGFloat = 2.76
    static let nameTimeGap: CGFloat = 5
    static let timeToDots: CGFloat = 12.6
    static let dotsWidth: CGFloat = 16.5
    static let dotsTrailing: CGFloat = 14
    static let sepMargin: CGFloat = 16.945
    static let sepPillPadX: CGFloat = 23.5
    static let sepPillPadY: CGFloat = 8.5
    static let sepLine: CGFloat = 2
    static let imageMax: CGFloat = 300
    static let imageInset: CGFloat = 1
    static let imageTop: CGFloat = 44.0
    static let imageToBoosts: CGFloat = 5
    static let imageBoostsBottom: CGFloat = 7.42
    static let imageBoostsX: CGFloat = 10.9
    static let codeRadius: CGFloat = 6.4
    static let codePad: CGFloat = 12.8
    static let codeBorder: CGFloat = 1
    static let blockGap: CGFloat = 6
    static let fileLine: CGFloat = 31.16
    static let boostTop: CGFloat = 4
    static let pillHeight: CGFloat = 28.64
    static let pillGapX: CGFloat = 5
    static let pillGapY: CGFloat = 4
    static let contentBottomPad: CGFloat = 1.6
    static let headerHeight: CGFloat = 60
    static let welcomeHeight: CGFloat = 400
}

/// Text settings for one Dynamic Type size. Every font the list measures and draws comes from here.
final class TextStyle {
    let scale: CGFloat
    let body: UIFont
    let bodyLine: CGFloat
    let name: UIFont
    let meta: UIFont
    let metaLine: CGFloat
    let separator: UIFont
    let separatorLine: CGFloat
    let emoji: UIFont
    let emojiLine: CGFloat
    let code: UIFont
    let codeLine: CGFloat
    let mention: UIFont
    let boostEmoji: UIFont
    let boostText: UIFont
    let fileName: UIFont
    let pillHeight: CGFloat
    let pillAvatar: UIFont
    static let avatarInitial = UIFont.systemFont(ofSize: 16, weight: .bold)

    init(traits: UITraitCollection) {
        let s = UIFontMetrics(forTextStyle: .body).scaledValue(for: 1000, compatibleWith: traits) / 1000
        scale = s
        body = .systemFont(ofSize: 16 * s)
        bodyLine = 22.4 * s
        name = .systemFont(ofSize: 12.8 * s, weight: .bold)
        meta = .systemFont(ofSize: 12.8 * s)
        metaLine = 19.2 * s
        separator = .systemFont(ofSize: 12.8 * s, weight: .semibold)
        separatorLine = 17.92 * s
        emoji = .systemFont(ofSize: 38.4 * s)
        emojiLine = 53.76 * s
        code = .monospacedSystemFont(ofSize: 12.8 * s, weight: .regular)
        codeLine = 17.92 * s
        mention = .systemFont(ofSize: 16 * s, weight: .semibold)
        boostEmoji = .systemFont(ofSize: 17.6 * s)
        boostText = .systemFont(ofSize: 13.6 * s)
        fileName = .systemFont(ofSize: 16 * s)
        pillHeight = (Geo.pillHeight * s).rounded(.up)
        pillAvatar = .systemFont(ofSize: ((pillHeight - 5.2) * 0.45).rounded(), weight: .heavy)
    }

    func paragraph(line: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = line
        p.maximumLineHeight = line
        p.lineBreakMode = .byWordWrapping
        return p
    }

    /// Half the extra space of a line taller than the font (CSS puts it above and below the glyphs).
    func baseline(_ font: UIFont, line: CGFloat) -> CGFloat { (line - font.lineHeight) / 2 }
}

/// Cached strings that repeat: one per minute, one per day.
enum Formats {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()
    private static var times: [Int: String] = [:]
    private static var days: [Int: String] = [:]

    static func time(_ date: Date) -> String {
        let key = Int(date.timeIntervalSince1970 / 60)
        if let s = times[key] { return s }
        let s = timeFormatter.string(from: date)
        if times.count > 4000 { times.removeAll(keepingCapacity: true) }
        times[key] = s
        return s
    }

    static func day(_ date: Date) -> String {
        let key = Int(date.timeIntervalSince1970 / 86_400)
        if let s = days[key] { return s }
        let s = dayFormatter.string(from: date).uppercased()
        if days.count > 1000 { days.removeAll(keepingCapacity: true) }
        days[key] = s
        return s
    }
}

/// Small images drawn once: inline mention avatars and the add-boost glyph.
enum Glyphs {
    private static var mentionAvatars: [String: UIImage] = [:]

    static func initial(of name: String) -> String { name.first.map { String($0).uppercased() } ?? "?" }

    static func mentionAvatar(user: User, diameter: CGFloat, trailing: CGFloat) -> UIImage {
        let key = "\(user.id)-\(Int(diameter * 10))-\(Int(trailing * 10))"
        if let img = mentionAvatars[key] { return img }
        let img = UIGraphicsImageRenderer(size: CGSize(width: diameter + trailing, height: diameter)).image { _ in
            Palette.avatar(user.id).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).fill()
            let font = UIFont.systemFont(ofSize: diameter * 0.48, weight: .heavy)
            let s = initial(of: user.name) as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let size = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (diameter - size.width) / 2, y: (diameter - size.height) / 2), withAttributes: attrs)
        }
        if mentionAvatars.count > 400 { mentionAvatars.removeAll() }
        mentionAvatars[key] = img
        return img
    }

    static let addBoost: UIImage = {
        let size = CGSize(width: 20, height: 20)
        let face = UIImage(systemName: "face.smiling", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))!
        let plus = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .heavy))!
        return UIGraphicsImageRenderer(size: size).image { ctx in
            face.draw(in: CGRect(x: 0, y: 0, width: 17, height: 17 * face.size.height / face.size.width))
            ctx.cgContext.setBlendMode(.clear)
            ctx.cgContext.fillEllipse(in: CGRect(x: 10, y: 10, width: 10.5, height: 10.5))
            ctx.cgContext.setBlendMode(.normal)
            plus.draw(in: CGRect(x: 11.5, y: 11.5, width: 7.5, height: 7.5))
        }.withRenderingMode(.alwaysTemplate)
    }()
}
