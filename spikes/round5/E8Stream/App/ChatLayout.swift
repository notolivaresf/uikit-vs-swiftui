import UIKit

/// One section, rows stacked top to bottom from saved heights. Row tops live in a sorted array, so
/// lookups by rect are binary searches. The controller edits the rows only inside the collection view's
/// own update (batch update closure or right before `reloadData`).
final class ChatLayout: UICollectionViewLayout {
    static let welcomeKind = "welcome"

    private(set) var heights: [CGFloat] = []
    private(set) var gaps: [CGFloat] = []
    private(set) var tops: [CGFloat] = []
    /// Space above the first row: the welcome card when the room's first message is loaded.
    private(set) var topPadding: CGFloat = 12
    private(set) var showsWelcome = false

    private var cache: [UICollectionViewLayoutAttributes?] = []
    private var welcomeAttrs: UICollectionViewLayoutAttributes?
    private var width: CGFloat = 0

    /// When set, the offset UIKit must use after the next update (keeps the reader's place or the pin).
    var pendingOffset: CGPoint?

    var count: Int { heights.count }
    var contentHeight: CGFloat {
        guard let last = tops.last, let h = heights.last else { return topPadding }
        return last + h
    }

    func top(_ i: Int) -> CGFloat { tops[i] }
    func height(_ i: Int) -> CGFloat { heights[i] }

    // MARK: Edits

    func setRows(heights h: [CGFloat], gaps g: [CGFloat], welcome: Bool, welcomeHeight: CGFloat) {
        heights = h
        gaps = g
        setWelcome(welcome, height: welcomeHeight)
        tops = Array(repeating: 0, count: h.count)
        cache = Array(repeating: nil, count: h.count)
        recomputeTops(from: 0)
        invalidateLayout()
    }

    func setWelcome(_ on: Bool, height: CGFloat) {
        showsWelcome = on
        topPadding = on ? height : 12
        welcomeAttrs = nil
    }

    func append(heights h: [CGFloat], gaps g: [CGFloat]) {
        let start = heights.count
        heights += h
        gaps += g
        tops += Array(repeating: 0, count: h.count)
        cache += Array(repeating: nil, count: h.count)
        recomputeTops(from: start)
        invalidateLayout()
    }

    func prepend(heights h: [CGFloat], gaps g: [CGFloat], welcome: Bool, welcomeHeight: CGFloat) {
        heights = h + heights
        gaps = g + gaps
        setWelcome(welcome, height: welcomeHeight)
        tops = Array(repeating: 0, count: heights.count)
        cache = Array(repeating: nil, count: heights.count)
        recomputeTops(from: 0)
        invalidateLayout()
    }

    func removeFirst(_ n: Int, welcome: Bool, welcomeHeight: CGFloat) {
        heights.removeFirst(n); gaps.removeFirst(n); tops.removeFirst(n); cache.removeFirst(n)
        setWelcome(welcome, height: welcomeHeight)
        for i in cache.indices { cache[i] = nil }
        recomputeTops(from: 0)
        invalidateLayout()
    }

    func removeLast(_ n: Int) {
        heights.removeLast(n); gaps.removeLast(n); tops.removeLast(n); cache.removeLast(n)
        invalidateLayout()
    }

    /// One row changed height: shift only the rows below it.
    func update(_ i: Int, height h: CGFloat, gap g: CGFloat) {
        guard heights[i] != h || gaps[i] != g else { return }
        heights[i] = h
        gaps[i] = g
        recomputeTops(from: i)
        invalidateLayout()
    }

    private func recomputeTops(from start: Int) {
        guard start < heights.count else { return }
        var y = start == 0 ? topPadding : tops[start - 1] + heights[start - 1] + gaps[start]
        for i in start..<heights.count {
            if i > start { y += gaps[i] }
            if tops[i] != y || cache[i]?.frame.height != heights[i] { cache[i] = nil }
            tops[i] = y
            y += heights[i]
        }
    }

    /// First row whose bottom is below `y` (that row is at least partly visible from `y` down).
    func firstIndex(bottomBelow y: CGFloat) -> Int? {
        var lo = 0, hi = tops.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if tops[mid] + heights[mid] <= y { lo = mid + 1 } else { hi = mid }
        }
        return lo < tops.count ? lo : nil
    }

    // MARK: UICollectionViewLayout

    override func prepare() {
        super.prepare()
        let w = collectionView?.bounds.width ?? 0
        if w != width {
            width = w
            for i in cache.indices { cache[i] = nil }
            welcomeAttrs = nil
        }
    }

    override var collectionViewContentSize: CGSize { CGSize(width: width, height: contentHeight) }

    private func attrs(_ i: Int) -> UICollectionViewLayoutAttributes {
        if let a = cache[i] { return a }
        let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
        a.frame = CGRect(x: 0, y: tops[i], width: width, height: heights[i])
        cache[i] = a
        return a
    }

    private func welcome() -> UICollectionViewLayoutAttributes {
        if let a = welcomeAttrs { return a }
        let a = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: ChatLayout.welcomeKind,
                                                 with: IndexPath(item: 0, section: 0))
        a.frame = CGRect(x: 0, y: 0, width: width, height: topPadding)
        welcomeAttrs = a
        return a
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var out: [UICollectionViewLayoutAttributes] = []
        if showsWelcome && rect.minY < topPadding { out.append(welcome()) }
        guard var i = firstIndex(bottomBelow: rect.minY) else { return out }
        while i < tops.count && tops[i] < rect.maxY {
            out.append(attrs(i))
            i += 1
        }
        return out
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        indexPath.item < heights.count ? attrs(indexPath.item) : nil
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        elementKind == ChatLayout.welcomeKind && showsWelcome ? welcome() : nil
    }

    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        layoutAttributesForItem(at: itemIndexPath)
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != width
    }

    override func targetContentOffset(forProposedContentOffset proposed: CGPoint) -> CGPoint {
        pendingOffset ?? proposed
    }

    override func targetContentOffset(forProposedContentOffset proposed: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        proposed
    }
}
