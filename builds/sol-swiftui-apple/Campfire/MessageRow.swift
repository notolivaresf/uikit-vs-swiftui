import SwiftUI
import CampfireKit
import class UIKit.UIPasteboard

struct MessageRow: View {
    let row: ChatRow
    let users: [Int: User]
    @Environment(\.colorScheme) private var scheme


    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        let message = row.message
        let presentation = row.presentation
        VStack(spacing: 0) {
            if presentation.isFirstOfDay { DaySeparator(title: row.day) }
            HStack(spacing: 0) {
                if presentation.isMine { Spacer(minLength: 0) }
                MessageBubble(row: row, users: users)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(presentation.isMine ? .trailing : .leading, 26.8)
                    .overlay(alignment: presentation.isMine ? .topTrailing : .topLeading) {
                        if !presentation.isThreaded {
                            Avatar(id: message.creatorID, initial: String(row.author.prefix(1)))
                                .background(Circle().fill(colors.background).padding(-2.5))
                        }
                    }
                if !presentation.isMine { Spacer(minLength: 0) }
            }
            .padding(.vertical, 1.6)
        }
        .padding(.horizontal, 14)
        .foregroundStyle(colors.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("message-\(row.id)")
    }
}

struct MessageBubble: View {
    let row: ChatRow
    let users: [Int: User]
    @Environment(\.colorScheme) private var scheme


    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        let message = row.message
        BubbleColumn(mine: row.presentation.isMine) {
            MessageMetadata(author: row.presentation.isThreaded ? nil : row.author,
                            time: row.time, mine: row.presentation.isMine)
                .padding(.horizontal, 15.12)
                .padding(.top, 10.56)
                .padding(.bottom, 2.76)
            if !message.blocks.isEmpty {
                StructuredBody(blocks: message.blocks, users: users, emojiOnly: message.isEmojiOnly)
                    .padding(.horizontal, 15.12)
                    .padding(.bottom, message.boosts.isEmpty && message.attachment == nil ? 10.56 : 0)
            }
            if let attachment = message.attachment {
                AttachmentView(attachment: attachment)
                    .padding(.top, isImage ? 10.56 : 0)
                    .padding(.horizontal, isImage ? 0 : 15.12)
                    .padding(.bottom, isImage || !message.boosts.isEmpty ? 0 : 10.56)
            }
            if !message.boosts.isEmpty {
                BoostStrip(boosts: message.boosts, users: users)
                    .padding(.top, 4)
                    .padding(.horizontal, isImage ? 10.56 : 15.12)
                    .padding(.bottom, 10.56)
            } else if isImage {
                Color.clear.frame(height: 10.56)
            }
        }
        .frame(maxWidth: isImage ? 300 : nil, alignment: .leading)
        .background(message.isEmojiOnly ? .clear : row.presentation.mentionsMe ? colors.mention : colors.bubble,
                    in: RoundedRectangle(cornerRadius: 10.56))
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = row.copyText }
            Button("Reply", systemImage: "arrowshape.turn.up.left") {}
        }
    }

    private var isImage: Bool {
        if case .image = row.message.attachment { return true }
        return false
    }
}

struct MessageMetadata: View {
    let author: String?
    let time: String
    let mine: Bool
    @ScaledMetric(relativeTo: .caption) private var size = 12.8

    var body: some View {
        ViewThatFits(in: .horizontal) {
            MetadataLine(author: author, time: time, mine: mine, size: size)
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                if let author { Text(author).fontWeight(.bold) }
                HStack(spacing: 10) {
                    Text(time).opacity(0.5)
                    MetadataMore()
                }
            }
            .font(.system(size: size))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MetadataLine: View {
    let author: String?
    let time: String
    let mine: Bool
    let size: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            if mine { MetadataMore().padding(.trailing, 7) }
            if let author, !mine { Text(author).fontWeight(.bold) }
            Text(time).opacity(0.5)
            if let author, mine { Text(author).fontWeight(.bold) }
            if !mine { MetadataMore().padding(.leading, 7) }
        }
        .font(.system(size: size))
        .frame(height: size * 1.5)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct MetadataMore: View {
    var body: some View {
        HStack(spacing: 1.5) {
            Circle().frame(width: 4.6, height: 4.6)
            Circle().frame(width: 4.6, height: 4.6)
            Circle().frame(width: 4.6, height: 4.6)
        }
        .opacity(0.5)
        .accessibilityHidden(true)
    }
}

struct StructuredBody: View {
    let blocks: [Block]
    let users: [Int: User]
    let emojiOnly: Bool
    @ScaledMetric(relativeTo: .body) private var size = 16.0
    @ScaledMetric(relativeTo: .body) private var emojiSize = 38.4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasInlineText {
                ProseLayout {
                    inlineText
                    .font(.system(size: emojiOnly ? emojiSize : size))
                    .lineSpacing(emojiOnly ? emojiSize * 0.15 : size * (hasMention ? 0 : 0.20625))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.vertical, emojiOnly ? emojiSize * 0.08 : size * (hasMention ? 0.025 : 0.096))
                }
            }
            ForEach(codeBlocks) { block in
                CodeBlock(source: block.source)
            }
        }
    }

    private var hasMention: Bool { blocks.contains { if case .mention = $0 { true } else { false } } }

    private var hasInlineText: Bool {
        blocks.contains { block in
            switch block { case .text(let value): !value.isEmpty; case .mention: true; case .code: false }
        }
    }

    private var inlineText: Text {
        blocks.reduce(Text(verbatim: "")) { result, block in
            let segment: Text
            switch block {
            case .text(let text): segment = Text(verbatim: text)
            case .mention(let id):
                let name = users[id]?.name ?? ""
                let avatar = MentionAvatars.image(id: id, initial: String(name.prefix(1)), size: size * 1.1)
                let icon = Text(avatar).baselineOffset(-size * 0.2)
                let person = Text(verbatim: name).font(.system(size: size, weight: .semibold))
                segment = Text("\(icon) \(person)")
            case .code: segment = Text(verbatim: "")
            }
            return Text("\(result)\(segment)")
        }
    }

    private var codeBlocks: [CodeItem] {
        blocks.enumerated().compactMap { index, block in
            if case .code(_, let source) = block { return CodeItem(id: index, source: source) }
            return nil
        }
    }
}

