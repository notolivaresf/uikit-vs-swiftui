import SwiftUI
import CampfireKit

struct MessageMetadata: View {
    @ScaledMetric(relativeTo: .caption) private var fontSize = 12.8
    let item: MessageItem

    var body: some View {
        HStack(spacing: 4) {
            if item.presentation.isMine {
                Image(systemName: "ellipsis").padding(.trailing, 8).opacity(0.5).accessibilityHidden(true)
                Text(item.message.createdAt.formatted(CampfireStyle.timeFormat)).opacity(0.5)
                if !item.presentation.isThreaded { Text(item.author.name).bold() }
            } else {
                if !item.presentation.isThreaded { Text(item.author.name).bold() }
                Text(item.message.createdAt.formatted(CampfireStyle.timeFormat)).opacity(0.5)
                Image(systemName: "ellipsis").padding(.leading, 8).opacity(0.5).accessibilityHidden(true)
            }
        }
        .font(.system(size: fontSize))
        .frame(minHeight: fontSize * 1.5, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
