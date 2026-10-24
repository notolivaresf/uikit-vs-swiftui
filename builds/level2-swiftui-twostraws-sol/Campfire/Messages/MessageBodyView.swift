import SwiftUI
import CampfireKit

struct MessageBodyView: View {
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize = 38.4
    let item: MessageItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.prose.isEmpty {
                SelectableMessageText(text: item.proseText, plainText: item.prose)
                    .font(.system(size: item.message.isEmojiOnly ? emojiSize : bodySize))
                    .lineSpacing(item.message.isEmojiOnly ? 7.9 : bodySize * 0.20625)
                    .padding(.vertical, item.message.isEmojiOnly ? 4 : bodySize * (item.message.mentionedUserIDs.isEmpty ? 0.103125 : 0.028125))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(item.message.blocks.enumerated()), id: \.offset) { _, block in
                if case .code(_, let source) = block { CodeBlockView(source: source) }
            }
        }
    }
}
