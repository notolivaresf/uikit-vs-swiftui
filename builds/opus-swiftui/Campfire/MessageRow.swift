import CampfireKit
import ImageIO
import SwiftUI

/// One message row, laid out like Campfire's `.message` grid: avatar column, bubble, optional day separator.
/// The row box starts 1.59 pt above the bubble and ends 1.6 pt below it (the bubble's bottom margin).
struct MessageRow: View, Equatable {
    let item: RowItem
    let people: People

    nonisolated static func == (a: MessageRow, b: MessageRow) -> Bool {
        a.item == b.item && a.people == b.people
    }

    var body: some View {
        VStack(spacing: 0) {
            if item.isFirstOfDay {
                DaySeparator(date: item.createdAt)
            }
            // A threaded row tucks 1.2 pt under the previous one (Campfire's -22.48 margin against the 21.28 gap);
            // the overlap is taken out of this row's top so row boxes never overlap.
            content
                .padding(.top, item.isThreaded ? Theme.bubbleTopInRow + Theme.gapBetweenRows + Theme.threadedRowMarginTop : Theme.bubbleTopInRow)
                .padding(.bottom, Theme.bubbleBottomMargin)
        }
        .padding(.horizontal, Theme.screenPaddingX)
    }

    @ViewBuilder private var content: some View {
        if item.isMine {
            ZStack(alignment: .topTrailing) {
                BubbleView(item: item, people: people)
                    .padding(.trailing, Theme.bubbleLeft - Theme.screenPaddingX)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if !item.isThreaded {
                    AvatarView(userID: item.creatorID, initial: people.initial(item.creatorID))
                }
            }
        } else {
            ZStack(alignment: .topLeading) {
                BubbleView(item: item, people: people)
                    .padding(.leading, Theme.bubbleLeft - Theme.screenPaddingX)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !item.isThreaded {
                    AvatarView(userID: item.creatorID, initial: people.initial(item.creatorID))
                }
            }
        }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let userID: UserID
    let initial: String
    var size: CGFloat = Theme.avatarSize
    var fontSize: CGFloat = 16
    var ring: CGFloat = Theme.avatarRing

    @Environment(\.palette) private var palette

    var body: some View {
        Circle()
            .fill(Theme.avatarColor(for: userID))
            .overlay {
                Text(initial)
                    .font(.system(size: fontSize, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .background {
                if ring > 0 {
                    Circle().fill(palette.background).padding(-ring)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Day separator

struct DaySeparator: View {
    let date: Date
    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale

    var body: some View {
        let size = scale(12.8)
        let lineHeight = scale(17.92)
        ZStack {
            Rectangle()
                .fill(palette.border)
                .frame(height: 2)
            Text(Format.day.string(from: date).uppercased())
                .font(.system(size: size, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(palette.text)
                .frame(height: lineHeight)
                .padding(.vertical, 8.5)
                .padding(.horizontal, 23.5)
                .background(Capsule().fill(palette.bubble))
        }
        .padding(.top, 17.02)
        .padding(.bottom, 16.87)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bubble

struct BubbleView: View {
    let item: RowItem
    let people: People

    @Environment(SelectionModel.self) private var selection
    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale

    private var imageOnly: Bool {
        if case .image? = item.attachment { return true }
        return false
    }

    var body: some View {
        FitContent {
            VStack(alignment: item.isMine ? .trailing : .leading, spacing: 0) {
                MetaLine(item: item)
                    .padding(.horizontal, Theme.bubblePaddingX)
                    .padding(.top, Theme.bubblePaddingY)
                bodyContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: item.isMine ? .trailing : .leading)
        }
        .background(bubbleShape.fill(bubbleFill))
        .clipShape(bubbleShape)
        .contentShape(bubbleShape)
        .onLongPressGesture(minimumDuration: 0.45) {
            selection.beginMenuOnly(message: item.id)
        }
        .anchorPreference(key: SelectionAnchorKey.self, value: .bounds) { anchor in
            selection.isSelecting(message: item.id)
                ? SelectionAnchor(bounds: anchor, isMine: item.isMine, copy: item.copyText) : nil
        }
        .sensoryFeedback(.selection, trigger: selection.isSelecting(message: item.id))
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: item.isEmojiOnly ? 0 : Theme.bubbleRadius, style: .circular)
    }

    private var bubbleFill: Color {
        if item.isEmojiOnly { return .clear }
        return item.mentionsMe ? palette.mentionedBubble : palette.bubble
    }

    @ViewBuilder private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .image(let w, let h, let color)? = item.attachment {
                ImageAttachment(width: w, height: h, color: color)
                    .padding(.top, 44 - Theme.bubblePaddingY - Theme.metaBlockHeight)
                if !item.blocks.isEmpty {
                    BlocksView(item: item, people: people)
                        .padding(.horizontal, Theme.bubblePaddingX)
                        .padding(.top, 8)
                }
            } else {
                if !item.blocks.isEmpty {
                    BlocksView(item: item, people: people)
                        .padding(.horizontal, Theme.bubblePaddingX)
                }
                if case .file(let name, let bytes)? = item.attachment {
                    FileAttachment(id: SelectionID(messageID: item.id, part: 100), name: name, bytes: bytes)
                        .padding(.horizontal, Theme.bubblePaddingX)
                }
            }
            if !item.boosts.isEmpty {
                BoostStrip(boosts: item.boosts, people: people)
                    .padding(.horizontal, imageOnly ? 10 : Theme.bubblePaddingX)
                    .padding(.top, imageOnly ? 5 : Theme.boostMarginTop)
            }
        }
        .padding(.bottom, bottomPadding)
    }

    private var bottomPadding: CGFloat {
        if imageOnly { return item.boosts.isEmpty && item.blocks.isEmpty ? 1 : 8 }
        return Theme.bubblePaddingY
    }
}

// MARK: - Meta line

struct MetaLine: View {
    let item: RowItem
    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale

    var body: some View {
        let size = scale(12.8)
        let lineHeight = scale(Theme.metaLineHeight)
        HStack(spacing: 0) {
            if item.isMine {
                // Campfire reverses the header for your own messages; the menu button keeps its slot and
                // a little more room on the outside.
                Color.clear.frame(width: 14.6, height: 1)
                MenuDots()
                    .padding(.leading, 2)
                stamp(size)
                if !item.isThreaded {
                    Text(" ") .font(.system(size: size))
                    name(size)
                }
            } else {
                if !item.isThreaded {
                    name(size)
                    Text(" ").font(.system(size: size))
                }
                stamp(size)
                MenuDots()
                    .padding(.trailing, 2)
            }
        }
        .lineLimit(1)
        .frame(height: lineHeight)
        // Chrome sets this line about a point lower than centring it in its 19.2 pt box.
        .padding(.top, 1)
        .padding(.bottom, scale(Theme.metaBlockHeight - Theme.metaLineHeight) - 1)
    }

    private func name(_ size: CGFloat) -> some View {
        Text(item.authorName)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(palette.text)
    }

    private func stamp(_ size: CGFloat) -> some View {
        Text(Format.time.string(from: item.createdAt))
            .font(.system(size: size))
            .foregroundStyle(palette.text.opacity(0.5))
    }
}

/// Campfire's "•••" message menu button (drawn, does nothing).
struct MenuDots: View {
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 1.67) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().frame(width: 4.67, height: 4.67)
            }
        }
        .foregroundStyle(palette.text.opacity(0.5))
        .frame(width: 42)
        .accessibilityHidden(true)
    }
}

// MARK: - Blocks (text, mentions, code)

struct BlocksView: View {
    let item: RowItem
    let people: People

    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale
    @Environment(\.listWidth) private var listWidth

    /// Width of the bubble's text column when the bubble is at its widest.
    private var textWidth: CGFloat {
        listWidth - 2 * Theme.screenPaddingX - (Theme.bubbleLeft - Theme.screenPaddingX) - 2 * Theme.bubblePaddingX
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                switch group {
                case .inline(let blocks):
                    inlineText(blocks, part: index)
                case .code(let language, let source):
                    CodeBlock(id: SelectionID(messageID: item.id, part: index), language: language, source: source)
                }
            }
        }
    }

    private enum Group {
        case inline([Block])
        case code(String?, String)
    }

    private var groups: [Group] {
        var out: [Group] = []
        var run: [Block] = []
        for b in item.blocks {
            if case .code(let l, let s) = b {
                if !run.isEmpty { out.append(.inline(run)); run = [] }
                out.append(.code(l, s))
            } else {
                run.append(b)
            }
        }
        if !run.isEmpty { out.append(.inline(run)) }
        return out
    }

    @ViewBuilder private func inlineText(_ blocks: [Block], part: Int) -> some View {
        let id = SelectionID(messageID: item.id, part: part)
        if item.isEmojiOnly {
            let size = scale(38.4)
            // Apple Color Emoji sits lower and wider in SwiftUI than in Chrome; nudge it onto Campfire's line box.
            SelectableText(id: id, normal: Text(blocks.textOnly)) { TextPiece.characters(of: blocks.textOnly) }
                .font(.system(size: size))
                .tracking(-size * 0.13)
                .fixedSize()
                .offset(x: -2 * scale.factor, y: -1 * scale.factor)
                .frame(height: scale(53.76), alignment: .center)
        } else {
            let size = scale(16)
            SelectableText(id: id, normal: composed(blocks, size: size)) { pieces(blocks, size: size) }
                .font(.system(size: size))
                .foregroundStyle(palette.text)
                .cssLineHeight(scale(22.4), fontSize: size)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .topLeading) {
                    if case .mention(let id)? = blocks.first {
                        AvatarView(userID: id, initial: people.initial(id), size: scale(MentionAvatar.size),
                                   fontSize: scale(8), ring: 0)
                            .offset(x: 1.08, y: scale(3.48))
                    }
                }
        }
    }

    /// The same text as `composed`, one piece per character, for selection.
    private func pieces(_ blocks: [Block], size: CGFloat) -> [TextPiece] {
        if blocks.count == 1, case .text(let t) = blocks[0] {
            return TextPiece.characters(of: LineBreaker.greedy(t, width: textWidth, fontSize: size))
        }
        var out: [TextPiece] = []
        var first = true
        for b in blocks {
            switch b {
            case .text(let t):
                out += TextPiece.characters(of: t)
            case .mention(let id):
                if first {
                    out.append(TextPiece(text: Text(MentionAvatar.spacer(width: scale(MentionAvatar.size) - 0.25)), copy: "@"))
                    out += TextPiece.characters(of: " ")
                } else {
                    out += TextPiece.characters(of: "@") { $0.fontWeight(.semibold) }
                }
                out += TextPiece.characters(of: people.name(id)) { $0.fontWeight(.semibold) }
            case .code:
                break
            }
            first = false
        }
        return out
    }

    private func composed(_ blocks: [Block], size: CGFloat) -> Text {
        if blocks.count == 1, case .text(let t) = blocks[0] {
            return Text(verbatim: LineBreaker.greedy(t, width: textWidth, fontSize: size))
        }
        if case .mention(let id)? = blocks.first {
            // A leading mention: leave a gap for the avatar (drawn as an overlay so it cannot change the line height).
            var text = Text(MentionAvatar.spacer(width: scale(MentionAvatar.size) - 0.25)) + Text(verbatim: " ")
                + Text(verbatim: people.name(id)).fontWeight(.semibold)
            for b in blocks.dropFirst() {
                switch b {
                case .text(let t): text = text + Text(verbatim: t)
                case .mention(let other):
                    text = text + Text(verbatim: "@").fontWeight(.semibold) + Text(verbatim: people.name(other)).fontWeight(.semibold)
                case .code: break
                }
            }
            return text
        }
        var text = Text(verbatim: "")
        for b in blocks {
            switch b {
            case .text(let t):
                text = text + Text(verbatim: t)
            case .mention(let id):
                text = text + Text(MentionAvatar.image(for: id, initial: people.initial(id), dark: palette.isDark))
                    .baselineOffset(-scale(3))
                    + Text(verbatim: " ") + Text(verbatim: people.name(id)).fontWeight(.semibold)
            case .code:
                break
            }
        }
        return text
    }
}

private extension Array where Element == Block {
    var textOnly: String {
        compactMap { if case .text(let t) = $0 { t } else { nil } }.joined()
    }
}

/// The small avatar inside a mention pill, rendered once per person into an inline image.
@MainActor
enum MentionAvatar {
    static let size: CGFloat = 17.5
    private static var cache: [String: Image] = [:]
    private static var spacers: [CGFloat: Image] = [:]

    /// A transparent 1 pt tall image that reserves horizontal room inside a Text.
    static func spacer(width: CGFloat) -> Image {
        if let img = spacers[width] { return img }
        let renderer = ImageRenderer(content: Color.clear.frame(width: width, height: 1))
        renderer.scale = 3
        let image: Image = renderer.cgImage.map { Image(decorative: $0, scale: 3) } ?? Image(systemName: "circle")
        spacers[width] = image
        return image
    }

    static func image(for id: UserID, initial: String, dark: Bool) -> Image {
        let key = "\(id)-\(dark)"
        if let img = cache[key] { return img }
        let view = Circle()
            .fill(Theme.avatarColor(for: id))
            .overlay { Text(initial).font(.system(size: 8, weight: .heavy)).foregroundStyle(.white) }
            .frame(width: 17, height: 17)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image: Image = renderer.cgImage.map { Image(decorative: $0, scale: 3) } ?? Image(systemName: "person.circle.fill")
        cache[key] = image
        return image
    }
}

// MARK: - Code

struct CodeBlock: View {
    let id: SelectionID
    let language: String?
    let source: String

    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale

    var body: some View {
        let size = scale(12.8)
        let highlighted = Highlighter.highlight(source, language: language, palette: palette)
        SelectableText(id: id, normal: Text(highlighted)) { TextPiece.characters(of: highlighted) }
            .font(.system(size: size, design: .monospaced))
            .tracking(-0.157 * scale.factor)
            .foregroundStyle(palette.text)
            .cssLineHeight(scale(17.92), fontSize: size)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.codePadding)
            .background(RoundedRectangle(cornerRadius: Theme.codeRadius).fill(palette.background))
            .overlay(RoundedRectangle(cornerRadius: Theme.codeRadius).strokeBorder(palette.border, lineWidth: 1))
            .padding(1)
    }
}

/// A few rules in the spirit of Rouge's GitHub theme: keywords, function names, strings, numbers, comments.
enum Highlighter {
    static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "class", "module", "if", "else", "elsif", "unless", "do", "return", "puts", "nil", "true", "false", "self", "yield"],
        "swift": ["let", "var", "func", "return", "if", "else", "guard", "struct", "class", "import", "print", "true", "false", "nil", "self"],
        "sh": [],
        "sql": ["SELECT", "FROM", "WHERE", "ORDER", "BY", "LIMIT", "DESC", "ASC", "AND", "OR", "INSERT", "UPDATE", "DELETE", "JOIN", "ON", "AS"],
    ]
    private static let builtins: Set<String> = ["puts", "print"]

    static func highlight(_ source: String, language: String?, palette: Palette) -> AttributedString {
        let lang = language ?? "sql"
        let kw = keywords[lang] ?? []
        var out = AttributedString()
        let chars = Array(source)
        var i = 0
        var previousWord = ""
        func append(_ s: String, _ color: Color?) {
            var a = AttributedString(s)
            if let color { a.foregroundColor = color }
            out += a
        }
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count, chars[j] != c, chars[j] != "\n" { j += 1 }
                let end = min(j + 1, chars.count)
                append(String(chars[i..<end]), palette.codeString)
                i = end
            } else if c == "#", lang != "ruby" || (i + 1 < chars.count && chars[i + 1] != "{") {
                var j = i
                while j < chars.count, chars[j] != "\n" { j += 1 }
                append(String(chars[i..<j]), palette.codeComment)
                i = j
            } else if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                let word = String(chars[i..<j])
                if (previousWord == "def" || previousWord == "func") {
                    append(word, palette.codeEntity)
                } else if kw.contains(word) && !builtins.contains(word) {
                    append(word, palette.codeKeyword)
                } else {
                    append(word, nil)
                }
                previousWord = word
                i = j
            } else if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber { j += 1 }
                append(String(chars[i..<j]), palette.codeConstant)
                i = j
            } else {
                append(String(c), nil)
                if !c.isWhitespace { previousWord = "" }
                i += 1
            }
        }
        return out
    }
}

