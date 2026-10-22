# Round 4: the same room as a Mac app

Fernando, 21 Oct: "for round 4, let's do AppKit. Same concept: rebuild the screen. For this round no skills, just plain AppKit. Figure out a plan with similar measurements, a way to measure them, and pass this to the agents. 4 runs for UIKit (objc and swift), 2 runs for SwiftUI."

So Round 4 is six Mac builds of the same Campfire room, with no skills loaded:

| Build | Stack | Model |
|---|---|---|
| round4-appkit-swift-opus | AppKit, Swift | Opus 5.5, effort high |
| round4-appkit-swift-sol | AppKit, Swift | Sol (gpt-6.1-sol), effort high |
| round4-appkit-objc-opus | AppKit, Objective-C | Opus 5.5, effort high |
| round4-appkit-objc-sol | AppKit, Objective-C | Sol, effort high |
| round4-swiftui-mac-opus | SwiftUI for Mac | Opus 5.5, effort high |
| round4-swiftui-mac-sol | SwiftUI for Mac | Sol, effort high |

"UIKit" in the request means the Apple-native view framework, which on the Mac is AppKit.

## What the agents get

- The prompt: [`PROMPT-mac.md`](../PROMPT-mac.md), with line 3 set to the build's stack. The filled-in copies are [`prompts/round4-appkit-swift.md`](../prompts/round4-appkit-swift.md), [`prompts/round4-appkit-objc.md`](../prompts/round4-appkit-objc.md) and [`prompts/round4-swiftui-mac.md`](../prompts/round4-swiftui-mac.md). It is the Round 1 prompt, worded for one Mac window instead of a phone. It says what to build and the numbers to hit, and names nothing but the stack (Fernando, 20 Oct).
- The same inputs as before: `Fixtures/`, `CampfireKit/` (its package already supports macOS 14, and both CampfireKit and the Objective-C wrapper build for the Mac), `screenshots/`. They come from the tag `v4-inputs`.
- No skills. Claude runs with bundled skills off and must report an empty skill list at start (the Level 2 "none" setup). Codex gets an empty home with its system skills and every host skill turned off.
- The same opening sentence as every round: "Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions."

What changed from the phone prompt, and why:

| Phone | Mac | Why |
|---|---|---|
| iPhone app, iOS 18 | Mac app, macOS 15, one window, signs to run locally | the target |
| screen | window content 393 × 852 pt at launch, centred, no restored size | the screenshots and `constants.json` were measured at that size, so they carry over 1:1 |
| Dynamic Type | the app's own text size, at least 4 steps above the default | the Mac has no system text size that apps follow, so "Text size +" drives it |
| portrait and landscape | window resizes 393 to 1,200+ wide, 600 to 1,200+ tall; rows re-wrap | resize is the Mac's rotation |
| long-press | right-click for Copy and Reply; double-click or drag selects, Command-C copies | Mac input |
| tap (touch up) | click (mouse up) | Mac input |
| | debug bar visible to accessibility with its exact text | the tests find it the way they do on the phone |

## The measurements, and how each one is taken

Everything is measured from outside the app: Instruments, XCUITest, and the app's state label (which the agent writes, but which only reports positions and its own timing, as in Rounds 1 to 3). No frame timing inside the app.

All passes run on this Mac (MacBook Pro M1 Max, 64 GB, macOS 27), one at a time, through the build queue. The window is 393 × 852 at the start of every test.

