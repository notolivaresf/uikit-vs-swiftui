import SwiftUI
import CampfireKit

/// The message bubble: meta line, body (text, mentions, code, image, file) and boost pills.
struct Bubble: View {
    let row: RowModel
    let metrics: Metrics
    let theme: Theme
    let store: ChatStore

    private var m: Metrics { metrics }
    private var message: Message { row.message }
    private var p: MessagePresentation { row.presentation }
    private var copyText: String { store.plainText(of: message) }

    var body: some View {
        content
            .background {
                if !message.isEmojiOnly {
                    RoundedRectangle(cornerRadius: m.bubbleRadius, style: .continuous)
                        .fill(p.mentionsMe ? theme.mentionedBubble : theme.bubble)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: m.bubbleRadius, style: .continuous))
            .messageMenu(copyText)
    }

    @ViewBuilder private var content: some View {
        if case .image(let w, let h, let color)? = message.attachment {
            imageContent(width: w, height: h, color: color)
        } else if message.isEmojiOnly {
            VStack(alignment: .leading, spacing: 0) {
                meta
                SelectableText(key: PartKey(message: message.id, part: 0),
                               text: Text(verbatim: message.plainText).font(.system(size: m.emojiSize)),
                               string: message.plainText, lineHeight: m.emojiLine, theme: theme)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .fixedSize()
                    .cssLineHeight(m.emojiLine, fontSize: m.emojiSize, shift: 3.1 * m.s)
            }
            .padding(.horizontal, m.bubblePadX)
            .padding(.bottom, m.bubblePadY)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                meta
                ForEach(Array(segments.enumerated()), id: \.offset) { n, segment in
                    switch segment {
                    case .text(let blocks):
                        BodyText(blocks: blocks, key: PartKey(message: message.id, part: n), metrics: m,
                                 theme: theme, store: store)
                    case .code(let language, let source):
                        CodeBox(source: source, language: language, key: PartKey(message: message.id, part: n),
                                metrics: m, theme: theme)
                            .padding(.top, n > 0 ? 4 * m.s : 0)
                            .padding(.bottom, m.codeBottomExtra)
                    }
                }
                if case .file(let name, let bytes)? = message.attachment {
                    FileLine(name: name, bytes: bytes, key: PartKey(message: message.id, part: segments.count),
                             metrics: m, theme: theme)
                }
                if !message.boosts.isEmpty {
                    BoostStrip(boosts: message.boosts, metrics: m, theme: theme, store: store)
                        .padding(.top, m.boostMarginTop)
                }
            }
            .padding(.horizontal, m.bubblePadX)
            .padding(.bottom, m.bubblePadY)
        }
    }

    private var meta: some View {
        MetaLine(name: p.isThreaded ? nil : (store.user(message.creatorID)?.name ?? "?"),
                 time: Formatting.timeString(message.createdAt), mine: p.isMine, metrics: m, theme: theme)
            .frame(maxWidth: .infinity, alignment: p.isMine ? .trailing : .leading)
            .frame(height: m.bodyTop, alignment: .top)
    }

    private func imageContent(width w: Int, height h: Int, color: RGB) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            meta
                .padding(.horizontal, m.bubblePadX)
                .frame(height: m.imageTop, alignment: .top)
            PlaceholderImage(width: w, height: h, color: color)
                .aspectRatio(CGFloat(w) / CGFloat(max(1, h)), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 1)
            if !captionBlocks.isEmpty {
                BodyText(blocks: captionBlocks, key: PartKey(message: message.id, part: 0), metrics: m,
                         theme: theme, store: store)
                    .padding(.horizontal, m.bubblePadX)
                    .padding(.top, 6 * m.s)
                    .padding(.bottom, message.boosts.isEmpty ? m.bubblePadY : 0)
            }
            if !message.boosts.isEmpty {
                BoostStrip(boosts: message.boosts, metrics: m, theme: theme, store: store)
                    .padding(.leading, 10 * m.s)
                    .padding(.trailing, m.bubblePadX)
                    .padding(.top, 5 * m.s)
                    .padding(.bottom, 7.8 * m.s)
            } else if captionBlocks.isEmpty {
                Color.clear.frame(height: 1)
            }
        }
        .frame(idealWidth: m.imageMaxWidth, maxWidth: m.imageMaxWidth)
        .clipShape(RoundedRectangle(cornerRadius: m.bubbleRadius, style: .continuous))
    }

    private var captionBlocks: [Block] {
        message.blocks.filter { if case .code = $0 { false } else { true } }
    }

    private enum Segment {
        case text([Block])
        case code(String?, String)
    }

    private var segments: [Segment] {
        var out: [Segment] = []
        var run: [Block] = []
        for block in message.blocks {
            if case .code(let language, let source) = block {
                if !run.isEmpty { out.append(.text(run)); run = [] }
                out.append(.code(language, source))
            } else {
                run.append(block)
            }
        }
        if !run.isEmpty { out.append(.text(run)) }
        return out
    }
}