// MARK: - Attachments

struct ImageAttachment: View {
    let width: Int
    let height: Int
    let color: RGB

    var body: some View {
        let w = min(Theme.imageMaxWidth - 2, CGFloat(width))
        let h = (w * CGFloat(height) / CGFloat(max(1, width))).rounded(.down)
        PlaceholderImage.image(for: color)
            .resizable()
            .interpolation(.none)
            .frame(width: w, height: h)
            .padding(.horizontal, 1)
            .accessibilityLabel("Image")
    }
}

/// CampfireKit's placeholder PNG, decoded once per colour. The placeholder is a single flat colour, so a small
/// bitmap stretched to the bubble draws exactly what the full-size one would.
@MainActor
enum PlaceholderImage {
    private static var cache: [RGB: Image] = [:]

    static func image(for color: RGB) -> Image {
        if let hit = cache[color] { return hit }
        let data = Placeholder.pngData(width: 4, height: 4, color: color) as CFData
        var image = Image(systemName: "photo")
        if let source = CGImageSourceCreateWithData(data, nil),
           let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            image = Image(decorative: cg, scale: 1)
        }
        cache[color] = image
        return image
    }
}

struct FileAttachment: View {
    let id: SelectionID
    let name: String
    let bytes: Int

    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale

    var body: some View {
        HStack(spacing: 0) {
            FileIcon()
                .frame(width: 18, height: 22)
                .padding(.leading, 2.08)
                .padding(.trailing, 7.5)
            SelectableText(id: id, normal: Text(name)) { TextPiece.characters(of: name) }
                .font(.system(size: scale(16)))
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Image(systemName: "arrow.down.to.line")
                .resizable()
                .fontWeight(.bold)
                .frame(width: 16, height: 16.67)
                .padding(.leading, 14.33)
            Image(systemName: "square.and.arrow.up")
                .resizable()
                .fontWeight(.medium)
                .frame(width: 11.33, height: 16.67)
                .padding(.leading, 25.33)
                .padding(.trailing, 11.2)
        }
        .foregroundStyle(palette.text)
        .frame(height: 33.92)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(Format.fileSize(bytes))")
    }
}

