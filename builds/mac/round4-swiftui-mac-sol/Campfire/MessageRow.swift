import SwiftUI
import CampfireKit
import AppKit // NSPasteboard only. All views and all scrolling are SwiftUI.

struct MessageRow: View {
    let message: Message
    let presentation: MessagePresentation
    let users: [Int: User]
    let theme: RoomTheme
    let scale: CGFloat
    let availableWidth: CGFloat

    private var author: User { users[message.creatorID]! }
    private var mine: Bool { presentation.isMine }
    private var contentMaxWidth: CGFloat { max(100, availableWidth - 54.8) }
    private var hasImage: Bool { if case .image = message.attachment { true } else { false } }

    var body: some View {
        VStack(spacing: 0) {
            if presentation.isFirstOfDay {
                DaySeparator(date: message.createdAt, theme: theme, scale: scale)
            }
            ZStack(alignment: mine ? .topTrailing : .topLeading) {
                bubble
                    .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                    .padding(mine ? .trailing : .leading, 26.79)
                if !presentation.isThreaded {
                    Avatar(user: author)
                        .background { Circle().fill(theme.background).padding(-2.3) }
                }
            }
            .padding(.horizontal, 14.01)
            .padding(.vertical, 1.6)
        }
        .foregroundStyle(theme.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("message-\(message.id)")
    }

    @ViewBuilder private var bubble: some View {
        if hasImage {
            imageBubble
        } else {
            BubbleWidth(maximum: contentMaxWidth) {
                VStack(alignment: mine ? .trailing : .leading, spacing: 0) {
                    metadata
                    if case .file(let name, let bytes) = message.attachment {
                        file(name, bytes: bytes)
                    } else if message.isEmojiOnly {
                        LineText(text: Text(message.plainText), size: 38.4 * scale, lineHeight: 53.76 * scale)
                            .textSelection(.enabled)
                    } else {
                        messageBody
                    }
                    if !message.boosts.isEmpty { boosts.padding(.top, 4) }
                }
                .padding(.horizontal, 15.12)
                .padding(.vertical, 10.56)
            }
            .background(message.isEmojiOnly ? .clear : presentation.mentionsMe ? theme.mention : theme.bubble,
                        in: RoundedRectangle(cornerRadius: 10.56))
            .frame(maxWidth: contentMaxWidth, alignment: mine ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .contextMenu { contextItems }
        }
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            header(name: author.name)
            header(name: String(author.name.split(separator: " ").first ?? ""))
        }
    }
    private func header(name: String) -> some View {
        HStack(spacing: 4 * scale) {
            if mine { more.padding(.trailing, 6 * scale) }
            if !presentation.isThreaded && !mine { Text(name).fontWeight(.bold).lineLimit(1) }
            Text(RoomDates.time.string(from: message.createdAt)).foregroundStyle(theme.text.opacity(0.5))
            if !presentation.isThreaded && mine { Text(name).fontWeight(.bold).lineLimit(1) }
            if !mine { more.padding(.leading, 6 * scale) }
        }
        .font(.system(size: 12.8 * scale))
        .frame(height: 21.96 * scale, alignment: .center)
        .fixedSize(horizontal: true, vertical: false)
    }
    private var more: some View {
        Button {} label: {
            Image(systemName: "ellipsis").font(.system(size: 15 * scale, weight: .heavy))
                .foregroundStyle(theme.text.opacity(0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Message actions")
    }

    private var messageBody: some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            ForEach(Array(bodyGroups.enumerated()), id: \.offset) { _, group in
                switch group {
                case .prose(let blocks):
                    LineText(text: inlineText(blocks), size: 16 * scale, lineHeight: 22.4 * scale,
                             compactInlineImages: blocks.contains { if case .mention = $0 { true } else { false } })
                        .textSelection(.enabled)
                case .code(let source):
                    LineText(text: highlightedCode(source), size: 12.8 * scale, lineHeight: 17.92 * scale, mono: true)
                        .textSelection(.enabled)
                        .padding(12.8 * scale)
                        .background(theme.background, in: RoundedRectangle(cornerRadius: 6.4))
                }
            }
        }
    }
    private enum BodyGroup {
        case prose([Block])
        case code(String)
    }
    private var bodyGroups: [BodyGroup] {
        var groups: [BodyGroup] = []
        var inline: [Block] = []
        for block in message.blocks {
            if case .code(_, let source) = block {
                if !inline.isEmpty { groups.append(.prose(inline)); inline = [] }
                groups.append(.code(source))
            } else { inline.append(block) }
        }
        if !inline.isEmpty { groups.append(.prose(inline)) }
        return groups
    }
    private func inlineText(_ blocks: [Block]) -> Text {
        blocks.reduce(Text("")) { result, block in
            switch block {
            case .text(let text): return Text("\(result)\(Text(text))")
            case .mention(let id):
                let user = users[id]!
                let avatar = MentionImages.image(user: user, scale: scale)
                let initial = Text(Image(decorative: avatar, scale: 3)).baselineOffset(0)
                return Text("\(result)\(initial) \(Text(user.name).fontWeight(.semibold))")
            case .code: return result
            }
        }
    }
    private func highlightedCode(_ source: String) -> Text {
        // Structured code blocks are rendered directly; only their tokens get
        // colour, never interpreted as message markup.
        var attributed = AttributedString(source)
        attributed.foregroundColor = theme.text
        let patterns: [(String, Color)] = [
            (#"\b(def|end|let|var|func|SELECT|FROM|ORDER BY|DESC|LIMIT)\b"#, theme.keyword),
            (#"\b(greet|print|map)\b"#, theme.entity),
            (#"\"[^\"]*\"|'[^']*'|https://[^\s]+"#, theme.string)
        ]
        for (pattern, color) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                if let range = Range(match.range, in: source),
                   let attrRange = Range(range, in: attributed) { attributed[attrRange].foregroundColor = color }
            }
        }
        return Text(attributed)
    }

    private var imageBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                metadata
                if !message.blocks.isEmpty { messageBody }
            }
            .padding(.horizontal, 15.12).padding(.top, 10.56).padding(.bottom, 12.16)
            if case .image(let width, let height, let color) = message.attachment {
                // CampfireKit's Placeholder specifies a solid colour at this ratio.
                Color(rgb: color)
                    .aspectRatio(CGFloat(width) / CGFloat(height), contentMode: .fit)
                    .padding(.horizontal, 1.1)
                    .accessibilityLabel("Image, \(width) by \(height)")
            }
            if !message.boosts.isEmpty {
                boosts.padding(.horizontal, 12.8).padding(.top, 4).padding(.bottom, 11.2)
            }
        }
        .frame(width: min(300, contentMaxWidth))
        .background(theme.bubble, in: RoundedRectangle(cornerRadius: 10.56))
        .clipShape(RoundedRectangle(cornerRadius: 10.56))
        .contextMenu { contextItems }
    }

