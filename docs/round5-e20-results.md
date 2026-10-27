# Round 5, E20: validation round 12, the Opus build with the thin2 skill (`v0.11.2-thin2`)

Run 27 Oct (local). Same method as E18 (`docs/round5-e18-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.11.2-thin2` (private skill repo, branch `thin2` from `thin-timer`, commit `0945814`; folder hash `5849b584...`, 4 files). Installed alone; the init skill list was exactly `uikit-chat-list` (`skill_isolation.error` null). The committed pin `CHATLIST_TAG` in `Harness/skillset.py` was not changed; the run used `UVS_CHATLIST_TAG=v0.11.2-thin2`. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.2-thin2 UVS_NAME_SUFFIX=-thin2 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: `runs/opus-uikit-ours-chatlist-thin2/e20-sim/` (summaries and scorecards tracked), control in `runs/e20-control-quiet/uikit-swift-opus/baseline.json`.

thin2 comes from a diagnosis of E18 (Opus crash) and E19 (Sol cold launch and memory), read from the generated code and the crash report; it is written up below, before the results.

## Diagnosis (from the code, before this build)

**Q1. Did the thin skill cause E18's crash, or was it a random agent bug?** The skill made it likely. The crash report (`Campfire-2026-10-27-040648.ips`) has `reconfigureItemsAtIndexPaths:` -> `cellForItemAt` -> `ChatStore.message(at:)` index out of range, from the timer's flush. In the E18 code the flush is one batch that collects changed rows by their old positions, trims k rows from the top of the store and the layout, and then reconfigures `reconfigured.filter { $0 >= k }` without shifting them by k. `reconfigureItems` asks the data source for the cell at once, at the position it is given, against the already trimmed store, so a changed row near the end asks past it. v0.9.0 had a rule against this ("never trim and insert in one batch; trim with `reloadData`", checklist item "no trim shares a batch with an insert"); both passing v0.9.0 Opus builds (E10, E11) trimmed with a reload and reconfigured only in batches with no deletions. thin took v0.10's "trim in the same batch" and rule 6's "`reconfigureItems` for changed ones" in the same flush, with nothing on the index space of a reconfigure. E16 (thin) escaped by luck: it updated visible cells directly after the batch. E15 (v0.10) escaped by reconfiguring in a batch of its own first. Sentence added to rule 7: "`reconfigureItems` asks for the cell at once, at the position given: reconfigure in a batch of its own before one that trims."

**Q2. What makes Sol's first 40 rows cold slow, and its peak memory swing?** Cold: the prompt's clock starts at the app's first line. Sol's thin and thin-timer builds start their clock in `main` before `UIApplicationMain`, but start making the data only in `didFinishLaunching`, behind a placeholder controller that is swapped for the list later, so UIKit's start-up and the data run one after the other. Sol's v0.9r build (E12, 122 ms) started both its clock and its data at `didFinishLaunching` and built the list while the data was made, so the cause was absent there. Every Opus build starts the data in `main` before `UIApplicationMain`. Rule 12 now says that. Memory: it tracks how much each cell draws itself. thin-timer's cell is one view with `draw(_:)` for the bubble and day line (86.5 MB, E19), v0.10's draws pills and avatars (76.0, E14), v0.9r's pills and file rows (71.2, E12); thin's has none (58.5, E17), nor do the Opus builds (about 54 to 57). A drawn view keeps a bitmap its own size. No skill version ever had a rule on this (v0.9's custom drawing note was about text). Clause added to rule 5: "no `draw(_:)` in cells (a drawn view keeps a bitmap its size)".

**Q3. Which v0.9 content did thin cut that the passing Opus v0.9 builds relied on?** Only the trim rule (core rule 12 and checklist item 3, above). Other cuts (the iOS 26 menu note, fresh anchors, the shortcuts list, the checklist itself, prefetching moved to a reference) did not show in the code: the thin builds still turn prefetching off and do the rest.

**Skill diff, thin-timer to thin2** (`SKILL.md` only, 827 to 829 words; thin was 819):

| Rule | Change |
|---|---|
| 5 | added "; no `draw(_:)` in cells (a drawn view keeps a bitmap its size)" |
| 7 | added "`reconfigureItems` asks for the cell at once, at the position given: reconfigure in a batch of its own before one that trims." |
| 12 | now "Start making the data on a background queue in the app's first line, before `UIApplicationMain`, and build the screen while it runs (no placeholder controller swapped in later); check a guessed width against the real one." |
| 6 | "The flush is one `performBatchUpdates`" to "a `performBatchUpdates`" (so rule 7's separate batch does not contradict it) |
| 1, 3, 4, 10 | cut to pay for the above: the iOS 26 ranges-method note, the off-grid sliver aside, image rows' stored size, "keep image caches" |

## In plain words

- **Opus with thin2 passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase. The stream finishes; no crash.
- **The agent did what the new rules say**: changed rows (boosts) are reconfigured in a batch of their own (`refreshRows`) before the append-and-trim batch (`appendRows`); the data starts in `main.swift` before `UIApplicationMain`; no cell draws itself. The flush runs on a 0.1 s timer.
- **The timer question is now answered for Opus: stream CPU is +4 % over the control** (6.53 against 6.30 s), inside the 10 % line. thin with the next-turn flush was +29 % (E16), v0.9.0 with the timer -8 % and -7 % (E10, E11).
- **Every other row is level or better**: first 40 rows cold -18 %, repeated level, jump -39 %, load older -53 %, text size at the bottom -48 %, mid-list -45 %. Peak memory 56.5 against 53.3 MB (+6 %, inside the 10 % line). App size 0.80 against 0.84 MB.
- **Agent time is inside the bar but the highest of the thin arms**: 2,389 s (bar 2,454 s; E18 1,949, E16 1,731, v0.9.0 2,115 and 2,221), 71 turns, 14 builds, none failed; 10.9 M input tokens including cache, $6.89.
- One build is one sample. Phone passes are not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + thin2 (E20) | **Passes** | 13 of 13 in 3 of 3 passes; no row more than 10 % worse than the same-day control (worst: memory +6 %, stream +4 %); wall 2,389 s within the bar (at most 2,454 s). |
| Against thin + timer (E18) | **Better** | E18 crashed in the stream (11 of 13). Cold here 136 against E18's 105 ms (both under their controls). |
| Against thin (E16) | **Better on the bar, slower agent** | E16 failed on stream +29 %; wall 1,731 against 2,389 s. |
| Against v0.9.0 (E10, E11) | **Level** | Both pass the bar; stream -8 %/-7 % there, +4 % here; wall 2,115 / 2,221 against 2,389 s; turns 62 against 71. |

## Against the pass bar (Opus)

| Bar item | E20 thin2 | E18 thin + timer | E16 thin | E10 / E11 v0.9.0 |
|---|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | No (11) | Yes | Yes / Yes |
| 1. Same on the phone | Not run | Not run | Pending | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (2,389 s, +7 % against the control's 2,231) | Yes (1,949 s) | Yes (1,731 s) | Yes / Yes |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (worst memory +6 %) | Not decidable | No (stream +29 %) | Yes / Yes |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets.

| Row | E20 build (thin2) | E20 control (same sitting) | Diff | E18 build (thin + timer) | E16 build (thin) | E10 build (v0.9.0) |
|---|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 11, 11, 11 | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 136 [136, 137, 136] | 165 [165, 152, 166] | -18 % | 105 | 145 | 139 |
| First 40 rows, repeated (ms) | 604 [604, 600, 606] | 602 [602, 603, 589] | 0 % | 492 | 614 | 574 |
| Stream CPU (s) | 6.53 [6.56, 6.53, 6.44] | 6.30 [6.30, 6.54, 6.23] | +4 % | n/m | 8.31 | 5.94 |
| Jump to 2,500 (ms) | 28 [33, 28, 26] | 46 [45, 46, 49] | -39 % | 31 | 38 | 44 |
| Load older (ms) | 18 [23, 18, 17] | 38 [39, 38, 38] | -53 % | 21 | 17 | 43 |
| Text size at bottom (ms) | 23 [20, 23, 27] | 44 [42, 49, 44] | -48 % | 24 | 26 | 41 |
| Text size mid-list (ms) | 24 [24, 31, 21] | 44 [42, 47, 44] | -45 % | 19 | 31 | 42 |
| Peak memory (MB) | 56.5 [56.1, 56.5, 57.1] | 53.3 [54.1, 53.3, 53.0] | +6 % | n/m | 57.4 | 54.1 |
| App size (MB, binary) | 0.80 | 0.84 | -5 % | 0.74 | 0.80 | 0.77 |

The control's stream figure is 6.30 s (E18: 6.35, E16: 6.45), tight across passes.

## Agent facts (`meta.json`, transcript)

| | Thin2 (E20) | Thin + timer (E18) | Thin (E16) | v0.9.0 (E10) | v0.9.0 (E11) | Control (Round 2) |
|---|---|---|---|---|---|---|
| Wall (s) | 2,389 | 1,949 | 1,731 | 2,115 | 2,221 | 2,231 |
| Turns | 71 | 83 | 74 | 62 | 62 | 95 |
| Builds (failed) | 14 (0) | 16 (0) | 13 (0) | 11 (0) | 9 (1) | 12 (0) |
| Input tokens incl. cache (M) | 10.9 | 13.0 | 11.0 | 10.0 | 10.0 | n/a |
| Cost ($) | 6.89 | 6.97 | 6.20 | 6.90 | 6.26 | n/a |

- Skill files read: `SKILL.md` through the Skill call, then `references/more-surfaces.md`. Never `measuring-text.md` or `table-view.md`.
- 0 commits, exit 0, not stopped by the limit. Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted (2/2); nothing extra to shut down.

## What this changes

1. **For Opus, thin2 is the first thin arm to pass the whole bar**, with a `SKILL.md` of 829 words. The timer flush holds stream CPU near the control once the build does not crash.
2. The reconfigure sentence did what it was meant to: the agent split the reconfigure into its own batch before the trim batch.
3. Next: the Sol build with thin2 (E21) to test the rule 12 and rule 5 changes on the model they were written for; phone passes for any arm that passes the sim bar.
