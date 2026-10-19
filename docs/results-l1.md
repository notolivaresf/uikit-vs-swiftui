# Results, level 1 (iPhone 12, 18 Oct)

Four builds of the same chat screen (Campfire), each written by an agent from PROMPT.md: two in UIKit, two in SwiftUI, by Opus and by Sol. Each was built for Release, installed on the iPhone 12 (iOS 26.0) and measured with the harness (`Harness/record.sh`, see `docs/harness.md`).

**One round per build.** Fernando cut rounds 2 and 3 on 18 Oct to save time. Every number below is from round 1: the median of the 3 measured iterations inside it (fling and memory: 1 iteration; cold launch: 3 fresh installs). The two Opus builds ran round 1 before the stream test was fixed (see "Known limits"), so their stream numbers come from a stream-only rerun (round 2, `record.sh --stream-only`) on the fixed harness. Raw data: `runs/<build>/<round>/summary.json` (not committed).

A behaviour passes when it meets PROMPT.md's numbers: position kept within 2 pt, the list stays pinned to the bottom, the stream adds all 600 messages, first content in under 1 s, text can be selected and the context menu opens.

## opus-uikit (Opus, UIKit)

| | |
|---|---|
| Builds and installs | yes |
| Stack rule (UIKit only) | pass |
| First content (time to 40 rows) | pass: 172 ms cold, 222 ms repeated; cold launch 596 ms |
| Fling | pass: 58.5 fps, 2 hitches (50 ms in 51 s of scrolling) |
| Jump to message 2500 | pass: 52 ms, drift 0.2 pt |
| Load older keeps place | pass: 77 ms, drift 0.3 pt |
| Live stream, 600 messages, stays pinned | pass (rerun): 600 added each time, pinned; 25.7 fps, 1 hitch (17 ms); CPU 11.8 s |
| Text size change | pass: 63 ms at the bottom (stays pinned), 74 ms mid-list, drift 0.1 pt |
| Rotation | pass: pinned at the bottom; drift 0.1 pt at 2500, round trip 0.0 |
| Boost burst | pass: stays pinned, the row grows |
| Context menu | pass |
| Text selection | **fail**: no selection, not even on long press |
| Peak memory (heavy session) | 43.9 MB |
| App size (Release .app, added 19 Oct) | 0.68 MB |
| Agent: wall time / turns / builds (failed) | 2633 s / 75 / 22 (2) |

## opus-swiftui (Opus, SwiftUI)

| | |
|---|---|
| Builds and installs | yes |
| Stack rule (SwiftUI only) | **fail**: `Campfire/Pasteboard.swift` imports UIKit for UIPasteboard |
| First content (time to 40 rows) | pass: 174 ms cold (repeated launches report 0 ms, not usable); cold launch 693 ms (2 of 3 samples) |
| Fling | pass: 57.9 fps, but 24 hitches (784 ms in 51 s) |
| Jump to message 2500 | pass: 85 ms, drift 0.1 pt |
| Load older keeps place | **not measurable**: 25 ms, but the app's state label reads `top 0` after Reset, so drift can't be read |
| Live stream, 600 messages, stays pinned | pass (rerun): 600 added each time, pinned; 22.6 fps, 25 hitches (417 ms); CPU 13.6 s |
| Text size change | pass: 35 ms at the bottom (stays pinned), 54 ms mid-list, drift 0.2 pt |
| Rotation | pass: pinned at the bottom; drift 0.2 pt at 2500, round trip 0.0 |
| Boost burst | pass: stays pinned, the row grows |
| Context menu | pass |
| Text selection | **fail** |
| Peak memory (heavy session) | 69.7 MB |
| App size (Release .app, added 19 Oct) | 1.48 MB |
| Agent: wall time / turns / builds (failed) | 8070 s / 204 / 41 (1) |

## sol-uikit (Sol, UIKit)

| | |
|---|---|
| Builds and installs | yes |
| Stack rule (UIKit only) | pass |
| First content (time to 40 rows) | pass: 201 ms cold, 272 ms repeated; cold launch 606 ms |
| Fling | pass: 58.3 fps, 2 hitches (67 ms in 52 s) |
| Jump to message 2500 | pass: 73 ms, drift 0.0 pt |
| Load older keeps place | pass: 61 ms, drift 0.0 pt |
| Live stream, 600 messages, stays pinned | pass: 600 added each time, pinned; 27.8 fps, 2 hitches (67 ms); CPU 11.7 s |
| Text size change | pass: 51 ms at the bottom (stays pinned), 70 ms mid-list, drift 0.0 pt |
| Rotation | pass: pinned at the bottom; drift 0.0 pt at 2500, round trip 0.0 |
| Boost burst | pass: stays pinned, the row grows |
| Context menu | pass |
| Text selection | pass (also on long press) |
| Peak memory (heavy session) | 39.7 MB |
| App size (Release .app, added 19 Oct) | 0.62 MB |
| Agent: wall time / turns / builds (failed) | 1200 s / 102 / 15 (3) |

## sol-swiftui (Sol, SwiftUI)

