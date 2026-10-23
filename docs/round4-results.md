# Round 4 results: six Mac builds, one fast pass each (22 Oct)

Xcode 27.1 (`DEVELOPER_DIR`), macOS 27, MacBook Pro M1 Max, one build at a time through `buildslot`. One fast pass per build (`record-mac.sh --fast`: one iteration per test, 3 cold-launch samples, median reported). Summaries: `runs/<build>/1/summary.json`. Fast passes are single-iteration readings, not the full benchmark: differences of about 10 to 15 % are noise.

Release apps were built with Xcode 26.4 (all six; Sol SwiftUI Mac had only a Debug build and got a Release build into its own `build/rel`, source untouched).

| Metric | AppKit Swift Opus | AppKit Swift Sol | AppKit ObjC Opus | AppKit ObjC Sol | SwiftUI Mac Opus | SwiftUI Mac Sol |
|---|---|---|---|---|---|---|
| Cold launch, median of 3 (ms) | 699 | 753 | 688 | 803 (one sample 5,132) | 763 | 919 |
| First 40 rows, cold (ms) | 270 | 279 | 209 | 312 | 345 | 520 |
| First 40 rows, repeated (ms) | 244 | 265 | 202 | 263 | 407 | 493 |
| Jump to message 2,500 (ms) | 32 | 33 | 15 | 22 | 66 | 407 (check fails) |
| Load older (ms) | 23 | 13 | 9 | 8 | 8 | 170 (check fails) |
| Text size at the bottom (ms) | 25 | 16 | 9 | 10 | 24 | 112 |
| Text size mid-list (ms) | 25 | 26 | 10 | 22 | 67 | 152 |
| Peak memory (MB) | 107.5 | 132.9 | 102.9 | 122.1 | 216.9 | not measured |
| Stream CPU (s) | 7.2 | 8.9 | 6.1 | 8.7 | 9.2 | not measured |
| App size (MB) | 1.26 | 0.99 | 1.16 | 1.01 | 1.68 | 3.08 |
| Fling fps (Instruments) | 91.0 | 82.9 | 97.9 | 87.8 | 57.3 | 68.4 |
| Fling hitch time (ms) | 1,758 | 1,150 | 1,108 | 1,800 | 3,142 | 1,733 |
| Stream hitch time (ms) | 242 | 492 | 308 | 3,533 | 3,800 | 9,983 |
| Resize hitch time (ms) | 8 | 8 | 8 | 8 | 8 | not measured |
| Checks passed (of 13) | 9 | 9 | 9 | 9 | 9 | 5 |

Shareable images (light and dark, made by `Harness/tools/results_table.py`): best AppKit against SwiftUI Opus and Sol `docs/images/results-round4-appkit-vs-swiftui.png`, and all six builds `docs/images/results-round4-all.png`.

Hitch numbers are the Instruments-derived ones; the XCTest hitch counters read 0 and are not reported.

## Too close to call

- Cold launch among the four AppKit builds and SwiftUI Opus (688 to 803 ms): one fast pass, three samples; ObjC Sol had one 5.1 s sample, so its median is shaky. Earlier trial on 27.1 read 2,749 ms on a single sample against 611 ms on 26.4, so cold launch here is noisy.
- Resize hitch: 8 ms on every build that measured it. It does not separate them.
- App size: 1.0 to 1.3 MB for all four AppKit builds (SwiftUI Opus 1.68, Sol 3.08).
- Memory and stream CPU between AppKit Swift Opus and AppKit ObjC Opus (107 vs 103 MB, 7.2 vs 6.1 s).
- Fling hitch time among AppKit Swift Sol, ObjC Opus, SwiftUI Sol (1.1 to 1.8 s) on one fling pass.
- Text-size timings among the AppKit builds (9 to 26 ms).

## What does separate them

- SwiftUI Opus: slower fling (57 fps, 3.1 s hitch), stream hitch 3.8 s, memory about twice the AppKit builds.
- SwiftUI Sol: 5 of 13 checks; stream test received only 260 of 600 messages, jump and load-older checks failed, resize trace failed, memory and stream CPU not measured. Its stream hitch (10 s) is not trustworthy given the failed run.
- AppKit ObjC Sol: stream hitch 3.5 s against 0.2 to 0.5 s for the other AppKit builds.
- AppKit ObjC Opus is fastest on the app-reported timings (first 40 rows, jump, text size).

## Checks

All four AppKit builds and SwiftUI Opus fail the same four: window-resize pinned, window-resize top row, context menu with Copy and Reply, double-click word copy. The same four fail on every build, which points at the harness (resize and clipboard/click scenarios on this Mac) as much as at the builds; the stack check (`check-stack`) is not part of the 13 here. The suite step reported a failure for ObjC Opus and SwiftUI Opus, and summarize failed for SwiftUI Opus and Sol; their summaries still hold the numbers above.

## Wall time per pass

| Build | Wall time |
|---|---|
| AppKit Swift Sol | 13 min 49 s |
| AppKit Swift Opus | 14 min 16 s |
| AppKit ObjC Opus | 13 min 41 s |
| AppKit ObjC Sol | 20 min 45 s |
| SwiftUI Mac Opus | 17 min 18 s |
| SwiftUI Mac Sol | 17 min 1 s |

About 2 h 30 min including three false starts.

## Harness changes made to get these passes

- `UVS_LAUNCH_SAMPLES` lets `--fast` take 3 cold-launch samples.
- On Xcode 27.1, `xctrace --launch` of a freshly copied app started a suspended Debug build of another lane (found by process list) and the tests then saw "not running". Each measured copy now gets its own executable name and is signed again ad hoc; the code is untouched.
- Instruments leaves a temporary `instruments*.ktrace` (0.8 to 4.2 GB each here, 6 per pass) in the user temp dir. The script now baselines the directory, logs sizes to `logs/ktrace-sizes.txt`, and with `UVS_REMOVE_KTRACE=1` (used for passes 5 and 6) removes only the files new in that run. The 90 older files were not touched. Saved traces are 70 to 660 MB each.
- Failed and partial attempts are kept as `runs/<build>/1-failed-*` and `1-killed-disk-full`.
