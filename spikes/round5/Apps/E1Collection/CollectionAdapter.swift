import UIKit
import SpikeKit

/// E1 spike B: a collection view with a custom layout (the shape the fast Round 3 builds used): one column, row tops
/// kept in a running list of offsets that grows at the end, saved heights from the shared measurer.
final class ChatLayout: UICollectionViewLayout {
    var heightAt: ((Int) -> CGFloat)?
    private var offsets: [CGFloat] = [0]
    private var width: CGFloat = 0
    private var rebuild = true

    func markDirty() { rebuild = true; invalidateLayout() }

    override func prepare() {
        guard let cv = collectionView, let heightAt else { return }
        let n = cv.numberOfItems(inSection: 0)
        if cv.bounds.width != width { width = cv.bounds.width; rebuild = true }
        if rebuild || offsets.count > n + 1 { offsets = [0]; rebuild = false }
        var y = offsets[offsets.count - 1]
        for i in (offsets.count - 1)..<max(n, offsets.count - 1) {
            y += heightAt(i)
            offsets.append(y)
        }
    }

    override var collectionViewContentSize: CGSize { CGSize(width: width, height: offsets[offsets.count - 1]) }
    func top(of i: Int) -> CGFloat { offsets[i] }
    func height(of i: Int) -> CGFloat { offsets[i + 1] - offsets[i] }
    var count: Int { offsets.count - 1 }

    /// First row whose bottom is below `y`.
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
}

final class CollectionAdapter: NSObject, ListAdapter, UICollectionViewDataSource, UICollectionViewDelegate {
    private let layout = ChatLayout()
    private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    weak var data: RoomDataProviding? {
        didSet { layout.heightAt = { [weak self] in self?.data?.savedHeight(at: $0) ?? 0 } }
    }
    var scrollView: UIScrollView { collection }

    override init() {
        super.init()
        collection.dataSource = self
        collection.delegate = self
        collection.allowsSelection = false
        collection.register(CollectionRowCell.self, forCellWithReuseIdentifier: "row")
    }

    func reloadAll() { layout.markDirty(); collection.reloadData() }
    func heightsChanged() { layout.markDirty(); collection.reloadData() }

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

    func rowFrame(_ index: Int) -> CGRect {
        collection.layoutIfNeeded()
        return CGRect(x: 0, y: layout.top(of: index), width: collection.bounds.width, height: layout.height(of: index))
    }

    func visibleTopRow() -> Int? {
        collection.layoutIfNeeded()
        guard layout.count > 0 else { return nil }
        return min(layout.row(at: max(0, collection.contentOffset.y)), layout.count - 1)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { data?.itemCount ?? 0 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "row", for: indexPath) as! CollectionRowCell
        data?.configure(cell.row, at: indexPath.item)
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { data?.listDidScroll() }
}
