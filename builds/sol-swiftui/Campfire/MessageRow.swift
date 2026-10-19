import SwiftUI
import CampfireKit
import class UIKit.UIPasteboard

struct MessageRow: View, Equatable {
    nonisolated static func == (lhs: MessageRow, rhs: MessageRow) -> Bool {
        lhs.row.message == rhs.row.message && lhs.row.presentation == rhs.row.presentation && lhs.extraBoosts == rhs.extraBoosts
    }
    let row: RoomRow
    let users: [UserID: User]
    let extraBoosts: [RoomBoost]
    @Environment(\.colorScheme) private var scheme
    @State private var hasSelection = false
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @ScaledMetric(relativeTo: .body) private var metaSize = 12.8
    @ScaledMetric(relativeTo: .body) private var emojiSize = 38.4
    @ScaledMetric(relativeTo: .body) private var codeSize = 12.8
    private var theme: RoomTheme { RoomTheme(scheme: scheme) }
    private var message: Message { row.message }
    private var presentation: MessagePresentation { row.presentation }
    private var author: User { users[message.creatorID]! }
    private var boosts: [RoomBoost] { message.boosts.map(RoomBoost.init) + extraBoosts }
    private var scale: CGFloat { bodySize / 16 }
    private var hasImage: Bool { if case .image? = message.attachment { true } else { false } }
    private var imageWidth: CGFloat? { hasImage ? 300 : nil }

    var body: some View {
        VStack(spacing: 0) {
            if presentation.isFirstOfDay { daySeparator }
            ZStack(alignment: presentation.isMine ? .topTrailing : .topLeading) {
                bubble
                    .padding(presentation.isMine ? .trailing : .leading, 26.79)
                    .padding(.leading, presentation.isMine ? 23.43 : 0)
                    .frame(maxWidth: .infinity, alignment: presentation.isMine ? .trailing : .leading)
                if !presentation.isThreaded {
                    Avatar(user: author)
                        .background { Circle().fill(theme.background).padding(-2.5) }
                }
            }
            .padding(.top, 1.6)
            .padding(.bottom, hasImage ? 5.14 : (message.isEmojiOnly ? 0 : 1.6))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("message-\(message.id)")
        }
        .onPreferenceChange(SelectionActiveKey.self) { hasSelection = $0 }
        .zIndex(hasSelection ? 10 : 0)
    }

    private var daySeparator: some View {
        Text(RoomDates.day.string(from: message.createdAt).uppercased())
            .font(.system(size: metaSize, weight: .semibold))
            .frame(height: 17.92 * scale)
            .padding(.horizontal, 19.5)
            .padding(.vertical, 8.5)
            .background(theme.bubble, in: Capsule())
            .frame(maxWidth: .infinity)
            .background { Rectangle().fill(theme.bubble).frame(height: 2) }
            .padding(.vertical, 17.02)
            .accessibilityIdentifier("day-\(message.id)")
    }

    private var bubble: some View {
        BubbleSizing(width: imageWidth) {
            VStack(alignment: .leading, spacing: 0) {
                metadata
                    .padding(.horizontal, 15.12)
                    .padding(.top, 10.56)
                    .padding(.bottom, (hasImage ? 14.24 : 2.76) * scale)
                if !message.blocks.isEmpty {
                    messageBody
                        .padding(.horizontal, 15.12)
                        .padding(.bottom, hasImage ? 10.56 : 0)
                }
                if let attachment = message.attachment {
                    attachmentView(attachment)
                }
                if !boosts.isEmpty {
                    BoostFlow {
                        ForEach(boosts) { boost in
                            boostPill(boost)
                        }
                        addBoost
                    }
                    .padding(.horizontal, hasImage ? 10.56 : 15.12)
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, hasImage ? 8.4 : 10.56)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(message.isEmojiOnly ? .clear : (presentation.mentionsMe ? theme.mention : theme.bubble),
                    in: RoundedRectangle(cornerRadius: 10.56))
        .foregroundStyle(theme.text)
        .contextMenu {
            if hasImage && message.blocks.isEmpty {
                Button("Copy", systemImage: "doc.on.doc") {
                    if case .image(let width, let height, let color)? = message.attachment {
                        UIPasteboard.general.setData(Placeholder.pngData(width: width, height: height, color: color),
                                                     forPasteboardType: "public.png")
                    }
                }
                Button("Reply", systemImage: "arrowshape.turn.up.left") { }
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            if presentation.isMine {
                moreButton
                timestamp
                if !presentation.isThreaded { authorName }
            } else {
                if !presentation.isThreaded { authorName }
                timestamp
                moreButton
            }
        }
        .font(.system(size: metaSize))
        .frame(height: 19.2 * scale)
        .frame(maxWidth: hasImage || presentation.isMine ? .infinity : nil, alignment: presentation.isMine ? .trailing : .leading)
    }

    private var authorName: some View {
        Text(author.name).fontWeight(.bold).lineLimit(1)
    }
    private var timestamp: some View {
        Text(RoomDates.time.string(from: message.createdAt)).opacity(0.5).fixedSize()
    }
    private var moreButton: some View {
        Button { } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: metaSize, weight: .heavy))
                .frame(width: 22.4 * scale, height: 19.2 * scale)
        }
        .buttonStyle(.plain)
        .opacity(0.5)
        .padding(presentation.isMine ? .trailing : .leading, 4)
        .accessibilityLabel("Message options")
    }

