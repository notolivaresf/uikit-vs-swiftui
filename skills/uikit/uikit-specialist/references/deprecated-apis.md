# Deprecated and outdated APIs

Search this file for an API name when you meet it in existing code or are about to write it. Each row names the old API, when it was deprecated (as marked in the SDK headers), and what to use. "To be deprecated" means the header marks it for future deprecation without a version yet. Fix a deprecated call when you touch that code; do not mass-migrate unasked.

## App, scenes and windows

| Old | Deprecated | Use |
|---|---|---|
| `UIApplicationDelegate` lifecycle methods (`applicationDidBecomeActive`, `applicationWillResignActive`, `applicationDidEnterBackground`, `applicationWillEnterForeground`) | iOS 26 | the matching `UISceneDelegate` / `UIWindowSceneDelegate` methods |
| `application(_:open:options:)`, user activity and shortcut item delegate methods, launch option keys | iOS 26 | `scene(_:openURLContexts:)`, `scene(_:continue:)`, `windowScene(_:performActionFor:completionHandler:)`, connection options |
| `UIWindow()`, `UIWindow(frame:)` | iOS 26 | `UIWindow(windowScene:)` |
| `UIScreen.main` | iOS 26 | `view.window?.windowScene?.screen`, `traitCollection.displayScale`, container size |
| `UIWindowScene.interfaceOrientation`, `coordinateSpace` | iOS 26 | `windowScene.effectiveGeometry` |
| `UIApplication.shared.windows` | iOS 15 | `view.window`, `windowScene.windows` |
| `UIApplication.shared.keyWindow` | iOS 13 | `windowScene.keyWindow`, `view.window` |
| `statusBarOrientation`, `statusBarFrame` and other status bar accessors on `UIApplication` | iOS 13 | `windowScene.effectiveGeometry`, `windowScene.statusBarManager`, size classes |
| `UIMenuNewScene` | iOS 26 | `UIMenuNewItem` |
| `UIRequiresFullScreen` as a way to avoid layout work | — | support resizing; see the whats-new skill for iOS 27 behavior |

## Traits

| Old | Deprecated | Use |
|---|---|---|
| `traitCollectionDidChange(_:)` | iOS 17 | `registerForTraitChanges(_:handler:)` or trait tracking in update methods |
| `overrideTraitCollection`, `setOverrideTraitCollection(_:forChild:)` | iOS 17 | `traitOverrides` |
| `UITraitCollection(traitsFrom:)` | iOS 17 | `UITraitCollection(mutations:)`, `modifyingTraits(_:)` |

## Lists and cells

| Old | Deprecated | Use |
|---|---|---|
| `UITableViewCell.textLabel`, `detailTextLabel`, `imageView` | to be deprecated | `defaultContentConfiguration()` and `contentConfiguration` |
| `UIBackgroundConfiguration.listPlainCell()`, `listGroupedCell()`, `listSidebarCell()` | iOS 18 | `listCell()` |
| `listPlainHeaderFooter()`, `listGroupedHeaderFooter()`, `listSidebarHeader()` | iOS 18 | `listHeader()`, `listFooter()` |
| `UIListContentConfiguration.sidebarCell()`, `sidebarSubtitleCell()` | iOS 18 | `cell()`, `subtitleCell()` |
| `plainHeader()`, `groupedHeader()`, `sidebarHeader()`, `plainFooter()`, `groupedFooter()` | iOS 18 | `header()`, `footer()` |
| `NSCollectionLayoutGroup.horizontal(layoutSize:subitem:count:)` and the vertical form | iOS 16 | `horizontal(layoutSize:repeatingSubitem:count:)` |
| string reuse identifiers with `register(_:forCellWithReuseIdentifier:)` | outdated | `UICollectionView.CellRegistration` |
| index-path data sources with `performBatchUpdates` | outdated | diffable data sources |
| `UICollectionViewFlowLayout` subclasses for complex layouts | outdated | compositional layout |
| `contextMenuConfigurationForItemAt:point:` (single index path) | iOS 16 | `contextMenuConfigurationForItemsAt:point:` |

## Bars and navigation

| Old | Deprecated | Use |
|---|---|---|
| `UIBarButtonItem.Style.done` | iOS 26 | `.prominent` |
| `doneButtonAppearance` on bar appearances | iOS 26 | `prominentButtonAppearance` |
| `UINavigationItem.SearchBarPlacement.inline` | iOS 26 | `.integrated` |
| `UITabBarController.viewControllers` as the way to declare tabs | outdated | `tabs` with `UITab` (iOS 18+) |
| bar styling through `barTintColor` and background images at runtime | outdated | `UINavigationBarAppearance` on the item |

## Text

| Old | Deprecated | Use |
|---|---|---|
| `textView(_:shouldInteractWith:in:interaction:)` (URL and attachment forms) | iOS 17 | `textView(_:primaryActionFor:defaultAction:)`, `textView(_:menuConfigurationFor:defaultMenu:)` |
| `textView(_:editMenuForTextIn:suggestedActions:)` | to be deprecated | `textView(_:editMenuForTextInRanges:suggestedActions:)` (iOS 26) |
| `UIMenuController` | iOS 16 | `UIEditMenuInteraction` |
| reading `UITextView.layoutManager` on a TextKit 2 view | outdated | `textLayoutManager` (reading `layoutManager` switches to TextKit 1) |

## Controls and drawing

| Old | Deprecated | Use |
|---|---|---|
| `contentEdgeInsets`, `titleEdgeInsets`, `imageEdgeInsets` on `UIButton` | iOS 15 | `UIButton.Configuration` |
| `UIGraphicsBeginImageContextWithOptions` and friends | iOS 17 | `UIGraphicsImageRenderer` |
| `UIPreviewInteraction`, 3D Touch peek and pop | outdated | `UIContextMenuInteraction` |
| `UIWebView` | removed | `WKWebView` |
| `UIActivityIndicatorView` overlays for empty and loading states | outdated | `UIContentUnavailableConfiguration` |

## Accessibility

| Old | Deprecated | Use |
|---|---|---|
| `UIAccessibility.buttonShapesEnabled` and its change notification | iOS 26.1 | `AXShowBordersEnabled` and its notification, in the Accessibility framework |

## Patterns to replace

These are not deprecated APIs, but they are the usual cause of bugs and slow screens:

- `reloadData()` after every change → snapshots, reconfigure.
- Model structs as diffable identifiers → IDs (see `diffable-data.md`).
- Keyboard notifications and frame math → `keyboardLayoutGuide`.
- A transform-flipped list for chat → natural order with anchor restore.
- Nested collection views for horizontal rows → orthogonal sections.
- `Timer` in the default run loop mode for UI updates → `.common` mode, `Task.sleep`, or `UIUpdateLink`.
- `DispatchQueue.main.async` sprinkled through async code → main-actor isolation.
- `UIHostingConfiguration` or SwiftUI views in a UIKit-only codebase to solve a layout problem → a `UIContentConfiguration`.
