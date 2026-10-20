# L1 results: hand-off (18 Oct, 16:05)

> Historical hand-off, kept as written. Its "L1"/"Level 1" now means Round 1 (no skills) and "L2"/"Level 2" means Round 2 (with skills); build names are the old run names (see `builds/README.md`), and "round" here means a measurement pass.

**Superseded:** L1 is finished; results are in `docs/results-round1.md`. Nothing is left to run (rounds 2 and 3 cut by Fernando, 18 Oct).

## Done

- Release device builds: all four build (`** BUILD SUCCEEDED **`), each into `~/uvs-builds/dd/<build>`; app at `~/uvs-builds/dd/<build>/Build/Products/Release-iphoneos/Campfire.app`, bundle id `campfire.bench`. Signed with team H8HSTBN8ZP, automatic, the App Store Connect key. No app code changed.
- Harness: final counts committed (350740e, Fernando 18 Oct): fling 10 + 10 swipes at 1 iteration (trace guard 5 s), memory one pass at 1 iteration, every other test 3 iterations. The harness builds for the phone.
- Stack rule (`git grep` outside `CampfireKit/`): opus-swiftui fails (`Campfire/Pasteboard.swift`, UIKit for UIPasteboard), sol-swiftui fails (`Campfire/MessageRow.swift`, `Campfire/SelectableMessageText.swift`, `UIKit.UIPasteboard`). Both UIKit builds pass, with no SwiftUI imports.

## Blocked: the phone

opus-uikit round 1 stopped at the first step. Both the wake test and the launch 1 test failed with "The test runner failed to initialize for UI testing (Timed out while enabling automation mode)". devicectl shows the phone paired, wired, Developer Mode on, `passcodeRequired: false`. xctrace lists it under "Offline". This needs someone at the phone: unlock it and keep it awake, check Settings > Developer > Enable UI Automation is on, and accept any prompt on the screen (if the prompt doesn't come back, unplug and replug the cable or restart the phone).

The failed attempt is in `runs/opus-uikit/aborted-r1-automation-mode-timeout/`. The earlier one, stopped before the harness change, is in `runs/opus-uikit/aborted-r1-before-harness-change/`. Both were moved, not deleted, so the round number 1 is free.

## Rounds left: all 12

Order: opus-uikit, opus-swiftui, sol-uikit, sol-swiftui, then repeat, for rounds 1, 2, 3. Next command:

`buildslot run --label "uvs: record opus-uikit r1" -- Harness/record.sh --build opus-uikit --round 1 --app-path ~/uvs-builds/dd/opus-uikit/Build/Products/Release-iphoneos/Campfire.app`

Then write `docs/results-round1.md` (see the lane brief). Notes for that write-up:

- The harness tests pass even when a spec number misses, e.g. smoke round 8 had a rotation drift of 61 pt and passed. So judge each behaviour against the spec numbers in `summary.json`: drift within 2 pt, still pinned, 600 added, first content under 1 s, selection and menu both "yes".
- `docs/spec.md` doesn't exist. The spec is `PROMPT.md` and the levels are in `docs/timing.md`.
- The level 2 layout match (screenshots and constants within 2 pt) and the jump-to-bottom button have no harness test: report them as not covered.
- `runs/<build>/` is not in `.gitignore` (only `runs/smoke/` is), so commit `docs/results-round1.md` by name.
