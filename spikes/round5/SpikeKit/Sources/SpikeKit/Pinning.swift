import UIKit

/// The bottom pinning both views use: pinned means the last row is within 100 points of the bottom.
public extension UIScrollView {
    var distanceFromBottom: CGFloat {
        contentSize.height - (contentOffset.y + bounds.height - contentInset.bottom)
    }
    var isPinnedToBottom: Bool { distanceFromBottom <= 100 }
    var maxOffsetY: CGFloat { max(-contentInset.top, contentSize.height - bounds.height + contentInset.bottom) }

    func scrollToBottomNow() {
        let y = maxOffsetY
        if contentOffset.y != y { setContentOffset(CGPoint(x: 0, y: y), animated: false) }
    }
}