| Measure | Phone (Rounds 1-3) | Mac (Round 4) | How |
|---|---|---|---|
| Cold launch | App Launch trace, process start to "Foreground - Active" | App Launch trace, process start to the end of the app's last "Launching" period (macOS has no "Foreground - Active" period) | `xctrace record --template "App Launch" --launch <fresh copy of the .app>`, 3 samples |
| First 40 rows, cold | the app's own `ms` after that launch | same | `MacTraceScenarios.testLaunchState` reads the label of the traced launch |
| First 40 rows, repeated | the app's `ms`, 3 launches | same | `MacChatBenchmarks.testTimeTo40Rows` |
| Fling | 10 fast swipes up, 10 down; fps and hitches from a Hitches + Frame Lifetimes + Display trace | 10 fast scroll-wheel flings towards older messages, 10 back; same trace and same numbers | `MacTraceScenarios.testTraceFling` under xctrace; XCUITest scroll events (see "Limits") |
| Jump to message 2,500 | the app's `ms` and `|y|` | same | `MacChatBenchmarks.testJumpTo2500` |
| Load older | the app's `ms`, drift of the top row | same | `MacChatBenchmarks.testLoadOlder` |
| Live stream, 600 messages | hitches (trace), CPU (XCTest), still pinned, 600 added | same | `MacTraceScenarios.testTraceStream` under xctrace; `MacChatBenchmarks.testLiveStream` |
| Text size | 3 steps of "Text size +" at the bottom (pinned) and at 2,500 (drift) | same, through the app's own control | `MacStressBenchmarks.testTextSize*` |
| Rotation | landscape and back, pinned and drift | window resize: the bottom-right corner dragged from 393 to 852 pt wide and back, at the bottom (pinned) and at 2,500 (drift); plus a resize trace for hitches | `MacStressBenchmarks.testResize*`, `MacTraceScenarios.testTraceResize` |
| Boost burst | still pinned, the room moved | same | `MacStressBenchmarks.testBoostBurst` |
| Peak memory | XCTest peak physical footprint over the heavy scenario | same | `MacChatBenchmarks.testMemory` |
| App size | | the .app bundle on disk, in MB | `summarize.py --mac --app` |

Cold, on the Mac, means the first launch of a freshly copied app after 30 s of idle. The disk cache is not purged (that needs an administrator password), so a fresh copy is the closest honest stand-in for the phone's "freshly installed".

### The 13 checks on the Mac

| Check | Carries over? | On the Mac |
|---|---|---|
| Stack rule | changed | see below |
| First content within 1 s | yes | |
| Jump drift within 2 pt | yes | |
| Load older drift within 2 pt | yes | |
| Stream: all 600 arrive | yes | |
| Stream: stays pinned | yes | |
| Text size keeps pinned | changed | the app's own text size |
| Text size keeps the top row | changed | the app's own text size |
| Rotation keeps pinned | replaced | window resize keeps pinned |
| Rotation keeps the top row | replaced | window resize keeps the top row (wide, back, and the round trip) |
| Boost burst stays pinned | yes | |
| Context menu | changed | right-click shows Copy and Reply, and Copy really puts the message text on the clipboard |
| Text selection | changed, stricter | double-click a word and press Command-C: the word (not the sentinel the test put there) lands on the clipboard |

On the phone, Copy could not be checked because reading the clipboard raises a paste prompt. On the Mac the test runner reads the general pasteboard directly: it writes a sentinel first, so only the app can change it.

### The stack rule, and how it is checked

`Harness/check-stack.sh <stack> <build folder> <built .app>` looks at the source and at the built app:

- AppKit, Swift: no `import SwiftUI`, no hosting of SwiftUI views. The binary has no symbol bound to SwiftUI (`nm -m`).
- AppKit, Objective-C: no .swift files in the app, no SwiftUI, CampfireKit unmodified. The binary has no symbol bound to SwiftUI.
- SwiftUI for Mac: no AppKit import, no wrapped or hosted AppKit views, no reaching into AppKit's windows, views, events, menus or the app object. The binary has no symbol bound to AppKit except the plain data types SwiftUI itself hands over (images, colours, fonts, the pasteboard), the same allowance UIImage and the pasteboard had on the phone.

The binary check was calibrated on 21 Oct: a pure SwiftUI test app has 0 AppKit symbols, the AppKit stand-in has 20 AppKit symbols and 0 SwiftUI ones.

## Who runs what, where

