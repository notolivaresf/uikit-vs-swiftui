import UIKit
import CampfireKit

/// The height measurer: works a row's height out from its message, the width and the text size, and keeps it by
/// message id ("saved heights"). A new width or text size empties the saved heights.
public final class HeightStore {
    private var heights: [MessageID: CGFloat] = [:]
    private var style: RowStyle?
    public private(set) var measureCount = 0

    public init() {}

    public func height(for item: RowItem, users: [UserID: User], style: RowStyle) -> CGFloat {
        if self.style != style { heights.removeAll(keepingCapacity: true); self.style = style }
        if let h = heights[item.message.id] { return h }
        let h = Self.measure(item, users: users, style: style)
        measureCount += 1
        heights[item.message.id] = h
        return h
    }

    public func invalidate(_ id: MessageID) { heights[id] = nil }
    public func invalidateAll() { heights.removeAll(keepingCapacity: true); style = nil }

    /// The measuring itself, with nothing saved: what a self-sizing row does every time the system asks.
    public static func measure(_ item: RowItem, users: [UserID: User], style: RowStyle) -> CGFloat {
        RowGeometry.make(item, users: users, style: style).height
    }
}