    private func file(_ name: String, bytes: Int) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.text.fill").resizable().scaledToFit()
                .frame(width: 18.2 * scale, height: 22.4 * scale)
            LineText(text: Text(name), size: 16 * scale, lineHeight: 22.4 * scale)
                .textSelection(.enabled)
                .padding(.leading, 9.2 * scale)
            Button {} label: {
                Image(systemName: "arrow.down.to.line").resizable().scaledToFit()
                    .frame(width: 19.2 * scale, height: 22.4 * scale)
            }
            .accessibilityLabel("Download \(name)")
            .padding(.leading, 13.4 * scale)
            Button {} label: {
                Image(systemName: "square.and.arrow.up").resizable().scaledToFit()
                    .frame(width: 16 * scale, height: 19.2 * scale)
            }
            .accessibilityLabel("Share \(name)")
            .padding(.leading, 22.4 * scale)
        }
        .padding(.trailing, 6.4 * scale)
        .buttonStyle(.plain)
        .padding(.vertical, 5.75 * scale)
        .accessibilityValue(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
    }
    private var boosts: some View {
        BoostFlow {
            ForEach(Array(message.boosts.enumerated()), id: \.offset) { _, boost in
                HStack(spacing: 4) {
                    Avatar(user: users[boost.boosterID]!, size: 23 * scale)
                    Text(boost.content).font(.system(size: 16 * scale))
                }
                .padding(.leading, 1.6).padding(.trailing, 5)
                .frame(height: 28.64 * scale)
                .background(theme.background, in: Capsule())
                .overlay { Capsule().strokeBorder(theme.border, lineWidth: 1) }
                .accessibilityLabel("\(users[boost.boosterID]!.name): \(boost.content)")
            }
            Button {} label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18 * scale))
                    .overlay(alignment: .bottomTrailing) {
                        Text("+").font(.system(size: 12 * scale, weight: .bold))
                            .background(theme.background).offset(x: 2, y: 2)
                    }
                    .frame(width: 28.64 * scale, height: 28.64 * scale)
                    .background(theme.background, in: Circle())
                    .overlay { Circle().strokeBorder(theme.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add boost")
        }
    }
    @ViewBuilder private var contextItems: some View {
        Button("Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyText, forType: .string)
        }
        Button("Reply") {}
    }
    private var copyText: String {
        var text = message.blocks.map { block in
            switch block {
            case .text(let value): value
            case .mention(let id): users[id]!.name
            case .code(_, let source): source
            }
        }.joined()
        if case .file(let name, _) = message.attachment { text += name }
        return text
    }
}

struct DaySeparator: View {
    let date: Date
    let theme: RoomTheme
    let scale: CGFloat
    var body: some View {
        Text(RoomDates.day.string(from: date).uppercased())
            .font(.system(size: 12.8 * scale, weight: .semibold))
            .frame(height: 17.92 * scale)
            .padding(.horizontal, 19.5)
            .padding(.vertical, 8.5)
            .background(theme.bubble, in: Capsule())
            .frame(maxWidth: .infinity)
            .background { Rectangle().fill(theme.bubble).frame(height: 2) }
            .padding(.horizontal, 14.01)
            .padding(.vertical, 17.02)
    }
}
