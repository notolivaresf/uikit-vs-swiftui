import UIKit

/// A plain vertical list whose frames are computed up front by the controller (heights are known exactly,
/// so prepends, re-layouts and anchoring are arithmetic rather than estimates).
final class RoomLayout: UICollectionViewLayout {
    static let welcomeKind = "welcome"

    private(set) var tops: [CGFloat] = []
    private(set) var heights: [CGFloat] = []
    private(set) var contentHeight: CGFloat = 0
    private(set) var showsWelcome = false
    private var width: CGFloat = 0
    private var attributes: [UICollectionViewLayoutAttributes] = []
    private var welcomeAttributes: UICollectionViewLayoutAttributes?

    func update(tops: [CGFloat], heights: [CGFloat], contentHeight: CGFloat, welcome: Bool, width: CGFloat) {
        self.tops = tops
        self.heights = heights
        self.contentHeight = contentHeight
        self.showsWelcome = welcome
        self.width = width
        attributes = tops.indices.map { i in
            let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            a.frame = CGRect(x: 0, y: tops[i], width: width, height: heights[i])
            a.zIndex = i
            return a
        }
        if welcome {
            let a = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: RoomLayout.welcomeKind,
                                                     with: IndexPath(item: 0, section: 0))
            a.frame = CGRect(x: 0, y: 0, width: width, height: WelcomeView.height)
            welcomeAttributes = a
        } else {
            welcomeAttributes = nil
        }
        invalidateLayout()
    }

    override var collectionViewContentSize: CGSize { CGSize(width: width, height: contentHeight) }

    /// Where a row stops being visible: its bottom, or the next row's top where a threaded row overlaps it.
    func visibleBottom(_ i: Int) -> CGFloat {
        let bottom = tops[i] + heights[i]
        return i + 1 < tops.count ? min(bottom, tops[i + 1]) : bottom
    }

    /// First row whose visible bottom is below `y`.
    func firstRow(below y: CGFloat) -> Int? {
        var lo = 0, hi = tops.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if visibleBottom(mid) > y { hi = mid } else { lo = mid + 1 }
        }
        return lo < tops.count ? lo : nil
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var out: [UICollectionViewLayoutAttributes] = []
        if let w = welcomeAttributes, w.frame.intersects(rect) { out.append(w) }
        guard var i = firstRow(below: rect.minY) else { return out }
        if i > 0 { i -= 1 }
        while i < attributes.count, tops[i] <= rect.maxY {
            out.append(attributes[i])
            i += 1
        }
        return out
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        indexPath.item < attributes.count ? attributes[indexPath.item] : nil
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String,
                                                       at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        elementKind == RoomLayout.welcomeKind ? welcomeAttributes : nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { false }
}
