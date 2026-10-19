# Deprecated and outdated APIs

Search this file for an API name when you meet it in existing code or are about to write it. Each row names the old API, when it was deprecated (as marked in the SDK headers), and what to use. "To be deprecated" means the header marks it for future deprecation without a version yet. Fix a deprecated call when you touch that code; do not mass-migrate unasked. Method names are the Objective-C selectors.

## Deprecation macros and availability checks

- A header marks deprecation with `API_DEPRECATED("message", ios(introduced, deprecated))` or `API_DEPRECATED_WITH_REPLACEMENT("newName", ios(introduced, deprecated))`. The compiler warning names the replacement; read it.
- Guard a newer API at its call site with `if (@available(iOS 26.0, *)) { ... } else { ... }`. `@available` is a runtime check the compiler understands, so calls inside it do not warn.
- `API_AVAILABLE(ios(26.0))` is the declaration side: put it on your own method or class that is only valid from that version. It does not check at runtime. Do not use `API_AVAILABLE` where you need a branch, and do not use `@available` on a declaration.
- Mark your own deprecated methods with `API_DEPRECATED_WITH_REPLACEMENT` or `NS_DEPRECATED_IOS`, not a comment.
- Check for a selector that may be missing on an older OS with `[obj respondsToSelector:@selector(...)]` only for unannotated or private-looking cases; for public APIs `@available` is the tool.
- Import frameworks as modules: `@import UIKit;` (or `#import <UIKit/UIKit.h>`, which clang also turns into a module import). Do not mix `#include`. A missing symbol after adding a framework usually means the module is not enabled (`CLANG_ENABLE_MODULES = YES`).

## App, scenes and windows

| Old | Deprecated | Use |
|---|---|---|
| `UIApplicationDelegate` lifecycle methods (`applicationDidBecomeActive:`, `applicationWillResignActive:`, `applicationDidEnterBackground:`, `applicationWillEnterForeground:`) | iOS 26 | the matching `UISceneDelegate` / `UIWindowSceneDelegate` methods (`sceneDidBecomeActive:` and so on) |
| `application:openURL:options:`, user activity and shortcut item delegate methods, launch option keys | iOS 26 | `scene:openURLContexts:`, `scene:continueUserActivity:`, `windowScene:performActionForShortcutItem:completionHandler:`, connection options |
| `-[UIWindow init]`, `-[UIWindow initWithFrame:]` | iOS 26 | `-[UIWindow initWithWindowScene:]` |
| `+[UIScreen mainScreen]` | iOS 26 | `view.window.windowScene.screen`, `traitCollection.displayScale`, container size |
| `UIWindowScene.interfaceOrientation`, `coordinateSpace` | iOS 26 | `windowScene.effectiveGeometry.interfaceOrientation`, `.coordinateSpace` |
| `[UIApplication sharedApplication].windows` | iOS 15 | `view.window`, `windowScene.windows` |
| `[UIApplication sharedApplication].keyWindow` | iOS 13 | `windowScene.keyWindow`, `view.window` |
| `statusBarOrientation`, `statusBarFrame` and other status bar accessors on `UIApplication` | iOS 13 | `windowScene.effectiveGeometry`, `windowScene.statusBarManager`, size classes |
| `UIMenuNewScene` | iOS 26 | `UIMenuNewItem` |
| `UIRequiresFullScreen` as a way to avoid layout work | — | support resizing; see the whats-new skill for iOS 27 behavior |

## Traits

| Old | Deprecated | Use |
|---|---|---|
| `-traitCollectionDidChange:` | iOS 17 | `-registerForTraitChanges:withHandler:` or trait tracking in update methods |
| `overrideTraitCollection`, `-setOverrideTraitCollection:forChildViewController:` | iOS 17 | `traitOverrides` |
| `+[UITraitCollection traitCollectionWithTraitsFromCollections:]` | iOS 17 | `+traitCollectionWithTraits:` and `-traitCollectionByModifyingTraits:` |

## Lists and cells

