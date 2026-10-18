# Benchmark harness

`Harness/` is a small Xcode UI-test project (`project.yml`, generated with xcodegen, project checked in). It has no app target: it drives the installed app, bundle id `campfire.bench`, launched with `-uvsBenchmark YES`, so neither build carries harness code. It finds things only by what the user sees, the debug bar in `PROMPT.md`: the buttons "Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst", the label "Stream done", and the state label, read by key in exactly this form:

`first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`

`top` and `y` are the topmost row on screen and its top in points under the header; `ms` is the app's own time from the last debug-bar tap (touch up) until its result is laid out, and at launch from the app's first line of code until 40 rows are on screen. Times that count come from `ms`, not from XCUITest's clock (which adds its own overhead and is kept only as an upper bound). Drift comes from `top` and `y`.

## The device we measure on

Fernando's iPhone 12 (iPhone13,2), iOS 26.0, plugged into the Max, Release build, nothing else running. The Simulator only checks that the tests compile and run; its frame times mean nothing.

Once on the phone: Developer Mode on, Settings > Developer > Enable UI Automation on. Keep it unlocked and awake during a round. Signing is automatic with team H8HSTBN8ZP; xcodebuild gets its profile through the App Store Connect key in `~/.appstoreconnect/private_keys`.

## Recording a round

`buildslot run --label "uvs: record" -- Harness/record.sh --build <name> --round <n> --app-path <Release .app>`

- It refuses a round folder that already exists (every round keeps its own number) and exits non-zero if anything failed: a test, a trace that did not record or was killed, a scenario that ran outside the traced process, or a number missing from the summary. `logs/failures.txt` says which.
- `--app-path` is the build's Release `.app`; it is installed again before each cold launch. Without it the launches run on the installed copy and `summary.json` says `freshly_installed: false`.

Steps, all in `runs/<build>/<round>/`:

1. Build the tests once (`build-for-testing`); every later step runs `test-without-building`.
2. Cold launch, 3 samples: stop the app, install it, 30 s idle, Instruments launches it (`launch.<n>.trace`, App Launch template, 25 s). 10 s in, when the launch is over, `TraceScenarios.testLaunchState` reads the app's own time to 40 rows from that same launch.
3. Scenario traces (before the suites: after them, in smoke round 6, the fling swipes did not scroll the app): Instruments launches the app (`xctrace record --launch`, so the trace covers the whole process), the script waits for its pid, a `TraceScenarios` test takes over that app with `activate()` and plays one pass; afterwards the pid must be the same and the recording still running. Light instrument sets: `fling.trace` and `stream.trace` record Hitches + Frame Lifetimes + Display (Hitches alone lists only a sample of the frames). The Allocations heap trace (`memory.trace`, about 2 GB) runs only with `--heap-trace`. When the test ends the script stops the recording with SIGINT (Ctrl-C); the time limit (240, 150, 200 s) is only a backstop, and a hard cap of limit + 300 s kills xctrace, so nothing hangs. Before every recording a do-nothing UI test wakes the phone (xctrace fails with "Timed out waiting for device to boot" when the screen is dark); a recording that still fails to start is retried 3 times, the failed attempt kept under `logs/`.
4. The suites, 5 iterations per measured test (`bench.xcresult`, `logs/suite.log`): `ChatBenchmarks` and `StressBenchmarks`.
5. `summary.json` from `Harness/summarize.py`.

Trace windows: each scenario prints `UVS_MARK start` and `UVS_MARK end` (phone wall clock); `summarize.py` lines them up with the trace's start date. Hitches and the hitch time ratio count over that whole window, so a stall can never cut itself out. Fling fps is frames per second of drawing time: frames in the window divided by the union of their frame lifetimes, so idle time between swipes does not count. If the list moved less than 20 s in the window (80 fast swipes keep it moving a minute or more), the fling fps is missing and the round fails rather than reporting a number about nothing. Stream fps is frames per second from the Start stream tap until "Stream done". The phone only draws a frame when something on screen changes, so this counts the frames the build actually put up: a build that adds each message without animation draws at most about one frame per message (20 a second), one that animates the insert or the scroll draws more. Read it with the stream's hitches and hitch time ratio, which say whether frames were late.

## The tests

