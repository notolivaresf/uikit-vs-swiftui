# Benchmark harness

`Harness/` is a small Xcode UI-test project (`project.yml`, generated with xcodegen, project checked in). It has no app target: it drives the installed app, bundle id `campfire.bench`, launched with `-uvsBenchmark YES`, so neither build carries harness code. It finds things only by what the user sees, the debug bar in `PROMPT.md`: the buttons "Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst", the label "Stream done", and the state label, read by key in exactly this form:

`first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`

`top` and `y` are the topmost row on screen and its top in points under the header; `ms` is the app's own time from the last debug-bar tap (touch up) until its result is laid out, and at launch from the app's first line of code until 40 rows are on screen. Times that count come from `ms`, not from XCUITest's clock (which adds its own overhead and is kept only as an upper bound). Drift comes from `top` and `y`.

## The device we measure on

Fernando's iPhone 12 (iPhone13,2), iOS 26.0, plugged into the Max, Release build, nothing else running. The Simulator only checks that the tests compile and run; its frame times mean nothing.

Once on the phone: Developer Mode on, Settings > Developer > Enable UI Automation on. Keep it unlocked and awake during a pass. Signing is automatic with team H8HSTBN8ZP; xcodebuild gets its profile through the App Store Connect key in `~/.appstoreconnect/private_keys`.

## Recording a pass

`buildslot run --label "uvs: record" -- Harness/record.sh --build <name> --round <n> --app-path <Release .app>`

- It refuses a pass folder that already exists (every pass keeps its own number) and exits non-zero if anything failed: a test, a trace that did not record or was killed, a scenario that ran outside the traced process, or a number missing from the summary. `logs/failures.txt` says which.
- `--app-path` is the build's Release `.app`; it is installed again before each cold launch. Without it the launches run on the installed copy and `summary.json` says `freshly_installed: false`.
- `--stream-only` installs the app once and runs only the stream trace and `ChatBenchmarks/testLiveStream` (no launches, fling trace or other tests); most of `summary.json` is then missing on purpose. It exists for the Round 1 stream reruns of opus-uikit and opus-swiftui, whose pass 1 ran the stream test before the relaunch fix (Fernando cut passes 2 and 3, 18 Oct).

Steps, all in `runs/<build>/<round>/`:

1. Build the tests once (`build-for-testing`); every later step runs `test-without-building`.
2. Cold launch, 3 samples: stop the app, install it, 30 s idle, Instruments launches it (`launch.<n>.trace`, 25 s; since 21 Oct only the dyld Activity instrument, see "Cold-launch traces that never saved" below). 10 s in, when the launch is over, `TraceScenarios.testLaunchState` reads the app's own time to 40 rows from that same launch.
3. Scenario traces (before the suites: after them, in smoke pass 6, the fling swipes did not scroll the app): Instruments launches the app (`xctrace record --launch`, so the trace covers the whole process), the script waits for its pid, a `TraceScenarios` test takes over that app with `activate()` and plays one pass; afterwards the pid must be the same and the recording still running. Light instrument sets: `fling.trace` and `stream.trace` record Hitches + Frame Lifetimes + Display (Hitches alone lists only a sample of the frames). The Allocations heap trace (`memory.trace`, about 2 GB) runs only with `--heap-trace`. When the test ends the script stops the recording with SIGINT (Ctrl-C); the time limit (240, 150, 200 s) is only a backstop, and a hard cap of limit + 300 s kills xctrace, so nothing hangs. Before every recording a do-nothing UI test wakes the phone (xctrace fails with "Timed out waiting for device to boot" when the screen is dark); a recording that still fails to start is retried 3 times, the failed attempt kept under `logs/`.
4. The suites (`bench.xcresult`, `logs/suite.log`): `ChatBenchmarks` and `StressBenchmarks`, 3 iterations per measured test, except `testFling` and `testMemory`, which run 1 (plus the warm-up XCTest always adds). Fernando, 18 Oct, "a representative heavy session": a pass of about 1 h was too long; in smoke pass 8, at 5 iterations, 40 + 40 fling swipes and a memory pass of 10 older pages and 20 + 20 swipes, `testMemory` took 19 min and `testFling` 12 min, and the fling and stream traces already measure frames and hitches. Same for every build; in effect from the first Round 1 pass (no Round 1 pass ran under the old counts).
5. `summary.json` from `Harness/summarize.py`.

