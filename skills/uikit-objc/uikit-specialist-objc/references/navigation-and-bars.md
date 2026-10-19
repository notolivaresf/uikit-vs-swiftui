# Navigation, bars, tabs, sheets and scenes

Container controllers own bars, safe areas, adaptivity and the system look. Use them as designed and configure them through their items; most bar bugs come from styling the bar view directly.

## Navigation controllers and items

- Configure a screen's bar through its `navigationItem`: `title`, `largeTitleDisplayMode`, `leftBarButtonItems` / `rightBarButtonItems`, `searchController`, `backAction`, and appearance objects.
- Set appearance with `UINavigationBarAppearance` on the item (`standardAppearance`, `scrollEdgeAppearance`, `compactAppearance`), not by setting `barTintColor` or a background image on the bar while the app runs.
- `navigationItem.style` (`UINavigationItemStyleNavigator`, `...Browser`, `...Editor`, iOS 16+) gives document-style bars with a centered title menu; `titleMenuProvider` (a block receiving the suggested actions and returning a `UIMenu`) and `documentProperties` add rename and share.
- iOS 26: `navigationItem.subtitle` and `largeSubtitle` (or `subtitleView`, `largeSubtitleView`) show a second line under the title. Use them instead of a custom title view with two labels.
- `UIBarButtonItem.badge` (iOS 26, a `UIBarButtonItemBadge`) shows a count or dot on a bar item.
- Group related bar items with `UIBarButtonItemGroup`, and use `+[UIBarButtonItem fixedSpaceItemOfWidth:]` and `+flexibleSpaceItem` for spacing.
- Bar item action targets are weak and use selectors; a mistyped `@selector` crashes at tap time. Prefer the `primaryAction:` initializers with a `UIAction` block capturing `weakSelf`.

Wrong: styling the bar at runtime.

```objc
self.navigationController.navigationBar.barTintColor = [UIColor systemBlueColor];
[self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
```

Right: leave the system style, or describe it with an appearance on the item.

```objc
UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
[appearance configureWithDefaultBackground];
self.navigationItem.standardAppearance = appearance;
```

On iOS 26 and later bars, toolbars and tab bars use the Liquid Glass material automatically. Do not paint opaque backgrounds behind bars, do not put content views behind them to imitate a bar, and use standard bar items so the system groups them into shared glass backgrounds. Opt an item out of the shared background with `hidesSharedBackground = YES` (iOS 26).

## Bar button styles

- `UIBarButtonItemStyleProminent` (iOS 26) marks the primary action. `UIBarButtonItemStyleDone` is deprecated in the iOS 26 SDK; use `...Prominent`.
- Build items with actions and menus: `-initWithBarButtonSystemItem:primaryAction:`, `-initWithBarButtonSystemItem:menu:`, `-initWithTitle:menu:`, `-initWithImage:menu:`, `-initWithPrimaryAction:` and `-initWithPrimaryAction:menu:`. A `UIAction` carries the title and image (`+actionWithTitle:image:identifier:handler:`). Give image-only items an accessibility label (the title does this when set).

## Search

- `self.navigationItem.searchController = [[UISearchController alloc] initWithSearchResultsController:nil]`, `searchResultsUpdater` (weak: another object keeps the delegate alive) for updates, `hidesSearchBarWhenScrolling` as needed.
- `navigationItem.preferredSearchBarPlacement`: `UINavigationItemSearchBarPlacementStacked`, `...Integrated`, `...IntegratedButton`, `...IntegratedCentered` (the integrated cases are iOS 26). `...Inline` is deprecated in iOS 26 in favour of `...Integrated`.
- In a tab bar controller, a `UISearchTab` (iOS 18) gives search its own tab; on iOS 26 it can appear as a separate search button in the tab bar.
- Debounce query updates: cancel the previous delayed call (`+cancelPreviousPerformRequestsWithTarget:selector:object:` plus `-performSelector:withObject:afterDelay:`, or a cancellable block) when a new query arrives.

## Tab bar controllers (iOS 18+)

Describe tabs with `UITab` objects instead of setting `viewControllers`.

```objc
UITab *inbox = [[UITab alloc] initWithTitle:NSLocalizedString(@"Inbox", @"Tab title")
                                      image:[UIImage systemImageNamed:@"tray"]
                                 identifier:@"inbox"
                     viewControllerProvider:^UIViewController *(__kindof UITab *tab) {
    return [[UINavigationController alloc] initWithRootViewController:[[InboxViewController alloc] init]];
}];
UISearchTab *search = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController *(__kindof UITab *tab) {
    return [[UINavigationController alloc] initWithRootViewController:[[SearchViewController alloc] init]];
}];
tabBarController.tabs = @[inbox, search];
tabBarController.mode = UITabBarControllerModeTabSidebar;
```

