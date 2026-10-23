# Campfire room performance

All nine numbers beat the original scorecard, and all 13 checks pass. Completed October 21, 2026 at 04:38 CST, before the 06:27 deadline.

UIKit, Objective-C app sources, iOS 18 deployment target, build 2. Data comes from the unmodified CampfireKitObjC product.

## Measurements

Measured with `./bench` on the iPhone 17 / iOS 26.4 simulator. Lower is better.

| Measure | Original scorecard | Final |
| --- | ---: | ---: |
| First 40 rows, cold | 175 ms | 160 ms |
| First 40 rows, repeated | 649 ms | 632 ms |
| Stream CPU | 15.6 s | 8.7 s |
| Jump to message 2,500 | 65 ms | 40 ms |
| Load older | 59 ms | 5 ms |
| Text size, at the bottom | 18 ms | 12 ms |
| Text size, mid-list | 29 ms | 21 ms |
| Peak memory | 45.6 MB | 44.2 MB |
| App size | 3.13 MB | 2.77 MB |

Final verification: `./bench`, results in `.bench-work/sim-20261021-043510`. All nine rows printed “better”; 13/13 checks passed, with no failed suite steps. The stack and protected-file checks also passed.

Fresh measurement before changes: repeated rows 650 ms, check passed.

The selection/menu fix was completed first and verified with 13/13 checks before performance work. A dedicated `./bench stream` before the layout change measured 15.5 s and passed both stream checks.

## Changes and validation

- Preserve UIKit's suggested text-selection actions and put Reply first, with the iOS 26 multi-range delegate and the iOS 18 fallback. The original menu replaced the system actions with Copy and Reply. Putting Reply last hid it in overflow; putting it first passed all 13 checks.
- Enable symbol stripping for the Release app product (`DEPLOYMENT_POSTPROCESSING`, `STRIP_INSTALLED_PRODUCT`, `STRIP_STYLE=all`). Dedicated size measurements: 3.13 MB before, 2.74 MB after.
- Replace one compositional section per message and whole-room diffable snapshots with one collection section and explicit insert batches. The custom `CFChatLayout` stores subtree row counts and heights in a balanced index: appends, prepends, ID/index lookup, and a boost height change follow tree paths; viewport queries visit intersecting rows. Older pages measure only their new messages. Loaded messages are retained instead of trimming to 300.
- Apply nonanimated updates and restore position synchronously. The layout also supplies the anchored target content offset during UIKit updates. A finger drag releases that anchor.
- Keep UIKit cell registrations, content configurations, and `reconfigureItemsAtIndexPaths:`. A row revision refreshes prefetched views when they next lay out and avoids rebuilding an unchanged view for redundant configuration passes. Body text remains native, selectable UITextView throughout.
- Give Reset and Jump a fresh collection and height index when replacing the window. Reusing the old collection while replacing its entire geometry caused repeated Reset failures; fresh collections passed the repeated paging and text-size suites. Small updates continue to reuse the existing collection. Reset reuses an unchanged newest page at the default size, after verifying there are no extra boosts, and pins it to the bottom.
- The custom layout owns measured heights, so automatic self-sizing invalidation is disabled. Width and Dynamic Type changes explicitly remeasure rows and restore the visible anchor.
- Dedicated runs verified each change before the final full confirmation. Repeated paging and text-size suites also pass after the whole-window replacement fix.

## Experiment log

| Experiment | Before | After | Decision |
| --- | --- | --- | --- |
| Incremental collection layout with balanced height index, freshly installed | Stream 15.5 s | Stream 9.6 s | Kept; both stream checks pass, 640 messages retained |
| Pool text-view objects | — | Stale installed app was measured | Not in final app |
| Defer text-view layout until touch, use lightweight display otherwise | — | Stale installed app was measured | Not in final app |
| Synchronous batch layout | Mid-list text size 63 ms | 41 ms | Kept |
| Layout target content offset respects the anchor | Mid-list text size 41 ms | 23 ms | Kept; zero drift |
| Row revision/configuration guard | Cold rows 176 ms | 162 ms | Kept |
| Set visible configurations directly instead of UIKit reconfigure | Mid-list text size 23 ms | 34 ms | Reverted; kept the independent revision guard |
| Fresh collection for whole-window replacement | Repeated Reset failed in dedicated suites | Older 5 ms; bottom text size 12 ms; mid-list 22 ms; repeated suites clean | Kept |
| Reuse an unchanged default page on Reset | Peak memory 48.3 MB | 44.0 MB | Kept |

Measurement workflow: single-metric runtime runs could measure the previously installed app. For example, the first height-index build removes the 300-row cap, but its stream summary still reported 300. The local recording script puts installation inside the cold-launch path. Running `./bench rows-cold` first, then the desired metric, installed the changed app: the stream result now reports the expected 640 loaded messages and 9.6 s CPU (`sim-20261021-035426`). Earlier 15.6 s / 68 ms results from stale installations are invalid comparisons. No harness files were changed.

## Guidance used

- Installed `.agents/skills/uikit-specialist-objc/SKILL.md`, especially text, list performance, diffable data, and updates/scrolling references.
- [Apple: UITextView](https://developer.apple.com/documentation/uikit/uitextview/)
- [Apple: Building high-performance lists and collection views](https://developer.apple.com/documentation/uikit/building-high-performance-lists-and-collection-views)
- [Apple: Creating Custom Layouts](https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/CollectionViewPGforIOS/CreatingCustomLayouts/CreatingCustomLayouts.html)
- [Apple: Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