Trace windows: each scenario prints `UVS_MARK start` and `UVS_MARK end` (phone wall clock); `summarize.py` lines them up with the trace's start date. Hitches and the hitch time ratio count over that whole window, so a stall can never cut itself out. Fling fps is frames per second of drawing time: frames in the window divided by the union of their frame lifetimes, so idle time between swipes does not count. If the list moved less than 5 s in the window, the fling fps is missing and the pass fails rather than reporting a number about nothing. The 20 swipes (10 up, 10 down) are expected to keep it moving about 19 s: smoke passes 7 and 8 moved 74.5 s for 80 swipes, about 0.93 s a swipe; a list that does not scroll moves close to 0. Before 18 Oct the scenario had 80 swipes and the guard was 20 s. The moving time each build's 20 swipes really gave is in `docs/results-round1.md`. Stream fps is frames per second from the Start stream tap until "Stream done". The phone only draws a frame when something on screen changes, so this counts the frames the build actually put up: a build that adds each message without animation draws at most about one frame per message (20 a second), one that animates the insert or the scroll draws more. Read it with the stream's hitches and hitch time ratio, which say whether frames were late.

## The tests

| Test | Scenario | What it gives |
|---|---|---|
| `testLaunch` | repeated launch to the debug bar (not fresh, not idle) | XCUITest launch metric, a second opinion |
| `testTimeTo40Rows` | repeated launch until 40 rows | app `ms` |
| `testFling` | 10 fast swipes up the history, 10 back (same in the fling trace); measured from first swipe to last; 1 iteration | scroll fps (dragging, deceleration), `XCTHitchMetric`, CPU |
| `testJumpTo2500` | tap Jump to 2500 | app `ms`; drift = abs(y) of row 2,500 (missing = another row is at the top) |
| `testLoadOlder` | tap Load older | app `ms`; drift of the top row |
| `testLiveStream` | fresh launch (outside the measuring), then Start stream until Stream done; the stream plays once per launch, as PROMPT.md does not require a replay after Reset | hitches, CPU; must end pinned and add 600 messages |
| `testMemory` | fresh launch, then jump to 2500, 2 older pages, 5 swipes down, reset, the 30 s stream, 5 swipes down (same in the memory trace); 1 iteration | peak physical footprint, growth from start to end |
| `testTextSizeAtBottom` | 3 x Text size + at the bottom | app `ms` per step (re-layout), still pinned, hitches |
| `testTextSizeMidScroll` | jump, then 3 x Text size + | app `ms`, drift of the top row per step, hitches |
| `testRotationAtBottom` | landscape and back at the bottom | still pinned, hitches; fails if the app did not turn |
| `testRotationAt2500` | landscape and back at 2,500 | drift per turn and round trip, hitches |
| `testBoostBurst` | Boost burst while pinned | still pinned, hitches, and whether the room moved (the newest row grew) |
| `testTextSelectionAndContextMenu` | long press, then double tap, on the newest message text | context menu (Copy and Reply), text selection (the system edit menu: Look Up, Translate, Select All...) |
| `TraceScenarios.*` | one pass each for Instruments | the trace numbers above |

