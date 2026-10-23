import AppKit
import CampfireKit

/// One message row as it is loaded in the room.
struct RowItem {
    var message: Message
    var boosts: [AppBoost]
    var presentation: MessagePresentation
    var layout: RowLayout
    /// Top of the row in document coordinates.
    var y: CGFloat = 0
    var bottom: CGFloat { y + layout.height }
}

struct LayoutContext {
    let width: CGFloat
    let typography: Typography
    let store: RoomStore
}

struct TextPiece {
    let string: NSAttributedString
    let frame: CGRect
}

struct PillLayout {
    let frame: CGRect
    let avatar: CGRect
    let avatarColor: NSColor
    let initial: String
    let content: NSAttributedString
    let contentOrigin: CGPoint
    let accessibilityLabel: String
}

struct FileLayout {
    let icon: CGRect
    let name: NSAttributedString
    let nameOrigin: CGPoint
    let download: CGRect
    let share: CGRect
    let tooltip: String
}

enum BubbleStyle { case normal, mention, none }

/// Geometry of one row, in the row's own (flipped) coordinates. Built once per message, width and text size.
final class RowLayout {
    var height: CGFloat = 0
    var separatorPill: CGRect?
    var separatorLineY: CGFloat = 0
    var separatorText: NSAttributedString?
    var bubble: CGRect = .zero
    var bubbleStyle: BubbleStyle = .normal
    var avatar: CGRect?
    var avatarColor: NSColor = .gray
    var avatarInitial = ""
    var header = NSAttributedString()
    var headerOrigin: CGPoint = .zero
    var dotsOrigin: CGPoint = .zero
    var dotsHeight: CGFloat = 0
    var texts: [TextPiece] = []
    var codeBoxes: [CGRect] = []
    var image: CGRect?
    var imageColor: NSColor = .gray
    var imageAttachment: Attachment?
    var imageAtBottom = false
    var file: FileLayout?
    var pills: [PillLayout] = []
    var addBoost: CGRect?
    var scale: CGFloat = 1
    /// Room width this was laid out for.
    var width: CGFloat = 0
    /// The message as text, for Copy.
    var plainText = ""
}

// MARK: - Text

/// Measures attributed strings with the same TextKit 1 set-up the body text views use, so sizes match exactly.
final class TextMeasurer {
    static let shared = TextMeasurer()
    private let storage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let container = NSTextContainer(size: .zero)

    private init() {
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        container.lineFragmentPadding = 0
    }

    func size(of string: NSAttributedString, width: CGFloat) -> CGSize {
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        storage.setAttributedString(string)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        return CGSize(width: ceil(used.width * 2) / 2, height: used.height)
    }
}

enum TextStyle {
    static func paragraph(lineHeight: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight
        p.maximumLineHeight = lineHeight
        p.lineBreakMode = .byWordWrapping
        return p
    }

    /// TextKit puts the extra line height above the glyphs; CSS splits it. This lifts the baseline to match CSS.
    static func baselineLift(font: NSFont, lineHeight: CGFloat) -> CGFloat {
        (lineHeight - (font.ascender - font.descender)) / 2 + 0.5
    }

