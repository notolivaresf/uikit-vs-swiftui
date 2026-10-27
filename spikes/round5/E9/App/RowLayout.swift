import UIKit
import CampfireKit

/// Everything a message row draws, measured once per (width, text size) and kept by message id.
/// Separator, avatar and bubble frames are in cell coordinates; the rest are in bubble coordinates.
final class RowLayout {
    struct Pill {
        let frame: CGRect
        let user: User?
        let content: String
        let isEmoji: Bool
    }

    struct Code {
        let box: CGRect
        let textFrame: CGRect
        let text: NSAttributedString
    }

    struct File {
        let icon: CGRect
        let nameFrame: CGRect
        let name: String
        let download: CGRect
        let share: CGRect
    }

    enum BubbleKind { case plain, mention, clear }

    let messageID: MessageID
    var height: CGFloat = 0
    var separatorText: String?
    var separatorPill: CGRect = .zero
    var separatorLineY: CGFloat = 0
    var avatarUser: User?
    var avatarFrame: CGRect?
    var bubble: CGRect = .zero
    var bubbleKind: BubbleKind = .plain
    var nameText: String?
    var nameFrame: CGRect = .zero
    var timeText = ""
    var timeFrame: CGRect = .zero
    var dotsFrame: CGRect = .zero
    var body: NSAttributedString?
    var bodyFrame: CGRect = .zero
    var codes: [Code] = []
    var imageFrame: CGRect?
    var imageColor: UIColor?
    var file: File?
    var pills: [Pill] = []
    var addBoostFrame: CGRect?
    var plainText = ""

    init(messageID: MessageID) { self.messageID = messageID }
}

/// A boost as the row draws it: from the dataset or added live.
struct BoostItem {
    let boosterID: UserID
    let content: String
}

/// Builds `RowLayout`s. One instance per text style and width; strings are measured with the exact
/// attributed strings the cell's text views draw (TextKit 2 `UITextView` + `boundingRect`).
final class RowMeasurer {
    let style: TextStyle
    let width: CGFloat
    private let users: [User]
    private var nameWidths: [Int: CGFloat] = [:]
    private var timeWidths: [String: CGFloat] = [:]

    init(style: TextStyle, width: CGFloat, users: [User]) {
        self.style = style
        self.width = width
        self.users = users
    }

    func user(_ id: UserID) -> User? { id >= 1 && id <= users.count ? users[id - 1] : nil }

    private func textWidth(_ s: String, _ font: UIFont) -> CGFloat {
        ceil((s as NSString).size(withAttributes: [.font: font]).width)
    }

    private func nameWidth(_ u: User) -> CGFloat {
        if let w = nameWidths[u.id] { return w }
        let w = textWidth(u.name, style.name)
        nameWidths[u.id] = w
        return w
    }

    private func timeWidth(_ s: String) -> CGFloat {
        if let w = timeWidths[s] { return w }
        let w = textWidth(s, style.meta)
        if timeWidths.count > 2000 { timeWidths.removeAll() }
        timeWidths[s] = w
        return w
    }

    #if TK1_MEASURE
    // TextKit 1 measuring stack, paired with TextKit 1 text views.
    private let tkStorage = NSTextStorage()
    private let tkManager = NSLayoutManager()
    private let tkContainer: NSTextContainer = {
        let c = NSTextContainer(size: .zero)
        c.lineFragmentPadding = 0
        return c
    }()
    private var tkReady = false

