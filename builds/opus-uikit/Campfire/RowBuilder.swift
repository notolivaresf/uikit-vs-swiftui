import UIKit
import CampfireKit

/// Everything a message row needs to draw itself, computed once per (message, width, text size).
/// Row coordinates: x from the row's left edge, y from the row's top. Bubble contents are in bubble coordinates.
struct RowGeometry {
    enum BubbleStyle { case normal, mention, none }

    struct TextItem {
        var frame: CGRect          // in bubble coordinates (the line boxes)
        var text: NSAttributedString
        var textViewOffsetY: CGFloat // UITextView origin relative to frame.minY so baselines land where CSS puts them
        var codeBox: CGRect?       // set for code blocks (bubble coordinates); frame is then relative to the box
    }

    struct Pill {
        var frame: CGRect          // bubble coordinates
        var boost: BoostItem
        var isEmoji: Bool
        var initial: String
        var color: UIColor
    }

    struct File {
        var icon: CGRect
        var name: CGRect
        var nameText: String
        var download: CGRect
        var share: CGRect
    }

    var messageID: MessageID
    var height: CGFloat
    var isThreaded: Bool
    var isMine: Bool
    var dayText: String?
    var dayPill: CGRect = .zero
    var dayLineY: CGFloat = 0
    var bubble: CGRect = .zero
    var style: BubbleStyle = .normal
    var avatar: CGRect?
    var avatarColor: UIColor = .gray
    var initial: String = ""
    var name: String?
    var nameFrame: CGRect = .zero
    var time: String = ""
    var timeFrame: CGRect = .zero
    var dotsFrame: CGRect = .zero
    var texts: [TextItem] = []
    var image: CGRect?
    var imageColor: UIColor = .gray
    var file: File?
    var pills: [Pill] = []
    var addBoost: CGRect?
    var plainText: String = ""
}

/// A boost as drawn: from the message itself or added locally (Boost burst).
struct BoostItem: Hashable {
    let id: Int
    let boosterID: UserID
    let content: String
}

/// Measures text with the same TextKit 1 stack the cells' UITextViews use, so heights and line breaks agree.
final class TextMeasurer {
    private let storage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let container = NSTextContainer(size: .zero)

    init() {
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
    }

    struct Result { var lines: Int; var usedWidth: CGFloat; var firstBaseline: CGFloat }

    func measure(_ text: NSAttributedString, width: CGFloat) -> Result {
        container.size = CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
        storage.setAttributedString(text)
        let glyphs = layoutManager.glyphRange(for: container)
        var lines = 0
        var used: CGFloat = 0
        layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { _, usedRect, _, _, _ in
            lines += 1
            used = max(used, usedRect.maxX)
        }
        var baseline: CGFloat = 0
        if glyphs.length > 0 {
            let frag = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
            baseline = frag.minY + layoutManager.location(forGlyphAt: 0).y
        }
        return Result(lines: max(lines, 1), usedWidth: used, firstBaseline: baseline)
    }
}

final class RowBuilder {
    let users: [User]
    let currentUserID: UserID
    private let measurer = TextMeasurer()
    private var mentionImages: [String: UIImage] = [:]

    init(users: [User], currentUserID: UserID) {
        self.users = users
        self.currentUserID = currentUserID
    }

    func user(_ id: UserID) -> User? { id >= 1 && id <= users.count ? users[id - 1] : users.first { $0.id == id } }

    func paragraphStyle(_ lineHeight: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight
        p.maximumLineHeight = lineHeight
        p.lineBreakMode = .byWordWrapping
        return p
    }

    // MARK: Text content

