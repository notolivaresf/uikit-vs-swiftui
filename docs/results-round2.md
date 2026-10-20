# Results, Round 2 (iPhone 12, 19 to 20 Oct)

> Build names are the folder names in [`builds/`](../builds). The harness's run records in `runs/` still use the older run names; [`builds/README.md`](../builds/README.md) maps one to the other. Round 1 is the four builds without skills, Round 2 the six with skills.

Six builds of the same chat screen (Campfire), each written by an agent from PROMPT.md with a skill installed: our UIKit pair (Swift), Apple's SwiftUI skills, and our Objective-C UIKit pair, each by Opus and by Sol. Each was built for Release, installed on the iPhone 12 (iOS 26.0) and measured with the harness (`Harness/record.sh`, see `docs/harness.md`), with the benchmark settings exactly as in Round 1 (Fernando: "Keep them the same"). How the builds were made, signed and checked: `docs/results-round2-handoff.md`.

**One pass per build**, as in Round 1. Every number below is from pass 1: the median of the 3 measured iterations inside it (fling and memory: 1 iteration; cold launch: 3 fresh installs). The six passes ran one at a time from about 22:35 CST on 19 Oct to 02:30 on 20 Oct. Every Round 2 build ran on the fixed stream test, so there are no stream-only reruns. Raw data: `runs/<build>/1/summary.json` (not committed). The table was sent to Fernando one row at a time from `docs/results-round2-rows.md`.

A behaviour passes when it meets PROMPT.md's numbers: position kept within 2 pt, the list stays pinned to the bottom, the stream adds all 600 messages, first content in under 1 s, text can be selected and the context menu opens. In all six passes every harness test passed (13 of 13 in the suites); the misses below are spec numbers, not test failures.

## The six builds

![Round 2 results](images/results-round2.png)

(Dark version: `images/results-round2-dark.png`; rendered with `python3 Harness/tools/results_table.py --round2`.)