| | |
|---|---|
| Builds and installs | yes |
| Stack rule (SwiftUI only) | **fail**: `Campfire/MessageRow.swift` and `Campfire/SelectableMessageText.swift` import UIKit's UIPasteboard |
| First content (time to 40 rows) | pass: 354 ms cold, 418 ms repeated; cold launch 743 ms |
| Fling | pass: 58.3 fps, 2 hitches (100 ms in 33 s) |
| Jump to message 2500 | pass: 210 ms, drift 0.0 pt |
| Load older keeps place | pass: 133 ms, drift 0.0 pt |
| Live stream, 600 messages, stays pinned | **fail**: the stream starts and stays pinned, but the app can't keep up with 20 messages a second; 60 s after the tap only about 450 of 600 were shown, so "Stream done" never appeared in time |
| Text size change | pass: 97 ms at the bottom (stays pinned), 127 ms mid-list, drift 0.0 pt |
| Rotation | pass: pinned at the bottom; drift 0.0 pt at 2500, round trip 0.0 |
| Boost burst | pass: stays pinned, the row grows |
| Context menu | pass |
| Text selection | **fail** |
| Peak memory (heavy session) | not measured: the heavy session includes the stream, which didn't finish |
| App size (Release .app, added 19 Oct) | 1.57 MB |
| Agent: wall time / turns / builds (failed) | 1972 s / 106 / 28 (9) |

## What failed and why

- opus-uikit, text selection: message text can't be selected.
- opus-swiftui, Stack rule: uses UIKit's UIPasteboard for Copy.
- opus-swiftui, load older: the state label reports `top 0` after Reset, so position kept can't be checked (not counted as pass or fail).
- opus-swiftui, text selection: message text can't be selected.
- sol-swiftui, Stack rule: uses UIKit's UIPasteboard for Copy.
- sol-swiftui, live stream: every message re-anchors the scroll and rebuilds the 300-row window on the main thread; the phone falls behind (about 7 messages a second instead of 20). The same failure took down the stream trace and the memory test, which plays the stream.
- sol-swiftui, text selection: message text can't be selected.

## App size (added 19 Oct)

Fernando asked on 19 Oct for the app's total size. It is the size on disk of the Release iPhone `.app` bundle the rounds installed (`~/uvs-builds/dd/<build>/Build/Products/Release-iphoneos/Campfire.app`, built on 18 Oct with Xcode 26.4.1, iOS SDK 26.4, `-configuration Release -destination id=<the iPhone 12>`, signed with team H8HSTBN8ZP), measured with `du -sk` and divided by 1024, so 1 MB here is 1,048,576 bytes. It covers everything in the bundle: the executable (CampfireKit is linked into it statically), Info.plist, the signature and the provisioning profile (about 36 KB together). It is not the App Store download size (no App Thinning, no compression). The four Level 1 bundles hold nothing else (no asset catalog, no frameworks); the executable is 97% of each. Level 2 sizes, measured the same way, are in `docs/results-l2.md`.

| Build | App size | Executable |
|---|---|---|
| opus-uikit | 0.68 MB | 676,304 bytes |
| opus-swiftui | 1.48 MB | 1,518,848 bytes |
| sol-uikit | 0.62 MB | 617,104 bytes |
| sol-swiftui | 1.57 MB | 1,612,352 bytes |

## Known limits

- One round per build (rounds 2 and 3 cut, Fernando 18 Oct): no spread between rounds, only within round 1.
- Not covered by any test: the layout matching the reference within 2 pt, and the jump-to-bottom button.
- Time numbers in ms (time to 40 rows, jump, load older, text size) are what each app reports in its own state label; the trace numbers (fps, hitches, cold launch) come from Instruments.
- Harness settings for every round here: fling 10 swipes up and 10 down; the memory test is one heavy session (jump to 2500, 2 Load older, 5 swipes, Reset, the 30 s stream, 5 swipes); fling and memory 1 iteration, every other test 3 (commits 1496f22, 350740e).
- Stream test fix (98b2d48): PROMPT.md doesn't ask for the stream to play again after Reset, so the test now relaunches the app before each play, outside the measured time. opus-uikit and opus-swiftui ran round 1 before the fix: their stream test failed only on the second play (0 added), so their round 1 stream numbers are not used and round 2 is a stream-only rerun. Their round 1 trace numbers, from a first play, were close (opus-uikit 27.5 fps, 2 hitches; opus-swiftui 24.3 fps, 41 hitches). sol-uikit and sol-swiftui ran round 1 on the fixed harness.
- opus-swiftui: one of its 3 cold-launch traces (launch 2) was killed while saving at the 300 s cap, so cold launch is the median of 2. Its repeated time to 40 rows reads 0 ms.
- sol-swiftui round 1 was run twice: the first try broke because the harness script was edited while it ran (a harness fault, kept in `runs/sol-swiftui/aborted-r1-record-sh-edited-mid-run`). The second, full run is the one reported.
- Fling: sol-swiftui's 20 swipes moved the list for 33 s, the others about 51 s (its swipes travel less); fps still compares, but its hitch count covers less scrolling (2.3 ms of hitch per second against 0.9 to 13.9 for the others).
- No phone locks in the rounds reported here (an earlier attempt at 16:00 stopped on "Timed out while enabling automation mode" and was rerun after the phone was reconnected).