/// "Name 10:12 AM •••", reversed for my own messages.
struct MetaLine: View {
    let name: String?
    let time: String
    let mine: Bool
    let metrics: Metrics
    let theme: Theme

    var body: some View {
        let m = metrics
        let fm = FontMetrics.system(m.metaSize)
        let dots = Dots(metrics: m, color: theme.text.opacity(0.5))
            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4.8 * m.s }
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if mine {
                dots.padding(.trailing, 11.5 * m.s)
                label(reversed: true)
            } else {
                label(reversed: false)
                dots.padding(.leading, 12.5 * m.s)
            }
        }
        .padding(.top, m.metaBaseline - fm.ascent)
    }

    private func label(reversed: Bool) -> Text {
        let m = metrics
        let timeText = Text(time).foregroundStyle(theme.text.opacity(0.5))
        guard let name else { return Text("\(timeText)").font(.system(size: m.metaSize)) }
        let nameText = Text(name).fontWeight(.bold).foregroundStyle(theme.text)
        let t = reversed ? Text("\(timeText) \(nameText)") : Text("\(nameText) \(timeText)")
        return t.font(.system(size: m.metaSize))
    }
}

/// Campfire's "•••" message menu button (drawn only).
struct Dots: View {
    let metrics: Metrics
    let color: Color

    var body: some View {
        HStack(spacing: 1.3 * metrics.s) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(color).frame(width: 4.7 * metrics.s, height: 4.7 * metrics.s)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Paragraph text with inline mentions, selectable like document text.
struct BodyText: View {
    let blocks: [Block]
    let key: PartKey
    let metrics: Metrics
    let theme: Theme
    let store: ChatStore

    var body: some View {
        let m = metrics
        let hasMention = blocks.contains { if case .mention = $0 { true } else { false } }
        SelectableText(key: key, text: composed.font(.system(size: m.bodySize)),
                       string: SelectableParts.paragraph(blocks, store: store), lineHeight: m.bodyLine, theme: theme)
            .foregroundStyle(theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .cssLineHeight(m.bodyLine, fontSize: m.bodySize, shift: 1.85 * m.s)
            // The inline avatar makes SwiftUI grow its line; a browser keeps the line box. Take it back.
            .padding(.top, hasMention ? -MentionAvatars.shared.lineGrowth(metrics: m) : 0)
    }

    /// Must match SelectableParts.paragraph character for character (in UTF-16).
    private var composed: Text {
        var t = Text(verbatim: "")
        for block in blocks {
            switch block {
            case .text(let s):
                t = Text("\(t)\(Text(verbatim: s))")
            case .mention(let id):
                let name = store.user(id)?.name ?? "Unknown"
                let image = MentionAvatars.shared.image(userID: id, name: name, metrics: metrics)
                let avatar = Text(image).baselineOffset(-3.4 * metrics.s)
                let label = Text(verbatim: name).font(.system(size: metrics.mentionSize, weight: .semibold))
                t = Text("\(t)\(avatar)\(label)")
            case .code(_, let s):
                t = Text("\(t)\(Text(verbatim: s))")
            }
        }
        return t
    }
}

/// Inline mention avatars are drawn once per person and size, so they can sit inside a Text run.
@MainActor
final class MentionAvatars {
    static let shared = MentionAvatars()
    private var cache: [String: Image] = [:]

    private var growth: [CGFloat: CGFloat] = [:]

    /// How much taller SwiftUI makes a body line that holds an inline avatar (measured once per text size).
    func lineGrowth(metrics m: Metrics) -> CGFloat {
        if let g = growth[m.s] { return g }
        var g: CGFloat = 0
        if #available(macOS 26, *) {
            let avatar = Text(image(userID: 1, name: "A", metrics: m)).baselineOffset(-3.4 * m.s)
            let probe = Text("\(avatar)Hg\nHg").font(.system(size: m.bodySize)).lineHeight(.exact(points: m.bodyLine))
            let plain = Text("Hg\nHg").font(.system(size: m.bodySize)).lineHeight(.exact(points: m.bodyLine))
            let a = ImageRenderer(content: probe.fixedSize()), b = ImageRenderer(content: plain.fixedSize())
            a.scale = 6; b.scale = 6
            if let ha = a.cgImage?.height, let hb = b.cgImage?.height { g = max(0, CGFloat(ha - hb) / 6) }
        }
        growth[m.s] = g
        return g
    }

    func image(userID: UserID, name: String, metrics: Metrics) -> Image {
        let key = "\(userID)-\(metrics.s)"
        if let hit = cache[key] { return hit }
        let size = metrics.mentionAvatar
        let gap = 2.7 * metrics.s
        let view = HStack(spacing: 0) {
            Text(Formatting.initial(of: name))
                .font(.system(size: size * 0.48, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(AvatarPalette.color(for: userID)))
            Color.clear.frame(width: gap, height: size)
        }
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image: Image
        if let cg = renderer.cgImage {
            image = Image(decorative: cg, scale: 3)
        } else {
            image = Image(systemName: "person.crop.circle.fill")
        }
        cache[key] = image
        return image
    }
}

struct CodeBox: View {
    let source: String
    let language: String?
    let key: PartKey
    let metrics: Metrics
    let theme: Theme

    var body: some View {
        let m = metrics
        SelectableText(key: key,
                       text: Text(CodeHighlighter.attributed(source, language: language, theme: theme))
                           .font(.system(size: m.codeSize, design: .monospaced)),
                       string: source, lineHeight: m.codeLine, theme: theme)
            .fixedSize(horizontal: false, vertical: true)
            .cssLineHeight(m.codeLine, fontSize: m.codeSize, shift: 1.1 * m.s)
            .padding(m.codePadding)
            .background(RoundedRectangle(cornerRadius: m.codeRadius, style: .continuous).fill(theme.codeBox))
    }
}

struct FileLine: View {
    let name: String
    let bytes: Int
    let key: PartKey
    let metrics: Metrics
    let theme: Theme

    var body: some View {
        let m = metrics
        HStack(spacing: 0) {
            Image(systemName: "doc.text.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18.6 * m.s, height: 22 * m.s)
                .foregroundStyle(theme.text)
            SelectableText(key: key, text: Text(verbatim: name).font(.system(size: m.bodySize)), string: name,
                           lineHeight: m.bodyLine, theme: theme)
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .padding(.leading, 7 * m.s)
            IconGlyph(systemName: "arrow.down.to.line", metrics: m, theme: theme)
                .padding(.leading, 8 * m.s)
            IconGlyph(systemName: "square.and.arrow.up", metrics: m, theme: theme)
                .padding(.leading, 9 * m.s)
        }
        .frame(height: 33.92 * m.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))")
    }
}

private struct IconGlyph: View {
    let systemName: String
    let metrics: Metrics
    let theme: Theme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16 * metrics.s, weight: .semibold))
            .foregroundStyle(theme.text)
            .frame(width: 30 * metrics.s, height: 30 * metrics.s)
    }
}

