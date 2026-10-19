# iOS 27.1: arrangements, hinges, reserved regions and vertical bars

iOS 27.1 adds APIs for devices whose shape changes: a hinge that folds, a display split by that hinge, hardware that covers part of the screen, and bars that can sit on a side edge. Everything here needs `if #available(iOS 27.1, *)`.

## `UIArrangementViewController`

A container that lays out a primary and a secondary view controller and adapts the arrangement to size class, orientation and reserved regions (such as the hinge).

```swift
@available(iOS 27.1, *)
func makeRoot() -> UIViewController {
    let root = UIArrangementViewController()
    root.setViewController(LibraryViewController(), for: .primary)
    root.setViewController(PlayerViewController(), for: .secondary)
    root.updateArrangement(UISplitArrangement().axes([.horizontal, .vertical]))
    return root
}
```

- `setViewController(_:for:animated:)` with a `ViewPlacement` (`.primary`, `.secondary`). Pass `nil` to clear a placement.
- `updateArrangement(_:animated:)` takes any `UIArrangementViewController.Arrangement`.
- `viewController(for:)`, `placement(for:)` and `state(for:)` look things up. `state(for:)` returns a `ViewState` with `isHidden`, `splitAxis` and `zIndex`.
- From a descendant, `arrangementViewController` finds the nearest ancestor arrangement.

### Split and overlay

- `UISplitArrangement` places the two side by side on one or more axes. `axes(_:)` limits which axes it may use. `UISplitArrangement.DimensionRange` sets a view's `minimum`, `preferred` and `maximum` size in the split.
- `UIOverlayArrangement` layers the primary view over the secondary, or places them side by side on a folded display. `axes(_:)` limits the axes on which it may go side by side.
- A custom arrangement conforms to `UIArrangementViewController.Arrangement`, giving `defaultViewProperties` and implementing `setViewProperties(_:for:)`.

When to use it instead of `UISplitViewController`:

- Two panes where the split should follow the fold or switch axis (top and bottom when half-folded, side by side when flat).
- An overlay that becomes side by side on a folded display.
- Keep `UISplitViewController` for classic sidebar, list and detail navigation with its collapse behavior.

Wrong: computing the hinge position yourself and placing two child views by frame. Right: an arrangement, which already avoids reserved regions.

## Reserved regions

`UIView.ReservedRegion` is a part of a view's coordinate space that hardware reserves, such as a camera or the hinge. `reservedRegions(kind:options:)` returns the regions of one kind that overlap the view.

- `Kind`: `.occlusion` (something covers the area) and `.division` (the display is split there, as at a hinge).
- Each region has `frame` (in the view's coordinates), `margins` (extra space that keeps interactive content clear), `isActive` and `kind`.
- `QueryOptions.includeInactive` also returns regions that are not active now.

```swift
@available(iOS 27.1, *)
override func layoutSubviews() {
    super.layoutSubviews()
    let hinges = reservedRegions(kind: .division)
    guard let hinge = hinges.first(where: \.isActive) else {
        layoutSinglePane()
        return
    }
    let keepOut = hinge.frame.inset(by: UIEdgeInsets(top: -hinge.margins.top, left: -hinge.margins.left,
                                                     bottom: -hinge.margins.bottom, right: -hinge.margins.right))
    layoutPanes(avoiding: keepOut)
}
```

Never put a control, text or the focus of an image across a `.division` region. Content may pass under an `.occlusion` region only if it is decorative.

## `UIHingeInteraction` and `UIHinge`

Add a `UIHingeInteraction` to a view to observe the hinge for that view's hierarchy.

```swift
@available(iOS 27.1, *)
func observeHinge() {
    let interaction = UIHingeInteraction { [weak self] _, update in
        guard let hinge = update.hinge else {
            self?.hingeDidGoAway()      // the view left a hierarchy that has a hinge
            return
        }
        switch hinge.status {
        case .closed, .fullyOpen: self?.useFlatLayout()
        case .partiallyOpen:      self?.useTentLayout(angle: hinge.angle)
        default:                  self?.useFlatLayout()
        }
    }
    view.addInteraction(interaction)
}
```

- `UIHingeInteraction(updateHandler:)`, with `isEnabled`.
- `Update.hinge` is `UIHinge?`: `nil` when the interaction leaves a hierarchy with hinge updates.
- `UIHinge.angle` is in radians. `UIHinge.status` is `.closed`, `.partiallyOpen`, `.fullyOpen` or `.unknown`.
- Do not animate on every angle change; switch layouts at status changes and use the angle only for content that should track it.

## Bars on the vertical axis

On some configurations the system can place bar content on a vertical edge.

- `UIViewController.preferredVerticalBarBehavior` (get only, override it) returns a `UIVerticalBarBehavior`: `.automatic` or `.disabled`. Return `.disabled` to keep a screen's bars horizontal.
- `childForPreferredVerticalBarBehavior` defers the choice to a child; `setNeedsUpdateOfVerticalBarConfiguration()` tells the system the preference changed.
- `UITraitCollection.verticalBarEdge` is a `UIVerticalBarEdge` (`.leading`, `.trailing`, `.unspecified`). Register for its changes with `systemTraitsAffectingVerticalBarEdge`.
- `UIView.LayoutRegion.bar(onEdge:extent:)` reserves a layout region for bar content on a given edge.
- `UIBarButtonItem.axisBehavior` (`.automatic`, `.horizontalOnly`, `.verticalPreferred`) says whether an item may move to the vertical bar.
- `UINavigationItem.verticalBarCompressionBehavior` (`.automatic`, `.prefersBarItems`, `.prefersTabBar`) says what compresses first when the tab bar and navigation or toolbar items share the vertical bar.

```swift
@available(iOS 27.1, *)
override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }   // a full-bleed editor
```

Mark items that make no sense in a vertical column (a wide segmented control, a search field) `.horizontalOnly`.

## Checks

1. Two-pane layouts on foldable devices use an arrangement, not frame math around the hinge.
2. Interactive content stays out of `.division` regions plus margins.
3. Hinge handling switches on status; the `nil` hinge case handled.
4. Bar items and screens state their vertical bar preference where it matters.

<!-- sources: https://developer.apple.com/documentation/updates/uikit, https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller, https://developer.apple.com/documentation/uikit/uisplitarrangement-swift.struct, https://developer.apple.com/documentation/uikit/uioverlayarrangement-swift.struct, https://developer.apple.com/documentation/uikit/uiview/reservedregion, https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:), https://developer.apple.com/documentation/uikit/uihingeinteraction, https://developer.apple.com/documentation/uikit/uihinge, https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredverticalbarbehavior, https://developer.apple.com/documentation/uikit/uitraitcollection/verticalbaredge, https://developer.apple.com/documentation/uikit/uibarbuttonitem/axisbehavior-swift.property, https://developer.apple.com/documentation/uikit/uinavigationitem/verticalbarcompressionbehavior -->