private struct CodeItem: Identifiable { let id: Int; let source: String }

struct CodeBlock: View {
    let source: String
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption) private var size = 12.8

    var body: some View {
        Text(highlighted)
            .font(.system(size: size, design: .monospaced))
            .lineSpacing(size * 0.21)
            .textSelection(.enabled)
            .padding(.vertical, size * 0.18)
            .padding(12.8)
            .background(RoomColors(dark: scheme == .dark).background,
                        in: RoundedRectangle(cornerRadius: 6.4))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var highlighted: AttributedString {
        var text = AttributedString(source)
        // Syntax coloring is presentation of an already structured code field.
        let keywords = ["def", "end", "func", "let", "var", "return", "if", "else", "class", "import"]
        for word in keywords {
            if let range = text.range(of: word) {
                text[range].foregroundColor = Color(hex: scheme == .dark ? 0xFF7B72 : 0xD73A49)
            }
        }
        if let range = text.range(of: "greet") {
            text[range].foregroundColor = Color(hex: scheme == .dark ? 0xD2A8FF : 0x6F42C1)
        }
        if let first = source.firstIndex(of: "\""), let last = source.lastIndex(of: "\""), first < last,
           let range = text.range(of: String(source[first...last])) {
            text[range].foregroundColor = Color(hex: scheme == .dark ? 0x79C0FF : 0x032F62)
        }
        return text
    }
}

struct AttachmentView: View {
    let attachment: Attachment
    @ScaledMetric(relativeTo: .body) private var size = 16.0

    var body: some View {
        switch attachment {
        case .image(let width, let height, let color):
            Rectangle().fill(Color(rgb: color))
                .aspectRatio(CGFloat(width) / CGFloat(height), contentMode: .fit)
                .frame(maxWidth: 300)
                .accessibilityLabel("Image, \(width) by \(height)")
        case .file(let name, let bytes):
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill").font(.system(size: 22))
                Text(name).font(.system(size: size)).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.down.to.line").font(.system(size: 19, weight: .bold)).padding(.leading, 4)
                Image(systemName: "square.and.arrow.up").font(.system(size: 19)).padding(.leading, 12)
            }
            .frame(minHeight: 33.92)
            .accessibilityLabel("\(name), \(bytes.formatted(.byteCount(style: .file)))")
        }
    }
}

struct DaySeparator: View {
    let title: String
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption) private var size = 12.8

    var body: some View {
        Text(title)
            .font(.system(size: size, weight: .semibold))
            .frame(minHeight: size * 1.4)
            .padding(.horizontal, 19.5)
            .padding(.vertical, 8.5)
            .background(RoomColors(dark: scheme == .dark).bubble, in: Capsule())
            .frame(maxWidth: .infinity)
            .background {
                Rectangle().fill(RoomColors(dark: scheme == .dark).bubble).frame(height: 2)
            }
            .padding(.vertical, 17.02)
    }
}

@MainActor
private enum MentionAvatars {
    private struct Key: Hashable { let id: Int; let initial: String; let size: CGFloat }
    private static var cache: [Key: Image] = [:]
    static func image(id: Int, initial: String, size: CGFloat) -> Image {
        let key = Key(id: id, initial: initial, size: size)
        if let image = cache[key] { return image }
        let renderer = ImageRenderer(content: Avatar(id: id, initial: initial, size: size))
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return Image(systemName: "person.crop.circle.fill") }
        let image = Image(decorative: cgImage, scale: 3)
        cache[key] = image
        return image
    }
}

private struct BubbleColumn: Layout {
    let mine: Bool
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
        return CGSize(width: sizes.map(\.width).max() ?? 0, height: sizes.reduce(0) { $0 + $1.height })
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (index, view) in subviews.enumerated() {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            let x = mine && index == 0 ? bounds.maxX - size.width : bounds.minX
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            y += size.height
        }
    }
}

// CSS fit-content keeps the available width when a paragraph needs wrapping.
// Text's default intrinsic width instead shrinks to its longest wrapped line.
private struct ProseLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let ideal = text.sizeThatFits(.unspecified)
        let width = min(proposal.width ?? ideal.width, ideal.width)
        let fitted = text.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: fitted.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