Every measured block starts with Reset, and set-up stays outside `startMeasuring()`/`stopMeasuring()`. A tap waits until the label changes (the tap's own result) and then until it holds still 0.6 s; a label that never settles fails the test. A step whose label did not change in 10 s is recorded with `label_changed: false`.

## summary.json

`launch_ms` (cold Instruments launch, median of 3, and whether freshly installed), `time_to_40_rows_ms` (cold from the traced launches, repeated from XCUITest), `fling`, `jump`, `load_older`, `stream`, `text_size`, `rotation`, `boost_burst`, `text_selection_and_context_menu`, `memory_mb` (peak footprint, growth over the scenario, footprint at the end, Allocations heap from launch), plus `all_xctest_metrics`, `all_results` and `missing` (any spec number that came out empty; the pass then fails).

Passes: 3 per build, alternating A, B, A, B, A, B; the headline is the median across passes.

## Fairness

Same package (`CampfireKit`), launch argument, phone, Xcode and Release configuration. The tests are never edited per build and look for elements by label and by any list type (table, collection or scroll view), so a SwiftUI list is found the same way as a UIKit one. If a build needs a harness change, change it for both and re-run both.

## Known limits

- `ms` is self-reported by each build; it is checked against XCUITest's clock (an upper bound) in the summary.
- Copy is not checked to really copy (reading the pasteboard from the test runner raises a paste prompt), and text selection is recognised by the system edit menu appearing.
- Boost burst can't be counted from the label; "room moved" is only a sign that the row grew.
- The XCUITest scroll metrics need UIKit's scroll signposts; a build whose scrolling emits none gets no XCUITest scroll fps (the trace fps does not depend on them).
- `XCTHitchMetric` read 0 in every smoke test, while Instruments counted hitches in the stream; trust the trace hitches.
- Status 18 Oct: smoke pass 7 (`runs/smoke/7`, traces before the suites) passed with nothing missing. Fling trace: 4,280 frames, 74.6 s moving in a 95.8 s window, 57.4 fps, 1 hitch; XCUITest gave 59.1 fps decelerating and 52.0 dragging for the same swipes. Stream trace: 528 frames in 31.6 s, 16.7 fps, 10 hitches (1.0 s); the Display instrument's own tables agree (526 swaps, 526 displayed surfaces), so no frames are missing: the smoke app reloads its table once per message and stalls now and then. Smoke pass 8 (`runs/smoke/8`), after the Ctrl-C fix, repeats it (fling 4,262 frames, 74.5 s moving, 57.2 fps against XCUITest's 59.0 / 49.0; stream 518 frames, 16.4 fps, 9 hitches) and both traces now end with "User pressed Stop" when the scenario ends (113 s and 48 s, not the 240 s and 150 s limits).
- Before 18 Oct, xctrace ignored Ctrl-C: `kill -INT` went to the background bash subshell around it, not to xctrace, so every trace ran to its time limit (harmless to the numbers, the windows come from the marks, but slow). Fixed in `capped_xctrace` (exec, SIGINT back to default).
- Smoke passes 7 and 8 ran the old counts (5 iterations, 40 + 40 fling swipes, 20 s guard); their numbers are not comparable one to one with the Round 1 passes.
- Why pass 6's fling, run after the suites, did not scroll is not known: its swipes were sent (0.6 s apart, the app idle right after each, against about 2.8 s of deceleration in pass 7), so the table took them without moving. It has not come back with the traces first; if it does, the moving-time guard (now 5 s) fails the pass.
- Stream fps counts content updates, not smoothness alone (see Trace windows); compare builds on stream hitches and hitch time ratio as well.
- Trace windows line up the phone clock with the trace start date; the offset is a few milliseconds against 30 s and longer windows.
- "Freshly installed" means installed again over the old copy; the app's data container is kept (the app stores nothing).

## The smoke app

`Harness/SmokeApp/` is a throwaway UIKit app (bundle id `campfire.bench`, CampfireKit, a plain table) that fulfils only the debug-bar contract, to check the harness end to end. It looks nothing like Campfire on purpose and is never a starting point for a run. Build: `xcodebuild build -project Harness/SmokeApp/SmokeApp.xcodeproj -scheme SmokeApp -configuration Release -destination id=<udid> -derivedDataPath build/SmokeDD -allowProvisioningUpdates ...`; then pass its `.app` as `--app-path`. Smoke passes go under `runs/smoke/` (not committed: the traces are large).

## Launching a build

`Harness/launch-build.sh <opus|sol> <uikit|swiftui> [--dry-run]` sets up and starts one isolated build. `--dry-run` only prints the folders, environment and exact command line; it creates nothing and calls no model. Fernando starts the real builds.

- Folder: `~/uvs-builds/<model>-<side>` (override with `UVS_BUILDS_ROOT`), outside the workspace. A fresh git repo (`git archive` of tag `v0-inputs`, so no history and no harness in reach), branch `build/<model>-<side>`, one commit holding `.gitignore`, `LICENSE`, `PROMPT.md` (line 3, the Stack line, resolved to the chosen side), `Fixtures/`, `CampfireKit/`, `screenshots/`. No README, docs, Harness or runs. It refuses folders that already exist.
- Opus: the normal Claude config and login are kept (no `CLAUDE_CONFIG_DIR`), and isolation comes from flags: `claude -p ... --model claude-opus-5-5 --effort high --setting-sources project --strict-mcp-config --disable-slash-commands --settings '{"autoMemoryEnabled":false}' --permission-mode bypassPermissions --output-format stream-json --verbose`, run in the build folder. Project settings only (the build folder has none), no MCP servers, no skills, no auto memory. Checked in a probe (init showed `mcp_servers` [], `skills` [], `slash_commands` [], only the built-in agents, no memory); every run's `meta.json` also stores the init event's lists as `isolation_check`, so the after-run transcript check is part of the record.
- Sol: `CODEX_HOME=<empty dir>`, `codex exec -m gpt-6.1-sol -c model_reasoning_effort=high --json --dangerously-bypass-approvals-and-sandbox --ignore-rules`. Only `auth.json` is copied into the empty home; no config, memories or rules.
- Transcript: stdout is saved to `runs/<model>-<side>/transcript.jsonl` (outside the build folder), with the arrival time of each line in `transcript.times`.
- `runs/<model>-<side>/meta.json` is read from the transcript, never from the model: start, stop, wall seconds, idle gaps over 20 minutes (count, seconds), turns (Opus: assistant messages; Sol: agent messages plus commands, file changes and tool calls), builds total and failed (`xcodebuild`, `swift build`), commits, model version (Opus: reported by the session; Sol: the requested slug) and CLI version. This launch is the Round 1 session; Round 2 and L3 sessions are launched by hand from the committed result of the one before.
- No time limit. This replaces the spec's "equal time limit" stop rule (Fernando, 18 Oct): each build runs until its model says it is done, and the times are recorded and compared.

