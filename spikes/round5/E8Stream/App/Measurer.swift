import UIKit
import CampfireKit

enum BubbleStyle { case normal, mention, none }

struct PillGeo {
    var frame: CGRect
    var avatarColor: UIColor
    var initial: String
    var content: NSAttributedString
    var contentFrame: CGRect   // in pill coordinates
}

struct FileGeo {
    var icon: CGRect
    var name: NSAttributedString
    var nameFrame: CGRect
    var download: CGRect
    var share: CGRect
}

/// What a row shows, copied out of a `Message` (or built directly for the reference-row fixture screen).
struct RowContent {
    let id: MessageID
    let creatorID: UserID
    let createdAt: Date
    let blocks: [Block]
    let attachment: Attachment?
    let isEmojiOnly: Bool

    init(_ m: Message) {
        id = m.id; creatorID = m.creatorID; createdAt = m.createdAt
        blocks = m.blocks; attachment = m.attachment; isEmojiOnly = m.isEmojiOnly
    }

    init(id: MessageID, creatorID: UserID, createdAt: Date, blocks: [Block], attachment: Attachment?, isEmojiOnly: Bool) {
        self.id = id; self.creatorID = creatorID; self.createdAt = createdAt
        self.blocks = blocks; self.attachment = attachment; self.isEmojiOnly = isEmojiOnly
    }
}

struct RowFlags {
    let isThreaded: Bool
    let isFirstOfDay: Bool
    let isMine: Bool
    let mentionsMe: Bool

    init(_ p: MessagePresentation) {
        isThreaded = p.isThreaded; isFirstOfDay = p.isFirstOfDay; isMine = p.isMine; mentionsMe = p.mentionsMe
    }

    init(threaded: Bool, firstOfDay: Bool, mine: Bool, mentionsMe: Bool) {
        isThreaded = threaded; isFirstOfDay = firstOfDay; isMine = mine; self.mentionsMe = mentionsMe
    }
}

/// Who a user id is: name and avatar colour.
struct People {
    let name: (UserID) -> String
    let color: (UserID) -> UIColor
}

/// Everything a row needs to draw, worked out once per message for one width and text size.
/// All frames are in the cell's coordinates.
final class RowGeo {
    let id: MessageID
    let revision: Int
    var height: CGFloat = 0
    var gapBefore: CGFloat = 0

    var separatorText: NSAttributedString?
    var separatorPill: CGRect = .zero
    var separatorLine: CGRect = .zero

    var bubble: CGRect = .zero
    var style: BubbleStyle = .normal
    var avatar: CGRect?
    var avatarColor: UIColor = .clear
    var initial = ""

    var name: NSAttributedString?
    var nameFrame: CGRect = .zero
    var time: NSAttributedString = NSAttributedString()
    var timeFrame: CGRect = .zero
    var dots: CGRect = .zero

    var body: NSAttributedString?
    var bodyFrame: CGRect = .zero
    var code: NSAttributedString?
    var codeBox: CGRect = .zero
    var codeTextFrame: CGRect = .zero
    var image: CGRect?
    var imageColor: UIColor = .clear
    var file: FileGeo?
    var pills: [PillGeo] = []
    var addBoost: CGRect?

    var copyText = ""

    init(id: MessageID, revision: Int) { self.id = id; self.revision = revision }
}

/// Measures rows with the same attributed strings the cells draw (TextKit 2 text views paired with
/// `boundingRect(with:options:[.usesLineFragmentOrigin, .usesFontLeading])`).
final class Measurer {
    let width: CGFloat
    let type: TypeScale
    private let people: People

    private let bodyFont: UIFont, mentionFont: UIFont, authorFont: UIFont, metaFont: UIFont
    private let separatorFont: UIFont, emojiFont: UIFont, codeFont: UIFont
    private let boostEmojiFont: UIFont, boostTextFont: UIFont
    private let bodyAttrs: [NSAttributedString.Key: Any]
    private let mentionAttrs: [NSAttributedString.Key: Any]
    private let emojiAttrs: [NSAttributedString.Key: Any]
    private let codeAttrs: [NSAttributedString.Key: Any]
    private let authorAttrs: [NSAttributedString.Key: Any]
    private let timeAttrs: [NSAttributedString.Key: Any]
    private let separatorAttrs: [NSAttributedString.Key: Any]
    private let fileAttrs: [NSAttributedString.Key: Any]
    private let spaceWidth: CGFloat

