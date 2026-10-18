# Benchmark harness

`Harness/` is a small Xcode UI-test project (`project.yml`, generated with xcodegen, project checked in). It has no app target: it launches the app you already installed, by bundle id `campfire.bench`, with `-uvsBenchmark YES`, so neither build carries any harness code. It finds things only by what the user sees: the debug bar in `PROMPT.md` (buttons "Reset", "Jump to 2500", "Load older", "Start stream", the label "Stream done", and the state label: first id, last id, loaded count, pinned).

## Running

1. Install the finished app on one simulator (Release configuration).
2. `xcodebuild test -project Harness/CampfireBench.xcodeproj -scheme CampfireBench -destination 'platform=iOS Simulator,name=<device>' -resultBundlePath <dir>/bench.xcresult`
3. Read the numbers: `xcrun xcresulttool get test-results metrics --path <dir>/bench.xcresult`. Each test has 5 iterations; compare medians and spread.

**Rounds:** run the whole suite 3 times per build, alternating between the builds (A, B, A, B, A, B, each with a fresh simulator state), and report the median across rounds as the headline.

To only compile the harness: `xcodebuild build-for-testing ... -destination 'generic/platform=iOS Simulator'`.

## What each test measures

| Test | Scenario | Metrics |
|---|---|---|
| `testLaunch` | cold launch to the debug bar | launch, clock, memory |
| `testFling` | 40 fast swipes towards older messages, 40 back | frames per second and hitches (scroll deceleration and dragging metrics), CPU, memory, clock |
| `testJumpTo2500` | tap "Jump to 2500" until message 2,500 is loaded | clock, CPU, memory |
| `testLoadOlder` | tap "Load older" until the first id drops | clock, CPU, memory |
| `testLiveStream` | "Start stream" (20 messages a second for 30 s) until "Stream done"; must end pinned | frames per second and hitches (dragging metric), CPU, memory, clock |

Frames per second come from the system's scroll metrics ("Frame Rate"), hitches and the "Hitch Time Ratio" from the same metrics. Wall time is reported for launch, jump and load older. Every measure block starts with "Reset". Hitch numbers from the Simulator only compare two builds measured the same day, not a device.

## Fairness

Same package (`CampfireKit`), same launch argument, same simulator model and OS, same Xcode, Release configuration, nothing else running. The tests are never edited per app; if a build needs a harness change, change it for both and re-run both.

## Known limits

XCUITest only sees rows that are on screen, so the harness reads positions from the state label and does not assert on rows outside the window. Memory is `XCTMemoryMetric` (peak physical footprint).
