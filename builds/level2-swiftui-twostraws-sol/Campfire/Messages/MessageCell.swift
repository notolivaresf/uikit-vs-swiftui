import SwiftUI

struct MessageCell: View, Equatable {
    let item: MessageItem

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.item === rhs.item }

    var body: some View {
        VStack(spacing: 0) {
            if item.presentation.isFirstOfDay { DaySeparator(date: item.message.createdAt) }
            MessageRowLayout(mine: item.presentation.isMine) {
                MessageBubble(item: item)
                AvatarView(user: item.author)
                    .background {
                        Circle().fill(.background).padding(-2.5)
                    }
                    .opacity(item.presentation.isThreaded ? 0 : 1)
            }
            .padding(.vertical, 1.6)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: RowFramesKey.self,
                                           value: [item.id: geometry.frame(in: .named("transcriptViewport"))])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("message-\(item.id)")
        }
        .padding(.top, item.presentation.isFirstOfDay ? 0 : (item.presentation.isThreaded ? -1.2 : 21.28))
    }
}
