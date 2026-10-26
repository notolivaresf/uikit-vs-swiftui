import UIKit
import CampfireKit

/// What the list view asks of the room.
public protocol RoomDataProviding: AnyObject {
    var itemCount: Int { get }
    var style: RowStyle { get }
    /// The saved height of a row (measured once per message id, width and text size).
    func savedHeight(at index: Int) -> CGFloat
    /// The height measured now, nothing saved (what a self-sizing row costs each time).
    func measuredHeight(at index: Int) -> CGFloat
    func configure(_ row: RowView, at index: Int)
    /// The message id of a row.
    func messageID(at index: Int) -> Int
    func listDidScroll()
}

/// The list view under test. A spike app supplies one; everything else about the room is shared.
public protocol ListAdapter: AnyObject {
    var scrollView: UIScrollView { get }
    var data: RoomDataProviding? { get set }
    /// The data was replaced (reset, jump).
    func reloadAll()
    /// Every row's height changed (text size, width); the row views need new fonts.
    func heightsChanged()
    func rowsAppended(_ count: Int)
    /// `count` rows were added above row 0.
    func rowsPrepended(_ count: Int)
    func rowChanged(_ index: Int)
    /// A row's frame in the scroll view's content coordinates.
    func rowFrame(_ index: Int) -> CGRect
    func visibleTopRow() -> Int?
    /// The row with this message id changed shape; anything remembered about its height is stale.
    func heightInvalidated(id: Int)
}

public extension ListAdapter {
    func heightInvalidated(id: Int) {}
}

/// A table cell and a collection cell host the same row view.
public final class TableRowCell: UITableViewCell {
    public let row = RowView()
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none; backgroundColor = .clear
        contentView.addSubview(row)
    }
    public required init?(coder: NSCoder) { fatalError() }
    public override func layoutSubviews() { super.layoutSubviews(); row.frame = contentView.bounds }
}

public final class CollectionRowCell: UICollectionViewCell {
    public let row = RowView()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.addSubview(row)
    }
    public required init?(coder: NSCoder) { fatalError() }
    public override func layoutSubviews() { super.layoutSubviews(); row.frame = contentView.bounds }
}

/// Cells for the self-sizing spikes: the system asks the cell for its height, and the cell measures the row each time.
public final class SelfSizingTableCell: UITableViewCell {
    public let row = RowView()
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none; backgroundColor = .clear
        contentView.addSubview(row)
    }
    public required init?(coder: NSCoder) { fatalError() }
    public override func layoutSubviews() { super.layoutSubviews(); row.frame = contentView.bounds }
    public override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority h: UILayoutPriority,
                                                 verticalFittingPriority v: UILayoutPriority) -> CGSize {
        CGSize(width: targetSize.width, height: row.fittingHeight(width: targetSize.width))
    }
}

public final class SelfSizingCollectionCell: UICollectionViewCell {
    public let row = RowView()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.addSubview(row)
    }
    public required init?(coder: NSCoder) { fatalError() }
    public override func layoutSubviews() { super.layoutSubviews(); row.frame = contentView.bounds }
    public override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let a = super.preferredLayoutAttributesFitting(layoutAttributes)
        a.frame.size.height = row.fittingHeight(width: layoutAttributes.size.width)
        return a
    }
}
