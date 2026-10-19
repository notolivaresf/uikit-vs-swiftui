# Navigation bars, scroll edges and search

## Navigation bar minimization: `navigationBarMinimization`

Navigation bars can slide away while people scroll, giving the content more room. By default the system decides when. iOS 27 adds `UINavigationItem.navigationBarMinimization`, a `UIBarMinimization` value with three settings:

| Property | Type | Values |
|---|---|---|
| `minimizationBehavior` | `UIBarMinimizationBehavior` | `.automatic`, `.never`, `.onScrollDown`, `.onScrollUp` |
| `restorationBehavior` | `UIBarMinimizationRestorationBehavior` | `.automatic`, `.atScrollEdge` |
| `safeAreaAdjustment` | `UIBarMinimizationSafeAreaAdjustment` | `.automatic`, `.disabled`, `.enabled` |

It replaces the separate `barMinimizeBehavior` and `barMinimizationSafeAreaAdjustment` properties shown in early iOS 27 material. Use only `navigationBarMinimization`.

Set it per navigation item, as early as possible (in `init` or `viewDidLoad`), so the first appearance already has it:

```swift
override init(nibName: String?, bundle: Bundle?) {
    super.init(nibName: nibName, bundle: bundle)
    if #available(iOS 27, *) {
        navigationItem.navigationBarMinimization.minimizationBehavior = .onScrollDown
        navigationItem.navigationBarMinimization.restorationBehavior = .atScrollEdge
    }
}
```

When to set what:

- Long reading or browsing screens: `.onScrollDown`, so the bar leaves as people read and returns when they scroll back up.
- Screens where the bar holds controls people need all the time (an editor's title menu, a filter): `.never`.
- `restorationBehavior` decides when a minimized bar comes back. `.atScrollEdge`, as its name says, ties the return to the scroll edge rather than to any scroll back; consider it where a reappearing bar would cover what people are reading, and check the behavior on device.
- `safeAreaAdjustment = .disabled` when you place content against the bar yourself and must not get the safe area changes as the bar minimizes. Leave `.automatic` otherwise.

Wrong: hiding the bar with `setNavigationBarHidden(_:animated:)` from `scrollViewDidScroll(_:)`. It fights the system behavior, jumps the safe area, and does not match the interactive slide.

The tab bar has its own `tabBarMinimizeBehavior` (iOS 26) on `UITabBarController`; it is separate.

## Scroll edge effects look different

The scroll edge effect (the treatment under bars where content scrolls behind them) has new visuals in iOS 27.

- `.automatic` (`UIScrollEdgeEffect.Style.automatic`, iOS 26) no longer switches between the `.soft` and `.hard` looks; it has its own appearance.
- If you set `.soft` or `.hard` on `topEdgeEffect`, `bottomEdgeEffect` or the side effects, review the screen. `.soft` in particular no longer matches the default system look.
- Prefer `.automatic` unless the design truly needs a hard edge (for example, a dense table with a pinned header).

```swift
// Review any override like this after the SDK update:
scrollView.topEdgeEffect.style = .soft
// Usually the right answer is to remove it.
```

## Edge element containers shape the effect

`UIScrollEdgeElementContainerInteraction` (iOS 26) tells a scroll view that a view floating over its edge (a custom bottom bar, a composer) should get the edge effect. In iOS 27, the container view of that interaction may also contribute its size and position to the overall shape of the scroll edge effect. So:

- Size the container to the floating content. An oversized, transparent container now makes the effect taller than it should be.
- Keep one container per floating cluster rather than one big view across the whole edge.

```swift
let edgeInteraction = UIScrollEdgeElementContainerInteraction()
edgeInteraction.scrollView = collectionView
edgeInteraction.edge = .bottom
composerContainer.addInteraction(edgeInteraction)   // composerContainer hugs the composer
```

## Centered search: scope bar inline

With the iOS 27 SDK, when a `UISearchController` uses the centered placement (`preferredSearchBarPlacement = .integratedCentered`), its scope bar appears inline on the same row as the search field, not on a row underneath. When the field lives inside the navigation bar, the scope bar sits beside it inside that bar.

- Keep scope titles short (one word each) and few (two to four). Long titles truncate on the shared row.
- If you measured the old two-row height to place content, stop: use the safe area and the scroll view's insets.
- More than a few scopes belong in a filter menu instead.

## Toolbar backgrounds with hidden shared backgrounds

Fixed in iOS 27: a bottom toolbar's background could go missing when an item set `UIBarButtonItem.hidesSharedBackground` to hide its glass background. Remove workarounds that added a background view behind the toolbar.

## Checks

1. Bar hiding through `navigationBarMinimization`, not manual hide calls.
2. Edge effect style overrides reviewed; `.soft` overrides removed or justified.
3. Edge element containers sized to their content.
4. Short scope titles with centered search.

<!-- sources: https://developer.apple.com/documentation/uikit/uinavigationitem/navigationbarminimization-1kj9z, https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes, https://developer.apple.com/videos/play/wwdc2026/278/ -->
