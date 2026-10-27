import UIKit

protocol ChatLayoutSource: AnyObject {
    var rowCount: Int { get }
    /// Height of the welcome card above the first row, 0 when the oldest message is not loaded.
    var welcomeHeight: CGFloat { get }
    func rowHeight(at index: Int) -> CGFloat
    /// Space between the previous row's bottom and this row's top (negative for threaded rows).
    func spacingBefore(row index: Int) -> CGFloat
    /// Called from `prepare` when the collection view's width differs from the one rows were measured for.
    func layoutWidthChanged(_ width: CGFloat)
}

/// One section of rows stacked top to bottom from saved heights. Only rows from the first dirty index
/// down are recomputed; an append only lays out the new rows.
final class ChatLayout: UICollectionViewLayout {
    static let welcomeKind = "welcome"
    weak var source: ChatLayoutSource?

    private(set) var tops: [CGFloat] = []
    private(set) var heights: [CGFloat] = []
    private var attributes: [UICollectionViewLayoutAttributes] = []
    private var welcomeAttributes: UICollectionViewLayoutAttributes?
    private var dirtyFrom: Int? = 0
    private var contentHeight: CGFloat = 0
    private(set) var preparedWidth: CGFloat = 0

    /// When set, decides the content offset UIKit should use after an update (keeps the reader's place).
    var targetOffsetProvider: (() -> CGPoint?)?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    static let topPadding: CGFloat = Geo.rowGap

    func invalidateRows(from index: Int) {
        dirtyFrom = min(dirtyFrom ?? index, max(0, index))
    }

    func invalidateAllRows() { dirtyFrom = 0 }

    override func prepare() {
        super.prepare()
        rebuildIfNeeded()
    }

    /// Brings the cached frames up to date; safe to call outside UIKit's own layout pass.
    func rebuildIfNeeded() {
        guard let cv = collectionView, let src = source else { return }
        let width = cv.bounds.width
        if width != preparedWidth {
            preparedWidth = width
            src.layoutWidthChanged(width)
            dirtyFrom = 0
        }
        let n = src.rowCount
        if n != tops.count { dirtyFrom = min(dirtyFrom ?? tops.count, min(n, tops.count)) }
        guard let from = dirtyFrom else { return }
        dirtyFrom = nil

        if tops.count > n {
            tops.removeLast(tops.count - n)
            heights.removeLast(heights.count - n)
            attributes.removeLast(attributes.count - n)
        }
        let welcome = src.welcomeHeight
        if welcome > 0 {
            let a = welcomeAttributes ?? UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: Self.welcomeKind, with: IndexPath(item: 0, section: 0))
            a.frame = CGRect(x: 0, y: 0, width: width, height: welcome)
            welcomeAttributes = a
        } else {
            welcomeAttributes = nil
        }
        var y: CGFloat = from == 0 ? (welcome > 0 ? welcome : Self.topPadding)
            : tops[from - 1] + heights[from - 1] + src.spacingBefore(row: from)
        for i in from..<n {
            if i > from { y += src.spacingBefore(row: i) }
            #if PIXEL_TOPS
            // Row edges on whole device pixels (3x), accumulated from the unrounded position.
            let rawH = src.rowHeight(at: i)
            let top = (y * 3).rounded() / 3
            let h = ((y + rawH) * 3).rounded() / 3 - top
            let frame = CGRect(x: 0, y: top, width: width, height: h)
            #else
            let h = src.rowHeight(at: i)
            let frame = CGRect(x: 0, y: y, width: width, height: h)
            #endif
            if i < tops.count {
                tops[i] = frame.minY
                heights[i] = h
                let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
                a.frame = frame
                a.zIndex = i
                attributes[i] = a
            } else {
                tops.append(frame.minY)
                heights.append(h)
                let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
                a.frame = frame
                a.zIndex = i
                attributes.append(a)
            }
            #if PIXEL_TOPS
            y += rawH
            #else
            y += h
            #endif
        }
        contentHeight = (n > 0 ? tops[n - 1] + heights[n - 1] : y) + Geo.contentBottomPad
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    /// First row whose bottom is below `y` (binary search; bottoms increase with the index).
    func firstRow(bottomBelow y: CGFloat) -> Int {
        var lo = 0, hi = tops.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if tops[mid] + heights[mid] > y { hi = mid } else { lo = mid + 1 }
        }
        return lo
    }

    func frame(ofRow i: Int) -> CGRect? {
        i >= 0 && i < tops.count ? CGRect(x: 0, y: tops[i], width: preparedWidth, height: heights[i]) : nil
    }

    var totalHeight: CGFloat { contentHeight }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var out: [UICollectionViewLayoutAttributes] = []
        if let w = welcomeAttributes, w.frame.intersects(rect) { out.append(w) }
        var i = firstRow(bottomBelow: rect.minY)
        while i < attributes.count && tops[i] < rect.maxY {
            out.append(attributes[i])
            i += 1
        }
        return out
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        indexPath.item < attributes.count ? attributes[indexPath.item] : nil
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        elementKind == Self.welcomeKind ? welcomeAttributes : nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != preparedWidth
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        targetOffsetProvider?() ?? proposedContentOffset
    }

    // Rows appear and disappear in place: no fades or slides.
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        layoutAttributesForItem(at: itemIndexPath)
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        nil
    }
}
