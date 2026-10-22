# Round 4 hand-off (22 Oct)

State of the Round 4 (AppKit and SwiftUI on the Mac) harness when this lane stopped. The plan is `docs/round4-plan.md`.

## What is done and works

- Plan, Mac prompt (`PROMPT-mac.md`) and the three Round 4 prompts (`prompts/round4-*.md`): outcomes and numbers only.
- `Harness/launch-build.sh` knows the three Round 4 stacks (`appkit-swift`, `appkit-objc`, `swiftui-mac`) and hands out `PROMPT-mac.md`, input tag `v4-inputs`.
- `Harness/record.sh --mac` hands over to `Harness/record-mac.sh`; it takes `--xctestrun FILE` to use tests built elsewhere.
- The Mac UI tests and trace scenarios (`Harness/MacTests`, project `Harness/MacBench`) build on the Max (`TEST BUILD SUCCEEDED`).
- `summarize.py` and `scorecard.py` Mac paths, checked on a summary from a guest run: Mac wording, stricter resize checks, launch with an open period gives no number.
- `check-stack.sh` for Round 4 reads every binary in the built app; checked on an AppKit and a SwiftUI test app (each passes its own arm and fails the other).
- Codex review: 15 points, triaged in the plan.

## What fails, and what we know

The end-to-end proof in a throwaway test guest (`testvm`, macOS 15, 2 cores) never produced a summary with numbers. Five runs. In the guest:

- the smoke app (`Harness/MacSmokeApp`) opens with `open -n` and draws correctly (screenshot showed the debug bar and rows);
- every UI test hangs about 66 s on "Launch campfire.bench", then "Application 'campfire.bench' does not have a process ID";
- the Instruments-launched app is reported as not running, its launch period never closes, and the traces exit 54 or 142.

Automation Mode: run 5 set "does not require authentication" (`automationmodetool enable-automationmode-without-authentication` answered through `expect` with the guest's admin password), and the status still reads "Automation Mode is disabled", which is normal until a test runner turns it on. Whether the runner then turns it on in the guest is not yet known.

Building the tests inside the guest fails ("redefinition of module SwiftShims", from the shared Xcode), so the tests are built on the Max and run in the guest with `--xctestrun`.

Most likely the guest itself (headless display, an app started by a raw launch never becoming active), not the harness: the same launch path is what the Max will use, and on the Max the earlier failure was only the locked screen.

## Next step

1. Easiest and most telling: on the Max, with Fernando's screen unlocked and Automation Mode on once (`automationmodetool enable-automationmode-without-authentication`, admin password), run one fast pass on the stand-in:
   `buildslot run --label "UvS R4: smoke pass" -- bash Harness/record-mac.sh --build smoke --round dry1 --fast --app-path build/MacSmokeDD/Build/Products/Release/MacSmokeApp.app`
   then `python3 Harness/scorecard.py --summary runs/smoke/dry1/summary.json`. A summary with numbers proves the pipeline.
2. If the guest proof is still wanted: run only `MacTraceScenarios/testLaunchState` after `open`, and collect `log show --last 5m --predicate 'process == "testmanagerd" OR process == "launchservicesd"'` to see why the launch never gets a process id.

The six builds do not need the passes to work: they can be launched now (`Harness/launch-build.sh <sol|opus> <stack>`, order in the plan). Only the passes need the unlocked Max.

## 22 Oct, later: the Mac harness runs on the Max

Root cause of "does not have a process ID": (1) stray running copies with bundle id campfire.bench (stand-in or build apps left running, one left suspended by Instruments) made XCUITest lose the app; `record-mac.sh` now stops them first (`stop_strays`, also inside `stop_app`). (2) `xctrace --launch <app bundle>` on macOS 27 with Xcode 26.4.1 starts two copies and traces the suspended one, so the launch period never closed, exit 54 and tests saw no app; the script now hands xctrace the executable inside the .app. Exit 54 with a saved trace is how this xctrace ends a launched process, so it counts as normal. The trace tests accept a launched app in the background, then activate it.
Instruments 16 never closes the Mac "Launching" periods: the cold launch is read from the start of the "Foreground" period (no Foreground period still gives no number).
Smoke pass on the stand-in (round dry5): suites and cold launch work, about 8.8 minutes. Still not measured: fling/stream/resize frames and hitches from Instruments (Frame Lifetimes and Animation Hitches record no frames on this toolchain; only Xcode 26.x is installed, no Xcode 27). Stand-in checks that fail by design: boosts, context menu, text selection; window resize reaches only 1 of 2 sizes.
