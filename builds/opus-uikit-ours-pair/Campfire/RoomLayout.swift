import UIKit

protocol RoomLayoutProvider: AnyObject {
    /// Item ids top to bottom (0 is the welcome card, other ids are message ids).
    var layoutItems: [Int] { get }
    /// Height of a row and the space above it, for rows `width` wide.
    func rowMetrics(for id: Int, width: CGFloat) -> (height: CGFloat, gapBefore: CGFloat)
}

/// A vertical stack of rows with heights known in advance (computed by `RowLayoutBuilder`),
/// so every frame is exact and the position of any row can be restored to the point.
final class RoomLayout: UICollectionViewLayout {
    weak var provider: RoomLayoutProvider?
    private(set) var items: [Int] = []
    private(set) var frames: [CGRect] = []
    private var contentHeight: CGFloat = 0
    private var cache: [IndexPath: UICollectionViewLayoutAttributes] = [:]

    /// Space above the first row when it is a message.
    static let topPadding: CGFloat = Metrics.rowGap

    override func prepare() {
        super.prepare()
        guard let collectionView, let provider else { return }
        items = provider.layoutItems
        let insets = collectionView.safeAreaInsets
        let x = insets.left
        let width = collectionView.bounds.width - insets.left - insets.right
        frames.removeAll(keepingCapacity: true)
        cache.removeAll(keepingCapacity: true)
        var y: CGFloat = 0
        for (i, id) in items.enumerated() {
            let m = provider.rowMetrics(for: id, width: width)
            if i == 0 {
                y += id == 0 ? 0 : Self.topPadding
            } else {
                y += items[i - 1] == 0 ? WelcomeCell.gapAfter : m.gapBefore
            }
            // On the pixel grid, so content offsets land exactly on a row's top.
            let top = (y * 3).rounded() / 3
            let bottom = ((y + m.height) * 3).rounded() / 3
            frames.append(CGRect(x: x, y: top, width: width, height: bottom - top))
            y += m.height
        }
        contentHeight = y
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    private func attributes(at index: Int) -> UICollectionViewLayoutAttributes {
        let indexPath = IndexPath(item: index, section: 0)
        if let cached = cache[indexPath] { return cached }
        let a = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        a.frame = frames[index]
        a.zIndex = index
        cache[indexPath] = a
        return a
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !frames.isEmpty else { return [] }
        // First frame whose bottom reaches the rect.
        var lo = 0, hi = frames.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if frames[mid].maxY < rect.minY { lo = mid + 1 } else { hi = mid }
        }
        var result: [UICollectionViewLayoutAttributes] = []
        var i = max(0, lo - 1)
        while i < frames.count && frames[i].minY <= rect.maxY {
            if frames[i].intersects(rect) { result.append(attributes(at: i)) }
            i += 1
        }
        return result
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0, frames.indices.contains(indexPath.item) else { return nil }
        return attributes(at: indexPath.item)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != collectionView?.bounds.width
    }

    func frame(of id: Int) -> CGRect? {
        guard let index = items.firstIndex(of: id), frames.indices.contains(index) else { return nil }
        return frames[index]
    }
}
