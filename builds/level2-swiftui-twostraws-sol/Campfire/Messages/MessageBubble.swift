import SwiftUI
import CampfireKit

struct MessageBubble: View {
    @Environment(\.colorScheme) private var scheme
    let item: MessageItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .image(let width, let height, let color) = item.message.attachment {
                MessageMetadata(item: item)
                    .padding(.horizontal, 15.12)
                    .padding(.top, 10.56)
                    .padding(.bottom, 13.97)
                if !item.message.blocks.isEmpty {
                    MessageBodyView(item: item)
                        .padding(.horizontal, 15.12).padding(.bottom, 10.56)
                }
                Rectangle()
                    .fill(CampfireStyle.color(color))
                    .aspectRatio(Double(width) / Double(height), contentMode: .fit)
                    .clipShape(.rect(bottomLeadingRadius: item.message.boosts.isEmpty ? 10.56 : 0,
                                     bottomTrailingRadius: item.message.boosts.isEmpty ? 10.56 : 0))
                    .accessibilityLabel("Image attachment, \(width) by \(height)")
                if !item.message.boosts.isEmpty {
                    BoostStrip(boosts: item.message.boosts, users: item.users)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 7.36)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    BubbleContent(item: item).fixedSize(horizontal: true, vertical: false)
                    BubbleContent(item: item).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: imageWidth, alignment: .leading)
        .background(item.message.isEmojiOnly ? .clear :
                        (item.presentation.mentionsMe ? CampfireStyle.mention(scheme) : CampfireStyle.bubble(scheme)),
                    in: .rect(cornerRadius: CampfireStyle.bubbleRadius))
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(item.copyText) }
            Button("Reply", systemImage: "arrowshape.turn.up.left") {}
        }
    }

    private var imageWidth: CGFloat? {
        if case .image = item.message.attachment { 300 } else { nil }
    }
}
