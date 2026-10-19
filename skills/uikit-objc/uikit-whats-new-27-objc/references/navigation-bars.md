# Navigation bars, scroll edges and search

## Navigation bar minimization: Swift only

`UINavigationItem.navigationBarMinimization` (iOS 27, a `UIBarMinimization` with `minimizationBehavior`, `restorationBehavior` and `safeAreaAdjustment`) lets a screen choose when its navigation bar slides away while people scroll. Apple's documentation shows a Swift declaration only: the Objective-C variant of the page does not exist. **In Objective-C there is no selector for it. Do not invent one** (`barMinimizeBehavior` and `barMinimizationSafeAreaAdjustment` from early iOS 27 material are not it either).

What to do from Objective-C:

- Leave the system default. The system decides when the bar minimizes.
- If a screen must opt in or out, put that one setter in a small Swift extension or a Swift view controller subclass and expose a plain `@objc` method (`-configureBarMinimizationForReading`) that the Objective-C code calls. Mark the Swift file `@available(iOS 27, *)` and guard the call with `@available(iOS 27.0, *)`.
- `UINavigationController.hidesBarsOnSwipe` (an older API) hides the whole bar on swipe; it behaves differently from the new setting, so do not treat it as an equivalent.

Wrong: hiding the bar with `-setNavigationBarHidden:animated:` from `scrollViewDidScroll:`. It fights the system behavior, jumps the safe area, and does not match the interactive slide.

The tab bar has its own `tabBarMinimizeBehavior` (iOS 26, Objective-C available) on `UITabBarController`; it is separate.

## Scroll edge effects look different

The scroll edge effect (the treatment under bars where content scrolls behind them) has new visuals in iOS 27.

- `+[UIScrollEdgeEffectStyle automaticStyle]` (iOS 26) no longer switches between the soft and hard looks; it has its own appearance.
- If you set `softStyle` or `hardStyle` on `topEdgeEffect`, `bottomEdgeEffect` or the side effects, review the screen. The soft style in particular no longer matches the default system look.
- Prefer the automatic style unless the design truly needs a hard edge (for example, a dense table with a pinned header).

```objc
// Review any override like this after the SDK update:
scrollView.topEdgeEffect.style = UIScrollEdgeEffectStyle.softStyle;
// Usually the right answer is to remove it.
```

## Edge element containers shape the effect

`UIScrollEdgeElementContainerInteraction` (iOS 26) tells a scroll view that a view floating over its edge (a custom bottom bar, a composer) should get the edge effect. In iOS 27, the container view of that interaction may also contribute its size and position to the overall shape of the scroll edge effect. So:

- Size the container to the floating content. An oversized, transparent container now makes the effect taller than it should be.
- Keep one container per floating cluster rather than one big view across the whole edge.

```objc
UIScrollEdgeElementContainerInteraction *edgeInteraction = [[UIScrollEdgeElementContainerInteraction alloc] init];
edgeInteraction.scrollView = self.collectionView;
edgeInteraction.edge = UIRectEdgeBottom;
[self.composerContainer addInteraction:edgeInteraction];     // composerContainer hugs the composer
```

## Centered search: scope bar inline

With the iOS 27 SDK, when a `UISearchController` uses the centered placement (`navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementIntegratedCentered`), its scope bar appears inline on the same row as the search field, not on a row underneath. When the field lives inside the navigation bar, the scope bar sits beside it inside that bar.

- Keep scope titles short (one word each) and few (two to four). Long titles truncate on the shared row.
- If you measured the old two-row height to place content, stop: use the safe area and the scroll view's insets.
- More than a few scopes belong in a filter menu instead.

## Toolbar backgrounds with hidden shared backgrounds

Fixed in iOS 27: a bottom toolbar's background could go missing when an item set `hidesSharedBackground` (`UIBarButtonItem`, iOS 26) to hide its glass background. Remove workarounds that added a background view behind the toolbar.

## Checks

1. No Objective-C code that pretends to call `navigationBarMinimization`; Swift shim or system default.
2. Edge effect style overrides reviewed; soft overrides removed or justified.
3. Edge element containers sized to their content.
4. Short scope titles with centered search.

<!-- sources: Apple's documentation page for UINavigationItem navigationBarMinimization (Swift declaration only), iOS 27 release notes, WWDC26 session 278. Other selectors checked against the iOS 26.4 SDK headers. -->
