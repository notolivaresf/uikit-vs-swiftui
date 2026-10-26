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
    /// Unrounded bottom of each row (the next row's position is accumulated from it).
    private var ends: [CGFloat] = []
    private var cache: [UICollectionViewLayoutAttributes?] = []
    private var preparedX: CGFloat = -1
    private var preparedWidth: CGFloat = -1
    /// Rows from this index on may have a new height; the ones before are reused as they are.
    private var dirtyFrom = 0

    /// Space above the first row when it is a message.
    static let topPadding: CGFloat = Metrics.rowGap

    /// The room calls this when rows' heights change (their layouts were rebuilt); rows added or removed
    /// are found by comparing the items. Everything before the first change keeps its frame, so a new
    /// message or a boost costs the same however many rows are loaded.
    func invalidateRows(from index: Int) {
        dirtyFrom = min(dirtyFrom, index)
        invalidateLayout()
    }

    override func prepare() {
        super.prepare()
        computeFrames()
    }

    /// The frames for the provider's current items. `prepare` does this; the room also calls it right after
    /// changing its rows, to place the content offset before the collection view lays out the change.
    func computeFrames() {
        guard let collectionView, let provider else { return }
        let newItems = provider.layoutItems
        let insets = collectionView.safeAreaInsets
        let x = insets.left
        let width = collectionView.bounds.width - insets.left - insets.right
        var k = min(dirtyFrom, newItems.count, items.count)
        if x != preparedX || width != preparedWidth { k = 0 }
        var i = 0
        while i < k && items[i] == newItems[i] { i += 1 }
        k = i
        dirtyFrom = .max
        preparedX = x
        preparedWidth = width
        items = newItems
        frames.removeSubrange(k...)
        ends.removeSubrange(k...)
        cache.removeSubrange(k...)
        var y: CGFloat = k > 0 ? ends[k - 1] : 0
        for i in k..<items.count {
            let id = items[i]
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
            ends.append(y)
            cache.append(nil)
        }
        contentHeight = y
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    private func attributes(at index: Int) -> UICollectionViewLayoutAttributes {
        if let cached = cache[index] { return cached }
        let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
        a.frame = frames[index]
        a.zIndex = index
        cache[index] = a
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

    /// Set while the room changes: where the content offset must end up once the update is laid out.
    var targetOffset: (() -> CGPoint?)?

    /// The room sets its scroll position itself (pinned, or the top row kept in place). Without a target
    /// for the change at hand, stay where it is: UIKit's proposal after rows are removed above is a shift
    /// it would animate in later, on top of the room's own repositioning.
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        targetOffset?() ?? collectionView?.contentOffset ?? proposedContentOffset
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != collectionView?.bounds.width
    }

    /// Message ids are contiguous, so a row's index follows from the first one (with a search as a fallback).
    func frame(of id: Int) -> CGRect? {
        guard let first = items.first(where: { $0 != 0 }), let base = items.firstIndex(of: first) else { return nil }
        var index = base + id - first
        if !items.indices.contains(index) || items[index] != id {
            guard let found = items.firstIndex(of: id) else { return nil }
            index = found
        }
        return frames.indices.contains(index) ? frames[index] : nil
    }
}
