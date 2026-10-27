# Round 5, E18: validation round 11, the Opus build with the thin skill plus the 0.1 s flush timer (`v0.11.1-thin-timer`)

Run 27 Oct (local). Same method as E16 (`docs/round5-e16-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.11.1-thin-timer` (private skill repo, branch `thin-timer` from `thin`, commit `b063ad3`; folder hash `083f8b95...`, 4 files). The only change from `v0.11.0-thin` is rule 6: "queue each arrival and flush the queue on a 0.1 s timer (one batch per tenth of a second is much cheaper than one per message)" in place of "schedule one flush on the next main-queue turn if none is pending (no timer)". Installed alone; the init skill list was exactly `uikit-chat-list` (`skill_isolation.error` null). The committed pin `CHATLIST_TAG` in `Harness/skillset.py` was not changed; the run used `UVS_CHATLIST_TAG=v0.11.1-thin-timer`. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.1-thin-timer UVS_NAME_SUFFIX=-thintimer UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: `runs/opus-uikit-ours-chatlist-thintimer/e18-sim/` (summaries and scorecards tracked), control in `runs/e18-control-quiet/uikit-swift-opus/baseline.json`.

The agent took rule 6 as written: `RoomViewController.swift` starts `Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true)` for the flush when the stream starts.

## In plain words

- **This build crashes in the live stream, so it fails.** 11 of 13 checks in all three passes. The two failures are "all 600 live messages arrive" and "stay pinned after the stream". The cause is not the timer's speed: the app dies while the stream runs (crash report, same stack in each pass): an index out of range in `ChatStore.message(at:)`, reached from `cellForItemAt` -> `spec(row:)` while `reconfigureItems` runs inside the flush batch (`RoomViewController.batch`, line 231). By the stack, a boosted row is reconfigured in the same batch as a top trim and its index no longer matches the store (I did not debug it further). The test then waits 60 s for "Stream done" and reports "stream never finished".
- **Stream CPU and peak memory could not be measured** (the stream row needs a finished stream). The rule 6 question (does the timer fix the +29 % stream CPU?) is therefore **unanswered by this build**; it needs a build whose stream finishes.
- **The other rows are good**: first 40 rows cold 105 against 167 ms (-37 %), repeated 492 against 598 (-18 %), jump 31 against 50 (-38 %), older 21 against 38 (-45 %), text size bottom 24 against 41 (-41 %), mid-list 19 against 50 (-62 %). App size 0.74 against 0.84 MB.
- **Build cost was higher than thin's E16**: 1,949 s, 83 turns, 16 builds, none failed; about 13.0 M input tokens including cache, $6.97 (E16: 1,731 s, 74 turns, 13 builds, 11.0 M, $6.20). 0 commits, exit 0, not stopped by the limit.
- One build is one sample, and this crash is a bug of this build's code, not proof that the timer wording causes it. v0.9.0 (timer) built Opus streams that finished twice (E10, E11). Phone passes are not run (the build fails on the simulator).

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + thin + timer (E18) | **Fails** (11 of 13, stream row not measurable) | The app crashes during the stream in 3 of 3 passes (index out of range in a reconfigure inside the flush batch). Wall 1,949 s is within the bar (at most 2,454 s). |
| Against thin (E16) for Opus | **Worse** | 13 of 13 and stream +29 % there; 11 of 13 and no stream figure here. Other speed rows better, wall 1,949 against 1,731 s, turns 83 against 74. |
| Against v0.9.0 for Opus | **Worse** | v0.9.0 passed 13 of 13 with stream -8 % and -7 %; wall 2,115 and 2,221 s, turns 62, tokens 10.0 M. |
| Against v0.10.0 for Opus | **Worse on checks, better on time** | v0.10.0 13 of 13 (stream +29 %), wall 2,914 s, turns 109, 23.3 M tokens. |

## Against the pass bar (Opus)

| Bar item | E18 thin + timer | E16 thin | E10 / E11 v0.9.0 | E15 v0.10.0 |
|---|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **No** (11, 11, 11; text selection passes) | Yes | Yes / Yes | Yes |
| 1. Same on the phone | Not run | Pending | Pending | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (1,949 s, -13 % against the control) | Yes (1,731 s) | Yes / Yes | No (2,914 s) |
| 3. No simulator row more than 10 % worse than the same-day control | Not decidable (stream and memory missing); every measured row is better | No (stream +29 %) | Yes / Yes | No |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. "n/m" = not measured (the stream never finished).

| Row | E18 build (thin + timer) | E18 control (same sitting) | Diff | E16 build (thin) | E10 build (v0.9.0) | E15 build (v0.10.0) |
|---|---|---|---|---|---|---|
| Checks passed | 11, 11, 11 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 105 [104, 106, 105] | 167 [161, 170, 167] | -37 % | 145 | 139 | 144 |
| First 40 rows, repeated (ms) | 492 [492, 493, 492] | 598 [594, 602, 598] | -18 % | 614 | 574 | 588 |
| Stream CPU (s) | n/m | 6.35 [6.30, 6.38, 6.35] | | 8.31 | 5.94 | 8.09 |
| Jump to 2,500 (ms) | 31 [31, 29, 31] | 50 [42, 50, 51] | -38 % | 38 | 44 | 43 |
| Load older (ms) | 21 [23, 21, 18] | 38 [39, 38, 37] | -45 % | 17 | 43 | 44 |
| Text size at bottom (ms) | 24 [21, 24, 26] | 41 [40, 41, 45] | -41 % | 26 | 41 | 50 |
| Text size mid-list (ms) | 19 [22, 19, 18] | 50 [47, 50, 50] | -62 % | 31 | 42 | 50 |
| Peak memory (MB) | n/m | 53.9 [53.9, 53.3, 54.2] | | 57.4 | 54.1 | 53.2 |
| App size (MB, binary) | 0.74 | 0.84 | -12 % | 0.80 | 0.77 | 0.79 |

The control's stream figure is 6.35 s (E16: 6.45, E15: 6.29), tight across passes.

## Agent facts (`meta.json`, transcript)

| | Thin + timer (E18) | Thin (E16) | v0.9.0 (E10) | v0.9.0 (E11) | v0.10.0 (E15) | Control (Round 2) |
|---|---|---|---|---|---|---|
| Wall (s) | 1,949 | 1,731 | 2,115 | 2,221 | 2,914 | 2,231 |
| Turns | 83 | 74 | 62 | 62 | 109 | 95 |
| Builds (failed) | 16 (0) | 13 (0) | 11 (0) | 9 (1) | 14 (1) | 12 (0) |
| Input tokens incl. cache (M) | 13.0 | 11.0 | 10.0 | 10.0 | 23.3 | n/a |
| Cost ($) | 6.97 | 6.20 | 6.90 | 6.26 | 10.94 | n/a |

(The transcript has two result lines; the figures above are the first, the build session. A second 3-turn line follows it, at $7.16 cumulative.)

- Skill files read: the Skill call at turn 3 (`SKILL.md`), then `references/more-surfaces.md` once (a full `cat`). Never `measuring-text.md` or `table-view.md`.
- The code has the timer flush, `isPrefetchingEnabled = false` and a TextKit 1 view per the thin rules. Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted (2/2); nothing extra to shut down.

## What this changes

1. **The timer arm did not answer its question.** The build crashed in the stream before the stream row could be read. The fault (a reconfigure inside the trim batch, by the stack) is in the agent's code; the skill says "trim in the same batch" and "`reconfigureItems` for changed ones" but nothing in its rules covers a changed row that sits in the trimmed part.
2. Open: repeat the timer arm to get one with a finished stream (a second Opus build); decide whether the skill should say that rows trimmed in a batch are never also reconfigured; phone passes.
