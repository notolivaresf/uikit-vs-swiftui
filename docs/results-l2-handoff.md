# L2 results: hand-off (19 Oct, 16:50; updated 18:55)

The six Level 2 builds are built for the phone, but no benchmark round could run yet: the phone would not start UI automation. Nothing about any build was changed.

## Done

- **Release device builds**: all six build (`** BUILD SUCCEEDED **`) into `~/uvs-builds/dd/<build>`, app at `~/uvs-builds/dd/<build>/Build/Products/Release-iphoneos/Campfire.app`, bundle id `campfire.bench`, signed with team H8HSTBN8ZP (checked with `codesign -dvv`). Xcode 26.4.1, iOS SDK 26.4, the same as Level 1. No source changed, nothing committed in the build folders. The command, run through `buildslot run --label "uvs-l2: release build <build>"` in each build folder:

  `xcodebuild build -project Campfire.xcodeproj -scheme Campfire -configuration Release -destination id=00008101-00062D410CE9003A -derivedDataPath ~/uvs-builds/dd/<build> -allowProvisioningUpdates DEVELOPMENT_TEAM=H8HSTBN8ZP CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES "CODE_SIGN_IDENTITY=Apple Development" -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_MYT9KLPSWK.p8 -authenticationKeyID MYT9KLPSWK -authenticationKeyIssuerID 69a6de85-b768-47e3-e053-5b8c7c11a4d1`

  The signing settings are given on the command line because three Sol builds set `CODE_SIGNING_ALLOWED: NO` in their `project.yml` (their `.app` came out unsigned and can't be installed), and opus-objc-ours-objc-pair sets `CODE_SIGN_IDENTITY: "-"`, which fails with "has entitlements that require signing with a development certificate". These are signing settings only, the same for all six; they don't touch any code. opus-uikit-ours-pair and opus-swiftui-apple were built once without the last three settings and came out signed the same way.
- **Stack rule** (`Harness/check-stack.sh <stack> <build folder>`):

  | Build | Stack rule |
  |---|---|
  | opus-uikit-ours-pair | pass |
  | sol-uikit-ours-pair | pass |
  | opus-swiftui-apple | **fail**: `Campfire/RowParts.swift:2: import UIKit  // UIPasteboard only; no UIKit views` |
  | sol-swiftui-apple | **fail**: `Campfire/MessageRow.swift:3: import class UIKit.UIPasteboard` |
  | opus-objc-ours-objc-pair | pass (no .swift file, no SwiftUI, CampfireKit unchanged) |
  | sol-objc-ours-objc-pair | pass |

  Both SwiftUI builds still reach for UIPasteboard for Copy, the same as in Level 1, even with Apple's skills installed.
- **App size** (method in `docs/results-l1.md`, "App size"; `du -sk` of the signed Release `.app` ÷ 1024; Level 1 sizes are also in `docs/results-l1.md`):

  | Build | App size | Executable (bytes) | Notes |
  |---|---|---|---|
  | opus-uikit (L1) | 0.68 MB | 676,304 | |
  | sol-uikit (L1) | 0.62 MB | 617,104 | |
  | opus-swiftui (L1) | 1.48 MB | 1,518,848 | |
  | sol-swiftui (L1) | 1.57 MB | 1,612,352 | |
  | opus-uikit-ours-pair | 0.71 MB | 705,936 | |
  | sol-uikit-ours-pair | 0.64 MB | 636,832 | |
  | opus-swiftui-apple | 1.50 MB | 1,540,800 | |
  | sol-swiftui-apple | 1.20 MB | 1,226,080 | |
  | opus-objc-ours-objc-pair | 0.66 MB | 655,472 | |
  | sol-objc-ours-objc-pair | 2.70 MB | 535,696 | the only bundle with an asset catalog: `Assets.car` 2,184,440 bytes (icons, with an `Assets-LICENSE.txt` from 37signals), plus two app icon PNGs |

- **Build-agent cost** (from `runs/<build>/meta.json`; Level 1 reported no tokens, so neither does this):

  | Build | Wall time | Turns | Xcode builds (failed) | Commits |
  |---|---|---|---|---|
  | opus-uikit-ours-pair | 2231 s | 95 | 12 (0) | 0 |
  | sol-uikit-ours-pair | 1233 s | 90 | 14 (7) | 0 |
  | opus-swiftui-apple | 4301 s | 197 | 24 (0) | 2 |
  | sol-swiftui-apple | 1209 s | 113 | 15 (8) | 0 |
  | opus-objc-ours-objc-pair | 2884 s | 106 | 12 (0) | 2 |
  | sol-objc-ours-objc-pair | 1297 s | 118 | 24 (8) | 0 |

  opus-uikit-ours-pair was cloned from the first `v2-inputs` cut (`8f7340b`, before the Objective-C pair was vendored); the other five from `80cda43`. For a Swift UIKit build the difference is only the files it never reads (the objc skills, not installed in its arm).
- `Harness/tools/results_table.py`: group headers can now span any number of columns, and the footer line is a spec field (default the Level 1 text). The Level 1 images re-render byte for byte the same.

## Blocked: the phone

The first round (opus-uikit-ours-pair, 16:39) stopped at once: the wake test and both cold-launch tests failed with "The test runner failed to initialize for UI testing (Timed out while enabling automation mode)", the same as in Level 1 on 18 Oct. devicectl shows the iPhone 12 connected, `passcodeRequired: false`. The queue was stopped after launch 2 so the other five rounds wouldn't fail the same way. The attempt is in `runs/opus-uikit-ours-pair/aborted-r1-automation-mode-timeout/` (moved, not deleted, so round 1 is free).

Someone has to be at the phone: unlock it and keep it awake, check Settings > Developer > Enable UI Automation is on, accept any prompt on the screen (if none shows, unplug and replug the cable or restart the phone).

### 19 Oct, 18:30: automation works now, but the phone is full

- Probe (18:32): `TraceScenarios/testWake` alone, through `buildslot run`, passed (`** TEST EXECUTE SUCCEEDED **`). UI automation on the iPhone 12 works again.
- Round 1 of opus-uikit-ours-pair (18:32 to 18:51) got partway. The 3 cold launches ran (cold launch median 741 ms, time to 40 rows cold 265 ms; partial, not to be reported). The fling scenario test passed, but its trace stopped with "Failed to stop recording session: Data Providers emitted errors: Logging". The stream trace then failed to start ("Failed starting ktrace session"), and the suites could not install the test runner: **"This app can't be installed because there isn't enough storage ... mkdir ... failed: No space left on device"**. The iPhone 12 has 64 GB and it is full. The two trace errors are most likely the same full disk.
- The queue was stopped there, so the other five rounds would not fail the same way. The attempt was moved (not deleted) to `runs/opus-uikit-ours-pair/aborted-r1-phone-storage-full/`, so round 1 is free again.
- Someone has to free space on the phone (Settings > General > iPhone Storage). Only Campfire and CampfireBenchUITests-Runner are ours, and both are small; the space is taken by other apps, photos or system data. Then run the probe again before the queue: `buildslot run --label "uvs-l2: automation probe" -- xcodebuild test-without-building -xctestrun build/DDH/Build/Products/CampfireBench_iphoneos26.4-arm64.xctestrun -destination id=00008101-00062D410CE9003A -only-testing:CampfireBenchUITests/TraceScenarios/testWake`. The suites install the runner again, so the probe alone does not prove there is room. Watch the first round until `logs/suite.log` shows tests running.

### 19 Oct, 20:28: still full after four apps were removed

- Before this try, four apps were removed from the phone (Basecamp, Basecamp 2, HEY Email, HEY Calendar). `devicectl device info apps` now lists only Campfire and CampfireBenchUITests-Runner besides Apple's apps, so what fills the 64 GB is photos, Apple's apps or system data. devicectl does not report free space.
- Round 1 of opus-uikit-ours-pair ran again (20:07 to 20:27) and failed in the same way. The 3 cold launches ran (time to 40 rows 284, 278 and 312 ms; partial, not to be reported). The fling scenario test passed, but its trace stopped with "Failed to stop recording session: Data Providers emitted errors: Logging". After that the stream scenario test and the suites could not install the test runner: **"This app can't be installed because there isn't enough storage ... mkdir of /private/var/containers/Shared/SystemGroup/systemgroup.com.apple.installcoordinationd/Library/InstallCoordination/PromiseStaging/... failed: No space left on device"**. The stream trace failed to start ("Failed starting ktrace session").
- The attempt was moved (not deleted) to `runs/opus-uikit-ours-pair/aborted-r1-phone-storage-full-2/`, so round 1 is free again. Nothing else was queued.
- Before the next try, someone has to look at Settings > General > iPhone Storage and free several GB. Space from removed apps can take a few minutes to show as free, and a restart of the phone often frees "System Data". Then watch the first round until `logs/suite.log` shows tests running.

### 19 Oct, 21:52 CST: room on the phone now, but automation times out again

- Before this try the iPhone 12 was restarted and unlocked, and a direct `devicectl device install app` of `CampfireBenchUITests-Runner.app` succeeded, so there is room for the runner now.
- Round 1 of opus-uikit-ours-pair started at 21:52. The wake test (21:54:13) and launch 1 (21:55:30) both failed with "The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.)" devicectl lists the iPhone 12 as connected.
- The round was stopped after launch 1, since every later test would fail the same way. No other build was started. The attempt was moved (not deleted) to `runs/opus-uikit-ours-pair/aborted-r1-automation-mode-timeout-2/`, so round 1 is free again.
- Before the next try, someone has to be at the phone: unlocked and awake, Settings > Developer > Enable UI Automation on, and any prompt on the screen accepted (it may show only after a restart). Run the wake probe from the 18:30 section first, then watch the first round until `logs/suite.log` shows tests running.

### 20 Oct, 02:30 CST: all six rounds done

Fernando accepted the prompt on the phone at about 22:30 and the wake probe passed. Round 1 of all six builds then ran in order (22:35 to 02:30); every suite test passed in each. In 13 of 18 launch traces Instruments did not finish saving within the cap, so cold launch (Instruments) is missing or partial; cold time to 40 rows is complete. Results: `docs/results-l2.md`, rows as sent: `docs/results-l2-rows.md`, images: `docs/images/results-l2*.png`. Steps 1 to 4 below are done.

## What is left (done 20 Oct)

1. Round 1 of each build, one at a time, in this order (about 32 min each, 3 h 15 min in all). Every Level 2 Opus build ran on the fixed stream test, so no stream-only reruns are needed:

   ```
   buildslot run --label "uvs-l2: record <build> r1" -- Harness/record.sh --build <build> --round 1 --app-path /Users/amazinghumans/uvs-builds/dd/<build>/Build/Products/Release-iphoneos/Campfire.app
   ```

   for `opus-uikit-ours-pair sol-uikit-ours-pair opus-swiftui-apple sol-swiftui-apple opus-objc-ours-objc-pair sol-objc-ours-objc-pair`, from the repo root. Watch `logs/failures.txt` in the round folder: if the first launch fails with the automation-mode time-out again, stop at once.
2. Write `docs/results-l2.md` shaped like `docs/results-l1.md`: one table per build (or one table with six columns) with the same rows, the stack rule, app size and agent cost from above, judged against the spec numbers in `summary.json` (drift within 2 pt, still pinned, 600 added, first content under 1 s, selection and menu both "yes"; the harness tests pass even when a spec number misses). Then a Level 1 vs Level 2 comparison: opus-uikit vs opus-uikit-ours-pair, sol-uikit vs sol-uikit-ours-pair, opus-swiftui vs opus-swiftui-apple, sol-swiftui vs sol-swiftui-apple (the objc builds have no Level 1 twin; compare them with the Swift UIKit builds of the same model).
3. Images: add an `L2` spec to `Harness/tools/results_table.py` (six columns, `file="results-l2"`, groups Opus (0, 2) and Sol (3, 5), `footer` naming Level 2) and a `--l2` switch that renders only it, so the Level 1 images stay as they are.
4. Commit by name (`runs/` is never committed) and push.