| Test | Scenario | What it gives |
|---|---|---|
| `testLaunch` | repeated launch to the debug bar (not fresh, not idle) | XCUITest launch metric, a second opinion |
| `testTimeTo40Rows` | repeated launch until 40 rows | app `ms` |
| `testFling` | 40 fast swipes up the history, 40 back; measured from first swipe to last | scroll fps (dragging, deceleration), `XCTHitchMetric`, CPU |
| `testJumpTo2500` | tap Jump to 2500 | app `ms`; drift = abs(y) of row 2,500 (missing = another row is at the top) |
| `testLoadOlder` | tap Load older | app `ms`; drift of the top row |
| `testLiveStream` | Start stream until Stream done | hitches, CPU; must end pinned and add 600 messages |
| `testMemory` | fresh launch, then jump, 10 older pages, 20 swipes, reset, the stream, 20 swipes | peak physical footprint, growth from start to end |
| `testTextSizeAtBottom` | 3 x Text size + at the bottom | app `ms` per step (re-layout), still pinned, hitches |
| `testTextSizeMidScroll` | jump, then 3 x Text size + | app `ms`, drift of the top row per step, hitches |
| `testRotationAtBottom` | landscape and back at the bottom | still pinned, hitches; fails if the app did not turn |
| `testRotationAt2500` | landscape and back at 2,500 | drift per turn and round trip, hitches |
| `testBoostBurst` | Boost burst while pinned | still pinned, hitches, and whether the room moved (the newest row grew) |
| `testTextSelectionAndContextMenu` | long press, then double tap, on the newest message text | context menu (Copy and Reply), text selection (the system edit menu: Look Up, Translate, Select All...) |
| `TraceScenarios.*` | one pass each for Instruments | the trace numbers above |

Every measured block starts with Reset, and set-up stays outside `startMeasuring()`/`stopMeasuring()`. A tap waits until the label changes (the tap's own result) and then until it holds still 0.6 s; a label that never settles fails the test. A step whose label did not change in 10 s is recorded with `label_changed: false`.

## summary.json

`launch_ms` (cold Instruments launch, median of 3, and whether freshly installed), `time_to_40_rows_ms` (cold from the traced launches, repeated from XCUITest), `fling`, `jump`, `load_older`, `stream`, `text_size`, `rotation`, `boost_burst`, `text_selection_and_context_menu`, `memory_mb` (peak footprint, growth over the scenario, footprint at the end, Allocations heap from launch), plus `all_xctest_metrics`, `all_results` and `missing` (any spec number that came out empty; the round then fails).

Rounds: 3 per build, alternating A, B, A, B, A, B; the headline is the median across rounds.

## Fairness

Same package (`CampfireKit`), launch argument, phone, Xcode and Release configuration. The tests are never edited per build and look for elements by label and by any list type (table, collection or scroll view), so a SwiftUI list is found the same way as a UIKit one. If a build needs a harness change, change it for both and re-run both.

## Known limits

- `ms` is self-reported by each build; it is checked against XCUITest's clock (an upper bound) in the summary.
- Copy is not checked to really copy (reading the pasteboard from the test runner raises a paste prompt), and text selection is recognised by the system edit menu appearing.
- Boost burst can't be counted from the label; "room moved" is only a sign that the row grew.
- The XCUITest scroll metrics need UIKit's scroll signposts; a build whose scrolling emits none gets no XCUITest scroll fps (the trace fps does not depend on them).
- `XCTHitchMetric` read 0 in every smoke test, while Instruments counted hitches in the stream; trust the trace hitches.
- Status 18 Oct: smoke round 7 (`runs/smoke/7`, traces before the suites) passed with nothing missing. Fling trace: 4,280 frames, 74.6 s moving in a 95.8 s window, 57.4 fps, 1 hitch; XCUITest gave 59.1 fps decelerating and 52.0 dragging for the same swipes. Stream trace: 528 frames in 31.6 s, 16.7 fps, 10 hitches (1.0 s); the Display instrument's own tables agree (526 swaps, 526 displayed surfaces), so no frames are missing: the smoke app reloads its table once per message and stalls now and then. Smoke round 8 (`runs/smoke/8`), after the Ctrl-C fix, repeats it (fling 4,262 frames, 74.5 s moving, 57.2 fps against XCUITest's 59.0 / 49.0; stream 518 frames, 16.4 fps, 9 hitches) and both traces now end with "User pressed Stop" when the scenario ends (113 s and 48 s, not the 240 s and 150 s limits).
- Before 18 Oct, xctrace ignored Ctrl-C: `kill -INT` went to the background bash subshell around it, not to xctrace, so every trace ran to its time limit (harmless to the numbers, the windows come from the marks, but slow). Fixed in `capped_xctrace` (exec, SIGINT back to default).
- Why round 6's fling, run after the suites, did not scroll is not known: its swipes were sent (0.6 s apart, the app idle right after each, against about 2.8 s of deceleration in round 7), so the table took them without moving. It has not come back with the traces first; if it does, the 20 s guard fails the round.
- Stream fps counts content updates, not smoothness alone (see Trace windows); compare builds on stream hitches and hitch time ratio as well.
- Trace windows line up the phone clock with the trace start date; the offset is a few milliseconds against 30 s and longer windows.
- "Freshly installed" means installed again over the old copy; the app's data container is kept (the app stores nothing).

