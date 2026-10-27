# Round 5, E28: the Opus build with the thin4 skill, repeated (`v0.11.4-thin4`)

Run 27 Oct (local). A repeat of E26 (`docs/round5-e26-results.md`) to check that E26's pass was not luck. Same method: Opus build (nothing scoring), Release simulator build, three scored passes, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.11.4-thin4` (commit `5fd6ca8`, one `SKILL.md`, folder hash `c1d1ef66...`), installed alone: the init skill list was exactly `uikit-chat-list`. Pin in `Harness/skillset.py` unchanged; prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.4-thin4 UVS_NAME_SUFFIX=-thin4b UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. One difference from E26, as briefed: the three passes ran on `uvs-r3-b` (E26 used `uvs-r3-a`). Raw data: `runs/opus-uikit-ours-chatlist-thin4b/` (meta, skillset, transcript times, `e28-sim/` scorecards); control in `runs/e28-control-quiet/uikit-swift-opus/baseline.json` (the Round 3 baseline before this sitting is beside it as `baseline-before.json`).

## In plain words

- **Opus with thin4 passes every check again**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase. No crash.
- **Agent wall time passes again, with room**: 1,807 s against at most 2,454 s (-19 % on the control's 2,231), 261 s slower than E26 (1,546 s) and far under E22 (thin3, 2,737 s) and E24 (no skill, 2,103 s). 72 turns (E26 46), 12 builds with 1 failed (E26 8, 0), 8 test runs, 11.5 M input tokens including cache (E26 6.4 M), 137 k output, $6.91 (E26 $5.37).
- **The test-timeout line worked a second time**: 7 of the 8 `xcodebuild` test runs carried `-test-timeouts-enabled YES` (allowance 60 or 90 s; the eighth was a build-for-testing), 4 with `-only-testing`. No test run hung: the longest single `xcodebuild` call was well under 200 s. It never read the pasteboard from a test (the one `UIPasteboard` in its code is the Copy action itself).
- **The speed rows are level with the control, but two exceed the 10 % line**: load older 45 against 38 ms (+18 %) and text size mid-list 50 against 45 ms (+11 %). Everything else is level or better: cold -8 %, repeated +5 %, stream CPU +1 %, jump +2 %, text size at the bottom +5 %, peak memory +4 %, app size -8 %. The two misses are 7 and 5 ms in absolute terms.
- **E28 is slower than E26 on the list rows** (older 45 against 17 ms, text size 45 / 50 against 22 / 25, jump 44 against 36), though both runs are far faster than thin3's worst and the E26 numbers were the best seen for this build. The control moved little between the two sittings (older 41 then 38, text 39 / 44 then 43 / 45, cold 163 then 166), so the gap is the build, or the other simulator, not the sitting. With one change of simulator and one change of build at once, this run cannot tell which.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + thin4, repeat (E28) | **Misses bar 3** (checks and wall pass) | 13 of 13 in 3 of 3 passes, wall 1,807 s against 2,454 s, but load older +18 % and text size mid-list +11 % against the same-sitting control. |
| Against E26 | **E26's pass on checks and wall held; its row margin did not** | Same 13 of 13, same no-hang behaviour, wall +261 s; E26 had every row within +3 % of the control. |

## Against the pass bar (Opus)

| Bar item | E28 thin4 repeat | E26 thin4 | E22 thin3 | E20 thin2 |
|---|---|---|---|---|
| 1. 13 of 13 on the sim median | **Yes** (13, 13, 13) | Yes | Yes | Yes |
| 1. Same on the phone | Not run | Not run | Not run | Not run |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (1,807 s, -19 %) | Yes (1,546 s) | No (2,737 s) | Yes (2,389 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (older +18 %, text mid-list +11 %) | Yes (worst +3 %) | Yes | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E28 build (thin4 repeat) | E28 control (same sitting) | Diff | E26 build | E26 control |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 152 [162, 148, 152] | 166 [166, 162, 171] | -8 % | 122 | 163 |
| First 40 rows, repeated (ms) | 617 [613, 617, 621] | 588 [587, 590, 588] | +5 % | 496 | 590 |
| Stream CPU (s) | 6.31 [6.32, 6.21, 6.31] | 6.23 [6.08, 6.23, 6.25] | +1 % | 6.57 | 6.39 |
| Jump to 2,500 (ms) | 44 [44, 44, 43] | 43 [40, 43, 45] | +2 % | 36 | 49 |
| Load older (ms) | 45 [38, 45, 47] | 38 [38, 33, 41] | **+18 %** | 17 | 41 |
| Text size at bottom (ms) | 45 [44, 46, 45] | 43 [43, 49, 40] | +5 % | 22 | 39 |
| Text size mid-list (ms) | 50 [50, 48, 50] | 45 [45, 45, 48] | **+11 %** | 25 | 44 |
| Peak memory (MB) | 56.4 [56.0, 56.9, 56.4] | 54.4 [54.4, 54.7, 53.3] | +4 % | 52.3 | 53.1 |
| App size (MB, binary) | 0.77 | 0.84 | -8 % | 0.79 | 0.84 |

## Agent time by phase (seconds)

Method: `transcript.times` charged to the tool call it belongs to (the model time before the call plus its run time), classified by the call's text. The same script was run over E26 and E28 for the middle two columns, so those two compare with each other; it is cruder than the skill repo's hand table (it has no separate reference-study fetch, and commands that chain an edit with a build or test land in the build or test row, so rows are good to a few tens of seconds). E22 and E24 are only given as wall, from the skill repo's table (`docs/thinning-plan.md`, "Agent time").

| Phase | E28 thin4 repeat | E26 thin4 (same script) | E26 (hand table) |
|---|---|---|---|
| Reading (prompt, skill, kit, logs) | 243 | 33 | 50 |
| Reference study (screenshot pixels) | 53 | 41 | 311 |
| Writing app code | 298 | 568 | 489 |
| Builds | 326 | 291 | 48 |
| Simulator by hand | 283 | 94 | 66 |
| Looking at own screenshots | 29 | 8 | 8 |
| Own UI tests (write, build, run, read) | 383 | 382 | 559 |
| of which one hung test run | 0 | 0 | 0 |
| Other tool calls, final report | 191 | 128 | 14 |
| **Wall** | **1,807** | **1,545** | **1,546** |

For comparison, wall: E22 (thin3) 2,737 s with a 601 s hung test, E24 (no skill) 2,103 s, Opus bar 2,454 s.

What it shows: the own-test row is the same in both thin4 builds (about 380 s) and neither hung, so the hung-test fix holds. The extra 261 s in E28 sits in reading (the agent read more of the kit and its own logs), simulator by hand (283 against 94 s: more installs, launches and screenshots) and builds (12 against 8).

## Agent facts

Wall 1,807 s, 72 turns (meta; the result event counts 100), 12 builds (1 failed), 0 commits, exit 0, not stopped by the limit; 11.5 M input tokens including 11.1 M cache reads, 137 k output (73 k thinking), $6.91. The `Skill` tool was called once; no `SKILL.md` file was read from disk. Simulators: the agent used its own simulator for its tests; only `uvs-r3-a` and `uvs-r3-b` were booted for scoring and no leftover was found at the start.

## E26 vs E28

| | E26 | E28 | Read |
|---|---|---|---|
| Checks | 13, 13, 13 | 13, 13, 13 | Same |
| Wall | 1,546 s | 1,807 s | Both under 2,454 s; 17 % apart |
| Turns / builds (failed) | 46 / 8 (0) | 72 / 12 (1) | E28 busier |
| Cost | $5.37 | $6.91 | E28 +29 % |
| Hung test run | none | none | Fix holds |
| Test runs with the timeout flag | 4 of 4 | 7 of 7 test runs | Skill line used both times |
| Worst row against the control | stream +3 % | older +18 %, text mid-list +11 % | Differs |
| Rows slower than 10 % over control | 0 | 2 | E26's margin was not repeated |
| Pass bar | All three | Checks and wall; misses bar 3 | |

So E26's pass was not pure luck on checks, wall time and the hung-test fix: the second build repeats all three. It was partly luck on the speed rows: the load-older and text-size rows came out 2 to 3 times slower than in E26 and, against a control that stayed put, cross the 10 % line. The scoring simulator also changed (`uvs-r3-a` to `uvs-r3-b`), as briefed, so a third sample on the same simulator as E26 would separate build spread from simulator spread.

## What this changes

1. thin4's time fix and check result are repeatable (two of two Opus builds: 13 of 13, wall under the bar, no hung run).
2. The list-row speed of an Opus thin4 build is not settled: E26 beat the control by 43 to 59 % on load older and text size, E28 is 11 to 18 % worse. Nothing in thin4 touches the list code, so read this as build-to-build spread until a third sample says otherwise.
3. Next: a third Opus thin4 sample, scored on `uvs-r3-a` like E26, or re-score this build's app on `uvs-r3-a` to rule out the simulator.

## Re-score: simulator vs build

Run 27 Oct (local), no new agent build. Question: is E28's miss on load older (+18 %) and text size mid-list (+11 %) the build or the simulator? Method as in E26 and E28: `Harness/record.sh` on the build's Release simulator app, three passes, scored with `Harness/scorecard.py --sim` (13 of 13 in every pass), median of three; the Opus control re-measured in the same sitting with `Harness/round3-baseline.sh uikit-swift-opus --runs 3`. Raw data: `runs/e29-rescore/` (`e28-on-a/`, `e26-on-b/`, `control-on-a/`).

One fact found on the way: the control's bench folder is pinned to `uvs-r3-a` (its `.bench/sim` file says `a`). So in E28 the build ran on `uvs-r3-b` while the control it was compared with always ran on `uvs-r3-a`. The re-score puts the build on the control's simulator.

### 2x2, median of three passes (ms unless noted)

| Row | E28 on r3-b (original) | E28 on r3-a (re-score) | E26 on r3-a (original) | E26 on r3-b (re-score) |
|---|---|---|---|---|
| Load older | 45 | **44** | 17 | 16 |
| Text size, bottom | 45 | 45 | 22 | 26 |
| Text size, mid-list | 50 | 44 | 25 | 26 |
| First 40 rows, cold | 152 | 158 | 122 | 124 |
| First 40 rows, repeated | 617 | 621 | 496 | 495 |

Per-pass values for the re-scores: E28 on r3-a: older [44, 46, 38], bottom [45, 45, 50], mid [44, 46, 44], cold [158, 157, 162], repeated [621, 622, 620]. E26 on r3-b: older [16, 16, 27], bottom [27, 21, 26], mid [23, 26, 26], cold [119, 124, 125], repeated [495, 498, 494].

### Each one's control (the control always runs on r3-a)

| Row | Control, E28 sitting | Control, E26 sitting | Control, re-score sitting (this one) |
|---|---|---|---|
| Load older | 38 | 41 | 39 [34, 39, 39] |
| Text size, bottom | 43 | 39 | 44 [46, 44, 42] |
| Text size, mid-list | 45 | 44 | 48 [48, 48, 51] |
| First 40 rows, cold | 166 | 163 | 164 [164, 160, 172] |
| First 40 rows, repeated | 588 | 590 | 596 [590, 596, 606] |

### Build against the re-score control (same sitting)

| Row | E28 on r3-a vs control | E26 on r3-b vs control |
|---|---|---|
| Load older | 44 vs 39: **+13 %** | 16 vs 39: -59 % |
| Text size, bottom | 45 vs 44: +2 % | 26 vs 44: -41 % |
| Text size, mid-list | 44 vs 48: -8 % | 26 vs 48: -46 % |
| First 40 rows, cold | 158 vs 164: -4 % | 124 vs 164: -24 % |
| First 40 rows, repeated | 621 vs 596: +4 % | 495 vs 596: -17 % |

### What the re-score shows

- **The gap is the build, not the simulator.** E28 scores about the same on both simulators (older 45 then 44, text mid 50 then 44, bottom 45 then 45); E26 scores about the same on both (older 17 then 16, text 22 / 25 then 26 / 26). Neither build moved with the simulator. The two builds differ by 2 to 3 times on load older and text size on either one.
- The control did not move either (older 38, 41, 39; mid 45, 44, 48 across the three sittings).
- On r3-a, the simulator E26 was scored on, E28 is still 44 ms on load older against E26's 17 and the control's 39.

### Verdict on bar 3 for E28 on uvs-r3-a

**E28 does not pass bar 3 on uvs-r3-a, by one row.** Load older is 44 ms against a same-sitting control of 39 ms, +13 % (the line is +10 %; the 5 ms gap is also about the spread between the control's own passes, 34 to 39). Text size mid-list, which missed on r3-b (+11 %), is now -8 % and passes; the other three rows pass. Checks are 13 of 13 and the wall time bar was already met, so the build misses the bar on a single speed row, and only just. Against the control from the E28 sitting (older 38) the same row would be +16 %.

The E26 pass stands as a build result, not a simulator result: E26 on r3-b is as far ahead of the control as on r3-a. The spread between two thin4 Opus builds (E26 about 17 ms on load older, E28 about 44 ms) is build-to-build and is the thing left to explain; nothing in the skill touches the list code.
