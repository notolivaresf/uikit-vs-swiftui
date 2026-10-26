import UIKit
import CampfireKit

/// One row to show: the message and how it is presented after the one before it.
public struct RowItem {
    public let message: Message
    public let presentation: MessagePresentation
    public init(message: Message, presentation: MessagePresentation) {
        self.message = message
        self.presentation = presentation
    }
}

/// What a row's size depends on besides the message: the list width and the text size.
public struct RowStyle: Equatable {
    public var width: CGFloat
    public var category: UIContentSizeCategory
    public init(width: CGFloat, category: UIContentSizeCategory) {
        self.width = width
        self.category = category
    }
}

/// The scaled fonts for one text size.
public struct RowFonts {
    public let body, bold, mono, author, time, separator, emoji, boost: UIFont
    init(_ category: UIContentSizeCategory) {
        let t = UITraitCollection(preferredContentSizeCategory: category)
        func scaled(_ f: UIFont, _ style: UIFont.TextStyle) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: f, compatibleWith: t)
        }
        body = scaled(.systemFont(ofSize: 16), .body)
        bold = scaled(.systemFont(ofSize: 16, weight: .semibold), .body)
        mono = scaled(.monospacedSystemFont(ofSize: 12.8, weight: .regular), .body)
        author = scaled(.systemFont(ofSize: 12.8, weight: .bold), .footnote)
        time = scaled(.systemFont(ofSize: 12.8), .footnote)
        separator = scaled(.systemFont(ofSize: 12.8, weight: .semibold), .footnote)
        emoji = scaled(.systemFont(ofSize: 38.4), .largeTitle)
        boost = scaled(.systemFont(ofSize: 17.6), .body)
    }
    nonisolated(unsafe) private static var cache: [UIContentSizeCategory: RowFonts] = [:]
    public static func forCategory(_ c: UIContentSizeCategory) -> RowFonts {
        if let f = cache[c] { return f }
        let f = RowFonts(c)
        cache[c] = f
        return f
    }
}

/// Every frame of one row, in the row's own coordinates. `RowGeometry.make` is the one place a row's size is worked out:
/// the measurer takes `height` from it, the row view takes the frames.
public struct RowGeometry {
    public var height: CGFloat = 0
    public var separator: CGRect?
    public var avatar: CGRect?
    public var name: CGRect?
    public var time: CGRect?
    public var bubble: CGRect?
    public var text: CGRect?
    public var image: CGRect?
    public var file: CGRect?
    public var pills: [CGRect] = []
    public var addBoost: CGRect?
    public var attributedText = NSAttributedString()
    public var emojiOnly = false

    static let padX: CGFloat = 14, avatarSize: CGFloat = 35.27, gap: CGFloat = 6.65
    static let bubblePadX: CGFloat = 15.12, bubblePadY: CGFloat = 10.56
    static let pillHeight: CGFloat = 28, pillGap: CGFloat = 6

