---
name: uikit-specialist
description: Best practices and performance for UIKit apps on iOS 18 and later. Use whenever writing, reviewing, refactoring or debugging UIKit code - UIViewController, UIView, UICollectionView, UITableView, compositional layout, diffable data sources, cell registrations, content and background configurations, self-sizing cells, scroll position and prepending, image loading and prefetching, Auto Layout, safe area, keyboardLayoutGuide, size classes and resizable windows, UINavigationController, UITabBarController and UITab, UISplitViewController, sheets, zoom transitions, scenes and windows, traits and custom traits, Observation and updateProperties, Dynamic Type, UITextView and TextKit 2, edit menus, context menus, swipe actions, drag and drop, keyboard shortcuts, animations and springs, Liquid Glass, accessibility, localization, Swift concurrency in UIKit, hitches and Instruments, and replacing deprecated UIKit APIs.
---

# UIKit specialist

Rules and patterns for UIKit code that is correct, fast and current on iOS 18 and later, with notes where iOS 26 adds a better way. For what changed in the iOS 27 SDK, also use the `uikit-whats-new-27` skill.

## How to work

1. Read the project first: its deployment target, Swift version and concurrency settings, architecture and naming. Match them. Guard APIs newer than the target with `if #available`.
2. Load only the references the task needs (list below). Each is self-contained.
3. Change the least code that fixes the problem. Do not migrate working code to a new pattern unless asked or unless the old pattern is the bug.
4. UIKit only. Do not bring SwiftUI into a UIKit codebase to solve a UIKit problem unless the project already mixes them on purpose.
5. When reviewing, report in this order: crashes and data races, main-thread stalls, layout and accessibility bugs, deprecated APIs, then style. Quote the line for each finding.
6. After a change to scrolling, layout or images, say how to check it (Instruments or a hitch test, see `list-performance.md`).

## Core rules

- Lists and grids: `UICollectionView` with a compositional layout and a diffable data source. Keep working `UITableView` screens, with a diffable data source.
- Item identifiers are stable IDs, not models, indexes or content. Content changes go through `reconfigureItems(_:)`.
- Cells come from registrations created once; content from content configurations; state through `configurationUpdateHandler` or `updateConfiguration(using:)`.
- Anything that holds text has an estimated size and grows with Dynamic Type.
- Nothing slow on the main actor: no decoding, disk or network reads, formatter creation or layout loops in configuration, layout or scroll callbacks.
- Layout from the view's bounds, traits and guides, never from the screen, the device idiom or the orientation.
- Read traits and observable models inside UIKit's update methods so changes are tracked; do not cache them.
- Store and cancel tasks; capture identifiers, never index paths, in closures that run later.
- Standard bars, controls and system colors, so the system look (Liquid Glass on iOS 26) and accessibility settings apply.

## References

- `references/collection-layout.md`: compositional layouts, list configurations, sizes and estimates, grids, orthogonal sections, supplementaries, self-sizing. Use when building or changing any list, grid or table layout.
- `references/diffable-data.md`: item identity, snapshots, reconfigure vs reload, section snapshots, reordering, duplicates. Use when a list animates wrongly, crashes on apply, loses state, or when designing a data source.
- `references/cells.md`: registrations, content and background configurations, configuration state, accessories, reuse safety, empty and loading states. Use when writing or debugging a cell, header or empty state.
- `references/updates-and-scrolling.md`: choosing an update, coalescing, prepending without jumps, chat bottom pinning, restoring position, scroll edge effects. Use when content changes while the user scrolls.
- `references/list-performance.md`: configuration budget, image decoding and caching, prefetching, rendering costs, Instruments and hitch tests. Use for slow scrolling, hitches, memory growth or image loading.
- `references/layout.md`: Auto Layout hygiene, guides, layout regions, concentric corners, keyboard, size classes and resizing, view controller lifecycle. Use for constraint bugs, keyboard handling, rotation and window resizing.
- `references/navigation-and-bars.md`: navigation items and bar appearance, bar button styles, search, `UITab` tab bars and sidebars, split views, sheets, zoom transition, scenes and windows. Use when building screens and app structure.
- `references/dataflow.md`: where state lives, Observation tracking, `updateProperties()`, `.flushUpdates`, explicit update paths. Use when wiring models to views or when views show stale data.
- `references/traits-and-environment.md`: reading and registering traits, trait overrides, custom traits, colors, Liquid Glass materials, display scale. Use for dark mode, theming, environment values and appearance bugs.
- `references/text.md`: Dynamic Type, labels, selectable text views, edit menus, links, text input, TextKit 2, localization. Use for any text display, editing or string work.
- `references/animation.md`: springs, layout animation, property animators, symbol effects, custom transitions, Reduce Motion. Use when adding or fixing motion.
- `references/interactions.md`: context menus, button and bar menus, edit menus, swipe actions, drag and drop, pointer, keyboard shortcuts, gestures, haptics. Use for anything the user presses, drags or clicks.
- `references/accessibility.md`: labels, traits, grouping, custom actions, order, announcements, settings, audits. Use when building custom views or reviewing accessibility.
- `references/concurrency.md`: main actor, tasks and cancellation, moving work off main, streams, callbacks, hang causes. Use for async work in view controllers and cells.
- `references/deprecated-apis.md`: deprecated and outdated APIs with replacements, by area. Use when touching older code or when the compiler warns.

## Review checklist

1. Main thread: anything slow in configuration, `viewDidLoad`, layout or scroll callbacks.
2. Data source: identifiers stable and unique, one apply path, reconfigure over reload.
3. Cells: reuse safe, sizing complete, no per-pass work that could be cached.
4. Layout: no ambiguity or conflicts, no screen or idiom math, works at compact width and the largest text size.
5. Lifetime: no retain cycles in stored closures, tasks and observers cancelled.
6. Accessibility: labels, traits, custom actions, order.
7. Deprecated APIs from `deprecated-apis.md`.

Show the changed code, say why in one line, and point to the reference for detail.
