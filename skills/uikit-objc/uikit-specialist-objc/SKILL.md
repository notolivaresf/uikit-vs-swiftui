---
name: uikit-specialist-objc
description: Best practices and performance for Objective-C UIKit apps on iOS 18 and later. Use whenever writing, reviewing, refactoring or debugging Objective-C UIKit code in .m and .h files - UIViewController, UIView, UICollectionView, UITableView, compositional layout, NSDiffableDataSourceSnapshot and diffable data sources, UICollectionViewCellRegistration, content and background configurations, self-sizing cells, scroll position and prepending, image loading and prefetching, Auto Layout, safe area, keyboardLayoutGuide, size classes and resizable windows, UINavigationController, UITabBarController and UITab, UISplitViewController, sheets, zoom transitions, scenes and windows, traits and custom traits, updateProperties, Dynamic Type, UITextView and TextKit 2, edit menus, context menus, swipe actions, drag and drop, keyboard shortcuts, animations and springs, Liquid Glass, accessibility, localization, blocks and retain cycles with weak and strong self, GCD and main-thread rules, nullability and lightweight generics, hitches and Instruments, and replacing deprecated UIKit APIs.
---

# UIKit specialist for Objective-C

Rules and patterns for Objective-C UIKit code that is correct, fast and current on iOS 18 and later, with notes where iOS 26 adds a better way. Every example is Objective-C and every selector name is the Objective-C one. For what changed in the iOS 27 SDK, also use the `uikit-whats-new-27-objc` skill.

## How to work

1. Read the project first: its deployment target, ARC and module settings, prefix and naming style, whether headers carry nullability annotations, and whether Swift code imports the headers. Match them. Guard APIs newer than the target with `if (@available(iOS 26.0, *))`.
2. Load only the references the task needs (list below). Each is self-contained.
3. Change the least code that fixes the problem. Do not migrate working code to a new pattern unless asked or unless the old pattern is the bug.
4. UIKit and Objective-C only. Do not bring SwiftUI or Swift into an Objective-C codebase to solve a UIKit problem unless the project already mixes them on purpose.
5. When reviewing, report in this order: crashes and retain cycles, main-thread stalls, layout and accessibility bugs, deprecated APIs, then style. Quote the line for each finding.
6. After a change to scrolling, layout or images, say how to check it (Instruments or a hitch test, see `list-performance.md`).
7. Import with `@import UIKit;` (or the framework umbrella header) and never `#include`. Look up a selector in the SDK header before using it; do not write a Swift name from memory.

## Core rules

- Lists and grids: `UICollectionView` with a compositional layout and a diffable data source. Keep working `UITableView` screens, with a diffable data source.
- Item identifiers are stable, immutable ID objects (`NSUUID`, `NSString`, `NSNumber`), not models, indexes or content. Content changes go through `-reconfigureItemsWithIdentifiers:`.
- Cells come from `UICollectionViewCellRegistration` objects created once; content from content configurations; state through `configurationUpdateHandler` or `-updateConfigurationUsingState:`.
- Anything that holds text has an estimated size and grows with Dynamic Type.
- Nothing slow on the main thread: no decoding, disk or network reads, formatter creation or layout loops in configuration, layout or scroll callbacks.
- Layout from the view's bounds, traits and guides, never from the screen, the device idiom or the orientation.
- Read traits inside UIKit's update methods so changes are tracked; do not cache them. Observation tracking of model properties is Swift only: in Objective-C call `-setNeedsUpdateProperties` yourself (see `dataflow.md`).
- A stored block uses `weakSelf` and re-checks it with a strong local. Block, `NSString` and collection properties are `copy`; delegates are `weak`.
- Cancel what you start (`NSURLSessionTask`, timers, delayed performs, observers) and capture identifiers, never index paths, in blocks that run later.
- UIKit is called on the main thread only: `dispatch_async(dispatch_get_main_queue(), ...)` at the boundary where a callback arrives.
- Every header has nullability (`NS_ASSUME_NONNULL_BEGIN`/`END`, `nullable` for the exceptions) and lightweight generics on collections; use `__kindof` for subclass-typed returns.
- Standard bars, controls and system colors, so the system look (Liquid Glass on iOS 26) and accessibility settings apply.

