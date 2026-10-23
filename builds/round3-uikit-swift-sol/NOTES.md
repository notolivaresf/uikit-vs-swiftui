# Campfire performance notes

UIKit only. Measurements use the supplied ./bench and iPhone 17 / iOS 26.4 simulator. Work started October 20, 2026 at 21:46 local time; final verification finished before the 00:46 deadline.

## Scorecard

The before column is the supplied scorecard. All after numbers come from the final fresh full run, .bench-work/sim-20261020-232111, including bounded eviction for large history windows. **All nine numbers beat the scorecard, and all 13 checks pass.**

| Measure | Before | After |
| --- | ---: | ---: |
| First 40 rows, cold | 195 ms | 129 ms |
| First 40 rows, repeated | 639 ms | 591 ms |
| Stream CPU | 9.8 s | 7.5 s |
| Jump to message 2,500 | 38 ms | 31 ms |
| Load older | 33 ms | 30 ms |
| Text size, at the bottom | 20 ms | 18 ms |
| Text size, mid-list | 31 ms | 30 ms |
| Peak memory | 59.6 MB | 57.2 MB |
| App size | 1.20 MB | 0.79 MB |

## What changed

- **System text selection.** Preserve UIKit's suggested edit-menu actions and place Reply first, keeping Copy/Reply directly available along with Select All, Look Up, and Translate. Implement both the iOS 26 multiple-range delegate and the older delegate. Messages still use native selectable TextKit 2 text views. Boost reconfiguration skips assigning unchanged attributed text.
- **Earlier background generation.** Start the unchanged FakeData.generate(size: .k50) and feed construction immediately after the unchanged launch-clock line, overlapping this work with UIKit scene/chrome creation. The initial page still comes from the complete 50,000-message dataset through CampfireKit.
- **One snapshot section.** Replace a section for every message with one section containing stable message IDs. Edit snapshots for insertions/removals and reconfigure only changed IDs. Wait for UIKit's snapshot completion before restoring the viewport, including boost-only changes.
- **Incremental row work.** Cache layouts by message ID. Measure inserted or boosted messages, and update the previous last row's trailing gap without rebuilding its text. Remove full-message layout keys, full-cache filtering, and per-update grouping passes over every loaded message. Font-size and width changes still remeasure the loaded rows.
- **Indexed heights.** A Fenwick prefix-height index supports logarithmic height changes and offset searches. Layout queries visit visible rows instead of building every row's frame. Leading storage supports older-page insertion; storage compaction is amortized. Cached rows are evicted in bounded batches so a large history window cannot turn one incoming message into thousands of removals.
- **Stable anchors.** Use the layout's geometry for anchors, round cumulative row boundaries to physical pixels, retain the already measured cell heights, and restore after cell layout. Exact top alignment uses UIKit's scrolling API. Automatic self-sizing invalidation is disabled because every height change is supplied explicitly by the room layout.
- **Reuse immutable presentation work.** Cache message timestamp strings by UTC minute of day, compile syntax-highlighting expressions once, and evaluate the emoji-only flag once per layout. Text, fonts, colors, wrapping rules, and bubble-local geometry are unchanged.
- **Release product size.** Enable standard dead-code/symbol stripping for the app's Release configuration. Debug settings are unchanged, and Release debug information remains in the external dSYM. project.yml matches the checked-in Xcode project.

Application message measurement and geometry updates depend on changed rows. UIKit still performs its identifier diff when a diffable snapshot is applied; this is not a claim that UIKit's entire update is mathematically constant-time.

## Verification

- Fresh full benchmark: **13/13 checks pass**, including text selection, Copy/Reply, all 600 live messages, boost growth, paging, font changes, and rotation.
- Added two height-index XCTest cases. Both passed in a standalone macOS XCTest run: **2 tests, 0 failures**. They cover mixed edits, a long sliding window, compaction, and older-page insertion through 10,000 rows.
- Additional standalone validation passed 20,000 randomized operations. An index-only microbenchmark ran 100,000 point changes plus prefix queries in about **2.6 ms at 50 rows** and **2.9 ms at 5,000 rows**. These are index timings, not whole-app timings.
- Cached UTC timestamp output matched the existing formatter for 25,000 dates and minute/day boundaries, including dates before the Unix epoch.
- Compiler checked the app, unit-test, and UI-test sources. The selection UI test now requires a system selection action, in addition to Copy and Reply.
- CampfireKit, fixtures, screenshots, PROMPT.md, bench, and .bench/ were not modified. Launch/debug clock boundary lines were checked against the original source and are unchanged.

## Measurement details

Representative controlled improvements during iteration: one snapshot section reduced stream CPU from 9.7 to 7.4 seconds; earlier generation reduced cold launch from 186 to 128 ms; metadata caching reduced the mid-list text-size result from a 31 ms tie to 30 ms; Release stripping reduced app size from 1.23 to 0.79 MB. The table uses a complete run rather than combining the best individual readings.

Several quick jump runs reported identical old geometry after source changes. A subsequent full fresh-install run reported message 2,500 at y=0 in all three trials with the exact same compiled-binary SHA-256 as the preceding quick run. Final runtime comparisons therefore use fresh-install full runs. No benchmark scripts or measurement boundaries were changed.

Unproven invalidation-timing changes and a separate live-history store were not retained. A label-to-text-view selection renderer was considered but not used; native text views were sufficient to beat the scorecard.

## References

- Installed UIKit specialist skill: text, collection layout, diffable data, list performance, scrolling/updates, concurrency, and accessibility references.
- [Apple: Make blazing fast lists and collection views](https://developer.apple.com/videos/play/wwdc2021/10252/)
- [Apple: Customizing collection view layouts](https://developer.apple.com/documentation/uikit/customizing-collection-view-layouts)
- [Apple: Text-view edit-menu delegate](https://developer.apple.com/documentation/uikit/uitextviewdelegate/textview(_:editmenufortextin:suggestedactions:))
- [Apple: Self-sizing invalidation](https://developer.apple.com/documentation/uikit/uicollectionview/selfsizinginvalidation-swift.enum/disabled)
- [Apple: Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
