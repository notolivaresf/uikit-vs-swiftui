# Tab bars and sidebars

iOS 27 adds two things to `UITabBarController`: any tab can be the prominent tab, and iPhone apps can opt into the sidebar. Both build on the `UITab` API from iOS 18.

## Prominent tab: `prominentTabIdentifier`

`UITabBarController.prominentTabIdentifier: String?` (iOS 27) names the tab that gets emphasis in the tab bar. The prominent tab stays visible even when the tab bar collapses during scrolling.

```swift
let tabs = [
    UITab(title: String(localized: "Shop"), image: UIImage(systemName: "bag"), identifier: "shop") { _ in ShopViewController() },
    UITab(title: String(localized: "Cart"), image: UIImage(systemName: "cart"), identifier: "cart") { _ in CartViewController() },
    UISearchTab { _ in SearchViewController() },
]
let tabBarController = UITabBarController(tabs: tabs)
if #available(iOS 27, *) {
    tabBarController.prominentTabIdentifier = "cart"
}
```

- Use `setProminentTabIdentifier(_:animated:)` to change it while the bar is on screen.
- When the property is `nil` and there is a `UISearchTab` with `automaticallyActivatesSearch = true`, the search tab gets the prominent treatment, as on iOS 26.
- The identifier must match a tab's `identifier`. Keep identifiers as constants; a typo silently gives no prominent tab.
- Pick the one destination people return to most. Do not move the prominence around as a notification.

Wrong: faking prominence with a custom tab bar item image or a floating button over the tab bar. It breaks the collapse behavior, Liquid Glass and accessibility.

## Sidebars on iPhone: `sidebar.preferredPlacement`

On iPad, a tab bar can expand into a sidebar and people can switch between the two. On iPhone, the tab bar stays at the bottom by default at every size. New in iOS 27, an iPhone app can opt into the sidebar:

```swift
if #available(iOS 27, *) {
    tabBarController.sidebar.preferredPlacement = .sidebar
}
```

`UITabBarController.Sidebar.Placement` has `.automatic`, `.sidebar` and `.tabBar`. The property is "the preferred placement when the sidebar and tab bar are mutually exclusive and only one can be shown".

On iPhone this is an app choice, not a user toggle: there is no control to flip between sidebar and tab bar. The system shows the sidebar when there is room (for example, a regular horizontal size class in iPhone Mirroring or on iPad) and the tab bar otherwise.

## `sidebar.isAvailable`

`UITabBarController.Sidebar.isAvailable: Bool` (iOS 27, read only) says whether the sidebar can be shown in the current context. When it is `true` the sidebar is visible, or can become visible depending on `isHidden`.

Use it to decide where to put content that only a sidebar reaches, such as child tabs of a `UITabGroup` or a group's landing page:

```swift
func updateNavigationAffordances() {
    if tabBarController.sidebar.isAvailable {
        // child tabs are reachable from the sidebar
        librarySectionPicker.isHidden = true
    } else {
        // surface the group's children inside the screen instead
        librarySectionPicker.isHidden = false
    }
}
```

Call it again when the size changes (`viewWillTransition(to:with:)` or a trait change for the horizontal size class), since availability follows the space.

## Tab bar design notes for iOS 27

- Nested tabs (`UITabGroup`) need a path on iPhone when no sidebar is available: a segmented control, a list on the group's root screen, or a menu.
- Keep `UITab` view controller providers cheap; they run on first selection.
- Customization (`allowsUserCustomization` on tabs, `customizationIdentifier`) is unchanged.

## Checks

1. Prominent tab set by identifier, not by custom art.
2. iPhone sidebar opt-in guarded with `#available(iOS 27, *)`.
3. Content in tab groups reachable when `sidebar.isAvailable` is false.

<!-- sources: https://developer.apple.com/documentation/uikit/uitabbarcontroller/prominenttabidentifier, https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/preferredplacement, https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/isavailable, https://developer.apple.com/videos/play/wwdc2026/278/ -->
