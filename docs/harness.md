# Benchmark harness

`Harness/` is a small Xcode UI-test project (`project.yml`, generated with xcodegen, project checked in). It has no app target: it launches the app you already installed, by bundle id `campfire.bench`, with `-uvsBenchmark YES`, so neither build carries any harness code. It finds things only by what the user sees: the debug bar in `PROMPT.md` (buttons "Reset", "Jump to 2500", "Load older", "Start stream", the label "Stream done", and the state label: first id, last id, loaded count, pinned).

## The device we measure on

Numbers that count are recorded on Fernando's iPhone 12 (iPhone13,2), iOS 26.0, plugged into the Max, Release build, nothing else running. The Simulator is only for checking that the tests work; its frame times mean nothing. iOS 26 is why `XCTHitchMetric` is back next to the scroll metrics (guarded with `#available(iOS 26, *)`).

Setup on the phone, once: Developer Mode on, and Settings > Developer > Enable UI Automation on (without it the test runner stops with "Timed out while enabling automation mode"). Keep the phone unlocked and awake while a round runs. Signing is automatic with team H8HSTBN8ZP (Amazing Humans); the phone's UDID is registered in the developer account and xcodebuild gets its profile through the App Store Connect key in `~/.appstoreconnect/private_keys`.

## Recording a round on the device

`buildslot run --label "uvs: record" -- Harness/record.sh --build <name> --round <n>` (the phone is on the Max, so no `remote-build`). The app must already be installed on the phone (Release, bundle id `campfire.bench`). It fills `runs/<build>/<round>/`:

- `bench.xcresult`: the whole XCUITest suite, 5 iterations per test.
- `launch.trace`: Instruments "App Launch", started by Instruments itself.
- `fling.trace`, `stream.trace`: Instruments "Animation Hitches" while one pass of the fling or the live stream plays (test class `TraceScenarios`: launch, 25 s to attach, scenario).
- `memory.trace`: Instruments "Allocations" while rows are loaded (jump, ten older pages, a fling).
- `summary.json`: the numbers below, from `Harness/summarize.py`; `logs/` holds the raw logs.

Why attach instead of launching under Instruments: the taps come from XCUITest, which starts the app itself, so the script finds the app's process id with `devicectl` during the 25 s wait and attaches `xctrace` to that id. Cold launch needs no taps, so Instruments starts the app (`--launch`).

### What is in summary.json

| Field | Meaning |
|---|---|
| `launch_ms` | Instruments: from process creation until the first frame is drawn (start of "Foreground - Active"). Also the XCUITest launch metric. |
| `time_to_40_rows_ms` | Cold launch until the state label says 40 or more rows are loaded. |
| `fling` / `stream` | frames per second, number of hitches, total hitch time and hitch time ratio (milliseconds of hitching per second of animation; lower is better). From Instruments, and the XCUITest scroll and hitch metrics next to them. |
| `jump_ms` | Tap "Jump to 2500" until message 2,500 is loaded. |
| `load_older_ms` | Tap "Load older" until the first id drops. |
| `peak_memory_mb` | Peak physical footprint from XCUITest, per test; and from Allocations the live heap at the end of the trace. |

## The smoke app

`Harness/SmokeApp/` is a throwaway UIKit app (bundle id `campfire.bench`, uses CampfireKit, a plain table with default cells) that fulfils only the debug-bar contract in `PROMPT.md`. It exists only to check that the harness works end to end. It looks nothing like Campfire on purpose, so no build gets a head start from it, and it is never a starting point for a run.

Install it for a check: build with `xcodebuild build -project Harness/SmokeApp/SmokeApp.xcodeproj -scheme SmokeApp -configuration Release -destination id=<udid> -allowProvisioningUpdates ...`, then `xcrun devicectl device install app --device <id> <SmokeApp.app>`.

1. Install the finished app on one simulator (Release configuration).
2. `xcodebuild test -project Harness/CampfireBench.xcodeproj -scheme CampfireBench -destination 'platform=iOS Simulator,name=<device>' -resultBundlePath <dir>/bench.xcresult`
3. Read the numbers: `xcrun xcresulttool get test-results metrics --path <dir>/bench.xcresult`. Each test has 5 iterations; compare medians and spread.

**Rounds:** run the whole suite 3 times per build, alternating between the builds (A, B, A, B, A, B, each with a fresh simulator state), and report the median across rounds as the headline.

To only compile the harness: `xcodebuild build-for-testing ... -destination 'generic/platform=iOS Simulator'`.

## What each test measures

| Test | Scenario | Metrics |
|---|---|---|
| `testLaunch` | cold launch to the debug bar | launch, clock, memory |
| `testTimeTo40Rows` | cold launch until 40 rows are loaded | clock |
| `testFling` | 40 fast swipes towards older messages, 40 back | frames per second and hitches (scroll deceleration and dragging metrics, plus `XCTHitchMetric` on iOS 26), CPU, memory, clock |
| `testJumpTo2500` | tap "Jump to 2500" until message 2,500 is loaded | clock, CPU, memory |
| `testLoadOlder` | tap "Load older" until the first id drops | clock, CPU, memory |
| `testLiveStream` | "Start stream" (20 messages a second for 30 s) until "Stream done"; must end pinned | frames per second and hitches (dragging metric and `XCTHitchMetric`), CPU, memory, clock |

Frames per second come from the system's scroll metrics ("Frame Rate"), hitches and the "Hitch Time Ratio" from the same metrics. Wall time is reported for launch, jump and load older. Every measure block starts with "Reset". Hitch numbers from the Simulator are not used; only the device counts.

## Fairness

Same package (`CampfireKit`), same launch argument, same simulator model and OS, same Xcode, Release configuration, nothing else running. The tests are never edited per app; if a build needs a harness change, change it for both and re-run both.

## Known limits

XCUITest only sees rows that are on screen, so the harness reads positions from the state label and does not assert on rows outside the window. Memory is `XCTMemoryMetric` (peak physical footprint).
