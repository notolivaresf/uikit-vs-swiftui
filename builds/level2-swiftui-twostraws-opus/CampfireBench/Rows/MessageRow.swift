import CampfireKit
import SwiftUI

/// One message: optional day separator, then the avatar and bubble. Mine sits on the right with the
/// avatar on the right and the header reversed.
struct MessageRow: View, Equatable {
    let row: RowModel

    @Environment(\.metrics) private var metrics
    @Environment(\.users) private var users
    @Environment(\.displayScale) private var displayScale
    @Environment(SelectionModel.self) private var selection

    nonisolated static func == (lhs: MessageRow, rhs: MessageRow) -> Bool { lhs.row == rhs.row }

    private var message: Message { row.message }
    private var presentation: MessagePresentation { row.presentation }
    private var isMine: Bool { presentation.isMine }

    var body: some View {
        VStack(spacing: 0) {
            if presentation.isFirstOfDay {
                DaySeparator(date: message.createdAt)
            }
            ZStack(alignment: isMine ? .topTrailing : .topLeading) {
                bubble
                    .padding(isMine ? .trailing : .leading, Metrics.bubbleOffset)
                    .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
                if !presentation.isThreaded {
                    AvatarView(userID: message.creatorID, name: users.name(message.creatorID))
                        .background(Circle().fill(Palette.background).padding(-Metrics.avatarRing))
                }
            }
            .padding(.top, Metrics.rowTopInset)
            .padding(.bottom, Metrics.rowBottomInset)
        }
        .padding(.horizontal, Metrics.screenPaddingX)
    }

    // MARK: Bubble

    private var bubble: some View {
        BubbleStack {
            MessageHeader(name: presentation.isThreaded ? nil : users.name(message.creatorID),
                          time: Formatters.timeString(message.createdAt), isMine: isMine)
                .padding(.top, Metrics.bubblePaddingY)
                .padding(.horizontal, Metrics.bubblePaddingX)
                .bubbleAlignment(isMine ? .trailing : .leading)
            content
        }
        .padding(.bottom, bottomPadding)
        .background {
            RoundedRectangle(cornerRadius: Metrics.bubbleRadius)
                .fill(bubbleColor)
        }
        .contentShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius))
        .onLongPressGesture(minimumDuration: 0.45) {
            selection.selectAll(messageID: message.id, block: 0, plain: firstSelectablePlain)
        }
        .anchorPreference(key: SelectedBubbleKey.self, value: .bounds) { [isSelected = selection.messageID == message.id] in
            isSelected ? $0 : nil
        }
        .accessibilityElement(children: .contain)
    }

    private var bubbleColor: Color {
        if message.isEmojiOnly { return .clear }
        return presentation.mentionsMe ? Palette.mentionBubble : Palette.bubble
    }

    @ViewBuilder
    private var content: some View {
        if message.isEmojiOnly, case .text(let emoji)? = message.blocks.first {
            SelectableText(messageID: message.id, block: 0,
                           text: Text(verbatim: emoji).font(.system(size: metrics.emojiSize)),
                           plain: emoji, fontSize: metrics.emojiSize, lineHeight: metrics.emojiLine)
                .frame(minHeight: metrics.emojiLine)
                .padding(.horizontal, Metrics.bubblePaddingX)
        } else {
            switch message.attachment {
            case .image(let width, let height, let color):
                ImageAttachmentView(width: width, height: height, color: color,
                                    roundsBottom: row.boosts.isEmpty && message.blocks.isEmpty)
                    .padding(.top, Metrics.imageTopGap)
                    .bubbleAlignment(.leading)
            case .file(let name, let bytes):
                FileAttachmentView(name: name, bytes: bytes)
                    .padding(.horizontal, Metrics.bubblePaddingX)
            case nil:
                EmptyView()
            }
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                sectionView(section, index: index)
                    .padding(.top, topGap(before: index))
                    .padding(.horizontal, Metrics.bubblePaddingX)
            }
        }
        if !row.boosts.isEmpty {
            BoostStrip(boosts: row.boosts)
                .padding(.top, isImage ? Metrics.boostTopGapAfterImage : Metrics.boostTopGap)
                .padding(.horizontal, Metrics.bubblePaddingX)
        }
    }

    private var sections: [BodySection] { RichText.sections(of: message.blocks) }

    @ViewBuilder
    private func sectionView(_ section: BodySection, index: Int) -> some View {
        switch section {
        case .paragraph(let blocks):
            let paragraph = RichText.paragraph(blocks, users: users, metrics: metrics, displayScale: displayScale)
            SelectableText(messageID: message.id, block: index, text: paragraph.text, plain: paragraph.plain,
                           fontSize: metrics.bodySize, lineHeight: metrics.bodyLine)
        case .code(let language, let source):
            CodeBlockView(messageID: message.id, block: index, language: language, source: source)
                .padding(.bottom, index == sections.count - 1 ? 2 : 0)
        }
    }

    private func topGap(before index: Int) -> CGFloat {
        if index == 0 { return isImage ? 8 : 0 }
        return 6
    }

    private var isImage: Bool {
        if case .image = message.attachment { return true }
        return false
    }

    private var bottomPadding: CGFloat {
        if isImage && message.blocks.isEmpty {
            return row.boosts.isEmpty ? Metrics.imageInset : Metrics.boostBottomAfterImage
        }
        return Metrics.bubblePaddingY
    }

    private var firstSelectablePlain: String {
        if message.isEmojiOnly { return message.plainText }
        if let first = sections.first {
            switch first {
            case .paragraph(let blocks):
                return RichText.paragraph(blocks, users: users, metrics: metrics, displayScale: displayScale).plain
            case .code(_, let source):
                return source
            }
        }
        if case .file(let name, _) = message.attachment { return name }
        return ""
    }
}
