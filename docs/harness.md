# Benchmark harness

The harness is a folder of XCTest sources, `Harness/` (`Identifiers.swift`, `ChatBenchmarks.swift`), that either app adds to its own UI test target. It compiles against iOS 17+ XCTest and has no app dependency; it talks to the app only through accessibility identifiers, launch arguments and signposts defined in `docs/spec.md` sections 6 to 8. It cannot run until an app exists. Last check: `swiftc -typecheck` on the iOS simulator SDK, no errors.

## Using it

1. In the app's Xcode project add a UI Testing Bundle target and add `Harness/*.swift` to it (reference the folder, do not copy).
2. The app launched by the tests receives `-uvsBenchmark YES -uvsDataset 50k`, shows the debug panel and uses the 50k dataset.
3. Run release, one simulator (`simcap ensure` first), through the build slot, on the Max, never an Air (timing noise):
   `buildslot run --label "uvs: <uikit|swiftui> bench" -- xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Release -resultBundlePath <dir>/bench.xcresult`
4. Shut the simulator down afterwards. Read the numbers from the result bundle: `xcrun xcresulttool get test-results metrics --path <dir>/bench.xcresult` (or `xcresulttool export`), per test: median and spread across the 5 iterations.

## What each test measures

| Test | Scenario | Metrics |
|---|---|---|
| `testLaunchToFirstContent` | open | launch, clock, signpost `initialLoad` |
| `testFlingScrollTopToBottom` | fling scroll | scroll-deceleration and drag hitch metrics, clock, memory, CPU |
| `testJumpToOldMessage` | jump to old | clock, memory, signpost `jumpToMessage` |
| `testPrependKeepsPosition` | prepend 500 | clock, memory, signpost `prepend`; fails if the row moves more than 2 pt |
| `testLiveBurst` | live burst | CPU, memory, clock, drag metric, signpost `burstInsert`; fails if not pinned at the end |
| `testJumpToBottomButton`, `testComposerSendsMessageAtBottom` | behaviour | not measured; a build that fails these is not comparable |

Every `measure` block uses 5 iterations (`XCTMeasureOptions.iterationCount`), starts with `chat.debug.reset`, and uses `XCTOSSignpostMetric.scrollDecelerationMetric` / `scrollDraggingMetric` for hitches. Hitch numbers on the Simulator are only comparable between our two builds on the same run day, not with a device.

## Signposts the apps emit

Subsystem `dev.amazinghumans.uvs`, category `chat`, use `OSSignposter` (os framework, not a UI one):

- `initialLoad`: process start of the chat view controller / view to first page laid out.
- `jumpToMessage`: tap on the debug button to target row laid out.
- `prepend`: data arrival to position restored.
- `burstInsert`: one interval per applied batch of live messages.

## Ground rules for fairness

Same dataset code (`CampfireKit`), same launch arguments, same simulator model and OS, same Xcode, release configuration, optimisation budget equal for both stacks, nothing else running (check `buildslot status`), the tests are never edited per app. If a build needs a harness change, the change is made in `Harness/` and both builds re-run.

## Gaps to know

- Hit-testing a 50k list through XCUITest only sees realized rows, so tests find rows by identifier after the app has scrolled them in; do not assert on rows out of the window.
- `chat.debug.state` is the ground truth for position and range; cells' frames are only used for the prepend position check.
- Memory is `XCTMemoryMetric(application:)` (physical footprint peak).