struct BoostStrip: View {
    let boosts: [Boost]
    let metrics: Metrics
    let theme: Theme
    let store: ChatStore

    var body: some View {
        let m = metrics
        FlowLayout(spacing: m.boostGap, lineSpacing: m.boostGap) {
            ForEach(Array(boosts.enumerated()), id: \.offset) { _, boost in
                BoostPill(boost: boost, name: store.user(boost.boosterID)?.name ?? "?", metrics: m, theme: theme)
            }
            AddBoostButton(metrics: m, theme: theme)
        }
    }
}

struct BoostPill: View {
    let boost: Boost
    let name: String
    let metrics: Metrics
    let theme: Theme

    private var isEmoji: Bool {
        boost.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || boost.content.unicodeScalars.first?.properties.isEmoji == true && boost.content.count <= 2
                && !boost.content.unicodeScalars.contains { $0.isASCII }
    }

    var body: some View {
        let m = metrics
        HStack(spacing: m.boostInnerGap) {
            AvatarView(userID: boost.boosterID, name: name, size: m.boostAvatar, theme: theme, fontScale: 0.45)
            Text(boost.content)
                .font(.system(size: isEmoji ? m.boostEmojiSize : m.boostTextSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, m.boostPadLeft + 1)
        .padding(.trailing, m.boostPadRight + 1)
        .frame(height: m.boostHeight)
        .background(Capsule().fill(theme.boostPill))
        .overlay(Capsule().strokeBorder(theme.borderDark, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) boosted \(boost.content)")
    }
}

struct AddBoostButton: View {
    let metrics: Metrics
    let theme: Theme

    var body: some View {
        let m = metrics
        Button {} label: {
            BoostAddIcon(size: 15 * m.s, color: theme.text)
                .frame(width: m.boostHeight, height: m.boostHeight)
                .background(Circle().fill(theme.boostPill))
                .overlay(Circle().strokeBorder(theme.borderDark, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add boost")
    }
}

/// A smiling face with a small plus at the lower right, like Campfire's add-boost icon.
struct BoostAddIcon: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Image(systemName: "face.smiling")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
            Image(systemName: "plus")
                .font(.system(size: size * 0.5, weight: .black))
                .foregroundStyle(color)
                .offset(x: size * 0.42, y: size * 0.4)
        }
    }
}

/// Right-click (or Control-click) on a message: Copy puts the message's text on the clipboard; Reply is
/// drawn only. Attached to the bubble and to each piece of selectable text inside it.
private struct MessageMenu: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Copy") { Clipboard.copy(text) }
            Button("Reply") {}
        }
    }
}

extension View {
    func messageMenu(_ text: String) -> some View { modifier(MessageMenu(text: text)) }
}