    private func bodyText(_ blocks: [Block], m: Metrics) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let attrs: [NSAttributedString.Key: Any] = [.font: m.body, .foregroundColor: Colors.text,
                                                     .paragraphStyle: paragraphStyle(m.bodyLine)]
        for block in blocks {
            switch block {
            case .text(let t):
                out.append(NSAttributedString(string: t, attributes: attrs))
            case .mention(let id):
                let u = user(id)
                let attachment = NSTextAttachment()
                let d = (18 * m.s).rounded()
                attachment.image = mentionAvatar(id: id, initial: initial(of: u), diameter: d)
                attachment.bounds = CGRect(x: 0, y: -3.4 * m.s, width: d + 3.6, height: d)
                let a = NSMutableAttributedString(attachment: attachment)
                a.addAttributes(attrs, range: NSRange(location: 0, length: a.length))
                out.append(a)
                var bold = attrs
                bold[.font] = m.mention
                out.append(NSAttributedString(string: u?.name ?? "Someone", attributes: bold))
            case .code:
                break
            }
        }
        return out
    }

    private func emojiText(_ t: String, m: Metrics) -> NSAttributedString {
        NSAttributedString(string: t, attributes: [.font: m.emoji, .foregroundColor: Colors.text,
                                                  .paragraphStyle: paragraphStyle(m.emojiLine)])
    }

    private func codeText(_ source: String, language: String?, m: Metrics) -> NSAttributedString {
        let out = NSMutableAttributedString(string: source, attributes: [
            .font: m.code, .foregroundColor: Colors.text, .paragraphStyle: paragraphStyle(m.codeLine)])
        SyntaxHighlighter.highlight(out, language: language)
        return out
    }

    func initial(of u: User?) -> String {
        guard let c = u?.name.first else { return "?" }
        return String(c).uppercased()
    }

    private func mentionAvatar(id: UserID, initial: String, diameter d: CGFloat) -> UIImage {
        let key = "\(id)-\(d)"
        if let img = mentionImages[key] { return img }
        let size = CGSize(width: d + 3.6, height: d)
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            Colors.avatar(id).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: d, height: d)).fill()
            let font = UIFont.systemFont(ofSize: d * 0.5, weight: .bold)
            let s = NSAttributedString(string: initial, attributes: [.font: font, .foregroundColor: UIColor.white])
            let sz = s.size()
            s.draw(at: CGPoint(x: (d - sz.width) / 2, y: (d - sz.height) / 2))
        }
        mentionImages[key] = img
        return img
    }

    // MARK: Row

    func build(_ msg: Message, _ p: MessagePresentation, extraBoosts: [BoostItem] = [], width W: CGFloat, m: Metrics) -> RowGeometry {
        var g = RowGeometry(messageID: msg.id, height: 0, isThreaded: p.isThreaded, isMine: p.isMine)
        let author = user(msg.creatorID)
        g.plainText = plainText(msg)
        var y0: CGFloat = 0
        if p.isFirstOfDay {
            let text = Formatters.day.string(from: msg.createdAt).uppercased()
            g.dayText = text
            let pillW = singleLineWidth(text, m.day) + K.dayPadX * 2
            g.dayPill = CGRect(x: ((W - pillW) / 2).rounded(), y: K.dayMarginY, width: pillW, height: m.dayPillHeight)
            g.dayLineY = K.dayMarginY + m.dayPillHeight / 2 - K.dayLine / 2
            y0 = m.dayBlockHeight
        }
        let bubbleTop = y0 + K.bubbleTopInRow
        let maxW = p.isMine ? W - K.bubbleX - K.mineMinX : W - K.bubbleX - K.screenPadX
        let innerMax = maxW - 2 * K.bubblePadX
        let emojiOnly = msg.isEmojiOnly
        g.style = emojiOnly ? .none : (p.mentionsMe ? .mention : .normal)

        // Header: name (unless threaded), time, the "•••" menu button.
        g.time = Formatters.time.string(from: msg.createdAt)
        let timeW = singleLineWidth(g.time, m.meta)
        var headerW = timeW + K.dotsGap + K.dotsWidth + K.dotsTrailing
        var nameW: CGFloat = 0
        if !p.isThreaded {
            g.name = author?.name ?? "Someone"
            nameW = singleLineWidth(g.name!, m.metaBold)
            headerW += nameW + 4.3 * m.s
            g.avatar = CGRect(x: p.isMine ? W - K.screenPadX - K.avatar : K.screenPadX, y: bubbleTop,
                              width: K.avatar, height: K.avatar)
            g.avatarColor = Colors.avatar(msg.creatorID)
            g.initial = initial(of: author)
        }

        // Content measured at the widest the bubble may be.
        enum Kind { case text, code, image, file }
        struct Item { var kind: Kind; var text: NSAttributedString?; var result: TextMeasurer.Result?; var width: CGFloat }
        var items: [Item] = []
        if case .image(let w, let h, let color)? = msg.attachment {
            items.append(Item(kind: .image, width: K.imageMaxWidth - 2 * K.bubblePadX))
            g.imageColor = UIColor(color)
            _ = (w, h)
        }
        if case .file? = msg.attachment { items.append(Item(kind: .file, width: 0)) }
        var run: [Block] = []
        func flushRun() {
            guard !run.isEmpty else { return }
            let t = emojiOnly ? emojiText(run.compactMap { if case .text(let s) = $0 { s } else { nil } }.joined(), m: m)
                              : bodyText(run, m: m)
            let r = measurer.measure(t, width: innerMax)
            items.append(Item(kind: .text, text: t, result: r, width: ceil(r.usedWidth)))
            run = []
        }
        for block in msg.blocks {
            if case .code(let lang, let src) = block {
                flushRun()
                let t = codeText(src, language: lang, m: m)
                let r = measurer.measure(t, width: innerMax - 2 * K.codeInsetX - 2 * K.codePad)
                items.append(Item(kind: .code, text: t, result: r, width: ceil(r.usedWidth) + 2 * K.codePad + 2 * K.codeInsetX))
            } else {
                run.append(block)
            }
        }
        flushRun()

        var fileNameW: CGFloat = 0
        if case .file(let name, _)? = msg.attachment {
            fileNameW = singleLineWidth(name, m.body)
            if let i = items.firstIndex(where: { $0.kind == .file }) {
                items[i].width = min(innerMax, 42.7 - K.bubblePadX + fileNameW + 14.5 + 17 + 24 + 13 + 25.5 - K.bubblePadX)
            }
        }

        // Boost pills: natural width on one line.
        let boosts = msg.boosts.map { BoostItem(id: $0.id, boosterID: $0.boosterID, content: $0.content) } + extraBoosts
        let pillSpecs: [(BoostItem, Bool, CGFloat)] = boosts.map { b in
            let isEmoji = b.content.unicodeScalars.first?.properties.isEmojiPresentation ?? false
            let cw = singleLineWidth(b.content, isEmoji ? m.boostEmoji : m.boostText)
            return (b, isEmoji, 2.6 + m.boostAvatar + (isEmoji ? 5 : 4) + cw + (isEmoji ? 5 : 8.3))
        }
        let addW = m.boostHeight
        let hasBoostStrip = !boosts.isEmpty
        let stripNatural = pillSpecs.reduce(0) { $0 + $1.2 + K.boostGapX } + addW

        let isImage = items.contains { $0.kind == .image }
        var contentW = max(headerW, items.map(\.width).max() ?? 0)
        if hasBoostStrip { contentW = max(contentW, min(stripNatural, innerMax)) }
        var bubbleW: CGFloat
        if isImage {
            bubbleW = min(maxW, K.imageMaxWidth)
        } else {
            bubbleW = min(maxW, ceil(contentW) + 2 * K.bubblePadX)
        }
        let innerW = bubbleW - 2 * K.bubblePadX

        // Header frames (bubble coordinates). Mine: reversed, right-aligned.
        let metaH = ceil(m.meta.lineHeight)
        let nameY = m.headerBaseline - m.metaBold.ascender
        let timeY = m.headerBaseline - m.meta.ascender
        let dotsH: CGFloat = 4.67
        let dotsY = m.headerBaseline - 9.33 * m.s / 2 - dotsH / 2 - 0.2
        if p.isMine {
            var x = bubbleW - K.bubblePadX
            if g.name != nil {
                x -= nameW
                g.nameFrame = CGRect(x: x, y: nameY, width: nameW, height: metaH)
                x -= 4.3 * m.s
            }
            x -= timeW
            g.timeFrame = CGRect(x: x, y: timeY, width: timeW, height: metaH)
            x -= K.dotsGap + K.dotsWidth
            g.dotsFrame = CGRect(x: x, y: dotsY, width: K.dotsWidth, height: dotsH)
        } else {
            var x = K.bubblePadX
            if g.name != nil {
                g.nameFrame = CGRect(x: x, y: nameY, width: nameW, height: metaH)
                x += nameW + 4.3 * m.s
            }
            g.timeFrame = CGRect(x: x, y: timeY, width: timeW, height: metaH)
            x += timeW + K.dotsGap
            g.dotsFrame = CGRect(x: x, y: dotsY, width: K.dotsWidth, height: dotsH)
        }

        // Vertical stacking of the content.
        var y = m.contentTop
        var last: Kind = .text
        var first = true
        for item in items {
            switch item.kind {
            case .image:
                y = m.imageTop
                guard case .image(let w, let h, _)? = msg.attachment else { break }
                let iw = bubbleW - 2 * K.imageInset
                let ih = (iw * CGFloat(h) / CGFloat(max(w, 1))).rounded(.toNearestOrAwayFromZero)
                g.image = CGRect(x: K.imageInset, y: y, width: iw, height: ih)
                y += ih
            case .file:
                guard case .file(let name, _)? = msg.attachment else { break }
                let lh = m.fileLineHeight
                let cy = y + 19.3 * max(1, m.s)
                g.file = RowGeometry.File(
                    icon: CGRect(x: 16.9, y: cy - 11, width: 18, height: 22),
                    name: CGRect(x: 42.7, y: cy - m.body.lineHeight / 2, width: min(fileNameW, innerW - 100), height: ceil(m.body.lineHeight)),
                    nameText: name,
                    download: CGRect(x: 42.7 + min(fileNameW, innerW - 100) + 14.2, y: cy - 8.5, width: 17, height: 17),
                    share: CGRect(x: 42.7 + min(fileNameW, innerW - 100) + 14.2 + 17 + 24.3, y: cy - 9.5, width: 14, height: 18))
                y += lh
            case .text:
                if !first { y += K.blockGap }
                let r = item.result!
                let h = CGFloat(r.lines) * (emojiOnly ? m.emojiLine : m.bodyLine)
                let css = emojiOnly ? Metrics.cssBaseline(m.emoji, m.emojiLine) : Metrics.cssBaseline(m.body, m.bodyLine)
                g.texts.append(.init(frame: CGRect(x: K.bubblePadX, y: y, width: innerW, height: h), text: item.text!,
                                     textViewOffsetY: css - r.firstBaseline))
                y += h
            case .code:
                if !first { y += K.blockGap }
                let r = item.result!
                let h = CGFloat(r.lines) * m.codeLine
                let boxW = min(item.width - 2 * K.codeInsetX, innerW - 2 * K.codeInsetX)
                let box = CGRect(x: K.bubblePadX + K.codeInsetX, y: y, width: boxW, height: h + 2 * K.codePad)
                let css = Metrics.cssBaseline(m.code, m.codeLine)
                g.texts.append(.init(frame: CGRect(x: K.codePad, y: K.codePad, width: boxW - 2 * K.codePad, height: h),
                                     text: item.text!, textViewOffsetY: css - r.firstBaseline, codeBox: box))
                y += box.height
            }
            last = item.kind
            first = false
        }

        if hasBoostStrip {
            y += last == .image ? 5.33 : 7.92
            let left: CGFloat = isImage ? 10 : K.bubblePadX
            let avail = bubbleW - left - (isImage ? 10 : K.bubblePadX)
            var x = left
            var rowY = y
            let bh = m.boostHeight
            for spec in pillSpecs {
                let w = min(spec.2, avail)
                if x > left && x + w > left + avail { x = left; rowY += bh + K.boostGapY }
                let u = user(spec.0.boosterID)
                g.pills.append(.init(frame: CGRect(x: x, y: rowY, width: w, height: bh), boost: spec.0, isEmoji: spec.1,
                                     initial: initial(of: u), color: Colors.avatar(spec.0.boosterID)))
                x += w + K.boostGapX
            }
            if x > left && x + addW > left + avail { x = left; rowY += bh + K.boostGapY }
            g.addBoost = CGRect(x: x, y: rowY, width: addW, height: bh)
            y = rowY + bh + 8
        } else {
            switch last {
            case .text: y += emojiOnly ? 10.38 : 10.36
            case .code: y += 12.05
            case .image: y += K.imageInset
            case .file: y += 77 - 32.72 - 34
            }
        }

        let bubbleX = p.isMine ? W - K.bubbleX - bubbleW : K.bubbleX
        g.bubble = CGRect(x: bubbleX, y: bubbleTop, width: bubbleW, height: ceil(y * 100) / 100)
        g.height = bubbleTop + g.bubble.height + K.bubbleBottomMargin
        return g
    }

    func plainText(_ msg: Message) -> String {
        var parts: [String] = []
        for b in msg.blocks {
            switch b {
            case .text(let t): parts.append(t)
            case .mention(let id): parts.append("@" + (user(id)?.name ?? ""))
            case .code(_, let s): parts.append("\n" + s + "\n")
            }
        }
        if case .file(let name, _)? = msg.attachment { parts.append(name) }
        return parts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Tiny highlighter for the four snippet languages (ruby, swift, sh, SQL), coloured like Campfire's GitHub theme.
enum SyntaxHighlighter {
    static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "class", "module", "if", "else", "elsif", "unless", "do", "return", "puts", "require", "self", "nil", "true", "false"],
        "swift": ["let", "var", "func", "return", "if", "else", "for", "in", "struct", "class", "import", "guard"],
        "sh": ["if", "then", "fi", "for", "do", "done", "echo", "export"],
        "sql": ["SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT", "AND", "OR", "INSERT", "UPDATE", "JOIN"],
    ]
    static let builtins: Set<String> = ["puts", "print"]

    static func highlight(_ s: NSMutableAttributedString, language: String?) {
        let text = s.string as NSString
        let lang = language ?? (text.uppercased == (text as String) || text.contains("SELECT") ? "sql" : "")
        let kw = keywords[lang] ?? []
        let full = NSRange(location: 0, length: text.length)
        let wordRegex = try! NSRegularExpression(pattern: "[A-Za-z_][A-Za-z0-9_]*")
        var previous = ""
        for match in wordRegex.matches(in: text as String, range: full) {
            let word = text.substring(with: match.range)
            if kw.contains(word) && !(lang == "ruby" && builtins.contains(word)) {
                s.addAttribute(.foregroundColor, value: Colors.codeKeyword, range: match.range)
            } else if previous == "def" || previous == "func" || previous == "class" {
                s.addAttribute(.foregroundColor, value: Colors.codeEntity, range: match.range)
            } else if lang == "swift" || lang == "sh" {
                let after = match.range.location + match.range.length
                if after < text.length && text.character(at: after) == 40 /* ( */ {
                    s.addAttribute(.foregroundColor, value: Colors.codeEntity, range: match.range)
                }
            }
            previous = word
        }
        let numbers = try! NSRegularExpression(pattern: "\\b[0-9]+\\b")
        for match in numbers.matches(in: text as String, range: full) {
            s.addAttribute(.foregroundColor, value: Colors.codeConstant, range: match.range)
        }
        let strings = try! NSRegularExpression(pattern: "\"[^\"\\n]*\"|'[^'\\n]*'")
        for match in strings.matches(in: text as String, range: full) {
            s.addAttribute(.foregroundColor, value: Colors.codeString, range: match.range)
        }
        let comments = try! NSRegularExpression(pattern: "(#(?!\\{)[^\\n]*$|--[^\\n]*$)", options: .anchorsMatchLines)
        for match in comments.matches(in: text as String, range: full) where lang != "ruby" || true {
            let start = match.range.location
            // Skip "#" inside a string (already coloured as string).
            if let c = s.attribute(.foregroundColor, at: start, effectiveRange: nil) as? UIColor, c == Colors.codeString { continue }
            s.addAttribute(.foregroundColor, value: Colors.codeComment, range: match.range)
        }
    }
}
