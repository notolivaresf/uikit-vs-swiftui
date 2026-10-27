# Round 5, E27: validation round 16, the Sol build with the thin4 skill (`v0.11.4-thin4`)

Run 27 Oct (local). Same method as E23 (`docs/round5-e23-results.md`), one thing at a time: Sol build (nothing scoring), Release simulator build, three scored passes on `uvs-r3-b`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` tag `v0.11.4-thin4` (commit `5fd6ca8`, one `SKILL.md`, folder hash `c1d1ef66...`). Pin in `Harness/skillset.py` unchanged; prompt unchanged. Codex weekly use was 1 % before the launch. Launch: `UVS_CHATLIST_TAG=v0.11.4-thin4 UVS_NAME_SUFFIX=-thin4 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-thin4/` (meta, transcript times, `e27-sim/` summaries and scorecards); control in `runs/e27-control-quiet/uikit-swift-sol/baseline.json`.

## In plain words

- **12 of 13 in all three passes.** The one failing check, every time: "Text size follows Dynamic Type; changing it keeps the row at the top in place (within 2 pt)". Stack rule ok, no `import SwiftUI`, no script build phase, no crash. E21 and E23 (Sol, thin2 and thin3) passed 13 of 13.
- **Every speed row is better than the same-sitting control except text size at the bottom**, which is 16 against 15 ms (+7 %, inside the 10 % allowance): cold -8 %, repeated -18 %, stream CPU -10 %, jump -32 %, load older -62 %, text size mid-list -46 %, peak memory -9 %, app size -4 %.
- **Agent wall time misses the bar**: 2,279 s against at most 1,356 s (+68 % on the bar, +85 % on the control's 1,233 s). Better than E23 (2,369 s), worse than E21 (1,595 s) and E25 no skill (1,954 s). 108 turns (E23 123, E21 77), 25 builds with 7 failed, about 22 `xcodebuild` test runs, 10.2 M input tokens including 10.0 M cached, 89 k output (47 k reasoning). No hung test run: the longest single wait was 33 s. The Codex transcript gives no dollar cost.
- The agent read `SKILL.md` with `cat` once, at turn 3; no reference files exist in this skill. It used `curl` (public Campfire repository tree and raw icon files, as E21 and E23 did); the executable is 0.76 MB. Noted, not scored.
- Phone passes were not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin4 (E27) | **Does not pass** (misses bar 1 and bar 2) | 12 of 13 in 3 of 3 passes (text size keeps the top row in place: fails), wall 2,279 s against 1,356 s. Rows level or better than the control. |
| Against thin3 (E23) | **Rows level, one check lost, a little faster** | Cold 122 against 117, repeated 478 against 466, stream 6.66 against 6.63 s, jump 17 against 18, older 10 against 8, text 16 / 14 against 12 / 10 ms, memory 52.0 against 54.9 MB; wall -90 s, turns -15; check 13 to 12. |

## Against the pass bar (Sol)

| Bar item | E27 thin4 | E23 thin3 | E21 thin2 |
|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **No** (12, 12, 12; text selection passes, text size row-in-place fails) | Yes | Yes |
| 1. Same on the phone | Not run | Not run | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (2,279 s, +68 %) | No (2,369 s) | No (1,595 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (worst: text at the bottom +7 %) | Yes | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E27 build (thin4) | E27 control (same sitting) | Diff | E23 build (thin3) |
|---|---|---|---|---|
| Checks passed | 12, 12, 12 | 13, 13, 13 | | 13, 13, 13 |
| First 40 rows, cold (ms) | 122 [126, 122, 120] | 132 [134, 132, 131] | -8 % | 117 |
| First 40 rows, repeated (ms) | 478 [475, 482, 478] | 582 [582, 585, 582] | -18 % | 466 |
| Stream CPU (s) | 6.66 [6.68, 6.66, 6.66] | 7.37 [7.54, 7.36, 7.37] | -10 % | 6.63 |
| Jump to 2,500 (ms) | 17 [17, 17, 15] | 25 [27, 25, 25] | -32 % | 18 |
| Load older (ms) | 10 [11, 10, 10] | 26 [26, 26, 25] | -62 % | 8 |
| Text size at bottom (ms) | 16 [16, 15, 16] | 15 [15, 15, 15] | +7 % | 12 |
| Text size mid-list (ms) | 14 [14, 15, 14] | 26 [26, 25, 26] | -46 % | 10 |
| Peak memory (MB) | 52.0 [51.9, 52.0, 52.7] | 57.3 [57.7, 57.0, 57.3] | -9 % | 54.9 |
| App size (MB, binary) | 0.76 | 0.79 | -4 % | 0.76 |

The control held steady against its E23 sitting (cold 132, repeated 579, stream 7.35, jump 26, older 26, text 15 / 26, memory 57.7).

## Agent time by phase (seconds, same method as the skill repo's table, approximate)

Method: every event in `transcript.times` charged to the command it belongs to (the model time before a call plus its run time), classified by command text. Commands that chain an edit with a test run are charged to the test row, so "Own UI tests" includes some code editing; treat rows as good to a few tens of seconds. Messages are the model time before each of the 15 progress messages and the final report.

| Phase | E27 Sol thin4 | E23 Sol thin3 | E21 Sol thin2 | E25 Sol none |
|---|---|---|---|---|
| Reading (prompt, skill, kit, logs) | 408 | 421 | 156 | 197 |
| Reference study (screenshot pixels, icon fetch) | 187 | 299 | 5 | 78 |
| Writing app code | 354 | 672 | 188 | 306 |
| Builds | 209 | 77 | 116 | 51 |
| Failed builds | in builds | 0 | 93 | 43 |
| Simulator by hand | 146 | 117 | 102 | 93 |
| Own UI tests (write, build, run, read) | 659 | 759 | 898 | 1,174 |
| of which one hung test run | 0 | 0 | 0 | 0 (two long runs, overlapped) |
| Messages, final report, other | 314 | 20 | 34 | 12 |
| **Wall** | **2,279** | **2,366** | **1,593** | **1,954** |

What it shows: thin4 removed the hung-test risk (no long waits at all) and the own-test row is the smallest of the four Sol skill/no-skill builds except E23, but it is still the biggest single row. The extra time against E21 sits in reading (the agent read its own test logs and the kit sources at length, 408 against 156 s), builds (25 builds, 7 failed) and the model time before its progress messages (314 s). The visual-matching work E23 showed (rendering test against the screenshots, icon fetch) is present again, smaller (reference study 187 against 299 s) and spread over the own-test row (its reference-render and visual-asset test runs). It is still a Sol behaviour thin4 does not address.

## Agent facts

Wall 2,279 s, 108 turns, 25 builds (7 failed), 0 commits, exit 0, not stopped by the limit; 10.2 M input tokens including 10.0 M cached, 89 k output (47 k reasoning). Simulators: the agent created its own `Campfire-Local` (iPhone 15, iOS 26.4) with `simctl create`, ran its tests on it and shut it down at the end (no delete, no erase); only `uvs-r3-a` and `uvs-r3-b` were booted for scoring.

## What this changes

1. thin4 does not fix Sol's wall-time miss: 2,279 s is 90 s better than thin3 but 923 s over the bar, and the agent still spends about 660 s on its own UI tests.
2. Sol lost the text-size row-in-place check this time (13 to 12, three of three passes), with both text-size timing rows level with the control. thin4 changed no list rule; with one sample per arm this is either build-to-build spread or an effect of the rule 1 / test-timeout sentences. A second Sol thin4 build, or a look at how this build re-anchors after a size change, would tell which.
3. Next: decide whether to run a second Sol sample (E21 passed the check, E23 passed it, E27 did not) before changing the skill.