| Old | Deprecated | Use |
|---|---|---|
| `UITableViewCell.textLabel`, `detailTextLabel`, `imageView` | to be deprecated | `-defaultContentConfiguration` and `contentConfiguration` |
| `+[UIBackgroundConfiguration listPlainCellConfiguration]`, `listGroupedCellConfiguration`, `listSidebarCellConfiguration` | iOS 18 | `+listCellConfiguration` |
| `listPlainHeaderFooterConfiguration`, `listGroupedHeaderFooterConfiguration`, `listSidebarHeaderConfiguration` | iOS 18 | `+listHeaderConfiguration`, `+listFooterConfiguration` |
| `+[UIListContentConfiguration sidebarCellConfiguration]`, `sidebarSubtitleCellConfiguration` | iOS 18 | `+cellConfiguration`, `+subtitleCellConfiguration` |
| `plainHeaderConfiguration`, `groupedHeaderConfiguration`, `sidebarHeaderConfiguration`, `plainFooterConfiguration`, `groupedFooterConfiguration` | iOS 18 | `+headerConfiguration`, `+footerConfiguration` |
| `+[NSCollectionLayoutGroup horizontalGroupWithLayoutSize:subitem:count:]` and the vertical form | iOS 16 | `+horizontalGroupWithLayoutSize:repeatingSubitem:count:` |
| string reuse identifiers with `registerClass:forCellWithReuseIdentifier:` | outdated | `UICollectionViewCellRegistration` |
| index-path data sources with `performBatchUpdates:completion:` | outdated | diffable data sources |
| `UICollectionViewFlowLayout` subclasses for complex layouts | outdated | compositional layout |
| `collectionView:shouldShowMenuForItemAtIndexPath:` and `canPerformAction:...` | iOS 16 | `collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:` |

## Bars and navigation

| Old | Deprecated | Use |
|---|---|---|
| `UIBarButtonItemStyleDone` | iOS 26 | `UIBarButtonItemStyleProminent` |
| `doneButtonAppearance` on bar appearances | iOS 26 | `prominentButtonAppearance` |
| `UINavigationItemSearchBarPlacementInline` | iOS 26 | `UINavigationItemSearchBarPlacementIntegrated` |
| `UITabBarController.viewControllers` as the way to declare tabs | outdated | `tabs` with `UITab` (iOS 18+) |
| bar styling through `barTintColor` and background images at runtime | outdated | `UINavigationBarAppearance` on the item |

## Text

| Old | Deprecated | Use |
|---|---|---|
| `textView:shouldInteractWithURL:inRange:interaction:` (and the attachment form) | iOS 17 | `textView:primaryActionForTextItem:defaultAction:`, `textView:menuConfigurationForTextItem:defaultMenu:` |
| `textView:editMenuForTextInRange:suggestedActions:` | iOS 26 | `textView:editMenuForTextInRanges:suggestedActions:` |
| `UIMenuController` | iOS 16 | `UIEditMenuInteraction` |
| reading `UITextView.layoutManager` on a TextKit 2 view | outdated | `textLayoutManager` (reading `layoutManager` switches to TextKit 1) |

## Controls and drawing

| Old | Deprecated | Use |
|---|---|---|
| `contentEdgeInsets`, `titleEdgeInsets`, `imageEdgeInsets` on `UIButton` | iOS 15 | `UIButtonConfiguration` |
| `UIGraphicsBeginImageContextWithOptions` and friends | iOS 17 | `UIGraphicsImageRenderer` |
| `UIPreviewInteraction`, 3D Touch peek and pop | outdated | `UIContextMenuInteraction` |
| `UIWebView` | removed | `WKWebView` |
| `UIActivityIndicatorView` overlays for empty and loading states | outdated | `UIContentUnavailableConfiguration` |

## Accessibility

| Old | Deprecated | Use |
|---|---|---|
| `UIAccessibilityButtonShapesEnabled()` and `UIAccessibilityButtonShapesEnabledStatusDidChangeNotification` | iOS 26.1 | `AXShowBordersEnabled()` and its notification, in the Accessibility framework |

## Objective-C patterns to replace

These are not deprecated APIs, but they are the usual cause of bugs and leaks:

- `reloadData` after every change → snapshots, reconfigure.
- Model objects as diffable identifiers → immutable ID objects (see `diffable-data.md`).
- Keyboard notifications and frame math → `keyboardLayoutGuide`.
- A transform-flipped list for chat → natural order with anchor restore.
- Nested collection views for horizontal rows → orthogonal sections.
- `NSTimer` with a target on the default run loop mode for UI updates → block timer in common mode, `dispatch_after`, or `UIUpdateLink`.
- `performSelector:withObject:afterDelay:` → a block, and cancel with `+cancelPreviousPerformRequestsWithTarget:selector:object:` if you keep it.
- `dispatch_async(dispatch_get_main_queue(), ...)` sprinkled everywhere → hop once, at the boundary where a callback arrives.
- Delegates declared `strong` or `assign` for objects → `weak`.
- Untyped collections and unannotated headers → lightweight generics and nullability.
- `UIHostingConfiguration` or SwiftUI views in a UIKit-only codebase to solve a layout problem → a `UIContentConfiguration`.
