# Deprecations and behavior fixes in the iOS 27 SDK

## Deprecated or required

| Change | What to do |
|---|---|
| App delegate life cycle: apps built with the iOS 27 SDK fail to launch without the scene life cycle | Adopt `UISceneDelegate` (see `app-lifecycle.md`) |
| No launch screen: rejected by the App Store for 27.0 SDK builds | Add `UILaunchScreen` or a launch storyboard key |
| `UIApplication.canOpenURL(_:)` deprecated in iOS 27 | Open the URL and handle failure; prefer universal links |
| `windowExternalDisplayNonInteractive` scenes no longer offered automatically | `registerSceneAccessory(_:)` with `.externalNonInteractive` (see `scene-accessories.md`) |
| Early names `barMinimizeBehavior`, `barMinimizationSafeAreaAdjustment` | `navigationItem.navigationBarMinimization` (see `navigation-bars.md`) |

Still deprecated from iOS 26 and more urgent now that iPhone apps resize: `UIScreen.main`, `UIWindow(frame:)`, the app delegate life cycle methods, `UIWindowScene.interfaceOrientation`. See the `uikit-specialist` skill's `deprecated-apis.md`.

## `canOpenURL(_:)`

Deprecated message: attempt to open the URL and handle any failure instead of validating it first; universal links remove the need for this check.

Wrong:

```swift
if UIApplication.shared.canOpenURL(mapsURL) {
    UIApplication.shared.open(mapsURL)
} else {
    showMapsMissing()
}
```

Right:

```swift
Task { @MainActor in
    let opened = await UIApplication.shared.open(mapsURL)
    if !opened { showMapsMissing() }
}
```

Or from a scene, `view.window?.windowScene?.open(mapsURL, options: nil) { opened in ... }`.

- For links to your own or a partner's app, use universal links (`https` URLs). With `.universalLinksOnly` in the open options, the call fails instead of falling back to the browser, which gives the "app installed?" answer without `canOpenURL`.
- Do not use URL checks to decide what to show before the user acts (hiding a button when an app is missing). Show the action and handle failure.
- `LSApplicationQueriesSchemes` entries exist only for `canOpenURL`; remove them once the calls are gone.

## Behavior fixes that change how apps run

These are listed as fixed in the iOS 27 release notes. Most apply only to apps built with the iOS 27 SDK. Code that worked around the old behavior may now misbehave; check each.

| Area | iOS 27 behavior | Check |
|---|---|---|
| Status bar accessors (`statusBarFrame`, `statusBarOrientation`, `statusBarStyle`, `isStatusBarHidden` on `UIApplication`) | may return NaN or null values with the 27 SDK | replace them (see `resizable-apps.md`) |
| iPad continuous resizing | no longer depends on listing all four orientations | layouts handle every size |
| iPad, iPhone-only apps | ignore supported orientations after the first window resize; layout must hold in an unsupported orientation | test rotated and resized |
| `UIRequiresFullScreen` (iPad, iPhone-only on iPad, iPhone Mirroring) | resizes arrive as discrete moves to a new `UIScreen` with new bounds, not continuous updates; `UIScreen.main` bounds stay fixed | rebuild on screen change |
| iPhone Mirroring | supported orientations honored until the user resizes; the scene starts on the main screen | do not assume portrait-only stays true |
| `UISceneClosureConfirmation` | now presents its dialog | remove custom alert workarounds |
| `UIMenuLeaf` | now has `subtitle` | drop casts to `UIAction` for it |
| Bottom toolbar with `hidesSharedBackground` items | background shows | remove added background views |
| Presented view controller traits | walk the superview chain through presentation views | check custom presentation controllers |
| Menu images on iPadOS and macOS | mostly hidden by default | set `preferredImageVisibility` where meaning depends on the image |
| Centered search with scopes | scope bar on the same row | short scope titles |
| Scroll edge effect `.automatic` | new look; no longer switches between soft and hard | review `.soft` and `.hard` overrides |
| Drag delegate | can be called by Siri without a gesture | no UI in `sessionWillBegin` |

## Grep list for an SDK update

```
UIScreen.main
userInterfaceIdiom
interfaceOrientation
statusBarOrientation
statusBarFrame
canOpenURL
windowExternalDisplayNonInteractive
UIRequiresFullScreen
sessionWillBegin
.soft
```

Each match either goes or gets a one-line comment saying why it stays.

<!-- sources: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes, https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:), https://developer.apple.com/documentation/updates/uikit, https://developer.apple.com/videos/play/wwdc2026/278/ -->