    private var timeCache: [Int: (NSAttributedString, CGFloat)] = [:]
    private var nameCache: [UserID: (NSAttributedString, CGFloat)] = [:]
    private var mentionImages: [String: UIImage] = [:]

    init(width: CGFloat, type: TypeScale, people: People) {
        self.width = width
        self.type = type
        self.people = people
        bodyFont = type.body; mentionFont = type.mention; authorFont = type.author; metaFont = type.meta
        separatorFont = type.separator; emojiFont = type.emoji; codeFont = type.code
        boostEmojiFont = type.boostEmoji; boostTextFont = type.boostText

        bodyAttrs = Measurer.lineAttrs(font: bodyFont, line: type.bodyLine, color: Theme.text)
        mentionAttrs = Measurer.lineAttrs(font: mentionFont, line: type.bodyLine, color: Theme.text, baseFont: bodyFont)
        var ea = Measurer.lineAttrs(font: emojiFont, line: type.emojiLine, color: Theme.text)
        ea[.kern] = -4.6 * type.s   // the browser advances big emoji about 1.11 em; Apple Color Emoji 1.23 em
        emojiAttrs = ea
        var ca = Measurer.lineAttrs(font: codeFont, line: type.codeLine, color: Theme.text, wrapChars: true)
        ca[.kern] = -0.21 * type.s   // SF Mono here runs a little wider than the browser's ui-monospace
        codeAttrs = ca
        authorAttrs = [.font: authorFont, .foregroundColor: Theme.text]
        timeAttrs = [.font: metaFont, .foregroundColor: Theme.dimText]
        separatorAttrs = [.font: separatorFont, .foregroundColor: Theme.text]
        fileAttrs = [.font: bodyFont, .foregroundColor: Theme.text]
        spaceWidth = (" " as NSString).size(withAttributes: [.font: metaFont]).width
    }

