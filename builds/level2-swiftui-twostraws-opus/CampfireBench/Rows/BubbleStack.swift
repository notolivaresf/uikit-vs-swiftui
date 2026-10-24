import SwiftUI

/// A vertical stack as wide as its widest child (up to the proposed width), where each child picks its own
/// horizontal alignment. Lets "mine" bubbles right-align the header while the text keeps its own width.
struct BubbleStack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let child = ProposedViewSize(width: proposal.width, height: nil)
        var size = CGSize.zero
        for subview in subviews {
            let s = subview.sizeThatFits(child)
            size.width = max(size.width, s.width)
            size.height += s.height
        }
        if let width = proposal.width { size.width = min(size.width, width) }
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let child = ProposedViewSize(width: bounds.width, height: nil)
        var y = bounds.minY
        for subview in subviews {
            let s = subview.sizeThatFits(child)
            let x: CGFloat = switch subview[BubbleAlignmentKey.self] {
            case .leading: bounds.minX
            case .trailing: bounds.maxX - s.width
            case .fill: bounds.minX
            }
            let width = subview[BubbleAlignmentKey.self] == .fill ? bounds.width : s.width
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: s.height))
            y += s.height
        }
    }
}

enum BubbleAlignment {
    case leading, trailing, fill
}

struct BubbleAlignmentKey: LayoutValueKey {
    static let defaultValue = BubbleAlignment.leading
}

extension View {
    func bubbleAlignment(_ alignment: BubbleAlignment) -> some View {
        layoutValue(key: BubbleAlignmentKey.self, value: alignment)
    }
}