    public static func make(_ item: RowItem, users: [UserID: User], style: RowStyle) -> RowGeometry {
        let m = item.message, p = item.presentation
        let f = RowFonts.forCategory(style.category)
        var g = RowGeometry()
        var y: CGFloat = 0
        let w = style.width

        if p.isFirstOfDay {
            let label = Self.dayString(m.createdAt)
            let tw = ceil((label as NSString).size(withAttributes: [.font: f.separator]).width) + 24
            let th = ceil(f.separator.lineHeight) + 8
            g.separator = CGRect(x: (w - tw) / 2, y: 12, width: tw, height: th)
            y = 12 + th + 6
        }
        y += p.isThreaded ? 1.6 : 12

        let bubbleLeft = padX + avatarSize + gap
        let bubbleMax = w - bubbleLeft - padX
        if !p.isThreaded {
            let lh = ceil(max(f.author.lineHeight, f.time.lineHeight))
            let name = users[m.creatorID]?.name ?? ""
            let nw = ceil((name as NSString).size(withAttributes: [.font: f.author]).width)
            let tw = ceil((Self.timeString(m.createdAt) as NSString).size(withAttributes: [.font: f.time]).width)
            g.avatar = CGRect(x: p.isMine ? w - padX - avatarSize : padX, y: y, width: avatarSize, height: avatarSize)
            if p.isMine {
                let right = w - bubbleLeft
                g.time = CGRect(x: right - tw, y: y, width: tw, height: lh)
                g.name = CGRect(x: right - tw - 6 - nw, y: y, width: nw, height: lh)
            } else {
                g.name = CGRect(x: bubbleLeft, y: y, width: nw, height: lh)
                g.time = CGRect(x: bubbleLeft + nw + 6, y: y, width: tw, height: lh)
            }
            y += lh + 1.6
        }

        // Content: text (and code), then an image or a file.
        let attr = Self.attributedText(m, users: users, fonts: f)
        g.attributedText = attr
        g.emojiOnly = m.isEmojiOnly
        let innerMax = bubbleMax - 2 * bubblePadX
        var textSize = CGSize.zero
        if attr.length > 0 {
            let r = attr.boundingRect(with: CGSize(width: g.emojiOnly ? bubbleMax : innerMax, height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            textSize = CGSize(width: ceil(r.width), height: ceil(r.height))
        }
        var imageSize = CGSize.zero
        var fileHeight: CGFloat = 0
        switch m.attachment {
        case .image(let pw, let ph, _)?:
            let iw = min(300, bubbleMax)
            imageSize = CGSize(width: iw, height: (iw * CGFloat(ph) / CGFloat(pw)).rounded())
        case .file?: fileHeight = 44
        case nil: break
        }

        if g.emojiOnly {
            let bx = p.isMine ? w - bubbleLeft - textSize.width : bubbleLeft
            g.text = CGRect(x: bx, y: y, width: textSize.width, height: textSize.height)
            y += textSize.height + 1.6
        } else {
            var contentW = textSize.width + 2 * bubblePadX
            contentW = max(contentW, imageSize.width, fileHeight > 0 ? 220 : 0)
            contentW = min(max(contentW, 60), bubbleMax)
            var inner: CGFloat = 0
            var parts: [(kind: Int, h: CGFloat)] = []
            if imageSize.height > 0 { parts.append((0, imageSize.height)); inner += imageSize.height }
            if fileHeight > 0 { parts.append((1, fileHeight)); inner += fileHeight }
            if textSize.height > 0 { parts.append((2, textSize.height + 2 * bubblePadY)); inner += textSize.height + 2 * bubblePadY }
            let bx = p.isMine ? w - bubbleLeft - contentW : bubbleLeft
            g.bubble = CGRect(x: bx, y: y, width: contentW, height: inner)
            var iy = y
            for part in parts {
                switch part.kind {
                case 0: g.image = CGRect(x: bx, y: iy, width: contentW, height: part.h)
                case 1: g.file = CGRect(x: bx, y: iy, width: contentW, height: part.h)
                default: g.text = CGRect(x: bx + bubblePadX, y: iy + bubblePadY, width: contentW - 2 * bubblePadX, height: textSize.height)
                }
                iy += part.h
            }
            y += inner + 1.6
        }

        if !m.boosts.isEmpty {
            y += 4
            let left = p.isMine ? padX : bubbleLeft
            let right = p.isMine ? w - bubbleLeft : w - padX
            var x = left
            for b in m.boosts {
                let ew = ceil((b.content as NSString).size(withAttributes: [.font: f.boost]).width)
                let pw = 8 + 20 + 4 + ew + 8
                if x + pw > right && x > left { x = left; y += pillHeight + pillGap }
                g.pills.append(CGRect(x: x, y: y, width: pw, height: pillHeight))
                x += pw + pillGap
            }
            if x + pillHeight > right && x > left { x = left; y += pillHeight + pillGap }
            g.addBoost = CGRect(x: x, y: y, width: pillHeight, height: pillHeight)
            y += pillHeight
        }
        g.height = ceil(y + 4)
        return g
    }

    static func attributedText(_ m: Message, users: [UserID: User], fonts f: RowFonts) -> NSAttributedString {
        let out = NSMutableAttributedString()
        if m.isEmojiOnly {
            out.append(NSAttributedString(string: m.plainText.trimmingCharacters(in: .whitespaces), attributes: [.font: f.emoji]))
            return out
        }
        var afterCode = false
        for block in m.blocks {
            switch block {
            case .text(let t):
                if afterCode { out.append(NSAttributedString(string: "\n", attributes: [.font: f.body])); afterCode = false }
                out.append(NSAttributedString(string: t, attributes: [.font: f.body]))
            case .mention(let id):
                if afterCode { out.append(NSAttributedString(string: "\n", attributes: [.font: f.body])); afterCode = false }
                out.append(NSAttributedString(string: "@" + (users[id]?.name ?? "someone"), attributes: [.font: f.bold]))
            case .code(_, let source):
                if out.length > 0 { out.append(NSAttributedString(string: "\n", attributes: [.font: f.body])) }
                out.append(NSAttributedString(string: source, attributes: [.font: f.mono]))
                afterCode = true
            }
        }
        return out
    }

    nonisolated(unsafe) static let dayFormatter: DateFormatter = {
        let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.timeZone = TimeZone(identifier: "UTC")
        d.dateFormat = "MMMM d, yyyy"; return d
    }()
    nonisolated(unsafe) static let timeFormatter: DateFormatter = {
        let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.timeZone = TimeZone(identifier: "UTC")
        d.dateFormat = "h:mm a"; return d
    }()
    static func dayString(_ d: Date) -> String { dayFormatter.string(from: d).uppercased() }
    static func timeString(_ d: Date) -> String { timeFormatter.string(from: d) }
}