| | round2-uikit-swift-opus | round2-swiftui-opus | round2-uikit-objc-opus | round2-uikit-swift-sol | round2-swiftui-sol | round2-uikit-objc-sol |
|---|---|---|---|---|---|---|
| Model, stack, skill | Opus, UIKit (Swift), our pair | Opus, SwiftUI, Apple's skills | Opus, UIKit (Objective-C), our pair | Sol, UIKit (Swift), our pair | Sol, SwiftUI, Apple's skills | Sol, UIKit (Objective-C), our pair |
| Builds and installs | yes | yes | yes | yes | yes | yes |
| Stack rule | pass | **fail**: `RowParts.swift` imports UIKit for UIPasteboard | pass | pass | **fail**: `MessageRow.swift` imports UIKit's UIPasteboard | pass |
| First content (time to 40 rows) | pass: 252 ms cold, 256 ms repeated | pass: 326 ms cold, 329 ms repeated | pass: 158 ms cold, 242 ms repeated | pass: 196 ms cold, 305 ms repeated | pass: 314 ms cold, 408 ms repeated | pass: 198 ms cold, 299 ms repeated |
| Cold launch (Instruments) | 843 ms (1 of 3 samples) | not measured (0 of 3) | not measured (0 of 3) | 776 ms (2 of 3) | not measured (0 of 3) | 736 ms (2 of 3) |
| Fling | 58.0 fps, 2 hitches (33 ms in 51 s) | 57.9 fps, 5 hitches (150 ms in 54 s) | 58.7 fps, 2 hitches (33 ms in 52 s) | 58.2 fps, 0 hitches (49 s) | 58.0 fps, 0 hitches (41 s) | 58.3 fps, 1 hitch (50 ms in 52 s) |
| Jump to message 2500 | pass: 90 ms, drift 0.0 pt | pass: 154 ms, drift 0.0 pt | pass: 67 ms, drift 0.1 pt | pass: 77 ms, drift 0.0 pt | pass: 191 ms, drift 0.1 pt | pass: 109 ms, drift 0.0 pt |
| Load older keeps place | pass: 93 ms, drift 0.0 pt | pass: 86 ms, drift 0.2 pt | pass: 34 ms, drift 0.1 pt | pass: 75 ms, drift 0.0 pt | pass: 143 ms, drift 0.1 pt | pass: 106 ms, drift 0.0 pt |
| Live stream, 600 messages, stays pinned | pass: 600, pinned; 15.2 fps, 1 hitch (17 ms); CPU 12.2 s | pass: 600, pinned; 22.0 fps, **425 hitches (13.9 s)**; CPU 34.8 s; stream window 37.6 s against about 31 s for the others | pass: 600, pinned; 27.3 fps, 3 hitches (67 ms); CPU 11.9 s | pass: 600, pinned; 22.4 fps, 6 hitches (100 ms); CPU 12.0 s | pass: 600, pinned; 33.2 fps, **242 hitches (4.9 s)**; CPU 22.1 s | pass: 600, pinned; 37.3 fps, 9 hitches (167 ms); CPU 18.7 s |
| Text size change | pass: 83 ms at the bottom (pinned), 103 ms mid-list, drift 0.0 pt | pass: 76 / 108 ms, drift 0.1 pt | pass: 77 / 93 ms, drift 0.1 pt | pass: 53 / 70 ms, drift 0.0 pt | pass: 123 / 139 ms, drift 0.0 pt | pass: 55 / 75 ms, drift 0.0 pt |
| Rotation | pass: pinned; drift 0.0 pt at 2500, round trip 0.0 | pass, same | pass, same | pass, same | pass, same | pass, same |
| Boost burst | pass: pinned, the row grows | pass | pass | pass | pass | pass |
| Context menu | pass | pass | pass | pass | pass | pass |
| Text selection | **pass** (also on long press) | **fail** | **fail** | **fail** | **fail** | **fail** |
| Peak memory (heavy session) | 107.9 MB | 215.4 MB | 52.0 MB | 44.5 MB | 103.4 MB | 35.0 MB |
| App size (Release .app) | 0.71 MB | 1.50 MB | 0.66 MB | 0.64 MB | 1.20 MB | 2.70 MB (asset catalog, 2.1 MB) |
| Agent: wall time / turns / builds (failed) | 2231 s / 95 / 12 (0) | 4301 s / 197 / 24 (0) | 2884 s / 106 / 12 (0) | 1233 s / 90 / 14 (7) | 1209 s / 113 / 15 (8) | 1297 s / 118 / 24 (8) |
| Passes everything | **yes** | 2 fails | 1 fail | 1 fail | 2 fails | 1 fail |

Text size cells read "at the bottom / mid-list". The stream's fps counts frames drawn between the tap and "Stream done"; a build that redraws only when a message lands shows fewer frames without stuttering, so read fps together with hitches (round2-uikit-swift-opus: 15.2 fps but 1 hitch).

## What failed and why

- round2-swiftui-opus, Stack rule: still uses UIKit's UIPasteboard for Copy, with Apple's SwiftUI skills installed.
- round2-swiftui-sol, Stack rule: the same.
- Text selection: message text can't be selected in five of the six builds (only round2-uikit-swift-opus passes, also on long press).
- Not a spec number, but the clearest gap: both SwiftUI builds stutter through the stream. round2-swiftui-opus drops 425 frames (13.9 s of hitches in a 37.6 s stream that should take 31 s) and burns 34.8 s of CPU; round2-swiftui-sol drops 242 (4.9 s). The four UIKit builds stay at 1 to 9 hitches and 12 to 19 s of CPU.

## Round 1 vs Round 2

Same harness, same settings, same phone; Round 1 ran on 18 Oct, Round 2 on 19 to 20 Oct, one pass each, so differences of a few ms are noise.