- The view controller provider runs lazily, the first time the tab is selected. The block is retained by the tab: do not capture `self` strongly if `self` owns the tab bar controller.
- `UITabGroup` groups tabs in the sidebar; `allowsReordering` lets people rearrange them.
- `mode = UITabBarControllerModeTabSidebar` lets the iPad tab bar turn into a sidebar. `tabBarController.sidebar` configures the sidebar (header, footer, `hidden`).
- Tab identifiers must be stable strings; they are used for state restoration and customization.
- iOS 26: `tabBarMinimizeBehavior` (`UITabBarMinimizeBehaviorAutomatic`, `...Never`, `...OnScrollDown`, `...OnScrollUp`) shrinks the tab bar while scrolling, and `bottomAccessory` (a `UITabAccessory` with a content view) places a persistent view above the tab bar, such as a mini player. Both are iOS 26 only: guard with `@available(iOS 26.0, *)`.

## Split view controllers

- Use the column-style API: `[[UISplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn]` or `...TripleColumn`, and `-setViewController:forColumn:` per column, plus the compact column for the collapsed iPhone layout.
- `preferredDisplayMode` and `preferredSplitBehavior` give a starting point; let the system adapt as the window resizes.
- iOS 26 adds `UISplitViewControllerColumnInspector` for a trailing inspector next to the content.
- On compact width the split collapses to a navigation stack. Do not reimplement that with size-class checks.

## Sheets and presentation

- Configure sheets through `sheetPresentationController`: `detents` (`+[UISheetPresentationControllerDetent mediumDetent]`, `+largeDetent`, `+customDetentWithIdentifier:resolver:`), `prefersGrabberVisible`, `largestUndimmedDetentIdentifier`, `prefersScrollingExpandsWhenScrolledToEdge`.
- Change detents with an animation by wrapping the change in `[sheet animateChanges:^{ ... }]`.
- For a popover on iPad that becomes a sheet on iPhone, set `modalPresentationStyle = UIModalPresentationPopover`, a `sourceItem` (iOS 16+) on `popoverPresentationController`, and configure `adaptiveSheetPresentationController`.
- Present from the controller that is on screen. Find it from the view hierarchy (`view.window.rootViewController` walked to the presented one) only as a last resort; pass a presenter in instead.
- `modalInPresentation = YES` blocks swipe-to-dismiss when there are unsaved changes; implement `presentationControllerDidAttemptToDismiss:` to ask. (The property is declared `modalInPresentation` with getter `isModalInPresentation`.)

## Zoom transition (iOS 18+)

```objc
PhotoViewController *detail = [[PhotoViewController alloc] initWithPhotoID:photoID];
__weak typeof(self) weakSelf = self;
detail.preferredTransition = [UIViewControllerTransition zoomWithOptions:nil
    sourceViewProvider:^UIView * _Nullable(UIZoomTransitionSourceViewProviderContext *context) {
    typeof(self) strongSelf = weakSelf;
    PhotoViewController *zoomed = (PhotoViewController *)context.zoomedViewController;
    NSIndexPath *indexPath = [strongSelf.dataSource indexPathForItemIdentifier:zoomed.photoID];
    return indexPath ? [strongSelf.collectionView cellForItemAtIndexPath:indexPath] : nil;
}];
[self.navigationController pushViewController:detail animated:YES];
```

- The provider runs on both the push and the pop. Resolve the source view from the current state each time; the cell may have been reused or the detail may show a different item after paging.
- Return `nil` when the item is off screen; the transition falls back gracefully.
- Works for push and for modal presentation.
- The provider is stored on the detail controller, which the navigation stack owns: `weakSelf` matters.

## Scenes and windows

- Scene-based life cycle: `-scene:willConnectToSession:options:` creates the window with `[[UIWindow alloc] initWithWindowScene:windowScene]`. `-[UIWindow init]` and `-initWithFrame:` are deprecated in the iOS 26 SDK. Keep the window in a `strong` property on the scene delegate.
- Do app-state work in scene callbacks (`sceneDidBecomeActive:`, `sceneWillResignActive:`, `sceneDidEnterBackground:`, `sceneWillEnterForeground:`). The matching `UIApplicationDelegate` methods are deprecated in the iOS 26 SDK.
- Handle URLs and user activities in the scene delegate (`scene:openURLContexts:`, `scene:continueUserActivity:`), and on first connection read them from the connection options.
- State restoration: return an `NSUserActivity` from `stateRestorationActivityForScene:` and restore it in `scene:willConnectToSession:options:` from `session.stateRestorationActivity`.
- Window geometry: `windowScene.effectiveGeometry` and the delegate callback `windowScene:didUpdateEffectiveGeometry:` (iOS 26). `interfaceOrientation` and `coordinateSpace` on the scene are deprecated in iOS 26 in favour of the geometry object.
- Open new windows with `-[UIApplication activateSceneSessionForRequest:errorHandler:]` and a `UISceneSessionActivationRequest` (iOS 17+).
- Never use `[UIApplication sharedApplication].windows` or `keyWindow` (deprecated). Use the view's window, or the scene's windows.

## Review checks

1. Bars configured through items and appearance objects, nothing styled on the bar view at runtime.
2. Tabs declared with `UITab`; stable identifiers.
3. Sheets use detents; popovers have a source item.
4. Zoom transition providers resolve the source from current state and capture `weakSelf`.
5. Windows created from a scene; no global window lookups; iOS 26 APIs behind `@available`.
