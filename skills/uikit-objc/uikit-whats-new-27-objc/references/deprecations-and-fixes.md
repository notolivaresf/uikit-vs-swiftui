# Deprecations and behavior fixes in the iOS 27 SDK

## Deprecated or required

| Change | What to do |
|---|---|
| App delegate life cycle: apps built with the iOS 27 SDK fail to launch without the scene life cycle | Adopt `UISceneDelegate` (see `app-lifecycle.md`) |
| No launch screen: rejected by the App Store for 27.0 SDK builds | Add `UILaunchScreen` or a launch storyboard key |
| `-[UIApplication canOpenURL:]` deprecated in iOS 27 | Open the URL and handle failure; prefer universal links |
| External display non-interactive scenes no longer offered automatically | `-registerSceneAccessory:` with `+externalNonInteractiveSceneAccessoryWithConfiguration:` (see `scene-accessories.md`) |
| Early names `barMinimizeBehavior`, `barMinimizationSafeAreaAdjustment` | `navigationBarMinimization`, which is Swift only (see `navigation-bars.md`) |

Still deprecated from iOS 26 and more urgent now that iPhone apps resize: `+[UIScreen mainScreen]`, `-[UIWindow initWithFrame:]`, the app delegate life cycle methods, `UIWindowScene.interfaceOrientation`. See the `uikit-specialist-objc` skill's `deprecated-apis.md`.

## `canOpenURL:`

Deprecated (iOS 27) with the message: prefer attempting to open URLs and handling any failures. Universal links remove the need for this check.

Wrong:

```objc
UIApplication *app = [UIApplication sharedApplication];
if ([app canOpenURL:mapsURL]) {
    [app openURL:mapsURL options:@{} completionHandler:nil];
} else {
    [self showMapsMissing];
}
```

Right:

```objc
__weak typeof(self) weakSelf = self;
[[UIApplication sharedApplication] openURL:mapsURL options:@{} completionHandler:^(BOOL success) {
    if (!success) {
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf showMapsMissing]; });
    }
}];
```

Or from a scene, `[windowScene openURL:mapsURL options:nil completionHandler:^(BOOL success) { ... }]`.

- For links to your own or a partner's app, use universal links (`https` URLs). With `UIApplicationOpenURLOptionUniversalLinksOnly` set to `@YES` in the open options, the call fails instead of falling back to the browser, which gives the "app installed?" answer without `canOpenURL:`.
- Do not use URL checks to decide what to show before the user acts (hiding a button when an app is missing). Show the action and handle failure.
- `LSApplicationQueriesSchemes` entries exist only for `canOpenURL:`; remove them once the calls are gone.

## Behavior fixes that change how apps run

These are listed as fixed in the iOS 27 release notes. Most apply only to apps built with the iOS 27 SDK. Code that worked around the old behavior may now misbehave; check each.

| Area | iOS 27 behavior | Check |
|---|---|---|
| Status bar accessors (`statusBarFrame`, `statusBarOrientation`, `statusBarStyle`, `isStatusBarHidden` on `UIApplication`) | may return NaN or null values with the 27 SDK | replace them (see `resizable-apps.md`) |
| iPad continuous resizing | no longer depends on listing all four orientations | layouts handle every size |
| iPad, iPhone-only apps | ignore supported orientations after the first window resize; layout must hold in an unsupported orientation | test rotated and resized |
| `UIRequiresFullScreen` (iPad, iPhone-only on iPad, iPhone Mirroring) | resizes arrive as discrete moves to a new `UIScreen` with new bounds, not continuous updates; the main screen's bounds stay fixed | rebuild on screen change |
| iPhone Mirroring | supported orientations honored until the user resizes; the scene starts on the main screen | do not assume portrait-only stays true |
| `UISceneClosureConfirmation` | now presents its dialog | remove custom alert workarounds |
| `UIMenuLeaf` | now has `subtitle` | drop casts to `UIAction` for it |
| Bottom toolbar with `hidesSharedBackground` items | background shows | remove added background views |
| Presented view controller traits | walk the superview chain through presentation views | check custom presentation controllers |
| Menu images on iPadOS and macOS | mostly hidden by default | set `preferredImageVisibility` where meaning depends on the image |
| Centered search with scopes | scope bar on the same row | short scope titles |
| Scroll edge effect automatic style | new look; no longer switches between soft and hard | review soft and hard overrides |
| Drag delegate | can be called by Siri without a gesture | no UI in `dragInteraction:sessionWillBegin:` |

## Grep list for an SDK update

```
mainScreen
userInterfaceIdiom
interfaceOrientation
statusBarOrientation
statusBarFrame
canOpenURL
UIWindowSceneSessionRoleExternalDisplayNonInteractive
UIRequiresFullScreen
sessionWillBegin
softStyle
hardStyle
```

Each match either goes or gets a one-line comment saying why it stays.

<!-- sources: iOS 27 release notes, Apple's page for -[UIApplication canOpenURL:] (deprecated 27.0, message quoted above), UIKit updates page, WWDC26 session 278. Open URL selectors checked against the iOS 26.4 SDK headers. -->