    @ViewBuilder private var messageBody: some View {
        if message.isEmojiOnly {
            SelectableMessageText(text: Text(message.plainText), plain: message.plainText)
                .font(.system(size: emojiSize))
                .frame(minHeight: 53.76 * scale, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8 * scale) {
                ForEach(Array(textGroups.enumerated()), id: \.offset) { _, group in
                    switch group {
                    case .paragraph(let blocks):
                        SelectableMessageText(text: paragraph(blocks), plain: plainText(blocks), inlineAvatars: blocks.contains { if case .mention = $0 { true } else { false } })
                            .font(.system(size: bodySize))
                            .lineSpacing(3.3 * scale)
                            .padding(.vertical, 1.65 * scale)
                            .fixedSize(horizontal: false, vertical: true)
                                case .code(let source):
                        SelectableMessageText(text: highlightedCode(source), plain: source)
                            .font(.system(size: codeSize, design: .monospaced))
                            .lineSpacing(2.6 * scale)
                            .padding(.vertical, 2.45 * scale)
                                        .padding(12.8)
                            .background(theme.background, in: RoundedRectangle(cornerRadius: 6.4))
                    }
                }
            }
        }
    }

    private enum TextGroup {
        case paragraph([Block])
        case code(String)
    }
    private var textGroups: [TextGroup] {
        var result: [TextGroup] = [], inline: [Block] = []
        for block in message.blocks {
            if case .code(_, let source) = block {
                if !inline.isEmpty { result.append(.paragraph(inline)); inline = [] }
                result.append(.code(source))
            } else { inline.append(block) }
        }
        if !inline.isEmpty { result.append(.paragraph(inline)) }
        return result
    }

    private func plainText(_ blocks: [Block]) -> String {
        blocks.map {
            switch $0 {
            case .text(let text): text
            case .mention(let id): "\u{2003} " + (users[id]?.name ?? "")
            case .code(_, let source): source
            }
        }.joined()
    }

    private func paragraph(_ blocks: [Block]) -> Text {
        blocks.reduce(Text("")) { result, block in
            switch block {
            case .text(let text): return result + Text(text)
            case .mention(let id):
                let user = users[id]!
                return result + Text("\u{2003}").customAttribute(InlineAvatarTag(color: Avatar.color(id), initial: String(user.name.prefix(1))))
                    + Text(" ") + Text(user.name).fontWeight(.semibold)
            case .code: return result
            }
        }
    }

    private func highlightedCode(_ source: String) -> Text {
        // Colour tokens for display only; the body remains the package's structured code block.
        let tokens = source.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" })
        return tokens.enumerated().reduce(Text("")) { result, item in
            var line = Text("")
            let value = String(item.element)
            if value.hasPrefix("def ") {
                let tail = String(value.dropFirst(4))
                let name = String(tail.prefix { $0 != "(" })
                line = Text("def ").foregroundColor(theme.keyword) + Text(name).foregroundColor(theme.entity)
                    + Text(String(tail.dropFirst(name.count)))
            } else if value == "end" {
                line = Text(value).foregroundColor(theme.keyword)
            } else if let start = value.firstIndex(of: "\"") {
                line = Text(String(value[..<start])) + Text(String(value[start...])).foregroundColor(theme.string)
            } else { line = Text(value) }
            return result + (item.offset == 0 ? Text("") : Text("\n")) + line
        }
    }

    @ViewBuilder private func attachmentView(_ attachment: Attachment) -> some View {
        switch attachment {
        case .image(let width, let height, let color):
            Rectangle()
                .fill(Color(rgb: color))
                .aspectRatio(CGFloat(width) / CGFloat(height), contentMode: .fit)
                .padding(.horizontal, 1)
                .accessibilityLabel("Image, \(width) by \(height)")
        case .file(let name, let bytes):
            HStack(spacing: 8) {
                FileGlyph(kind: .document, ink: theme.text, cutout: theme.background)
                SelectableMessageText(text: Text(name), plain: name).font(.system(size: bodySize)).lineLimit(1)
                FileGlyph(kind: .download, ink: theme.text, cutout: theme.background)
                FileGlyph(kind: .share, ink: theme.text, cutout: theme.background)
            }
            .frame(minHeight: 31.52 * scale)
            .offset(y: 2.1)
            .padding(.horizontal, 15.12)
            .padding(.bottom, 2.6)
            .accessibilityLabel("\(name), \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))")
        }
    }

    private func boostPill(_ boost: RoomBoost) -> some View {
        HStack(spacing: 4) {
            Avatar(user: users[boost.userID]!, size: 22.4)
            Text(boost.content)
                .font(.system(size: boost.content.contains(where: { $0.isLetter || $0.isNumber || $0 == "+" }) ? bodySize : 17.6 * scale))
                .lineLimit(1)
        }
        .padding(.leading, 1.6).padding(.trailing, 5.2)
        .frame(minHeight: 28.64)
        .background(theme.background, in: Capsule())
        .overlay { Capsule().strokeBorder(theme.border, lineWidth: 1) }
        .accessibilityLabel("\(users[boost.userID]!.name) boosted \(boost.content)")
    }
    private var addBoost: some View {
        Button { } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: 18))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus").font(.system(size: 8, weight: .heavy))
                        .padding(1).background(theme.background, in: Circle()).offset(x: 3, y: 1)
                }
                .frame(width: 28.64, height: 28.64)
                .background(theme.background, in: Circle())
                .overlay { Circle().strokeBorder(theme.border, lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel("Add boost")
    }
}