| Pair | What changed |
|---|---|
| round1-uikit-swift-opus → round2-uikit-swift-opus | Text selection **fail → pass**: now passes everything, the only build in either round besides round1-uikit-swift-sol (Round 1). Slower elsewhere: first content 172 → 252 ms, jump 52 → 90 ms, load older 77 → 93 ms, text size 63/74 → 83/103 ms. Fling the same (58.5 → 58.0 fps, 2 hitches). Stream 25.7 → 15.2 fps, 1 hitch both times. Peak memory 43.9 → 107.9 MB. Agent: 2633 s / 75 turns / 22 builds → 2231 s / 95 / 12. |
| round1-uikit-swift-sol → round2-uikit-swift-sol | Text selection **pass → fail**: Round 1's only all-pass build loses selection. Otherwise close: first content 201 → 196 ms, jump 73 → 77, load older 61 → 75, text size 51/70 → 53/70, fling 58.3 → 58.2 fps (2 → 0 hitches). Stream 27.8 fps, 2 hitches → 22.4 fps, 6 hitches. Memory 39.7 → 44.5 MB. Agent: 1200 s / 102 / 15 (3) → 1233 s / 90 / 14 (7). |
| round1-swiftui-opus → round2-swiftui-opus | Stack rule still fails, selection still fails. Load older **not measurable → pass** (86 ms, drift 0.2 pt). Fling hitches 24 → 5. Stream much worse: 25 hitches (417 ms) → 425 (13.9 s), CPU 13.6 → 34.8 s. First content 174 → 326 ms, jump 85 → 154 ms. Memory 69.7 → 215.4 MB, the highest in either round. Agent time almost halved: 8070 s / 204 / 41 → 4301 s / 197 / 24. |
| round1-swiftui-sol → round2-swiftui-sol | Stream **fail → pass**: 600 of 600 now arrive in time (Round 1 showed about 450), but with 242 hitches. Memory now measurable: 103.4 MB. Stack rule and selection still fail. First content 354 → 314 ms, jump 210 → 191, load older 133 → 143, text size 97/127 → 123/139 ms. App 1.57 → 1.20 MB. Agent: 1972 s / 106 / 28 (9) → 1209 s / 113 / 15 (8). |
| round2-uikit-objc-opus (no Round 1 twin) | Against round1-uikit-swift-opus (Round 1) and round2-uikit-swift-opus: fastest first content of all ten builds (158 ms), fastest Round 2 jump (67 ms; round1-uikit-swift-opus's 52 ms in Round 1 is faster), fastest measurable load older (34 ms), best fling (58.7 fps), stream 27.3 fps with 3 hitches, memory 52.0 MB (half of round2-uikit-swift-opus). Fails selection, like round1-uikit-swift-opus. |
| round2-uikit-objc-sol (no Round 1 twin) | Against round1-uikit-swift-sol (Round 1) and round2-uikit-swift-sol: lowest memory of all ten (35.0 MB), smoothest-looking stream (37.3 fps, 9 hitches) but the most CPU of the UIKit builds (18.7 s); jump and load older slower (109 / 106 ms). Fails selection, like round2-uikit-swift-sol. Largest app (2.70 MB) only because of its icon asset catalog. |

In short: the skills fixed one failure each in three of four pairs (round1-uikit-swift-opus selection, round1-swiftui-opus load older, round1-swiftui-sol stream), broke one (round1-uikit-swift-sol selection), and left the SwiftUI stack-rule failure in place. Both SwiftUI builds still stutter in the stream and use the most memory; the Objective-C UIKit builds are the quickest to first content (Opus) and the leanest in memory (Sol) of all ten.

## Known limits

- One pass per build: no spread between passes, only within pass 1.
- Cold launch: in 13 of 18 launch traces Instruments did not finish saving within the 300 s cap (`xctrace exit 142`; several logs show "Timeline modification failed -- dylibs overlap"). Each install and the app launch itself worked: the cold time to 40 rows comes from all 3 fresh launches in every build. Cold launch (Instruments) is reported only where at least one trace saved; it is not comparable to Round 1's 3-sample medians.
- Not covered by any test: the layout matching the reference within 2 pt, and the jump-to-bottom button.
- Time numbers in ms (time to 40 rows, jump, load older, text size) are what each app reports in its own state label; the trace numbers (fps, hitches, cold launch) come from Instruments.
- Fling: round2-swiftui-sol's 20 swipes moved the list for 41 s, the others 49 to 54 s, so its hitch count covers less scrolling.
- Earlier attempts at pass 1 of round2-uikit-swift-opus (four, 18 to 19 Oct) stopped on the phone (UI automation time-out, then a full disk) and are kept in `runs/opus-uikit-ours-pair/aborted-r1-*`; none of their numbers are used.