    static func attributes(font: NSFont, lineHeight: CGFloat, color: NSColor = Palette.text) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color, .paragraphStyle: paragraph(lineHeight: lineHeight),
         .baselineOffset: baselineLift(font: font, lineHeight: lineHeight)]
    }

    /// Body text with inline mention pills (avatar + bold name).
    static func prose(_ blocks: [Block], typography t: Typography, store: RoomStore) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let base = attributes(font: t.body, lineHeight: t.bodyLineHeight)
        for block in blocks {
            switch block {
            case .text(let s):
                out.append(NSAttributedString(string: s, attributes: base))
            case .mention(let id):
                let name = store.name(of: id)
                let attachment = NSTextAttachment()
                let d = t.mentionAvatar
                let gap = 3 * t.scale
                attachment.image = mentionAvatarImage(userID: id, name: name, diameter: d, gap: gap)
                attachment.bounds = CGRect(x: 0, y: -4.4 * t.scale, width: d + gap, height: d)
                var attrs = base
                attrs[.attachment] = attachment
                out.append(NSAttributedString(string: "\u{FFFC}", attributes: attrs))
                var nameAttrs = base
                nameAttrs[.font] = t.mention
                out.append(NSAttributedString(string: name, attributes: nameAttrs))
            case .code:
                break
            }
        }
        return out
    }

    static func code(_ source: String, language: String?, typography t: Typography) -> NSAttributedString {
        var attrs = attributes(font: t.code, lineHeight: t.codeLineHeight)
        attrs[.kern] = -0.12 * t.scale  // SF Mono on the Mac runs a little wider than Campfire's ui-monospace
        let out = NSMutableAttributedString(string: source, attributes: attrs)
        CodeHighlighter.highlight(out, language: language)
        return out
    }

    static func emoji(_ text: String, typography t: Typography) -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes(font: t.emoji, lineHeight: t.emojiLineHeight))
    }

    private static var mentionImages: [String: NSImage] = [:]

    static func mentionAvatarImage(userID: Int, name: String, diameter d: CGFloat, gap: CGFloat) -> NSImage {
        let key = "\(userID)|\(d)"
        if let hit = mentionImages[key] { return hit }
        let color = Palette.avatarColor(for: userID)
        let letter = initial(of: name)
        let img = NSImage(size: NSSize(width: d + gap, height: d), flipped: true) { _ in
            Draw.avatar(CGRect(x: 0, y: 0, width: d, height: d), color: color, initial: letter, fontSize: d * 0.5)
            return true
        }
        mentionImages[key] = img
        return img
    }
}

/// A light keyword / string / comment colouring for code blocks, in Campfire's code colours.
enum CodeHighlighter {
    private static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "class", "module", "if", "elsif", "else", "unless", "do", "return", "yield", "while",
                 "begin", "rescue", "ensure", "then", "case", "when", "self", "nil", "true", "false", "require"],
        "swift": ["let", "var", "func", "return", "if", "else", "guard", "import", "struct", "class", "enum", "for",
                  "in", "while", "switch", "case", "self", "nil", "true", "false", "init"],
        "sh": ["if", "then", "else", "fi", "for", "do", "done", "export", "echo", "cd"],
        "sql": ["SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT", "AND", "OR", "INSERT", "INTO",
                "UPDATE", "SET", "DELETE", "JOIN", "ON", "GROUP", "AS"],
    ]
    private static let token = try! NSRegularExpression(
        pattern: #"("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|(#(?!\{).*$|//.*$|--.*$)|(\b\d+(?:\.\d+)?\b)|(\b[A-Za-z_][A-Za-z0-9_]*\b)|(\s-{1,2}[A-Za-z]+)"#,
        options: [.anchorsMatchLines])

    private static func isComment(_ token: String, _ lang: String) -> Bool {
        switch lang {
        case "swift": return token.hasPrefix("//")
        case "sql": return token.hasPrefix("--")
        default: return token.hasPrefix("#")
        }
    }

    static func highlight(_ s: NSMutableAttributedString, language: String?) {
        let lang = language ?? "sql"
        let words = keywords[lang] ?? []
        let text = s.string as NSString
        var previousWord = ""
        for m in token.matches(in: s.string, range: NSRange(location: 0, length: text.length)) {
            if m.range(at: 1).location != NSNotFound {
                s.addAttribute(.foregroundColor, value: Palette.codeString, range: m.range(at: 1))
            } else if m.range(at: 2).location != NSNotFound, isComment(text.substring(with: m.range(at: 2)), lang) {
                s.addAttribute(.foregroundColor, value: Palette.codeComment, range: m.range(at: 2))
            } else if m.range(at: 3).location != NSNotFound {
                s.addAttribute(.foregroundColor, value: Palette.codeConstant, range: m.range(at: 3))
            } else if m.range(at: 4).location != NSNotFound {
                let word = text.substring(with: m.range(at: 4))
                if words.contains(word) {
                    s.addAttribute(.foregroundColor, value: Palette.codeKeyword, range: m.range(at: 4))
                } else if previousWord == "def" || previousWord == "func" || previousWord == "class" {
                    s.addAttribute(.foregroundColor, value: Palette.codeEntity, range: m.range(at: 4))
                }
                previousWord = word
            } else if m.range(at: 5).location != NSNotFound {
                s.addAttribute(.foregroundColor, value: Palette.codeConstant, range: m.range(at: 5))
            }
        }
    }
}

// MARK: - Layout

