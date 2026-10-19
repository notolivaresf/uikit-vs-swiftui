# Tab bars and sidebars

iOS 27 adds two things to `UITabBarController`: any tab can be the prominent tab, and iPhone apps can opt into the sidebar. Both build on the `UITab` API from iOS 18.

## Prominent tab: `prominentTabIdentifier`

`prominentTabIdentifier` (iOS 27, `NSString *`) names the tab that gets emphasis in the tab bar. The prominent tab stays visible even when the tab bar collapses during scrolling.

```objc
UITab *shop = [[UITab alloc] initWithTitle:NSLocalizedString(@"Shop", @"Tab") image:[UIImage systemImageNamed:@"bag"]
    identifier:kShopTabID viewControllerProvider:^UIViewController *(__kindof UITab *tab) { return [[ShopViewController alloc] init]; }];
UITab *cart = [[UITab alloc] initWithTitle:NSLocalizedString(@"Cart", @"Tab") image:[UIImage systemImageNamed:@"cart"]
    identifier:kCartTabID viewControllerProvider:^UIViewController *(__kindof UITab *tab) { return [[CartViewController alloc] init]; }];
UISearchTab *search = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController *(__kindof UITab *tab) {
    return [[SearchViewController alloc] init];
}];
UITabBarController *tabBarController = [[UITabBarController alloc] init];
tabBarController.tabs = @[shop, cart, search];
if (@available(iOS 27.0, *)) {
    tabBarController.prominentTabIdentifier = kCartTabID;
}
```

- Use `-setProminentTabIdentifier:animated:` to change it while the bar is on screen.
- When the property is `nil` and there is a `UISearchTab` with `automaticallyActivatesSearch = YES`, the search tab gets the prominent treatment, as on iOS 26.
- The identifier must match a tab's `identifier`. Keep identifiers as `static NSString * const` constants; a typo silently gives no prominent tab.
- Pick the one destination people return to most. Do not move the prominence around as a notification.

Wrong: faking prominence with a custom tab bar item image or a floating button over the tab bar. It breaks the collapse behavior, Liquid Glass and accessibility.

## Sidebars on iPhone: `sidebar.preferredPlacement`

On iPad, a tab bar can expand into a sidebar and people can switch between the two. On iPhone, the tab bar stays at the bottom by default at every size. New in iOS 27, an iPhone app can opt into the sidebar:

```objc
if (@available(iOS 27.0, *)) {
    tabBarController.sidebar.preferredPlacement = UITabBarControllerSidebarPlacementSidebar;
}
```

`sidebar` is a `UITabBarControllerSidebar`. `UITabBarControllerSidebarPlacement` has `UITabBarControllerSidebarPlacementAutomatic`, `...Sidebar` and `...TabBar`. The property is the preferred placement when the sidebar and tab bar are mutually exclusive and only one can be shown.

On iPhone this is an app choice, not a user toggle: there is no control to flip between sidebar and tab bar. The system shows the sidebar when there is room (for example, a regular horizontal size class in iPhone Mirroring or on iPad) and the tab bar otherwise.

## `sidebar.isAvailable`

`UITabBarControllerSidebar.isAvailable` (iOS 27, `BOOL`, read only) says whether the sidebar can be shown in the current context. Documentation lists it as a property named `isAvailable`, so write `tabBarController.sidebar.isAvailable`. When it is true the sidebar is visible, or can become visible depending on `hidden`.

Use it to decide where to put content that only a sidebar reaches, such as child tabs of a `UITabGroup` or a group's landing page:

```objc
- (void)updateNavigationAffordances {
    BOOL sidebar = NO;
    if (@available(iOS 27.0, *)) { sidebar = self.tabBarController.sidebar.isAvailable; }
    // child tabs are reachable from the sidebar; otherwise surface them inside the screen
    self.librarySectionPicker.hidden = sidebar;
}
```

Call it again when the size changes (`viewWillTransitionToSize:withTransitionCoordinator:` or a trait registration for the horizontal size class), since availability follows the space.

## Tab bar design notes for iOS 27

- Nested tabs (`UITabGroup`) need a path on iPhone when no sidebar is available: a segmented control, a list on the group's root screen, or a menu.
- Keep `UITab` view controller providers cheap; they run on first selection, and they are blocks retained by the tab (`weakSelf`).
- Customization of tab order is unchanged.

## Checks

1. Prominent tab set by identifier, not by custom art.
2. iPhone sidebar opt-in guarded with `@available(iOS 27.0, *)`.
3. Content in tab groups reachable when `sidebar.isAvailable` is false.

<!-- sources: Objective-C declarations on Apple's pages for UITabBarController prominentTabIdentifier, setProminentTabIdentifier:animated:, UITabBarControllerSidebar preferredPlacement and isAvailable, UITabBarControllerSidebarPlacement; WWDC26 session 278. -->