## References

- `references/collection-layout.md`: compositional layouts, list configurations, sizes and estimates, grids, orthogonal sections, supplementaries, self-sizing. Use when building or changing any list, grid or table layout.
- `references/diffable-data.md`: item identity with `isEqual:` and `hash`, snapshots, reconfigure vs reload, section snapshots, reordering, duplicates, `NSNotFound`. Use when a list animates wrongly, crashes on apply, loses state, or when designing a data source.
- `references/cells.md`: registrations, content and background configurations, configuration state, accessories, reuse safety, empty and loading states. Use when writing or debugging a cell, header or empty state.
- `references/updates-and-scrolling.md`: choosing an update, coalescing, prepending without jumps, chat bottom pinning, restoring position, scroll edge effects. Use when content changes while the user scrolls.
- `references/list-performance.md`: configuration budget, image decoding and caching, prefetching, rendering costs, Instruments and hitch tests. Use for slow scrolling, hitches, memory growth or image loading.
- `references/layout.md`: Auto Layout hygiene, guides, layout regions, concentric corners, keyboard, size classes and resizing, view controller lifecycle. Use for constraint bugs, keyboard handling, rotation and window resizing.
- `references/navigation-and-bars.md`: navigation items and bar appearance, bar button styles, search, `UITab` tab bars and sidebars, split views, sheets, zoom transition, scenes and windows. Use when building screens and app structure.
- `references/dataflow.md`: where state lives, what observation tracking does and does not do in Objective-C, `-updateProperties`, `UIViewAnimationOptionFlushUpdates`, KVO and explicit update paths. Use when wiring models to views or when views show stale data.
- `references/traits-and-environment.md`: reading and registering traits, trait overrides, custom trait classes, colors, Liquid Glass materials, display scale. Use for dark mode, theming, environment values and appearance bugs.
- `references/text.md`: Dynamic Type, labels, selectable text views, edit menus, links, text input, TextKit 2, localization. Use for any text display, editing or string work.
- `references/animation.md`: springs, layout animation, property animators, symbol effects, custom transitions, Reduce Motion. Use when adding or fixing motion.
- `references/interactions.md`: context menus, button and bar menus, edit menus, swipe actions, drag and drop, pointer, keyboard shortcuts, gestures, haptics. Use for anything the user presses, drags or clicks.
- `references/accessibility.md`: labels, traits, grouping, custom actions, order, announcements, settings, audits. Use when building custom views or reviewing accessibility.
- `references/concurrency.md`: GCD and main-thread rules, cancellation, retain cycles with blocks, property attributes, KVO and timers, Swift interop annotations (`NS_SWIFT_UI_ACTOR`, `NS_SWIFT_NONISOLATED`), hang causes. Use for async work, callbacks and memory in view controllers and cells.
- `references/deprecated-apis.md`: deprecated and outdated APIs with replacements, `API_AVAILABLE` and `@available`, modules, by area. Use when touching older code or when the compiler warns.

## Review checklist

1. Main thread: anything slow in configuration, `viewDidLoad`, layout or scroll callbacks; UIKit touched from a callback queue.
2. Data source: identifiers stable, unique, immutable with matching `isEqual:` and `hash`; one apply path; reconfigure over reload.
3. Cells: reuse safe, sizing complete, no per-pass work that could be cached.
4. Layout: no ambiguity or conflicts, no screen or idiom math, works at compact width and the largest text size.
5. Lifetime: no retain cycles in stored blocks, timers, display links and observers; delegates weak; requests and observers cancelled and removed.
6. Accessibility: labels, traits, custom actions, order.
7. Headers: nullability, generics, `copy` on blocks and strings.
8. Deprecated APIs from `deprecated-apis.md`; newer APIs behind `@available`.

Show the changed code, say why in one line, and point to the reference for detail.