    static func lineAttrs(font: UIFont, line: CGFloat, color: UIColor, baseFont: UIFont? = nil,
                          wrapChars: Bool = false) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = line
        p.maximumLineHeight = line
        if wrapChars { p.lineBreakMode = .byWordWrapping }
        return [.font: font, .foregroundColor: color, .paragraphStyle: p]
    }

    // MARK: Helpers

    private static let scale = UIScreen.main.scale
    @inline(__always) private func px(_ v: CGFloat) -> CGFloat { ceil(v * Measurer.scale - 0.001) / Measurer.scale }

    private func size(_ s: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        let r = s.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        // Heights stay exact (n fixed-height lines) so rows add up like the CSS; widths round up to pixels.
        return CGSize(width: px(r.width), height: (r.height * 100).rounded() / 100)
    }

    private func lineWidth(_ s: String, _ attrs: [NSAttributedString.Key: Any]) -> CGFloat {
        px((s as NSString).size(withAttributes: attrs).width)
    }

    private func time(_ date: Date) -> (NSAttributedString, CGFloat) {
        let secs = Int(date.timeIntervalSince1970)
        let minuteOfDay = ((secs % 86_400) + 86_400) % 86_400 / 60
        if let c = timeCache[minuteOfDay] { return c }
        let h = minuteOfDay / 60, m = minuteOfDay % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        let s = "\(h12):\(m < 10 ? "0" : "")\(m) \(h < 12 ? "AM" : "PM")"
        let v = (NSAttributedString(string: s, attributes: timeAttrs), lineWidth(s, timeAttrs))
        timeCache[minuteOfDay] = v
        return v
    }

    private func name(_ id: UserID) -> (NSAttributedString, CGFloat) {
        if let c = nameCache[id] { return c }
        let s = people.name(id)
        let v = (NSAttributedString(string: s, attributes: authorAttrs), lineWidth(s, authorAttrs))
        nameCache[id] = v
        return v
    }

    private static let months = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST",
                                 "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    static func dayString(_ date: Date) -> String {
        let c = Grouping.calendar.dateComponents([.year, .month, .day], from: date)
        return "\(months[(c.month ?? 1) - 1]) \(c.day ?? 1), \(c.year ?? 2025)"
    }

    static func initial(of name: String) -> String { name.first.map { String($0).uppercased() } ?? "?" }

    /// The mention's small avatar, with the browser's spacing (1.4 before, 4 after) baked into the image.
    private func mentionImage(_ user: UserID) -> UIImage {
        let d = (17.6 * type.s).rounded()
        let key = "\(user)-\(d)"
        if let i = mentionImages[key] { return i }
        let color = people.color(user)
        let initial = Measurer.initial(of: people.name(user))
        let size = CGSize(width: d + mentionPadLeft + mentionPadRight, height: d)
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(ovalIn: CGRect(x: mentionPadLeft, y: 0, width: d, height: d)).fill()
            let f = UIFont.systemFont(ofSize: d * 0.5, weight: .bold)
            let a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: UIColor.white]
            let sz = (initial as NSString).size(withAttributes: a)
            (initial as NSString).draw(at: CGPoint(x: mentionPadLeft + (d - sz.width) / 2, y: (d - sz.height) / 2), withAttributes: a)
        }
        if mentionImages.count > 400 { mentionImages.removeAll() }
        mentionImages[key] = img
        return img
    }

    private let mentionPadLeft: CGFloat = 1.4
    private let mentionPadRight: CGFloat = 3.3

    // MARK: Body strings

    /// Text and mention blocks as one paragraph run; code blocks are returned separately.
    private func bodyString(_ m: RowContent, emojiOnly: Bool) -> (NSAttributedString?, String?, String) {
        let out = NSMutableAttributedString()
        var code: String?
        var plain = ""
        for block in m.blocks {
            switch block {
            case .text(let t):
                out.append(NSAttributedString(string: t, attributes: emojiOnly ? emojiAttrs : bodyAttrs))
                plain += t
            case .mention(let uid):
                let att = NSTextAttachment(image: mentionImage(uid))
                let d = (17.6 * type.s).rounded()
                att.bounds = CGRect(x: 0, y: (bodyFont.capHeight - d) / 2 - 0.6 * type.s,
                                    width: d + mentionPadLeft + mentionPadRight, height: d)
                let a = NSMutableAttributedString(attachment: att)
                a.addAttributes(bodyAttrs, range: NSRange(location: 0, length: a.length))
                out.append(a)
                let n = people.name(uid)
                out.append(NSAttributedString(string: n, attributes: mentionAttrs))
                plain += n
            case .code(_, let src):
                code = code.map { $0 + "\n" + src } ?? src
            }
        }
        if let c = code { plain += plain.isEmpty ? c : "\n" + c }
        return (out.length > 0 ? out : nil, code, plain)
    }

    private static let keywords: Set<String> = [
        "def", "end", "class", "module", "if", "else", "elsif", "unless", "do", "return", "let", "var", "func",
        "import", "for", "in", "while", "struct", "SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT",
        "true", "false", "nil", "self",
    ]
    private static let entityIntroducers: Set<String> = ["def", "func", "class", "struct", "module"]

    private func codeString(_ src: String) -> NSAttributedString {
        let s = NSMutableAttributedString(string: src, attributes: codeAttrs)
        let chars = Array(src.utf16)
        var i = 0
        var lastWord = ""
        func isIdent(_ c: UInt16, first: Bool) -> Bool {
            (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || (!first && c >= 48 && c <= 57)
        }
        while i < chars.count {
            let c = chars[i]
            if c == 34 || c == 39 {   // string literal
                var j = i + 1
                while j < chars.count && chars[j] != c && chars[j] != 10 { j += 1 }
                j = min(j + 1, chars.count)
                s.addAttribute(.foregroundColor, value: Theme.codeString, range: NSRange(location: i, length: j - i))
                i = j
            } else if c == 35 && i + 1 < chars.count && chars[i + 1] != 123 || (c == 47 && i + 1 < chars.count && chars[i + 1] == 47) {
                var j = i
                while j < chars.count && chars[j] != 10 { j += 1 }
                s.addAttribute(.foregroundColor, value: Theme.codeComment, range: NSRange(location: i, length: j - i))
                i = j
            } else if isIdent(c, first: true) {
                var j = i + 1
                while j < chars.count && isIdent(chars[j], first: false) { j += 1 }
                let w = String(utf16CodeUnits: Array(chars[i..<j]), count: j - i)
                if Measurer.keywords.contains(w) {
                    s.addAttribute(.foregroundColor, value: Theme.codeKeyword, range: NSRange(location: i, length: j - i))
                } else if Measurer.entityIntroducers.contains(lastWord) {
                    s.addAttribute(.foregroundColor, value: Theme.codeEntity, range: NSRange(location: i, length: j - i))
                }
                lastWord = w
                i = j
            } else if c >= 48 && c <= 57 {
                var j = i + 1
                while j < chars.count && chars[j] >= 48 && chars[j] <= 57 { j += 1 }
                s.addAttribute(.foregroundColor, value: Theme.codeConstant, range: NSRange(location: i, length: j - i))
                i = j
            } else {
                if c != 32 { lastWord = "" }
                i += 1
            }
        }
        return s
    }

    // MARK: Row

    func measure(_ m: RowContent, _ p: RowFlags, boosts: [BoostItem], revision: Int) -> RowGeo {
        let g = RowGeo(id: m.id, revision: revision)
        let W = width
        let padX = Metrics.bubblePadX, padY = Metrics.bubblePadY
        let maxBubble = W - Metrics.bubbleLeft - Metrics.bubbleRightInset
        let maxInner = maxBubble - 2 * padX
        let metaLine = type.metaLine

        var y: CGFloat = 0
        if p.isFirstOfDay {
            let text = Measurer.dayString(m.createdAt)
            g.separatorText = NSAttributedString(string: text, attributes: separatorAttrs)
            let tw = lineWidth(text, separatorAttrs)
            let pillH = 2 * Metrics.separatorPadY + type.separatorLine
            let pillW = tw + 2 * Metrics.separatorPadX
            g.separatorPill = CGRect(x: ((W - pillW) / 2 * 3).rounded() / 3, y: Metrics.separatorTop, width: pillW, height: pillH)
            g.separatorLine = CGRect(x: Metrics.screenPadding, y: Metrics.separatorTop + pillH / 2 - 1,
                                     width: W - 2 * Metrics.screenPadding, height: 2)
            y = Metrics.separatorTop + pillH + Metrics.separatorBottom
        }
        g.gapBefore = p.isThreaded ? 0 : Metrics.rowGap
        let bubbleTop = y + (p.isThreaded ? Metrics.threadedTopInset : Metrics.rowTopInset)
        let showAuthor = !p.isThreaded

        // Header: name, time, menu dots.
        let (timeStr, timeW) = time(m.createdAt)
        g.time = timeStr
        var nameW: CGFloat = 0
        if showAuthor {
            let (n, w) = name(m.creatorID)
            g.name = n
            nameW = w
        }
        let headerW: CGFloat
        if p.isMine {
            // Campfire reserves about 30 pt of hidden actions before the dots in my own header.
            headerW = 30.8 + Metrics.dotsWidth + 13 + timeW + (showAuthor ? 6.3 + nameW : 0)
        } else {
            headerW = (showAuthor ? nameW + spaceWidth : 0) + timeW + 12.7 + Metrics.dotsWidth
        }

        let emojiOnly = m.isEmojiOnly
        let (body, code, plain) = bodyString(m, emojiOnly: emojiOnly)
        g.copyText = plain
        var innerW = headerW
        var fillsMax = false
        var cy = padY + metaLine + Metrics.metaToBody
        var bodyRel = CGRect.zero
        if let b = body {
            let sz = size(b, maxWidth: maxInner)
            let lineH = emojiOnly ? type.emojiLine : type.bodyLine
            let hardLines = CGFloat(b.string.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
            if sz.height > hardLines * lineH + 1 { fillsMax = true }
            g.body = b
            // TextKit puts a fixed line height's extra space above the glyphs; CSS splits it. Move the view up.
            let lift = (lineH - (emojiOnly ? emojiFont : bodyFont).lineHeight) / 2
            bodyRel = CGRect(x: padX - (emojiOnly ? 2 : 0), y: cy - lift, width: sz.width, height: ceil(sz.height + lift))
            cy += sz.height
            innerW = max(innerW, sz.width)
        }
        var codeRel = CGRect.zero, codeTextRel = CGRect.zero
        if let c = code {
            if body != nil { cy += 4 }
            let cs = codeString(c)
            let sz = size(cs, maxWidth: maxInner - 2 - 2 * Metrics.codePad)
            let lines = CGFloat(c.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
            if sz.height > lines * type.codeLine + 1 { fillsMax = true }
            g.code = cs
            codeRel = CGRect(x: padX + 1, y: cy + 1, width: sz.width + 2 * Metrics.codePad, height: sz.height + 2 * Metrics.codePad)
            let lift = (type.codeLine - codeFont.lineHeight) / 2
            codeTextRel = CGRect(x: Metrics.codePad, y: Metrics.codePad - lift, width: sz.width, height: ceil(sz.height + lift))
            cy += codeRel.height + 2
            innerW = max(innerW, codeRel.width + 2)
        }

        var isImage = false
        var bubbleW: CGFloat = 0
        var imageRel = CGRect.zero
        var fileRel: FileGeo?
        switch m.attachment {
        case .image(let iw, let ih, let color):
            isImage = true
            bubbleW = min(Metrics.imageMax, maxBubble)
            let w = bubbleW - 2
            let h = (w * CGFloat(ih) / CGFloat(max(iw, 1)) * 3).rounded() / 3
            let top = body != nil ? cy + 8 : cy + 11.48
            imageRel = CGRect(x: 1, y: top, width: w, height: h)
            g.imageColor = UIColor(red: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255, blue: CGFloat(color.b) / 255, alpha: 1)
            cy = top + h
        case .file(let fname, _):
            let line = type.fileLine
            let nameW = min(lineWidth(fname, fileAttrs), maxInner - 105.8)
            let x0 = padX
            let nameFrame = CGRect(x: x0 + 27, y: cy + (line - type.bodyLine) / 2, width: nameW, height: type.bodyLine)
            let dl = CGRect(x: nameFrame.maxX + 13, y: cy + (line - 22) / 2, width: 22, height: 22)
            let sh = CGRect(x: dl.maxX + 16, y: dl.minY, width: 22, height: 22)
            fileRel = FileGeo(icon: CGRect(x: x0, y: cy + (line - 24) / 2, width: 22, height: 24),
                              name: NSAttributedString(string: fname, attributes: fileAttrs),
                              nameFrame: nameFrame, download: dl, share: sh)
            innerW = max(innerW, 27 + nameW + 13 + 22 + 16 + 22 + 4.7)
            cy += line
            if g.copyText.isEmpty { g.copyText = fname }
        case nil:
            break
        }

        // Boosts: pills that wrap, then the add-boost button.
        var pillsRel: [PillGeo] = []
        var addRel: CGRect?
        if !boosts.isEmpty {
            let startX: CGFloat = isImage ? 10 : padX
            let avail = isImage ? bubbleW - 20 : maxInner
            let ph = type.pillHeight
            cy += isImage ? 5.5 : 4
            var x: CGFloat = 0, rowY: CGFloat = 0, maxRowW: CGFloat = 0
            func place(_ w: CGFloat) -> CGRect {
                if x > 0 && x + w > avail { x = 0; rowY += ph + 4 }
                let r = CGRect(x: startX + x, y: cy + rowY, width: w, height: ph)
                x += w + Metrics.pillGap
                maxRowW = max(maxRowW, x - Metrics.pillGap)
                return r
            }
            for b in boosts {
                let isEmoji = b.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
                    || b.content.unicodeScalars.first.map { $0.properties.isEmoji && $0.value > 0x2000 } == true
                let font = isEmoji ? boostEmojiFont : boostTextFont
                let content = NSAttributedString(string: b.content, attributes: [.font: font, .foregroundColor: Theme.text])
                let cw = min(lineWidth(b.content, [.font: font]) + (isEmoji ? 1.4 * type.s : 0), avail - 40)
                let leftPad: CGFloat = 1 + 1.6
                let w = leftPad + Metrics.pillAvatar + 5 + cw + 7.33
                let frame = place(w)
                let ch = px(font.lineHeight)
                pillsRel.append(PillGeo(
                    frame: frame, avatarColor: people.color(b.boosterID),
                    initial: Measurer.initial(of: people.name(b.boosterID)), content: content,
                    contentFrame: CGRect(x: leftPad + Metrics.pillAvatar + 5, y: (ph - ch) / 2, width: cw, height: ch)))
            }
            addRel = place(ph)
            cy += rowY + ph
            if !isImage { innerW = max(innerW, maxRowW) }
            cy += isImage ? 7 : padY
        } else {
            cy += (isImage && code == nil) ? 1 : padY
        }

        if !isImage {
            bubbleW = fillsMax ? maxBubble : min(maxBubble, px(innerW) + 2 * padX)
        }
        let bubbleX = p.isMine ? W - Metrics.bubbleLeft - bubbleW : Metrics.bubbleLeft
        let origin = CGPoint(x: bubbleX, y: bubbleTop)
        g.bubble = CGRect(x: bubbleX, y: bubbleTop, width: bubbleW, height: cy)
        g.style = emojiOnly ? .none : (p.mentionsMe ? .mention : .normal)
        func abs(_ r: CGRect) -> CGRect { r.offsetBy(dx: origin.x, dy: origin.y) }

        if g.body != nil {
            bodyRel.size.width = max(bodyRel.width, bubbleW - 2 * padX)
            g.bodyFrame = abs(bodyRel)
        }
        if g.code != nil {
            g.codeBox = abs(codeRel)
            g.codeTextFrame = codeTextRel
        }
        if isImage { g.image = abs(imageRel) }
        if var f = fileRel {
            f.icon = abs(f.icon); f.nameFrame = abs(f.nameFrame); f.download = abs(f.download); f.share = abs(f.share)
            g.file = f
        }
        g.pills = pillsRel.map { var p = $0; p.frame = abs(p.frame); return p }
        g.addBoost = addRel.map(abs)

        // Header frames.
        let hy = bubbleTop + padY
        if p.isMine {
            var right = g.bubble.maxX - padX
            if showAuthor {
                g.nameFrame = CGRect(x: right - nameW, y: hy, width: nameW, height: metaLine)
                right = g.nameFrame.minX - 6.3
            }
            g.timeFrame = CGRect(x: right - timeW, y: hy, width: timeW, height: metaLine)
            g.dots = CGRect(x: g.timeFrame.minX - 13 - Metrics.dotsWidth, y: hy, width: Metrics.dotsWidth, height: metaLine)
        } else {
            var x = bubbleX + padX
            if showAuthor {
                g.nameFrame = CGRect(x: x, y: hy, width: nameW, height: metaLine)
                x = g.nameFrame.maxX + spaceWidth
            }
            g.timeFrame = CGRect(x: x, y: hy, width: timeW, height: metaLine)
            g.dots = CGRect(x: g.timeFrame.maxX + 12.7, y: hy, width: Metrics.dotsWidth, height: metaLine)
        }

        if showAuthor {
            g.avatar = CGRect(x: p.isMine ? W - Metrics.screenPadding - Metrics.avatar : Metrics.screenPadding,
                              y: bubbleTop, width: Metrics.avatar, height: Metrics.avatar)
            g.avatarColor = people.color(m.creatorID)
            g.initial = Measurer.initial(of: people.name(m.creatorID))
        }
        // Emoji-only rows have no bubble margin; a boosted image row's strip hangs 3.67 below the bubble.
        let bottom = emojiOnly ? 0 : Metrics.bubbleBottomMargin + (isImage && !boosts.isEmpty ? 3.67 : 0)
        g.height = bubbleTop + cy + bottom
        return g
    }
}
