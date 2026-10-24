import SwiftUI
import CampfireKit

struct BubbleContent: View {
    let item: MessageItem

    var body: some View {
        VStack(alignment: item.presentation.isMine ? .trailing : .leading, spacing: 0) {
            MessageMetadata(item: item).padding(.bottom, 2.76)
            if case .file(let name, let bytes) = item.message.attachment {
                FileAttachmentView(name: name, bytes: bytes).frame(minHeight: 34)
            } else {
                MessageBodyView(item: item)
            }
            if !item.message.boosts.isEmpty {
                BoostStrip(boosts: item.message.boosts, users: item.users)
            }
        }
        .padding(.horizontal, CampfireStyle.paddingX)
        .padding(.vertical, CampfireStyle.paddingY)
        .frame(minWidth: item.message.isEmojiOnly ? 168.53 : nil)
    }
}