    private func size(_ a: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        if !tkReady { tkManager.addTextContainer(tkContainer); tkStorage.addLayoutManager(tkManager); tkReady = true }
        tkContainer.size = CGSize(width: maxWidth, height: 1_000_000)
        tkStorage.setAttributedString(a)
        tkManager.ensureLayout(for: tkContainer)
        let r = tkManager.usedRect(for: tkContainer)
        return CGSize(width: ceil(r.width * 3) / 3, height: ceil(r.height * 3) / 3)
    }
    #else
    private func size(_ a: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        let r = a.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: ceil(r.width * 3) / 3, height: ceil(r.height * 3) / 3)
    }
    #endif

    static func isEmoji(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.allSatisfy { ch in
            ch.unicodeScalars.contains { $0.properties.isEmojiPresentation }
                || (ch.unicodeScalars.first?.properties.isEmoji == true && ch.unicodeScalars.contains { $0.value == 0xFE0F })
        }
    }

    // MARK: Attributed strings

    private func textAttrs(_ font: UIFont, line: CGFloat, color: UIColor = Palette.text) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color, .paragraphStyle: style.paragraph(line: line)]
    }

    private enum Segment { case text(NSAttributedString), code(NSAttributedString) }

    private func segments(of m: Message, plain: inout String) -> [Segment] {
        var out: [Segment] = []
        var current: NSMutableAttributedString?
        let base = textAttrs(style.body, line: style.bodyLine)
        for block in m.blocks {
            switch block {
            case .text(let t):
                if current == nil { current = NSMutableAttributedString() }
                current!.append(NSAttributedString(string: t, attributes: base))
                plain += t
            case .mention(let id):
                if current == nil { current = NSMutableAttributedString() }
                let u = user(id)
                let name = u?.name ?? "Unknown"
                if let u {
                    let d = (16.7 * style.scale).rounded()
                    let gap = (3.7 * style.scale).rounded()
                    let att = NSTextAttachment()
                    att.image = Glyphs.mentionAvatar(user: u, diameter: d, trailing: gap)
                    att.bounds = CGRect(x: 0, y: (style.mention.capHeight - d) / 2, width: d + gap, height: d)
                    let a = NSMutableAttributedString(attachment: att)
                    a.addAttributes(base, range: NSRange(location: 0, length: a.length))
                    current!.append(a)
                }
                current!.append(NSAttributedString(string: name, attributes: textAttrs(style.mention, line: style.bodyLine)))
                plain += name
            case .code(let lang, let src):
                if let c = current { out.append(.text(c)); current = nil }
                out.append(.code(CodeHighlighter.highlight(src, language: lang, style: style)))
                if !plain.isEmpty { plain += "\n" }
                plain += src
            }
        }
        if let c = current { out.append(.text(c)) }
        return out
    }

    // MARK: Measure

    func measure(_ m: Message, _ p: MessagePresentation, boosts: [BoostItem]) -> RowLayout {
        let L = RowLayout(messageID: m.id)
        let s = style
        let W = width
        var top: CGFloat = 0

        if p.isFirstOfDay {
            let text = Formats.day(m.createdAt)
            let pillH = s.separatorLine + 2 * Geo.sepPillPadY
            let pw = textWidth(text, s.separator) + 2 * Geo.sepPillPadX
            L.separatorText = text
            L.separatorPill = CGRect(x: ((W - pw) / 2).rounded(), y: Geo.sepMargin, width: pw, height: pillH)
            L.separatorLineY = Geo.sepMargin + pillH / 2 - Geo.sepLine / 2
            top = 2 * Geo.sepMargin + pillH
        }
        // A threaded row sits 1.2 pt into the previous row's bottom margin (Campfire's -22.48 margin);
        // the row frame starts at the previous row's bottom and the bubble moves up instead, so frames never overlap.
        let bubbleTop = top + Geo.rowTopToBubble + (p.isThreaded ? Geo.threadedGap : 0)
        // My bubbles stop short of the left edge (Campfire: 287.97 wide at 393, left edge 64.23).
        let maxBubble = p.isMine ? W - Geo.bubbleLeft - Geo.mineMinLeft : W - Geo.bubbleLeft - Geo.bubbleRightInset
        let innerMax = maxBubble - 2 * Geo.bubblePadX

        // Meta line
        let author = user(m.creatorID)
        let time = Formats.time(m.createdAt)
        let timeW = timeWidth(time)
        let nameW: CGFloat = (!p.isThreaded && author != nil) ? nameWidth(author!) : 0
        let metaW = (nameW > 0 ? nameW + Geo.nameTimeGap : 0) + timeW + Geo.timeToDots + Geo.dotsWidth + Geo.dotsTrailing
        let metaY = Geo.bubblePadY
        let metaBottom = metaY + s.metaLine
        var y = metaBottom + Geo.metaToBody
        var contentW: CGFloat = 0
        var plain = ""
        var isImage = false
        var bubbleW: CGFloat = 0

        if m.isEmojiOnly, case .text(let t)? = m.blocks.first {
            let a = NSAttributedString(string: t, attributes: textAttrs(s.emoji, line: s.emojiLine))
            let sz = size(a, maxWidth: innerMax)
            L.body = a
            L.bodyFrame = CGRect(x: Geo.bubblePadX, y: y - s.baseline(s.emoji, line: s.emojiLine), width: sz.width, height: sz.height)
            contentW = sz.width
            y += sz.height
            plain = t
            L.bubbleKind = .clear
        } else {
            var first = true
            for seg in segments(of: m, plain: &plain) {
                if !first { y += Geo.blockGap }
                first = false
                switch seg {
                case .text(let a):
                    let sz = size(a, maxWidth: innerMax)
                    L.body = a
                    // TextKit puts a tall line's extra space above the glyphs; CSS splits it. Shift up by half.
                    L.bodyFrame = CGRect(x: Geo.bubblePadX, y: y - s.baseline(s.body, line: s.bodyLine), width: sz.width, height: sz.height)
                    contentW = max(contentW, sz.width)
                    y += sz.height
                case .code(let a):
                    let inset = Geo.codePad + Geo.codeBorder
                    let sz = size(a, maxWidth: innerMax - 2 * inset)
                    let box = CGRect(x: Geo.bubblePadX, y: y, width: sz.width + 2 * inset, height: sz.height + 2 * inset)
                    L.codes.append(.init(box: box, textFrame: CGRect(x: box.minX + inset, y: box.minY + inset - s.baseline(s.code, line: s.codeLine),
                                                                     width: sz.width, height: sz.height), text: a))
                    contentW = max(contentW, box.width)
                    y += box.height
                }
            }
            switch m.attachment {
            case .image(let w, let h, let c):
                isImage = true
                bubbleW = min(Geo.imageMax, maxBubble)
                y = first ? metaBottom + (Geo.imageTop - Geo.bubblePadY - 19.2) : y + 8
                let iw = bubbleW - 2 * Geo.imageInset
                let ih = (iw * CGFloat(h) / CGFloat(max(w, 1))).rounded()
                L.imageFrame = CGRect(x: Geo.imageInset, y: y, width: iw, height: ih)
                L.imageColor = UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
                y += ih
            case .file(let name, _):
                if !first { y += Geo.blockGap }
                let line = max(Geo.fileLine, s.bodyLine + 8.76)
                let nameW = min(textWidth(name, s.fileName), innerMax - 27.4 - 72)
                let iconH = 22 * s.scale
                let icon = CGRect(x: Geo.bubblePadX + 1.6, y: y + (line - iconH) / 2, width: 18 * s.scale, height: iconH)
                let nameFrame = CGRect(x: Geo.bubblePadX + 27.4, y: y + (line - s.bodyLine) / 2, width: nameW, height: s.bodyLine)
                let b = 24 * s.scale
                let download = CGRect(x: nameFrame.maxX + 8, y: y + (line - b) / 2, width: b, height: b)
                let share = CGRect(x: download.maxX + 16, y: download.minY, width: b, height: b)
                L.file = .init(icon: icon, nameFrame: nameFrame, name: name, download: download, share: share)
                contentW = max(contentW, share.maxX - Geo.bubblePadX)
                y += line
                if !plain.isEmpty { plain += "\n" }
                plain += name
            case nil:
                break
            }
        }

        // Boosts
        var stripW: CGFloat = 0
        if !boosts.isEmpty {
            let stripX = isImage ? Geo.imageBoostsX : Geo.bubblePadX
            y += isImage ? Geo.imageToBoosts : Geo.boostTop
            let avail = (isImage ? bubbleW : maxBubble) - 2 * stripX
            let ph = s.pillHeight
            let avatarD = ph - 2 * (1 + 1.6)
            var x: CGFloat = 0, rowY = y
            func place(_ w: CGFloat) -> CGRect {
                if x > 0 && x + w > avail { x = 0; rowY += ph + Geo.pillGapY }
                let r = CGRect(x: stripX + x, y: rowY, width: w, height: ph)
                x += w + Geo.pillGapX
                stripW = max(stripW, x - Geo.pillGapX)
                return r
            }
            for b in boosts {
                let emoji = RowMeasurer.isEmoji(b.content)
                let cw = textWidth(b.content, emoji ? s.boostEmoji : s.boostText)
                let w = 2.6 + avatarD + 4.4 * s.scale + cw + (emoji ? 9 : 7.7) * s.scale
                L.pills.append(.init(frame: place(min(w, avail)), user: user(b.boosterID), content: b.content, isEmoji: emoji))
            }
            L.addBoostFrame = place(ph)
            y = rowY + ph
        }

        if isImage {
            y += boosts.isEmpty ? Geo.imageInset : Geo.imageBoostsBottom
        } else {
            y += Geo.bubblePadY
            bubbleW = min(maxBubble, ceil(max(metaW, contentW, stripW) + 2 * Geo.bubblePadX))
        }
        let bubbleH = y
        let mine = p.isMine
        let bubbleX = mine ? W - Geo.bubbleLeft - bubbleW : Geo.bubbleLeft
        L.bubble = CGRect(x: bubbleX, y: bubbleTop, width: bubbleW, height: bubbleH)
        if L.bubbleKind != .clear && p.mentionsMe { L.bubbleKind = .mention }

        // Meta frames
        L.timeText = time
        if mine {
            let right = bubbleW - Geo.bubblePadX
            var x = right
            if nameW > 0 {
                L.nameText = author!.name
                L.nameFrame = CGRect(x: right - nameW, y: metaY, width: nameW, height: s.metaLine)
                x = right - nameW - Geo.nameTimeGap
            }
            L.timeFrame = CGRect(x: x - timeW, y: metaY, width: timeW, height: s.metaLine)
            L.dotsFrame = CGRect(x: L.timeFrame.minX - 11.7 - Geo.dotsWidth, y: metaY, width: Geo.dotsWidth, height: s.metaLine)
        } else {
            var x = Geo.bubblePadX
            if nameW > 0 {
                L.nameText = author!.name
                L.nameFrame = CGRect(x: x, y: metaY, width: nameW, height: s.metaLine)
                x += nameW + Geo.nameTimeGap
            }
            L.timeFrame = CGRect(x: x, y: metaY, width: timeW, height: s.metaLine)
            L.dotsFrame = CGRect(x: L.timeFrame.maxX + Geo.timeToDots, y: metaY, width: Geo.dotsWidth, height: s.metaLine)
        }

        if !p.isThreaded {
            L.avatarUser = author
            let ax = mine ? W - Geo.padX - Geo.avatar : Geo.padX
            L.avatarFrame = CGRect(x: ax - Geo.avatarRing, y: bubbleTop + 0.7 - Geo.avatarRing,
                                   width: Geo.avatar + 2 * Geo.avatarRing, height: Geo.avatar + 2 * Geo.avatarRing)
        }
        L.height = bubbleTop + bubbleH + Geo.bubbleBottomMargin
        L.plainText = plain
        return L
    }
}

