---
name: uikit-whats-new-27
description: What is new, changed or deprecated in UIKit in the iOS 27 SDK (iOS 27.0 and 27.1). Use when building with Xcode 27 or the iOS 27 SDK, raising a deployment target to iOS 27, fixing new warnings or launch failures after an SDK update, or asked about iOS 27 UIKit - the required scene life cycle, the required launch screen, state restoration on foreground, resizable iPhone apps in iPhone Mirroring and on iPad, UIScreen.main and displayScale, effectiveGeometry, user interface idiom and orientation checks, UIRequiresFullScreen discrete resizing, presented view controller traits, tab bar prominentTabIdentifier, iPhone sidebars with sidebar.preferredPlacement and isAvailable, navigationBarMinimization, scroll edge effect changes, centered search scope bars, menu image visibility with preferredImageVisibility, Ask Siri and drag sessions without a gesture, allowsPointerDragBeforeLiftDelay, scene accessories with registerSceneAccessory, external display content, TextKit viewport rendering surfaces, text tables, attachment view reuse, observation in section providers, the UIView motion and heading body, Mac Catalyst refresh controls and steppers, canOpenURL deprecation, and the iOS 27.1 foldable APIs - UIArrangementViewController, split and overlay arrangements, UIHingeInteraction, reserved regions and vertical bars.
---

# UIKit: what is new in the iOS 27 SDK

This skill covers changes in UIKit between the iOS 26 SDK and the iOS 27 SDK, including the iOS 27.1 additions. For general UIKit practice use the `uikit-specialist` skill; this one only says what is different now.

## How to work

1. Check the deployment target. Every API marked iOS 27 or 27.1 here needs `if #available(iOS 27, *)` (or `27.1`) when the target is lower. Behavior changes marked "when built with the iOS 27 SDK" apply to any app linked against the new SDK, whatever its deployment target.
2. Load the reference for the area you are touching. Each one is short and self-contained.
3. Treat the two requirements first (scene life cycle, launch screen): an app that misses either one fails to launch or is rejected.
4. Do not rename or restructure working code just because a newer API exists. Adopt the new API where it fixes a real problem or removes a deprecation warning.
5. If an API you want is not in these references, check the SDK headers or Apple's documentation before using it; do not guess names.

## Must do when moving to the iOS 27 SDK

- The app uses the scene-based life cycle (a `UISceneDelegate` and a scene manifest). Without it the app does not launch.
- `Info.plist` declares a launch screen with one of `UILaunchStoryboardName`, `UILaunchStoryboards`, `UILaunchScreen` or `UILaunchScreens`.
- No layout depends on `UIScreen.main`, the device idiom or the interface orientation. iPhone apps are freely resizable in iPhone Mirroring and on iPad.
- `canOpenURL(_:)` calls are replaced with an attempt to open and a failure path.

## References

- `references/app-lifecycle.md`: required scene life cycle, required launch screen, state restoration extended into foreground, scene closure confirmation. Use when the app fails to launch on the new SDK, when migrating off the app delegate life cycle, or when restoring state.
- `references/resizable-apps.md`: resizable iPhone apps, screens, `displayScale`, effective geometry, idiom and orientation, `UIRequiresFullScreen` discrete resizing, presented view controller traits, status bar accessors. Use when an app looks wrong in iPhone Mirroring, on iPad, or after resizing.
- `references/tabs-and-sidebar.md`: `prominentTabIdentifier`, iPhone sidebars with `sidebar.preferredPlacement`, `sidebar.isAvailable`. Use when changing a `UITabBarController`.
- `references/navigation-bars.md`: `navigationBarMinimization`, scroll edge effect changes, edge element containers, centered search scope bars, toolbar background fix. Use for bars that hide on scroll, edge effects and search.
- `references/menus-and-drag.md`: menu image visibility, Ask Siri in menus, drag sessions that start without a gesture, pointer drag timing, `UIMenuLeaf.subtitle`. Use when building menus or drag and drop.
- `references/scene-accessories.md`: `registerSceneAccessory(_:)`, external display content, the camera capture accessory on iOS 27.1. Use for second-screen content.
- `references/text.md`: viewport layout in `UITextView` subclasses, attachment view reuse, text tables, rendering surfaces. Use for TextKit 2 work.
- `references/observation-and-sensors.md`: observation in compositional layout section providers, `UIView` as the motion and heading body, Mac Catalyst controls. Use when wiring models to layouts or orienting sensor data.
- `references/foldables-27-1.md`: `UIArrangementViewController`, split and overlay arrangements, `UIHingeInteraction`, reserved regions, vertical bars and bar item axes. Use for devices with a hinge or an outer display, and for layouts that must avoid hardware regions.
- `references/deprecations-and-fixes.md`: what is deprecated in the iOS 27 SDK and which behavior fixes may change how an app runs. Use when the compiler warns after the SDK update or when behavior changed.

## Review checklist for an iOS 27 SDK update

1. Scene delegate present and the app launches; launch screen key present.
2. `grep` for `UIScreen.main`, `userInterfaceIdiom`, `interfaceOrientation`, `statusBarOrientation`, `canOpenURL`; each one has a replacement or a reason.
3. Custom presentation controllers still pass the right traits.
4. Drag delegate begin methods do no animation or modal UI.
5. Menus that need images set `preferredImageVisibility`.
6. External display code registers a scene accessory.
7. The app runs in the resizable simulator and at compact width.