## Stack rule check (Fernando, 18 Oct)

Each build's result gets a "Stack rule" row. A SwiftUI build that uses any UIKit API, including small ones such as `UIPasteboard` for Copy, fails that row, and the failure is listed as missing functionality: the build could not do that feature in SwiftUI alone. It doesn't have to redo the work, and the rest of its tests and benchmarks still run and are reported. Check with `git grep -nE 'UIKit|UIViewRepresentable|UIViewControllerRepresentable|UIHostingController' -- '*.swift'`, outside `CampfireKit/`. Status at the end of Round 1: opus-swiftui (`Campfire/Pasteboard.swift`) and sol-swiftui (`Campfire/MessageRow.swift`, `Campfire/SelectableMessageText.swift`) both fail it, because they import `UIKit.UIPasteboard` for Copy.

## Round 2: skills and Objective-C (19 Oct)

Round 2 builds (Fernando, 19 Oct, line-up changed the same day), each run for Opus and Sol, one at a time, built from a fresh clone as in Round 1. Six builds:

| Kind | Stack | Skills installed | Build names |
|---|---|---|---|
| Swift UIKit + our UIKit pair | uikit | `uikit-specialist`, `uikit-whats-new-27` (vendored in `skills/uikit/`, tag `v0.3-pair` of uikit-skill) | `opus-uikit-ours-pair`, `sol-uikit-ours-pair` |
| SwiftUI + Apple's Xcode 27 pair | swiftui | `swiftui-specialist`, `swiftui-whats-new-27` (not vendored) | `opus-swiftui-apple`, `sol-swiftui-apple` |
| Objective-C UIKit + our Objective-C pair | objc | `uikit-specialist-objc`, `uikit-whats-new-27-objc` (to be vendored in `skills/uikit-objc/`; refuses to run until then) | `opus-objc-ours-objc-pair`, `sol-objc-ours-objc-pair` |

Run order, one at a time (Fernando starts them):

```
Harness/launch-build.sh opus uikit --skills ours-pair
Harness/launch-build.sh sol uikit --skills ours-pair
Harness/launch-build.sh opus swiftui --skills apple
Harness/launch-build.sh sol swiftui --skills apple
Harness/launch-build.sh opus objc --skills ours-objc-pair
Harness/launch-build.sh sol objc --skills ours-objc-pair
```

Add `--dry-run` to any of them to print what it would do. Where the skills come from, with hashes: `skills/README.md`. The older kinds `ours-slim`, `ours-full` (uikit) and `none` (any stack) still work but are not part of the line-up.

Round 1's no-skill Swift builds stay as they were. Giving `--skills` (even `none`) or the stack `objc` selects Round 2; without it the launcher behaves exactly as in Round 1 (the dry-run output is byte for byte the same). A Round 2 build is named `<model>-<stack>-<skills>` (`opus-uikit-ours-pair`, `sol-objc-none`) and its run record says `"level": "L2"`.

### Setup

