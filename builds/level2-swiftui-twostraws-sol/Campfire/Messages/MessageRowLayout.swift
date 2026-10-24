import SwiftUI

struct MessageRowLayout: Layout {
    let mine: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 393
        let bubbleWidth = max(80, width - (mine ? 104.7 : 54.81))
        let bubble = subviews[0].sizeThatFits(ProposedViewSize(width: bubbleWidth, height: nil))
        return CGSize(width: width, height: max(bubble.height, CampfireStyle.avatarSize))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let bubbleWidth = max(80, bounds.width - (mine ? 104.7 : 54.81))
        let bubble = subviews[0].sizeThatFits(ProposedViewSize(width: bubbleWidth, height: nil))
        let x = mine ? bounds.maxX - 40.8 - bubble.width : bounds.minX + 40.8
        subviews[0].place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: bubbleWidth, height: nil))
        subviews[1].place(at: CGPoint(x: mine ? bounds.maxX - 49.28 : bounds.minX + 14.01, y: bounds.minY),
                          proposal: ProposedViewSize(width: 35.27, height: 35.27))
    }
}
