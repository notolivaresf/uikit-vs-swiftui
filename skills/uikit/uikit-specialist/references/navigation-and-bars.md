# Navigation, bars, tabs, sheets and scenes

Container controllers own bars, safe areas, adaptivity and the system look. Use them as designed and configure them through their items; most bar bugs come from styling the bar view directly.

## Navigation controllers and items

- Configure a screen's bar through its `navigationItem`: `title`, `largeTitleDisplayMode`, `leftBarButtonItems` / `rightBarButtonItems`, `searchController`, `backAction`, and appearance objects.
- Set appearance with `UINavigationBarAppearance` on the item (`standardAppearance`, `scrollEdgeAppearance`, `compactAppearance`), not by setting `barTintColor` or a background image on the bar while the app runs.
- `navigationItem.style` (`.navigator`, `.browser`, `.editor`, iOS 16+) gives document-style bars with a centered title menu; `titleMenuProvider` and `documentProperties` add rename and share.
- iOS 26: `navigationItem.subtitle` and `largeSubtitle` (or `largeSubtitleView`) show a second line under the title. Use them instead of a custom title view with two labels.
- `UIBarButtonItem.badge` (iOS 26) shows a count or dot on a bar item.
- Group related bar items with `UIBarButtonItemGroup`, and use `UIBarButtonItem.fixedSpace(_:)` and `.flexibleSpace()` for spacing.

Wrong: styling the bar at runtime.

```swift
navigationController?.navigationBar.barTintColor = .systemBlue
navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
```

Right: leave the system style, or describe it with an appearance on the item.

```swift
let appearance = UINavigationBarAppearance()
appearance.configureWithDefaultBackground()
navigationItem.standardAppearance = appearance
```

On iOS 26 and later bars, toolbars and tab bars use the Liquid Glass material automatically. Do not paint opaque backgrounds behind bars, do not put content views behind them to imitate a bar, and use standard bar items so the system groups them into shared glass backgrounds. Opt an item out of the shared background with `hidesSharedBackground = true` (iOS 26).

## Bar button styles

- `UIBarButtonItem.Style.prominent` (iOS 26) marks the primary action. `.done` is deprecated in the iOS 26 SDK; use `.prominent`.
- `UIBarButtonItem(systemItem:primaryAction:menu:)` and `UIBarButtonItem(title:image:primaryAction:menu:)` build items with actions and menus. Give image-only items an accessibility label (the title does this when set).

## Search

- `navigationItem.searchController = UISearchController(searchResultsController:)`, `searchResultsUpdater` for updates, `hidesSearchBarWhenScrolling` as needed.
- `navigationItem.preferredSearchBarPlacement`: `.stacked`, `.integrated`, `.integratedButton`, `.integratedCentered` (the integrated cases are iOS 26). `.inline` is deprecated in iOS 26 in favour of `.integrated`.
- In a tab bar controller, a `UISearchTab` (iOS 18) gives search its own tab; on iOS 26 it can appear as a separate search button in the tab bar.
- Debounce query updates: cancel the previous search task when a new query arrives.

## Tab bar controllers (iOS 18+)

Describe tabs with `UITab` objects instead of setting `viewControllers`.

```swift
let tabs: [UITab] = [
    UITab(title: String(localized: "Inbox"), image: UIImage(systemName: "tray"), identifier: "inbox") { _ in
        UINavigationController(rootViewController: InboxViewController())
    },
    UISearchTab { _ in
        UINavigationController(rootViewController: SearchViewController())
    },
]
tabBarController.tabs = tabs
tabBarController.mode = .tabSidebar
```

- The view controller provider runs lazily, the first time the tab is selected.
- `UITabGroup` groups tabs in the sidebar; `allowsUserCustomization` with `customizationIdentifier` lets people rearrange.
- `mode = .tabSidebar` lets the iPad tab bar turn into a sidebar. `tabBarController.sidebar` configures the sidebar (header, footer, `isHidden`).
- Tab identifiers must be stable strings; they are used for state restoration and customization.
- iOS 26: `tabBarMinimizeBehavior` (`.automatic`, `.never`, `.onScrollDown`, `.onScrollUp`) shrinks the tab bar while scrolling, and `bottomAccessory` (a `UITabAccessory` with a content view) places a persistent view above the tab bar, such as a mini player.