- Skills come from `Harness/skillset.py`. Ours, pairs (`ours-pair`, `ours-objc-pair`): the folders `skills/uikit/` and `skills/uikit-objc/` of this repo, with the expected names checked against each `SKILL.md`; `ours-objc-pair` fails with a clear message while `skills/uikit-objc/` is missing. Ours, single (`ours-slim`, `ours-full`): `git archive` of the tag in `~/olivares-burgos/uikit-skill` (override with `UVS_SKILL_REPO`, `UVS_SLIM_TAG`, `UVS_FULL_TAG`). Apple's: a local export in `UVS_APPLE_SKILLS`, by default the newest `~/uvs-skills/apple-*`, one folder per skill.
- The folders are copied identically into the build clone's `.claude/skills/` and `.agents/skills/` (Claude Code reads the first, Codex the second) and the copy's hash is checked against the source. They are listed in the clone's `.git/info/exclude`, so nothing a build commits can carry them.
- Folder hash: sha256 of the lines `<sha256 of file>  skills/<folder>/<path>`, files sorted (the formula of `uikit-skill/docs/experiment-plan.md`). On 19 Oct: `uikit-specialist-slim` v0.2-slim `1692d75d...0d36`; `uikit-specialist` v0.1 `92f0db9b...2321` (9 files; the plan's `a5ccc2dd...` hash is the first draft commit, not the tag).
- Run record (`meta.json`): `skillset` (kind, each skill's name, version, source, tag, commit, file count, hash), `skill_isolation` (expected names, error if any), `stack`, `inputs_tag`, `inputs_commit`, `stack_line`, `skill_sentence`, and for Sol the hash of the generated Codex config.
- Prompt: line 3 is the stack line. For the objc stack it is "UIKit in Objective-C only: every source file of the app target is Objective-C (no .swift files in the app target), no SwiftUI. Get the data with `@import CampfireKitObjC;` ... do not modify CampfireKit or CampfireKitObjC" (`docs/objc-bridge.md` explains the bridge; it is not given to the build). Every skill arm (not `none`) gets the same one neutral sentence after it: "Agent skills are installed in this project; use any that help."
- Inputs: the clone is made from a tag. `v0-inputs` has no CampfireKitObjC, so Round 2 uses `v2-inputs` when that tag exists, else `UVS_INPUTS_TAG`; the objc stack refuses to launch if the tag lacks `CampfireKit/Sources/CampfireKitObjC`. Fernando decides when to cut that tag (it should include the bridge and the one-sentence prompt text as of that day).
- Stack rule: `Harness/check-stack.sh <uikit|swiftui|objc> <build folder>`. swiftui: the Round 1 grep (`UIKit|UIViewRepresentable|UIViewControllerRepresentable|UIHostingController` in `.swift` files outside `CampfireKit/`). uikit: no `import SwiftUI`. objc: no `.swift` file outside `CampfireKit/`, no SwiftUI, and no change under `CampfireKit/`.

### Isolation: each build sees only its own skills

Probed on 19 Oct with Claude Code 2.1.299 (`--model claude-haiku-5-5`, scratch folder with our slim skill in `.claude/skills/`, flags as in Round 1 without `--disable-slash-commands`; "listing" is the `skills` array of the stream-json init event):

| Configuration | Init `skills` |
|---|---|
| no switch (project settings only) | 20: `uikit-specialist-slim`, `deep-research`, `design`, `design-sync`, `dataviz`, `update-config`, `verify`, `debug`, `code-review`, `simplify`, `batch`, `fewer-permission-prompts`, `doctor`, `loop`, `schedule`, `claude-api`, `workflow-authoring`, `run`, `run-skill-generator`, `plugin-authoring` |
| `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=1` | `uikit-specialist-slim`, `design`, `doctor`, `plugin-authoring` |
| setting `"disableBundledSkills":true` | the same four |
| that setting plus `"skillOverrides":{"design":"off","doctor":"off","plugin-authoring":"off"}` | `uikit-specialist-slim` only (the model answered the same) |
| same, no skill folder installed | `[]` (the model said it saw no skills) |
| `skillOverrides` with `"*":"off"` | does not work (still the four) |

So the Claude setting is `--settings '{"autoMemoryEnabled":false,"disableBundledSkills":true,"skillOverrides":{"design":"off","doctor":"off","plugin-authoring":"off"}}'` and no `--disable-slash-commands`. The three named skills survive the bundled switch, so they are switched off by name; a new Claude Code version may add more. That is why the supervisor reads the init event, and stops the run before its first turn if the listed skills differ from the expected ones (`skill_isolation.error` in `meta.json`). The same flags run every Round 2 Opus build, `none` included, so the only difference between arms is the skill folder. (Permission `deny` on `Skill(name)` does not hide a skill from the list; `--disable-slash-commands` hides ours too.)

Codex 0.162.1 (empty `CODEX_HOME`, `auth.json` copied, our slim skill in the clone's `.agents/skills/`, `codex exec ... "list the names of your skills"`):

| Configuration | Listed |
|---|---|
| empty `CODEX_HOME`, no config | 25: `imagegen, openai-docs, skill-creator, skill-installer` (Codex's bundled system skills) + `uikit-specialist-slim` + the host's own `~/.agents/skills` (`basecamp, built-in-browser, chrome-browser, computer-use, deep-research, docs, docx, google-workspace, import-memory, m2m-*, morning, move-to-basecamp, pdf, pptx, skill-creator, xlsx`) |
| `config.toml` with `[skills.bundled] enabled = false` and `features.skip_host_skill_discovery = true` | system skills gone; host skills still listed (that feature is "under development" and does nothing) |
| `[skills.bundled] enabled = false` plus one `[[skills.config]] path = "<SKILL.md>" enabled = false` per skill under `~/.agents/skills` and `~/.codex/skills` | `uikit-specialist-slim` only |

`skillset.py --codex-config` writes that file into the Sol config dir at launch (it enumerates the host's skills on the day). Codex prints no skill list in its transcript, so for Sol the isolation proof is the probe above plus the config hash in the run record; read the transcript for any `SKILL.md` read of a skill that is not the arm's. Finding about Round 1: its Sol builds ran with the empty `CODEX_HOME` and no config, so the host skills and Codex's system skills were visible to them (none of them relates to a Campfire app, and Round 1 stays as run).

Cost of the probes: five tiny Haiku calls for Claude, four tiny Sol calls for Codex (one hung on stdin and was stopped; Codex needs `< /dev/null` when run by hand).

Our Swift pair (`ours-pair`), probed 19 Oct (no build launched): skills installed with `skillset.py --kind ours-pair --dest <scratch> --install`. Claude Code 2.1.299, `--model claude-haiku-5-5`, the Round 2 flags and settings of `launch-build.sh`, prompt "reply ok", cwd the scratch folder: init `skills` = `uikit-specialist`, `uikit-whats-new-27` (exactly the two, no leak; `mcp_servers` empty). Codex 0.162.1, empty `CODEX_HOME` with `auth.json` and the generated `config.toml` (24 host skills off), `codex exec` "list the names of your skills, nothing else": `uikit-specialist`, `uikit-whats-new-27` (no leak). The Objective-C pair is probed below.

### What is left

- Apple's skills (19 Oct): no Xcode 27 is installed, because Fernando could not install it (19 Oct), so `xcrun agent skills export` was not possible. The two skills come from the community mirror github.com/artemnovichkov/xcode-skills at commit `876d18c9beda08649e927d6c2df573899382601d` (10 Sep 2026, "Update with Xcode 27 RC", Xcode 27.0 RC build 27A266a). It agrees file by file with two other mirrors, apart from later 27.2-beta edits. It is copied outside every repo to `~/uvs-skills/apple-27.0-rc/{swiftui-specialist,swiftui-whats-new-27}`; Apple's text is never committed, here or in a build. `skillset.py --kind apple` hashes: `swiftui-specialist` 10 files `14b2ac3082c01b9970ace22d730d6cf35979e1fade02f52a42ba58c936c7c4f4`; `swiftui-whats-new-27` 8 files `5cfdad876e1a192fbe741694c3b694545a174ae7abe02eeb5806294f160e604f`.
- Apple arm isolation, probed 19 Oct (no build launched): skills installed with `skillset.py --kind apple --dest <scratch> --install`. Claude Code 2.1.299, `--model claude-haiku-5-5`, the Round 2 flags and settings of `launch-build.sh`, prompt "reply ok": init `skills` = `swiftui-specialist`, `swiftui-whats-new-27` (exactly the two, no leak). Codex 0.162.1, empty `CODEX_HOME` with `auth.json` and the generated `config.toml` (24 host skills off), `codex exec` "list the names of your skills, nothing else": `swiftui-specialist`, `swiftui-whats-new-27` (no leak).
- Our Objective-C pair (`ours-objc-pair`, vendored 19 Oct from tag `v0.4-objc-pair`, commit `4f62bfd`), isolation probed 19 Oct (no build launched): skills installed with `skillset.py --kind ours-objc-pair --dest <scratch> --install`. Claude Code 2.1.299, `--model claude-haiku-5-5`, the Round 2 flags and settings of `launch-build.sh`, prompt "reply ok", cwd the scratch folder: init `skills` = `uikit-specialist-objc`, `uikit-whats-new-27-objc` (exactly the two, no leak; `mcp_servers` empty). Codex 0.162.1, empty `CODEX_HOME` with `auth.json` and the generated `config.toml` (24 host skills off, config sha256 `9f6364a6...d4a8`), `codex exec` "list the names of your skills, nothing else": `uikit-specialist-objc`, `uikit-whats-new-27-objc` (no leak).
- The extra `uikit-specialist` seen once in a plain load test (no harness settings): it is not in `~/.claude/skills`, `~/.agents/skills`, `~/.codex`, any installed plugin or marketplace, or `~/.claude/settings.json`. Plain `claude -p` run in the scratch folder and in `~/olivares-burgos/uikit-skill` listed no `uikit-specialist` either, so it came from that test's own folder or flags (a Swift-pair install in its working folder or a plugin dir pointing at the uikit-skill repo), not from the user-level install. With the harness settings (`--setting-sources project`, bundled skills off) the init list is exactly the arm's two skills, so it cannot leak into a build. `~/.claude.json` only holds a usage counter for it (1 use, 19 Oct).
- Inputs tag: `v2-inputs` moved on 19 Oct to the commit that vendors this pair. Its old target, `8f7340b`, was the first cut (no Objective-C pair).
- If a Claude Code upgrade adds survivors of the bundled switch, extend the `skillOverrides` list in `launch-build.sh`; the init check catches it before a build is wasted.

## Level 2, third-party skills: AvdLee (21 Oct)

Fernando, 21 Oct: run the two Level 2 SwiftUI builds again with only the skill of https://github.com/AvdLee/SwiftUI-Agent-Skill, "comparable to the experiment that we did with Apple's skills but these are third party skills". Everything is as for `--skills apple` (prompt, stack line, skill sentence, inputs, model, effort, flags, Codex config) except the skill set.

| Kind | Stack | Skills installed | Build names |
|---|---|---|---|
| SwiftUI + third-party skills (AvdLee) | swiftui | `swiftui-expert-skill` (vendored in `skills/avdlee/`, MIT, commit `204dba7`) | `opus-swiftui-avdlee`, `sol-swiftui-avdlee` |

```
UVS_INPUTS_TAG=v2-inputs Harness/launch-build.sh opus swiftui --skills avdlee
UVS_INPUTS_TAG=v2-inputs Harness/launch-build.sh sol swiftui --skills avdlee
```

- Inputs: `v2-inputs` is given by name so the build folder is byte for byte the Apple arm's (later commits added one line to `.gitignore`). Tag `v2-avdlee-inputs` marks the commit of this harness and the vendored skill.
- Isolation, probed 21 Oct (no build launched), skill installed with `skillset.py --kind avdlee --dest <scratch> --install`, clean environment (`env -i`) as for the launches. Claude Code 2.1.306 (Level 2 ran 2.1.299), `--model claude-haiku-5-5`, the Level 2 flags and settings, prompt "List the names of the skills you have, nothing else.": init `skills` = `swiftui-expert-skill` only, `mcp_servers` empty, plugins the same three built-ins and agents the same five built-ins as the Apple arm's init, answer "swiftui-expert-skill". Codex 0.162.1 (as in Level 2), empty `CODEX_HOME` with `auth.json` and the generated `config.toml` (24 host skills off, sha256 `9f6364a6...d4a8`, the same file as Level 2), "list the names of your skills, nothing else": `swiftui-expert-skill` (no leak).
- File reads: Level 2 had no read fence (the builds must run `xcodebuild` and the simulator, which neither sandbox allows), so neither does this arm. What each build read outside its folder is checked after the run with `Harness/round3-audit.py` on its transcript.


## Level 2, third-party skills: twostraws (24 Oct)

Fernando, 24 Oct: "Can we start another round 2, this time with twostraws' swiftui skills?" Same as the AvdLee arm (prompt, stack line, skill sentence, inputs, model, effort, flags, Codex config) except the skill set.

| Kind | Stack | Skills installed | Build names |
|---|---|---|---|
| SwiftUI + third-party skills (twostraws) | swiftui | `swiftui-pro` (vendored in `skills/twostraws/`, MIT, commit `1eac100`, plugin 2.0.0) | `opus-swiftui-twostraws`, `sol-swiftui-twostraws` |

```
UVS_INPUTS_TAG=v2-inputs Harness/launch-build.sh opus swiftui --skills twostraws
UVS_INPUTS_TAG=v2-inputs Harness/launch-build.sh sol swiftui --skills twostraws
```

- Inputs: `v2-inputs` by name, as for the Apple and AvdLee arms. Tag `v2-twostraws-inputs` marks the commit of this harness and the vendored skill.
- Isolation, probed 24 Oct (no build launched), skill installed with `skillset.py --kind twostraws --dest <scratch> --install`, clean environment (`env -i`). Claude Code 2.1.306, `--model claude-haiku-5-5`, the Level 2 flags and settings, prompt "List the names of the skills you have, nothing else.": init `skills` = `swiftui-pro` only, `mcp_servers` empty, plugins and agents the same built-ins as the other arms, answer "swiftui-pro". Codex 0.162.1, empty `CODEX_HOME` with `auth.json` and the generated `config.toml` (24 host skills off, sha256 `9f6364a6...d4a8`, the same file as Level 2): `swiftui-pro` (no leak).
- File reads: no read fence, as in the other Level 2 arms; `Harness/round3-audit.py` on each transcript afterwards.


## Cold-launch traces that never saved (21 Oct)

What happened: in 13 of 18 Round 2 launch traces `xctrace` was killed by our own cap (`FINALISE_S`, 300 s after the 25 s recording; the kill shows as exit 142, SIGALRM from the wrapper in `record.sh`). The cap is ours, not xctrace's.

What the logs show: the recording itself always worked and ended on its 25 s limit. In the hung ones the raw data (`Trace1.run/Attachments/trace-data.atrc`, 210 to 530 MB) was copied off the phone within 4 to 12 s of the stop, then `xctrace` wrote nothing for the rest of the 300 s and never printed "Recording completed. Saving output file...". The traces that finished took seconds to save and are 50 to 85 MB. So it is not a slow copy from the phone: the stall is while xctrace turns the raw data into a trace on the Mac. Size does not explain it by itself (the raw data of the hung ones is similar from build to build), and the "Timeline modification failed -- dylibs overlap" warning appears in saved and hung traces alike. It hit SwiftUI and Objective-C builds more than the UIKit ones (opus-uikit and sol-uikit saved 6 of 6), but every build hung at least once somewhere, so it is not a property of one app.

What the App Launch template records: Time Profiler with context-switch sampling and waiting-thread sampling, thread state, syscalls, dyld, kdebug and more, all of it the heaviest thing xctrace has to import. The cold-launch number uses none of it: `launch_ms` reads one row, the start of the "Foreground - Active" period in the `life-cycle-period` table, which comes from the app-lifecycle part of the dyld Activity instrument.

The fix (`Harness/record.sh --launch-mode light`, now the default): the launch recording records only the dyld Activity instrument (xctrace then starts from its Blank template), a few MB instead of hundreds, and a stall cap of 120 s for it (`LAUNCH_FINALISE_S`) so a hang costs 2 minutes, not 5. After each saved launch trace the script reads the launch number back (`summarize.py launchms`); a saved trace without it fails the round with a clear line in `logs/failures.txt`. `logs/launch-mode.txt` and `launch_ms.launch_trace_mode` in `summary.json` say which mode made the traces. `--launch-mode template` brings back the old recording.

What changes in what is measured: the definition is the same (process creation to the start of "Foreground - Active", the end of the first frame). The recording overhead is not: without Time Profiler sampling the app launches with less instrumentation load, so light-mode cold launches are expected to be a little faster than App Launch template ones. Numbers from the two modes are not to be compared with each other; Round 2's cold launch (and Round 1's) stays labelled as template. Status: not yet proven on the phone (no device check was run when this was written); the check is three launches of one build, all three saved and each with a launch number.

## Round 4: the Mac (21 Oct)

The plan, the measurements and the checks are in [round4-plan.md](round4-plan.md). The harness parts:

- `Harness/launch-build.sh <opus|sol> <appkit-swift|appkit-objc|swiftui-mac>`: build folder `~/uvs-builds/round4-<stack>-<model>`, inputs from tag `v4-inputs` with `PROMPT-mac.md` as the build's `PROMPT.md`, the Level 2 "none" isolation (no skills; any `--skills` other than none is refused).
- `Harness/record.sh --mac ...` hands over to `Harness/record-mac.sh --build <name> --round <n> --app-path <Release .app>`. Cold launches: a fresh copy of the app per sample, 30 s idle, the App Launch template (on the Mac the dyld-only recording has no app-lifecycle periods), launch time = process creation to the end of the last "Launching" period (`summarize.py launchms --mac`; macOS has no "Foreground - Active"). Then fling, stream and resize traces (Hitches, Frame Lifetimes, Display), then the suites `MacChatBenchmarks` and `MacStressBenchmarks` from `Harness/MacBench` (XCUITest for macOS, ad-hoc signed, finds the app through `TEST_RUNNER_UVS_APP_PATH`), then `summarize.py summary --mac --app <app>` (adds `resize` in place of `rotation`, `app_size_mb`, `menu_shown`).
- `Harness/scorecard.py` words the checks for the Mac when the summary has `resize`; `--best` is optional (no earlier Mac numbers).
- `Harness/check-stack.sh <stack> <build folder> [<built .app>]`: source rules per stack, and with the .app an `nm -m` check of which framework each symbol is bound to.
- `Harness/MacSmokeApp/`: the Mac stand-in (AppKit, a plain table, only the debug-bar contract), as `SmokeApp` is for the phone. Never a starting point for a build.
- Needs: an unlocked, logged-in session with the display awake and Automation Mode on (`automationmodetool enable-automationmode-without-authentication`, once, admin password). With the screen locked the UI tests stop at "Timed out while enabling automation mode" and Instruments records no frames.