enum RowLayoutBuilder {
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

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static func isEmojiText(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.unicodeScalars.contains { $0.properties.isEmojiPresentation } || $0.unicodeScalars.first?.properties.isEmoji == true && $0.unicodeScalars.count > 1 }
    }

    static func make(_ message: Message, boosts: [AppBoost], _ p: MessagePresentation, _ ctx: LayoutContext) -> RowLayout {
        let L = RowLayout()
        let t = ctx.typography
        let s = t.scale
        let W = ctx.width
        let mine = p.isMine
        let measurer = TextMeasurer.shared
        L.scale = s
        L.width = W

        // Day separator.
        var y: CGFloat = 0
        if p.isFirstOfDay {
            let label = dayFormatter.string(from: message.createdAt).uppercased()
            let str = NSAttributedString(string: label, attributes: [.font: t.separator, .foregroundColor: Palette.text])
            let pillH = t.separatorLineHeight + 2 * Metrics.separatorPadY
            let pillW = ceil(str.size().width) + 2 * Metrics.separatorPadX
            L.separatorText = str
            L.separatorPill = CGRect(x: ((W - pillW) / 2).rounded(), y: Metrics.separatorTop, width: pillW, height: pillH)
            L.separatorLineY = Metrics.separatorTop + pillH / 2
            y = Metrics.separatorTop + pillH + Metrics.separatorBottom
        }
        let bubbleTop = y + Metrics.bubbleTopInRow
        let padX = Metrics.bubblePadX
        let maxBubbleW = mine ? W - 2 * Metrics.bubbleLeft : W - Metrics.bubbleLeft - Metrics.bubbleRightInset
        let contentMax = maxBubbleW - 2 * padX

        // Header: name and time (time only when threaded), then the actions dots.
        let name = ctx.store.name(of: message.creatorID)
        let timeStr = NSAttributedString(string: time(message.createdAt), attributes: [.font: t.meta, .foregroundColor: Palette.dimText])
        let header = NSMutableAttributedString()
        if !p.isThreaded {
            let nameStr = NSAttributedString(string: name, attributes: [.font: t.metaBold, .foregroundColor: Palette.text])
            let space = NSAttributedString(string: " ", attributes: [.font: t.meta])
            if mine {
                header.append(timeStr); header.append(space); header.append(nameStr)
            } else {
                header.append(nameStr); header.append(space); header.append(timeStr)
            }
        } else {
            header.append(timeStr)
        }
        L.header = header
        let headerTextW = ceil(header.size().width)
        let dotsGap = Metrics.dotsGap * s, dotsW = Metrics.dotsWidth * s
        let headerW = headerTextW + dotsGap + dotsW + Metrics.dotsTrail * s

        // Body pieces.
        enum Piece { case prose(NSAttributedString, CGSize), code(NSAttributedString, CGSize), emoji(NSAttributedString, CGSize) }
        var pieces: [Piece] = []
        var plain: [String] = []
        if message.isEmojiOnly, case .text(let e)? = message.blocks.first {
            let str = TextStyle.emoji(e.trimmingCharacters(in: .whitespaces), typography: t)
            pieces.append(.emoji(str, measurer.size(of: str, width: contentMax)))
            plain.append(e)
        } else {
            var run: [Block] = []
            func flush() {
                guard !run.isEmpty else { return }
                let str = TextStyle.prose(run, typography: t, store: ctx.store)
                pieces.append(.prose(str, measurer.size(of: str, width: contentMax)))
                plain.append(run.map { b -> String in
                    switch b {
                    case .text(let s): return s
                    case .mention(let id): return ctx.store.name(of: id)
                    case .code(_, let src): return src
                    }
                }.joined())
                run.removeAll()
            }
            for block in message.blocks {
                if case .code(let lang, let src) = block {
                    flush()
                    let str = TextStyle.code(src, language: lang, typography: t)
                    pieces.append(.code(str, measurer.size(of: str, width: contentMax - 2 * Metrics.codePadding)))
                    plain.append(src)
                } else {
                    run.append(block)
                }
            }
            flush()
        }

        var imageSize: CGSize?
        var fileName: NSAttributedString?
        switch message.attachment {
        case .image(let w, let h, let c):
            imageSize = CGSize(width: w, height: h)
            L.imageColor = NSColor(srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
            L.imageAttachment = message.attachment
        case .file(let n, let bytes):
            fileName = NSAttributedString(string: n, attributes: [.font: t.body, .foregroundColor: Palette.text])
            plain.append(n)
            L.file = FileLayout(icon: .zero, name: fileName!, nameOrigin: .zero, download: .zero, share: .zero,
                                tooltip: "\(n), \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))")
        case nil:
            break
        }
        L.plainText = plain.joined(separator: "\n")

        // File row widths: icon, name, download and share buttons (measured from Campfire).
        let fileNameW = fileName.map { ceil($0.size().width) } ?? 0
        let fileRowW = fileName == nil ? 0 : 27.4 + fileNameW + 15 + 16 + 25.7 + 11 + (25.6 - padX)

        // Boost pills.
        let pillH = t.boostHeight
        var pillSizes: [(AppBoost, CGFloat, NSAttributedString)] = []
        for b in boosts {
            let emoji = isEmojiText(b.content)
            let str = NSAttributedString(string: b.content, attributes: [.font: emoji ? t.boostEmoji : t.boostText, .foregroundColor: Palette.text])
            let w = 1 + 1.6 * s + (pillH - 2 - 3.2 * s) + 3.5 * s + ceil(str.size().width) + 8.5 * s + 1
            pillSizes.append((b, w, str))
        }
        let hasPills = !pillSizes.isEmpty
        let pillGapX = 5.6 * s, pillGapY = 4 * s

        func flow(_ widths: [CGFloat], maxWidth: CGFloat) -> (positions: [CGPoint], width: CGFloat, height: CGFloat) {
            var x: CGFloat = 0, yy: CGFloat = 0, widest: CGFloat = 0
            var out: [CGPoint] = []
            for w in widths {
                if x > 0, x + w > maxWidth { x = 0; yy += pillH + pillGapY }
                out.append(CGPoint(x: x, y: yy))
                widest = max(widest, x + w)
                x += w + pillGapX
            }
            return (out, widest, widths.isEmpty ? 0 : yy + pillH)
        }

        // Bubble width.
        var bubbleW: CGFloat
        let stripInset: CGFloat
        if let img = imageSize {
            bubbleW = min(Metrics.imageMaxWidth, maxBubbleW)
            stripInset = 10.56
            _ = img
        } else {
            stripInset = padX
            var bodyW: CGFloat = 0
            for piece in pieces {
                switch piece {
                case .prose(_, let sz), .emoji(_, let sz): bodyW = max(bodyW, sz.width)
                case .code(_, let sz): bodyW = max(bodyW, sz.width + 2 * Metrics.codePadding)
                }
            }
            bodyW = max(bodyW, fileRowW)
            if hasPills {
                let f = flow(pillSizes.map(\.1) + [pillH], maxWidth: contentMax)
                bodyW = max(bodyW, f.width)
            }
            bubbleW = min(maxBubbleW, ceil(max(headerW, bodyW)) + 2 * padX)
        }
        let bubbleX = mine ? W - Metrics.bubbleLeft - bubbleW : Metrics.bubbleLeft
        let contentX = bubbleX + padX

        // Header placement.
        let headerLineTop = bubbleTop + Metrics.bubblePadTop
        let headerY = headerLineTop + (t.metaLineHeight - t.meta.lineBoxHeight) / 2 + 0.8
        L.dotsHeight = t.metaLineHeight
        if mine {
            let right = bubbleX + bubbleW - padX
            L.headerOrigin = CGPoint(x: right - headerTextW, y: headerY)
            L.dotsOrigin = CGPoint(x: right - headerTextW - dotsGap - dotsW, y: headerLineTop)
        } else {
            L.headerOrigin = CGPoint(x: contentX, y: headerY)
            L.dotsOrigin = CGPoint(x: contentX + headerTextW + dotsGap, y: headerLineTop)
        }

        // Body, top to bottom.
        var cy = headerLineTop + t.metaLineHeight + Metrics.headerToBody
        var lastWasImage = false
        if let img = imageSize {
            let iw = bubbleW - 2 * Metrics.imageInset
            let ih = (iw * img.height / max(img.width, 1)).rounded(.toNearestOrAwayFromZero)
            let top = headerLineTop + t.metaLineHeight + Metrics.imageTopExtra
            L.image = CGRect(x: bubbleX + Metrics.imageInset, y: top, width: iw, height: ih)
            cy = top + ih
            lastWasImage = true
            if !pieces.isEmpty { cy += 8 }
        }
        var previous = false
        for piece in pieces {
            switch piece {
            case .prose(let str, let sz):
                if previous { cy += 6.4 }
                L.texts.append(TextPiece(string: str, frame: CGRect(x: contentX, y: cy, width: ceil(sz.width) + 2, height: sz.height)))
                cy += sz.height
            case .emoji(let str, let sz):
                L.texts.append(TextPiece(string: str, frame: CGRect(x: contentX, y: cy, width: ceil(sz.width) + 2, height: sz.height)))
                cy += sz.height
            case .code(let str, let sz):
                cy += previous ? 6.4 : 1
                let box = CGRect(x: contentX, y: cy, width: min(contentMax, sz.width + 2 * Metrics.codePadding),
                                 height: sz.height + 2 * Metrics.codePadding)
                L.codeBoxes.append(box)
                L.texts.append(TextPiece(string: str, frame: CGRect(x: box.minX + Metrics.codePadding, y: box.minY + Metrics.codePadding,
                                                                    width: ceil(sz.width) + 2, height: sz.height)))
                cy = box.maxY + 1
            }
            previous = true
            lastWasImage = false
        }
        if let f = L.file {
            if previous { cy += 6.4 }
            let rowH = max(33.92, t.bodyLineHeight + 11.52)
            let mid = cy + rowH / 2 + 0.8
            let icon = CGRect(x: contentX + 1.8, y: mid - 11, width: 18.7, height: 22)
            let nameOrigin = CGPoint(x: contentX + 27.4, y: mid - t.body.lineBoxHeight / 2)
            let download = CGRect(x: nameOrigin.x + fileNameW + 15, y: mid - 8, width: 16, height: 16)
            let share = CGRect(x: download.maxX + 25.7 - 2.5, y: mid - 8, width: 16, height: 16)
            L.file = FileLayout(icon: icon, name: f.name, nameOrigin: nameOrigin, download: download, share: share, tooltip: f.tooltip)
            cy += rowH
            lastWasImage = false
        }

        if hasPills {
            cy += lastWasImage ? 5.3 : 4
            let stripX = bubbleX + stripInset
            let f = flow(pillSizes.map(\.1) + [pillH], maxWidth: bubbleW - 2 * stripInset)
            for (i, item) in pillSizes.enumerated() {
                let o = f.positions[i]
                let frame = CGRect(x: stripX + o.x, y: cy + o.y, width: item.1, height: pillH)
                let d = pillH - 2 - 3.2 * s
                let avatar = CGRect(x: frame.minX + 1 + 1.6 * s, y: frame.minY + 1 + 1.6 * s, width: d, height: d)
                let font = item.2.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? t.boostText
                let contentOrigin = CGPoint(x: avatar.maxX + 3.5 * s, y: frame.midY - font.lineBoxHeight / 2)
                let booster = ctx.store.name(of: item.0.boosterID)
                L.pills.append(PillLayout(frame: frame, avatar: avatar, avatarColor: Palette.avatarColor(for: item.0.boosterID),
                                          initial: initial(of: booster), content: item.2, contentOrigin: contentOrigin,
                                          accessibilityLabel: "\(booster) \(item.0.content)"))
            }
            let o = f.positions[pillSizes.count]
            L.addBoost = CGRect(x: stripX + o.x, y: cy + o.y, width: pillH, height: pillH)
            cy += f.height
            cy += lastWasImage ? 7.12 : Metrics.bubblePadBottom
        } else if lastWasImage {
            cy += Metrics.imageInset
            L.imageAtBottom = true
        } else {
            cy += Metrics.bubblePadBottom
        }

        L.bubble = CGRect(x: bubbleX, y: bubbleTop, width: bubbleW, height: cy - bubbleTop)
        L.bubbleStyle = message.isEmojiOnly ? .none : (p.mentionsMe ? .mention : .normal)

        if !p.isThreaded {
            let x = mine ? W - Metrics.screenPaddingX - Metrics.avatarSize : Metrics.screenPaddingX
            L.avatar = CGRect(x: x, y: bubbleTop, width: Metrics.avatarSize, height: Metrics.avatarSize)
            L.avatarColor = Palette.avatarColor(for: message.creatorID)
            L.avatarInitial = initial(of: name)
        }
        L.height = L.bubble.maxY + Metrics.bubbleBottomMargin
        return L
    }
}