/// Campfire's document glyph: a black page with a folded corner and three lines.
struct FileIcon: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, fold = w * 0.36
            var page = Path()
            page.move(to: CGPoint(x: 2, y: 0))
            page.addLine(to: CGPoint(x: w - fold, y: 0))
            page.addLine(to: CGPoint(x: w, y: fold))
            page.addLine(to: CGPoint(x: w, y: h - 2))
            page.addQuadCurve(to: CGPoint(x: w - 2, y: h), control: CGPoint(x: w, y: h))
            page.addLine(to: CGPoint(x: 2, y: h))
            page.addQuadCurve(to: CGPoint(x: 0, y: h - 2), control: CGPoint(x: 0, y: h))
            page.addLine(to: CGPoint(x: 0, y: 2))
            page.addQuadCurve(to: CGPoint(x: 2, y: 0), control: CGPoint(x: 0, y: 0))
            ctx.fill(page, with: .color(palette.text))
            let lineColor = palette.bubble
            for (i, frac) in [0.62, 0.62, 0.42].enumerated() {
                let y = h * 0.5 + CGFloat(i) * 3.6
                let r = CGRect(x: w * 0.2, y: y, width: w * frac, height: 2)
                ctx.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(lineColor))
            }
        }
    }
}

// MARK: - Boosts