/// A tiny highlighter for the few languages in the data: keywords, the name after def/func, strings, numbers.
enum CodeHighlighter {
    private static let keywords: Set<String> = [
        "def", "end", "class", "module", "if", "else", "elsif", "unless", "do", "return", "let", "var", "func", "import",
        "for", "in", "while", "true", "false", "nil", "self", "SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC",
        "LIMIT", "AND", "OR", "JOIN", "ON", "GROUP", "INSERT", "UPDATE",
    ]
    private static let definers: Set<String> = ["def", "func", "class", "module"]

    static func highlight(_ src: String, language: String?, style: TextStyle) -> NSAttributedString {
        let font = style.code
        let base: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: Palette.text, .paragraphStyle: style.paragraph(line: style.codeLine),
        ]
        let out = NSMutableAttributedString(string: src, attributes: base)
        let chars = Array(src.utf16)
        var i = 0
        var expectName = false
        func isWord(_ c: UInt16) -> Bool {
            (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
        }
        while i < chars.count {
            let c = chars[i]
            if c == 34 || c == 39 {  // string
                let start = i
                i += 1
                while i < chars.count && chars[i] != c && chars[i] != 10 { i += 1 }
                i = min(i + 1, chars.count)
                out.addAttribute(.foregroundColor, value: Palette.codeString, range: NSRange(location: start, length: i - start))
            } else if c == 35 && language == "sh" {  // shell comment
                let start = i
                while i < chars.count && chars[i] != 10 { i += 1 }
                out.addAttribute(.foregroundColor, value: Palette.codeComment, range: NSRange(location: start, length: i - start))
            } else if isWord(c) {
                let start = i
                while i < chars.count && isWord(chars[i]) { i += 1 }
                let range = NSRange(location: start, length: i - start)
                let word = String(utf16CodeUnits: Array(chars[start..<i]), count: i - start)
                if expectName {
                    out.addAttribute(.foregroundColor, value: Palette.codeEntity, range: range)
                    expectName = false
                } else if keywords.contains(word) {
                    out.addAttribute(.foregroundColor, value: Palette.codeKeyword, range: range)
                    expectName = definers.contains(word)
                } else if c >= 48 && c <= 57 {
                    out.addAttribute(.foregroundColor, value: Palette.codeConstant, range: range)
                }
            } else {
                if c != 32 { expectName = false }
                i += 1
            }
        }
        return out
    }
}
