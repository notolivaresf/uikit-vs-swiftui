# Round 5, E26: the Opus build with the thin4 skill (`v0.11.4-thin4`)

Run 27 Oct (local). Same method as E22 (`docs/round5-e22-results.md`, runbook `docs/round5-e7-runbook.md`), one thing at a time: Opus build (nothing scoring), three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.11.4-thin4` (private skill repo, branch `thin4` from `thin3`, commit `5fd6ca8`; one `SKILL.md` of 677 words, folder hash `c1d1ef66...`). Installed alone; the init skill list was exactly `uikit-chat-list` (`skill_isolation.error` null). The pin `CHATLIST_TAG` in `Harness/skillset.py` was not changed; the run used `UVS_CHATLIST_TAG=v0.11.4-thin4`. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.4-thin4 UVS_NAME_SUFFIX=-thin4 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: `runs/opus-uikit-ours-chatlist-thin4/` (meta, skillset, transcript times, `e26-sim/` scorecards), control in `runs/e26-control-quiet/uikit-swift-opus/baseline.json`.

## What thin4 changed and why

The agent-time table in the skill repo (`docs/thinning-plan.md`, section "Agent time") reads the six transcripts E20 to E25 by phase. The biggest single detour was one `xcodebuild test` call that never ended and held the agent for its full 10-minute tool timeout, in both Opus skill builds (E20 600 s, E22 601 s). In E22 it came from rule 1: the agent checked Copy by tapping it in its own UI test and reading the pasteboard from the test, which waits on the paste prompt. thin4 adds two sentences and changes no rule: rule 1 says Copy is the system's item and the pasteboard must not be read from a UI test; a line before the closing one says to run `xcodebuild test` for the changed test with `-test-timeouts-enabled YES` and a default allowance of 60 s.

## In plain words

- **Opus with thin4 passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase. No crash.
- **Every speed row is level or better than the same-sitting control**: cold -25 %, repeated -16 %, jump -27 %, load older -59 %, text size at the bottom -44 %, mid-list -43 %, peak memory -2 %. Stream CPU +3 % (6.57 against 6.39 s), inside the 10 % line. App size 0.79 against 0.84 MB.
- **Agent wall time is inside the bar**: 1,546 s against at most 2,454 s (-31 % on the control's 2,231). E22 (thin3) took 2,737 s, E20 (thin2) 2,389 s, E24 (no skill) 2,103 s. 46 turns (E22 85), 8 builds with none failed (E22 21), 4 test runs (E22 15), 6.4 M input tokens including cache (E22 15.1 M), 121 k output, $5.37 (E22 $7.83).
- **The agent used the new line**: all four of its test runs carried `-test-timeouts-enabled YES` (allowance 90 s, its own choice), two of them with `-only-testing`. No test run hung. It never read the pasteboard; its menu tests check that Reply and Copy show.
- One build is one sample; Opus builds of one skill have spread by several hundred seconds. But the drop (1,191 s on E22) is twice that spread, and the phase table shows where it came from: own UI tests 559 s (E22 1,423 s), no hung run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + thin4 (E26) | **Passes** | 13 of 13 in 3 of 3 passes, no simulator row more than 10 % worse than the control (worst stream +3 %), wall 1,546 s against 2,454 s. First skill build to pass all three bars since thin2 E20. |
| Against thin3 (E22) | **Rows level, much faster agent** | Same checks; cold 122 against 129, repeated 496 against 599, older 17 against 16, memory 52.3 against 58.7 MB; jump 36 against 13 and text size 22 / 25 against 7 / 9 ms are slower but still far under the control; wall -1,191 s. |
| Against no skill (E24) | **Better on both** | E24 fails text selection (12 of 13) and misses stream, text and memory rows; E26 passes all and is 557 s faster. |

## Against the pass bar (Opus)

| Bar item | E26 thin4 | E22 thin3 | E20 thin2 |
|---|---|---|---|
| 1. 13 of 13 on the sim median | **Yes** (13, 13, 13) | Yes | Yes |
| 1. Same on the phone | Not run | Not run | Not run |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (1,546 s, -31 %) | No (2,737 s) | Yes (2,389 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (worst stream +3 %) | Yes | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E26 build (thin4) | E26 control (same sitting) | Diff | E22 build (thin3) |
|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 |
| First 40 rows, cold (ms) | 122 [121, 122, 122] | 163 [163, 164, 158] | -25 % | 129 |
| First 40 rows, repeated (ms) | 496 [495, 497, 496] | 590 [590, 590, 604] | -16 % | 599 |
| Stream CPU (s) | 6.57 [6.61, 6.57, 6.54] | 6.39 [6.37, 6.50, 6.39] | +3 % | 6.55 |
| Jump to 2,500 (ms) | 36 [27, 37, 36] | 49 [53, 39, 49] | -27 % | 13 |
| Load older (ms) | 17 [13, 17, 18] | 41 [41, 45, 37] | -59 % | 16 |
| Text size at bottom (ms) | 22 [22, 24, 20] | 39 [38, 39, 47] | -44 % | 7 |
| Text size mid-list (ms) | 25 [25, 26, 23] | 44 [44, 47, 41] | -43 % | 9 |
| Peak memory (MB) | 52.3 [52.3, 52.3, 52.2] | 53.1 [53.7, 53.1, 53.0] | -2 % | 58.7 |
| App size (MB, binary) | 0.79 | 0.84 | -6 % | 0.80 |

## Agent time by phase (seconds, same method as the skill repo's table)

| Phase | E26 thin4 | E22 thin3 | E24 no skill |
|---|---|---|---|
| Reading | 50 | 39 | 187 |
| Reference study (screenshot pixels) | 311 | 590 | 409 |
| Writing app code | 489 | 454 | 455 |
| Builds | 48 | 91 | 105 |
| Simulator by hand | 66 | 33 | 282 |
| Looking at own screenshots | 8 | 76 | 11 |
| Own UI tests (write, build, run, read) | 559 | 1,423 | 634 |
| of which one hung test run | 0 | 601 | 0 |
| Waiting and final report | 14 | 30 | 19 |
| **Wall** | **1,546** | **2,737** | **2,102** |

## Agent facts

Wall 1,546 s, 46 turns, 8 builds (0 failed), 1 commit, exit 0, not stopped by the limit; 6.4 M input tokens including cache, 121 k output, $5.37. Skill files read: `SKILL.md` through the Skill call only. Simulators: the agent ran its tests on an iPhone 17 Pro simulator by name and shut it down at the end; `uvs-r3-a` and `uvs-r3-b` stayed booted for scoring (a leftover E25 simulator, `cf15`, was shut down before the launch to keep the cap).

## What this changes

1. thin4 removes the hung-test detour without losing any screen gain: the skill build now beats the no-skill build on checks, rows and agent time.
2. The jump and text-size rows came out slower than E22 but in line with E20 (28 and 23 / 24 ms); none of the two new sentences touches the list code, so read this as build-to-build spread.
3. Next: the Sol build with thin4 (E27), see `docs/round5-handoff-e27.md`.