## Split view controllers

- Use the column-style API: `UISplitViewController(style: .doubleColumn)` or `.tripleColumn`, and `setViewController(_:for:)` per column, plus a `.compact` column for the collapsed iPhone layout.
- `preferredDisplayMode` and `preferredSplitBehavior` give a starting point; let the system adapt as the window resizes.
- iOS 26 adds an `.inspector` column for a trailing inspector next to the content.
- On compact width the split collapses to a navigation stack. Do not reimplement that with size-class checks.

## Sheets and presentation

- Configure sheets through `sheetPresentationController`: `detents` (`.medium()`, `.large()`, `.custom { context in ... }`), `prefersGrabberVisible`, `largestUndimmedDetentIdentifier`, `prefersScrollingExpandsWhenScrolledToEdge`.
- Change detents with an animation by wrapping the change in `sheet.animateChanges { }`.
- For a popover on iPad that becomes a sheet on iPhone, set `modalPresentationStyle = .popover`, a `sourceItem` (iOS 16+) on `popoverPresentationController`, and configure `adaptiveSheetPresentationController`.
- Present from the controller that is on screen. Find it from the view hierarchy (`view.window?.rootViewController` walked to the presented one) only as a last resort; pass a presenter in instead.
- `isModalInPresentation = true` blocks swipe-to-dismiss when there are unsaved changes; implement `presentationControllerDidAttemptToDismiss(_:)` to ask.

## Zoom transition (iOS 18+)

```swift
let detail = PhotoViewController(photoID: id)
detail.preferredTransition = .zoom { [weak self] context in
    guard let self,
          let detail = context.zoomedViewController as? PhotoViewController,
          let indexPath = self.dataSource.indexPath(for: detail.photoID) else { return nil }
    return self.collectionView.cellForItem(at: indexPath)
}
navigationController?.pushViewController(detail, animated: true)
```

- The provider runs on both the push and the pop. Resolve the source view from the current state each time; the cell may have been reused or the detail may show a different item after paging.
- Return `nil` when the item is off screen; the transition falls back gracefully.
- Works for push and for modal presentation.

## Scenes and windows

- Scene-based life cycle: `UIWindowSceneDelegate.scene(_:willConnectTo:options:)` creates the window with `UIWindow(windowScene:)`. `UIWindow()` and `UIWindow(frame:)` are deprecated in the iOS 26 SDK.
- Do app-state work in scene callbacks (`sceneDidBecomeActive`, `sceneWillResignActive`, `sceneDidEnterBackground`, `sceneWillEnterForeground`). The matching `UIApplicationDelegate` methods are deprecated in the iOS 26 SDK.
- Handle URLs and user activities in the scene delegate (`scene(_:openURLContexts:)`, `scene(_:continue:)`), and on first connection read them from the connection options.
- State restoration: return an `NSUserActivity` from `stateRestorationActivity(for:)` and restore it in `scene(_:willConnectTo:options:)` from `session.stateRestorationActivity`.
- Window geometry: `windowScene.effectiveGeometry` and the delegate callback `windowScene(_:didUpdateEffectiveGeometry:)`. `interfaceOrientation` and `coordinateSpace` on the scene are deprecated in iOS 26 in favour of the geometry object.
- Open new windows with `UIApplication.shared.activateSceneSession(for:errorHandler:)` and a `UISceneSessionActivationRequest` (iOS 17+).
- Never use `UIApplication.shared.windows` or `keyWindow` (deprecated). Use the view's window, or the scene's windows.

## Review checks

1. Bars configured through items and appearance objects, nothing styled on the bar view at runtime.
2. Tabs declared with `UITab`; stable identifiers.
3. Sheets use detents; popovers have a source item.
4. Zoom transition providers resolve the source from current state.
5. Windows created from a scene; no global window lookups.
