# iOS 27.1: hinges, vertical bars and the Swift-only arrangement APIs

iOS 27.1 adds APIs for devices whose shape changes: a hinge that folds, a display split by that hinge, hardware that covers part of the screen, and bars that can sit on a side edge. Everything here needs `if (@available(iOS 27.1, *))`. Several of these are Swift only; this file says which.

## `UIArrangementViewController`: Swift only (mostly)

`UIArrangementViewController` is a container that lays out a primary and a secondary view controller and adapts the arrangement to size class, orientation and reserved regions. In Apple's documentation:

- The class itself, `-init`, and `UIViewController.arrangementViewController` (`@property (nonatomic, readonly, nullable) UIArrangementViewController *arrangementViewController`) have Objective-C declarations.
- `setViewController(_:for:animated:)`, `updateArrangement(_:animated:)`, `viewController(for:)`, `placement(for:)` and `state(for:)` are **Swift only** (they use generics and Swift structs: `ViewPlacement`, `ViewState`, `UISplitArrangement`, `UIOverlayArrangement`, the `Arrangement` protocol). Objective-C has no selector for them. Do not invent one.

So from Objective-C an arrangement view controller can be created but not configured. Use `UISplitViewController` (column API, `-setViewController:forColumn:`) for two-pane screens. If a screen needs a true arrangement, write it as a Swift view controller and present it from Objective-C.

Wrong: computing the hinge position yourself and placing two child views by frame. Right: `UISplitViewController`, or a Swift arrangement, which already avoids reserved regions.

## Reserved regions: Swift only

`UIView.reservedRegions(kind:options:)` and the members of `UIView.ReservedRegion` (`frame`, `margins`, `isActive`, `kind`) have only Swift declarations. In Objective-C you cannot read the region rectangles. Use the safe area and layout margins (`safeAreaLayoutGuide`), and use `UIHingeInteraction` below to know when the hinge changes. Never put a control, text or the focus of an image across a hinge: when the hinge is partially open, switch to a layout that keeps the two halves separate.

## `UIHingeInteraction` and `UIHinge`

These have full Objective-C declarations. Add a `UIHingeInteraction` to a view to observe the hinge for that view's hierarchy.

```objc
- (void)observeHinge {
    if (@available(iOS 27.1, *)) {
        __weak typeof(self) weakSelf = self;
        UIHingeInteraction *interaction = [[UIHingeInteraction alloc] initWithUpdateHandler:
            ^(UIHingeInteraction *hingeInteraction, UIHingeInteractionUpdate *update) {
            typeof(self) strongSelf = weakSelf;
            UIHinge *hinge = update.hinge;
            if (!hinge) {
                [strongSelf hingeDidGoAway];      // the view left a hierarchy that has a hinge
                return;
            }
            switch (hinge.status) {
                case UIHingeStatusPartiallyOpen: [strongSelf useTentLayoutWithAngle:hinge.angle]; break;
                case UIHingeStatusClosed:
                case UIHingeStatusFullyOpen:
                default:                          [strongSelf useFlatLayout]; break;
            }
        }];
        [self.view addInteraction:interaction];
    }
}
```

- `-initWithUpdateHandler:`, with `enabled` (getter `isEnabled`).
- `UIHingeInteractionUpdate.hinge` is `UIHinge *`, nullable: `nil` when the interaction leaves a hierarchy with hinge updates.
- `UIHinge.angle` is a `CGFloat` in radians. `UIHinge.status` is `UIHingeStatusClosed`, `...PartiallyOpen`, `...FullyOpen` or `...Unknown`.
- The handler is a block kept by the interaction, which the view keeps: capture `weakSelf`.
- Do not animate on every angle change; switch layouts at status changes and use the angle only for content that should track it.

## Bars on the vertical axis

On some configurations the system can place bar content on a vertical edge. These have Objective-C declarations unless noted.

- `UIViewController.preferredVerticalBarBehavior` (read only, override the getter) returns a `UIVerticalBarBehavior`: `UIVerticalBarBehaviorAutomatic` or `...Disabled`. Return `Disabled` to keep a screen's bars horizontal.
- `childViewControllerForPreferredVerticalBarBehavior` defers the choice to a child; `-setNeedsUpdateOfVerticalBarConfiguration` tells the system the preference changed.
- `UITraitCollection.verticalBarEdge` is a `UIVerticalBarEdge` (`UIVerticalBarEdgeLeading`, `...Trailing`, `...Unspecified`). A trait-set constant for registering for its changes exists (`systemTraitsAffectingVerticalBarEdge` in the Swift docs); look up its Objective-C name in the Xcode 27 header before using it.
- `UIView.LayoutRegion.bar(onEdge:extent:)` is **Swift only**.
- `UIBarButtonItem.axisBehavior` (`UIBarButtonItemAxisBehaviorAutomatic`, `...HorizontalOnly`, `...VerticalPreferred`) says whether an item may move to the vertical bar.
- `UINavigationItem.verticalBarCompressionBehavior` (`UIVerticalBarCompressionBehaviorAutomatic`, `...PrefersBarItems`, `...PrefersTabBar`) says what compresses first when the tab bar and navigation or toolbar items share the vertical bar.

```objc
// in a full-bleed editor view controller
- (UIVerticalBarBehavior)preferredVerticalBarBehavior API_AVAILABLE(ios(27.1)) {
    return UIVerticalBarBehaviorDisabled;
}
```

Mark items that make no sense in a vertical column (a wide segmented control, a search field) `UIBarButtonItemAxisBehaviorHorizontalOnly`. `API_AVAILABLE(ios(27.1))` on your own override is the declaration marker; it does not check at runtime (the system only calls it on 27.1).

## Checks

1. Two-pane layouts on foldable devices use `UISplitViewController` (or a Swift arrangement), not frame math around the hinge.
2. No Objective-C code pretends to call the Swift-only arrangement or reserved region APIs.
3. Hinge handling switches on status; the `nil` hinge case handled; handler uses `weakSelf`.
4. Bar items and screens state their vertical bar preference where it matters.

<!-- sources: Apple's documentation pages with the language toggle: UIArrangementViewController (class, init and arrangementViewController have Objective-C; the placement and arrangement methods show Swift only), UIHingeInteraction, UIHingeInteractionUpdate, UIHinge, UIHingeStatus, UIVerticalBarBehavior, UIVerticalBarEdge, UIBarButtonItemAxisBehavior, UIVerticalBarCompressionBehavior, preferredVerticalBarBehavior, setNeedsUpdateOfVerticalBarConfiguration; UIView.ReservedRegion and LayoutRegion.bar show Swift only. -->
