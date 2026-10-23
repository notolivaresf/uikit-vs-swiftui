import SwiftUI
import CampfireKit

/// One message: optional day separator, avatar, bubble with meta line, body and boosts.
struct MessageRow: View, Equatable {
    let row: RowModel
    let metrics: Metrics
    let theme: Theme
    let isFirst: Bool
    let store: ChatStore

    nonisolated static func == (a: MessageRow, b: MessageRow) -> Bool {
        a.row == b.row && a.metrics == b.metrics && a.theme == b.theme && a.isFirst == b.isFirst
    }

    private var m: Metrics { metrics }
    private var p: MessagePresentation { row.presentation }
    private var message: Message { row.message }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if p.isFirstOfDay {
                DaySeparator(date: message.createdAt, metrics: m, theme: theme)
            }
            ZStack(alignment: p.isMine ? .topTrailing : .topLeading) {
                FitContentLayout(maxWidth: .infinity) {
                    Bubble(row: row, metrics: m, theme: theme, store: store)
                }
                .padding(p.isMine ? .trailing : .leading, m.screenPaddingX + m.bubbleInsetFromAvatar)
                .padding(p.isMine ? .leading : .trailing, p.isMine ? m.mineLeftLimit : m.screenPaddingX)
                .frame(maxWidth: .infinity, alignment: p.isMine ? .trailing : .leading)
                .padding(.top, m.bubbleTop)
                .padding(.bottom, m.bubbleBottom)
                if !p.isThreaded {
                    AvatarView(userID: message.creatorID, name: store.user(message.creatorID)?.name ?? "?",
                               size: m.avatar, ring: m.avatarRing, theme: theme, fontScale: 0.45)
                        .padding(p.isMine ? .trailing : .leading, m.screenPaddingX - m.avatarRing)
                        .padding(.top, m.bubbleTop - m.avatarRing)
                }
            }
        }
    }

    /// Space above a row: the grid gap, or the threaded row's negative margin (it tucks under the row above).
    static func gap(for row: RowModel, isFirst: Bool, metrics m: Metrics) -> CGFloat {
        isFirst ? 0 : (row.presentation.isThreaded ? m.rowGap + m.threadedMarginTop : m.rowGap)
    }
}

/// Round avatar: palette colour with the white bold initial, optionally ringed in the page colour so it
/// cuts into the bubble behind it as Campfire's does.
struct AvatarView: View {
    let userID: UserID
    let name: String
    let size: CGFloat
    var ring: CGFloat = 0
    let theme: Theme
    var fontScale: CGFloat = 0.45

    var body: some View {
        Text(Formatting.initial(of: name))
            .font(.system(size: size * fontScale, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(AvatarPalette.color(for: userID)))
            .padding(ring)
            .background(ring > 0 ? Circle().fill(theme.background) : nil)
            .accessibilityHidden(true)
    }
}

struct DaySeparator: View {
    let date: Date
    let metrics: Metrics
    let theme: Theme

    var body: some View {
        let m = metrics
        let fm = FontMetrics.system(m.separatorSize)
        let pillHeight = m.separatorLine + 2 * m.separatorPadY
        ZStack {
            Rectangle()
                .fill(theme.border)
                .frame(height: m.separatorLineThickness)
                .padding(.horizontal, m.screenPaddingX)
            Text(Formatting.dayString(date))
                .font(.system(size: m.separatorSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .frame(height: fm.lineHeight)
                .padding(.vertical, (pillHeight - fm.lineHeight) / 2)
                .padding(.horizontal, m.separatorPadX)
                .background(Capsule().fill(theme.border))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68.81 * m.s)
        .accessibilityElement(children: .combine)
    }
}
