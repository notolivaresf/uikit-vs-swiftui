import UIKit

struct LayoutRow {
    let id: Int
    let height: CGFloat
    let threaded: Bool
}

/// Owns exact, pixel-aligned geometry. Bounds scrolling never invalidates the cache.
final class ChatLayout: UICollectionViewLayout {
    private(set) var rows: [LayoutRow] = []
    private(set) var attributes: [UICollectionViewLayoutAttributes] = []
    private var indices: [Int: Int] = [:]
    private var total: CGFloat = 0
    var layoutWidth: CGFloat = 393
    var forcedOffset: CGPoint?
    private let pixels: CGFloat = 3
    override var collectionViewContentSize: CGSize { CGSize(width: layoutWidth, height: total + 12) }
    private func aligned(_ y: CGFloat) -> CGFloat { (y * pixels).rounded() / pixels }
    private func makeAttribute(index: Int, y: CGFloat) -> UICollectionViewLayoutAttributes {
        let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
        let top = aligned(y)
        a.frame = CGRect(x: 0, y: top, width: layoutWidth, height: aligned(y + rows[index].height) - top)
        return a
    }
    func replace(_ newRows: [LayoutRow], width: CGFloat) {
        rows = newRows; layoutWidth = width; attributes.removeAll(keepingCapacity: true); indices.removeAll(keepingCapacity: true)
        var y: CGFloat = 0
        for i in rows.indices {
            if i > 0 { y += rows[i].threaded ? -1.2 : 21.28 }
            let a = makeAttribute(index: i, y: y)
            attributes.append(a); indices[rows[i].id] = i; y = a.frame.maxY
        }
        total = y
        invalidateLayout()
    }
    func append(_ newRows: [LayoutRow]) {
        let start = rows.count
        rows.append(contentsOf: newRows)
        var y = total
        for i in start..<rows.count {
            if i > 0 { y += rows[i].threaded ? -1.2 : 21.28 }
            let a = makeAttribute(index: i, y: y)
            attributes.append(a); indices[rows[i].id] = i; y = a.frame.maxY
        }
        total = y; invalidateLayout()
    }
    func prepend(_ newRows: [LayoutRow]) {
        guard !newRows.isEmpty else { return }
        let count = newRows.count
        rows.insert(contentsOf: newRows, at: 0)
        var leading: [UICollectionViewLayoutAttributes] = []
        var y: CGFloat = 0
        for i in 0..<count {
            if i > 0 { y += rows[i].threaded ? -1.2 : 21.28 }
            let a = makeAttribute(index: i, y: y)
            leading.append(a); y = a.frame.maxY
        }
        let gap: CGFloat = rows.count > count ? (rows[count].threaded ? -1.2 : 21.28) : 0
        let shift = aligned(y + gap) - (attributes.first?.frame.minY ?? 0)
        for a in attributes {
            a.indexPath = IndexPath(item: a.indexPath.item + count, section: 0)
            a.frame.origin.y += shift
        }
        attributes.insert(contentsOf: leading, at: 0)
        for i in rows.indices { indices[rows[i].id] = i }
        total = attributes.last?.frame.maxY ?? 0
        invalidateLayout()
    }
    func update(_ row: LayoutRow) {
        guard let i = indices[row.id] else { return }
        rows[i] = row
        let oldBottom = attributes[i].frame.maxY
        attributes[i].frame.size.height = aligned(attributes[i].frame.minY + row.height) - attributes[i].frame.minY
        let delta = attributes[i].frame.maxY - oldBottom
        if delta != 0 {
            for j in (i+1)..<attributes.count { attributes[j].frame.origin.y += delta }
            total += delta
        }
        invalidateLayout()
    }
    func frame(id: Int) -> CGRect? { indices[id].map { attributes[$0].frame } }
    func topIndex(at y: CGFloat) -> Int? {
        var lo = 0; var hi = attributes.count
        while lo < hi {
            let mid = (lo + hi)/2
            // Threaded rows overlap only their blank bottom margin. That margin is not
            // visible message content and must not make a precise jump report its predecessor.
            let end = mid+1 < attributes.count ? min(attributes[mid].frame.maxY, attributes[mid+1].frame.minY) : attributes[mid].frame.maxY
            if end <= y { lo = mid + 1 } else { hi = mid }
        }
        return lo < attributes.count ? lo : nil
    }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let start = topIndex(at: rect.minY) else { return [] }
        var result: [UICollectionViewLayoutAttributes] = []
        var i = start
        while i < attributes.count && attributes[i].frame.minY < rect.maxY { result.append(attributes[i]); i += 1 }
        return result
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard attributes.indices.contains(indexPath.item) else { return nil }
        return attributes[indexPath.item]
    }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { false }
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint { Probe.targetCalls += 1; return forcedOffset ?? proposedContentOffset }
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint { forcedOffset ?? proposedContentOffset }
}