- Builds: the agents, in `~/uvs-builds/round4-<stack>-<model>`, started by `Harness/launch-build.sh` in a clean environment (below). The agents build and run their app on this Mac.
- Passes: `Harness/record.sh --mac` (it hands over to `Harness/record-mac.sh`), through `buildslot run --label "UvS R4: …"`, one build at a time, after all six builds are done. 3 rounds per build, as in Round 1.
- Scorecard: `Harness/scorecard.py --summary runs/<build>/<round>/summary.json --stack-rule ok|FAIL` (no `--best`: there are no earlier Mac numbers).

### What the passes need from the Mac

A Mac UI test drives the real mouse and keyboard and needs a window on a real screen. Measured on 21 Oct: with the screen locked, the test runner stops with "Timed out while enabling automation mode", and Instruments records no frames and leaves the launch period open. So each pass needs:

1. a logged-in session with the screen unlocked and the display awake, nobody using the mouse or keyboard for the pass (about 30 to 45 min per round, 18 rounds);
2. Automation Mode on, once, by an administrator: `automationmodetool enable-automationmode-without-authentication` (it asks for the password).

The throwaway test guest (`testvm`) proves the pipeline but is not where numbers come from: 2 virtual cores and a software display would measure the guest, not the build.

## Limits, said plainly

- XCUITest's scroll is a single scroll event per call, without the trackpad's momentum phase. Every build gets the same events, so the fling compares builds fairly, but it is not a finger-fling.
- The window resize is a mouse drag of the corner, so it is a live resize with intermediate sizes; the readings are taken after the drag ends.
- Cold launch keeps the disk cache (no purge without an administrator).
- The Mac numbers are not comparable to the phone's; only the six Mac builds compare with each other.

## Review (Codex, 21 Oct) and what we changed

A read-only Codex review of the plan, prompts and harness raised 15 points. Taken:

- The resize checks now fail if the window did not really resize (the drag must reach 852 pt and come back to 393 pt, within 20 pt).
- Copy from the menu must give the message's own text; the double-click copy must be one word from that message.
- The Mac checks need every reading within 2 pt (the worst one, not the median), the text-size label to change at every step, and the boosts to have moved the room.
- A launch whose last "Launching" period never closed gives no number, even if an earlier period closed.
- The stack check needs the built app for Round 4, reads every executable file inside it, refuses run-time lookups of classes or libraries in the SwiftUI arm, refuses Objective-C files in the Swift arm, and checks CampfireKit is unchanged in all three.
- The fling trace's "the list really moved" guard is 1 s on the Mac (5 s on the phone), because wheel events without momentum move the list for less time. To be checked on the first real pass.

Decided not to change, and why:

- The prompt names the CampfireKit data types (`FakeData`, `Windowing`, `Grouping`, `FakeLiveFeed`, `Placeholder`). They are the inputs we hand over, not techniques, and every round so far named them; removing them would make Round 4 a different task from Rounds 1 to 3.
- The state label is reported by the app itself, the stream and load-older checks read counters, the unpinned branches of stream and boosts are not driven, and text size is driven for 3 steps although the prompt asks for 4 or more. All of this is the same as on the phone, so the six Mac builds stay comparable with each other and with how the phone rounds were judged. Listed here as known limits.
- The tests find the room as the largest list or scroll area and the message text as accessible text, as on the phone. A build whose text is invisible to accessibility fails the copy checks; the prompt already says the debug bar must be accessible, and standard text is.

## Order and time

Run the builds one at a time, alternating models and stacks so a slow evening doesn't land on one stack:

1. round4-appkit-swift-sol
2. round4-appkit-swift-opus
3. round4-appkit-objc-sol
4. round4-appkit-objc-opus
5. round4-swiftui-mac-sol
6. round4-swiftui-mac-opus

Past builds took 20 min (Sol, UIKit) to 2 h 15 min (Opus, SwiftUI): Sol 20 to 35 min, Opus 40 min to 2 h 15 min. Six builds: about 5 to 8 hours one after another. Builds by different models can run side by side (they only share the Mac's build queue), which brings it to about 3 to 4 hours. Then the passes: about 30 to 45 min per round, 3 rounds per build, about 9 to 14 hours of Mac time.