struct BoostStrip: View {
    let boosts: [BoostItem]
    let people: People

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(boosts) { b in
                BoostPill(boost: b, initial: people.initial(b.boosterID))
            }
            AddBoostButton()
        }
    }
}

struct BoostPill: View {
    let boost: BoostItem
    let initial: String

    @Environment(\.palette) private var palette
    @Environment(\.typeScale) private var scale

    private var isEmoji: Bool {
        boost.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }

    var body: some View {
        HStack(spacing: 0) {
            AvatarView(userID: boost.boosterID, initial: initial, size: 24, fontSize: 11.5, ring: 0)
            Text(boost.content)
                .font(.system(size: scale(12.8)))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .padding(.leading, isEmoji ? 2.67 : 4)
                .padding(.trailing, isEmoji ? 6.67 : 5)
        }
        .padding(.leading, 1.6)
        .padding(.trailing, 3.2)
        .frame(minHeight: 27)
        .background(Capsule().fill(palette.background))
        .overlay(Capsule().strokeBorder(palette.borderDark, lineWidth: 1).padding(-1))
        .padding(1)
        .accessibilityElement(children: .combine)
    }
}

struct AddBoostButton: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Button {} label: {
            SmileyPlusGlyph()
                .frame(width: 18, height: 18)
                .foregroundStyle(palette.text)
                .frame(width: 28, height: 28)
                .background(Circle().fill(palette.background))
                .overlay(Circle().strokeBorder(palette.borderDark, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add boost")
    }
}

/// Campfire's add-boost glyph: an outlined smiley with a plus at its lower right.
struct SmileyPlusGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 18
            let face = Path { p in
                p.addArc(center: CGPoint(x: 8 * s, y: 8 * s), radius: 6.6 * s,
                         startAngle: .degrees(70), endAngle: .degrees(20), clockwise: false)
            }
            ctx.stroke(face, with: .foreground, style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round))
            for x in [5.6, 10.4] {
                ctx.fill(Path(ellipseIn: CGRect(x: (x - 1.1) * s, y: 5.2 * s, width: 2.2 * s, height: 2.2 * s)), with: .foreground)
            }
            let smile = Path { p in
                p.addArc(center: CGPoint(x: 8 * s, y: 8.6 * s), radius: 3.2 * s,
                         startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
            }
            ctx.stroke(smile, with: .foreground, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
            var plus = Path()
            plus.move(to: CGPoint(x: 14.5 * s, y: 11.6 * s)); plus.addLine(to: CGPoint(x: 14.5 * s, y: 17.2 * s))
            plus.move(to: CGPoint(x: 11.7 * s, y: 14.4 * s)); plus.addLine(to: CGPoint(x: 17.3 * s, y: 14.4 * s))
            ctx.stroke(plus, with: .foreground, style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round))
        }
    }
}

/// Left-to-right wrapping layout for the boost strip.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > bounds.width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// CSS `width: fit-content`: as wide as the content wants, but never wider than offered; once text wraps the
/// box takes the whole offered width (SwiftUI would otherwise shrink it to the longest wrapped line).
struct FitContent: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(.unspecified)
        let width = proposal.width.map { min(ideal.width, $0) } ?? ideal.width
        let height = child.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}