## The smoke app

`Harness/SmokeApp/` is a throwaway UIKit app (bundle id `campfire.bench`, CampfireKit, a plain table) that fulfils only the debug-bar contract, to check the harness end to end. It looks nothing like Campfire on purpose and is never a starting point for a run. Build: `xcodebuild build -project Harness/SmokeApp/SmokeApp.xcodeproj -scheme SmokeApp -configuration Release -destination id=<udid> -derivedDataPath build/SmokeDD -allowProvisioningUpdates ...`; then pass its `.app` as `--app-path`. Smoke rounds go under `runs/smoke/` (not committed: the traces are large).

## Launching a build

`Harness/launch-build.sh <opus|sol> <uikit|swiftui> [--dry-run]` sets up and starts one isolated build. `--dry-run` only prints the folders, environment and exact command line; it creates nothing and calls no model. Fernando starts the real builds.

- Folder: `~/uvs-builds/<model>-<side>` (override with `UVS_BUILDS_ROOT`), outside the workspace. A fresh git repo (`git archive` of tag `v0-inputs`, so no history and no harness in reach), branch `build/<model>-<side>`, one commit holding `.gitignore`, `LICENSE`, `PROMPT.md` (line 3, the Stack line, resolved to the chosen side), `Fixtures/`, `CampfireKit/`, `screenshots/`. No README, docs, Harness or runs. It refuses folders that already exist.
- Opus: the normal Claude config and login are kept (no `CLAUDE_CONFIG_DIR`), and isolation comes from flags: `claude -p ... --model claude-opus-5-5 --effort high --setting-sources project --strict-mcp-config --disable-slash-commands --settings '{"autoMemoryEnabled":false}' --permission-mode bypassPermissions --output-format stream-json --verbose`, run in the build folder. Project settings only (the build folder has none), no MCP servers, no skills, no auto memory. Checked in a probe (init showed `mcp_servers` [], `skills` [], `slash_commands` [], only the built-in agents, no memory); every run's `meta.json` also stores the init event's lists as `isolation_check`, so the after-run transcript check is part of the record.
- Sol: `CODEX_HOME=<empty dir>`, `codex exec -m gpt-6.1-sol -c model_reasoning_effort=high --json --dangerously-bypass-approvals-and-sandbox --ignore-rules`. Only `auth.json` is copied into the empty home; no config, memories or rules.
- Transcript: stdout is saved to `runs/<model>-<side>/transcript.jsonl` (outside the build folder), with the arrival time of each line in `transcript.times`.
- `runs/<model>-<side>/meta.json` is read from the transcript, never from the model: start, stop, wall seconds, idle gaps over 20 minutes (count, seconds), turns (Opus: assistant messages; Sol: agent messages plus commands, file changes and tool calls), builds total and failed (`xcodebuild`, `swift build`), commits, model version (Opus: reported by the session; Sol: the requested slug) and CLI version. This launch is the L1 session; L2 and L3 sessions are launched by hand from the committed result of the one before.
- No time limit. This replaces the spec's "equal time limit" stop rule (Fernando, 18 Oct): each build runs until its model says it is done, and the times are recorded and compared.

## Stack rule check (Fernando, 18 Oct)

Each build's result gets a "Stack rule" row. A SwiftUI build that uses any UIKit API, including small ones such as `UIPasteboard` for Copy, fails that row, and the failure is listed as missing functionality: the build could not do that feature in SwiftUI alone. It doesn't have to redo the work, and the rest of its tests and benchmarks still run and are reported. Check with `git grep -nE 'UIKit|UIViewRepresentable|UIViewControllerRepresentable|UIHostingController' -- '*.swift'`, outside `CampfireKit/`. Status at the end of L1: opus-swiftui (`Campfire/Pasteboard.swift`) and sol-swiftui (`Campfire/MessageRow.swift`, `Campfire/SelectableMessageText.swift`) both fail it, because they import `UIKit.UIPasteboard` for Copy.
