import UIKit
import SpikeKit

/// E2 spike: the E1 collection view and custom layout with self-sizing rows. Every row starts at an estimate; the
/// system asks each cell for its real height (preferred attributes), the layout keeps the answer by message id and
/// moves the rows below it.
final class ChatLayout: UICollectionViewLayout {
    var count: Int { offsets.count - 1 }
    var idAt: ((Int) -> Int)?
    var estimate: CGFloat = 120
    private var known: [Int: CGFloat] = [:]
    private var offsets: [CGFloat] = [0]
    private var width: CGFloat = 0
    private var dirtyFrom: Int? = 0

    func forgetAll() { known.removeAll(keepingCapacity: true); dirtyFrom = 0; invalidateLayout() }
    func forget(id: Int) { known[id] = nil; dirtyFrom = 0; invalidateLayout() }
    func markDirty() { dirtyFrom = 0; invalidateLayout() }

    override func prepare() {
        guard let cv = collectionView, let idAt else { return }
        let n = cv.numberOfItems(inSection: 0)
        if cv.bounds.width != width { width = cv.bounds.width; known.removeAll(keepingCapacity: true); dirtyFrom = 0 }
        if let d = dirtyFrom { offsets.removeSubrange((min(d, offsets.count - 1) + 1)..<offsets.count); dirtyFrom = nil }
        if offsets.count > n + 1 { offsets.removeSubrange((n + 1)..<offsets.count) }
        var y = offsets[offsets.count - 1]
        for i in (offsets.count - 1)..<max(n, offsets.count - 1) {
            y += known[idAt(i)] ?? estimate
            offsets.append(y)
        }
    }

    override var collectionViewContentSize: CGSize { CGSize(width: width, height: offsets[offsets.count - 1]) }
    func top(of i: Int) -> CGFloat { offsets[i] }
    func height(of i: Int) -> CGFloat { offsets[i + 1] - offsets[i] }

    func row(at y: CGFloat) -> Int {
        var lo = 0, hi = count
        while lo < hi { let mid = (lo + hi) / 2; if offsets[mid + 1] <= y { lo = mid + 1 } else { hi = mid } }
        return lo
    }

    private func attributes(_ i: Int) -> UICollectionViewLayoutAttributes {
        let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
        a.frame = CGRect(x: 0, y: offsets[i], width: width, height: offsets[i + 1] - offsets[i])
        return a
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard count > 0 else { return [] }
        var out: [UICollectionViewLayoutAttributes] = []
        var i = row(at: rect.minY)
        while i < count && offsets[i] < rect.maxY { out.append(attributes(i)); i += 1 }
        return out
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        indexPath.item < count ? attributes(indexPath.item) : nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { newBounds.width != width }

    override func shouldInvalidateLayout(forPreferredLayoutAttributes preferred: UICollectionViewLayoutAttributes,
                                         withOriginalAttributes original: UICollectionViewLayoutAttributes) -> Bool {
        abs(preferred.size.height - original.size.height) > 0.5
    }

    override func invalidationContext(forPreferredLayoutAttributes preferred: UICollectionViewLayoutAttributes,
                                      withOriginalAttributes original: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutInvalidationContext {
        let ctx = super.invalidationContext(forPreferredLayoutAttributes: preferred, withOriginalAttributes: original)
        let i = preferred.indexPath.item
        guard i < count, let idAt else { return ctx }
        let delta = preferred.size.height - original.size.height
        known[idAt(i)] = preferred.size.height
        dirtyFrom = min(dirtyFrom ?? i, i)
        // A row above what the reader sees changed: move the offset by the same amount so what is on screen stays.
        if let cv = collectionView, offsets[i] < cv.contentOffset.y { ctx.contentOffsetAdjustment.y += delta }
        ctx.contentSizeAdjustment.height += delta
        return ctx
    }
}

final class CollectionAdapter: NSObject, ListAdapter, UICollectionViewDataSource, UICollectionViewDelegate {
    private let layout = ChatLayout()
    private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    weak var data: RoomDataProviding? {
        didSet { layout.idAt = { [weak self] in self?.data?.messageID(at: $0) ?? 0 } }
    }
    var scrollView: UIScrollView { collection }

    override init() {
        super.init()
        collection.dataSource = self
        collection.delegate = self
        collection.allowsSelection = false
        collection.register(SelfSizingCollectionCell.self, forCellWithReuseIdentifier: "row")
    }

    func reloadAll() { layout.markDirty(); collection.reloadData() }
    func heightsChanged() { layout.forgetAll(); collection.reloadData() }
    func heightInvalidated(id: Int) { layout.forget(id: id) }

    func rowsAppended(_ count: Int) {
        guard let n = data?.itemCount else { return }
        let paths = ((n - count)..<n).map { IndexPath(item: $0, section: 0) }
        UIView.performWithoutAnimation {
            collection.performBatchUpdates { collection.insertItems(at: paths) }
        }
    }

    func rowsPrepended(_ count: Int) {
        let paths = (0..<count).map { IndexPath(item: $0, section: 0) }
        layout.markDirty()
        UIView.performWithoutAnimation {
            collection.performBatchUpdates { collection.insertItems(at: paths) }
        }
    }

    func rowChanged(_ index: Int) {
        layout.markDirty()
        UIView.performWithoutAnimation { collection.reloadItems(at: [IndexPath(item: index, section: 0)]) }
    }

    /// True while UIKit calls scrollViewDidScroll. That call can come from inside the collection view's own layout pass
    /// (when a cell's real height moves the offset), and a layoutIfNeeded there throws "Expected dequeued view to be
    /// returned to the collection view". The layout is up to date at that point, so the reads just skip the flush.
    private var inScrollCallback = false

    func rowFrame(_ index: Int) -> CGRect {
        if !inScrollCallback { collection.layoutIfNeeded() }
        return CGRect(x: 0, y: layout.top(of: index), width: collection.bounds.width, height: layout.height(of: index))
    }

    func visibleTopRow() -> Int? {
        if !inScrollCallback { collection.layoutIfNeeded() }
        guard layout.count > 0 else { return nil }
        return min(layout.row(at: max(0, collection.contentOffset.y)), layout.count - 1)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { data?.itemCount ?? 0 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "row", for: indexPath) as! SelfSizingCollectionCell
        data?.configure(cell.row, at: indexPath.item)
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        inScrollCallback = true
        data?.listDidScroll()
        inScrollCallback = false
    }
}
