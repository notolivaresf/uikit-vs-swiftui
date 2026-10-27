# Round 5, E11: validation round 5, a second Opus build with skill v0.9.0

Run 26 Oct (local). A repeat of E10 (`docs/round5-e10-results.md`) to see whether its result holds. Same method as E9 and E10 (runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes, then the Opus control re-measured in the same sitting. Nothing else ran on the two kept simulators (`uvs-r3-a`, `uvs-r3-b`) while scoring ran; scoring used `uvs-r3-a`. Skill `uikit-chat-list` v0.9.0 (same tag, same folder hash as E10, `0521b290...`), installed alone; the Opus init skill list was exactly `uikit-chat-list`. Prompt unchanged. Launch: `UVS_NAME_SUFFIX=-v09b UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: scored passes in `runs/opus-uikit-ours-chatlist-v09b/e11-sim/`, control re-measure in `runs/e11-control-quiet/`; meta, transcript and stderr stay local under `runs/`.

## In plain words

- **The E10 result repeated.** The second Opus build with v0.9.0 passes 13 of 13 checks in all three passes, text selection and both text size checks included, the same as E10.
- **The three E9 misses stay gone.** Stream CPU 5.96 s against the control's 6.44 s the same sitting (-7 %; E10 was -8 %, E9 +14 %). Peak memory 54.8 MB against 53.7 MB (+2 %; E10 +1 %, E9 +18 %). The pixel-snapped rows, TextKit 1 text views (`usingTextLayoutManager: false`) and prefetching off are all in the code this agent wrote, found on its own from the skill, as in E10.
- **This time no row is more than 10 % worse than the control.** Load older is 41 ms against 38 ms (+8 %, 3 ms, less than one frame); in E10 the same row was +10 % (4 ms). The control's own spread on it is 37 to 38 ms here and 35 to 44 ms in E10. Noise.
- **The agent was fast again.** 2,221 s (control 2,231 s, bar 2,454 s), 62 turns (control 95; E10 also 62), 9 builds of which 1 failed. Stack rule ok, no `import SwiftUI`, no script build phase, no time cap hit.
- **Phone passes are still pending** (nobody at the iPhone 12), and Sol was not part of this repeat. Everything below is simulator (iPhone 17, iOS 26.4) plus the agent's own facts. Two Opus builds with v0.9.0 now agree; still a small sample.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + skill v0.9.0, second build (E11) | **Passes** the simulator part | 13 of 13 in 3 of 3 passes, text selection and text size pass. Wall time met (-0.4 % against the control). No row more than +10 % worse than the same-sitting control (worst: load older +8 %, 3 ms). Phone pending. |
| E10 repeated? | **Yes** | Same checks, same direction on every row, stream and memory gaps closed again. The two builds differ by 1 to 3 % on the numbers that matter, inside the sitting-to-sitting movement of the control. |

## Against the pass bar (Opus)

| Bar item | E11 build | E10 build |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes (13, 13, 13) |
| 1. Same on the phone | Pending | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (2,221 s, -0.4 %) | Yes (2,115 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (worst: load older +8 %, memory +2 %) | Yes with one caveat (load older +10.3 %) |
| 3. Phone hitch rule | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The same-day control is the Round 2 Opus UIKit tree (Round 3 folder), measured after the build was scored, same simulator, same method (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`).

| Row | E11 build (v0.9.0) | E11 control (same day) | Diff | E10 build (v0.9.0) | E10 control |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 145 [145, 145, 149] | 162 [162, 166, 162] | -10 % | 139 | 163 |
| First 40 rows, repeated (ms) | 580 [576, 586, 580] | 594 [603, 594, 588] | -2 % | 574 | 595 |
| Stream CPU (s) | 5.96 [5.96, 6.01, 5.83] | 6.44 [6.57, 6.44, 6.39] | -7 % | 5.94 | 6.44 |
| Jump to 2,500 (ms) | 44 [47, 44, 41] | 51 [55, 51, 43] | -14 % | 44 | 42 |
| Load older (ms) | 41 [46, 41, 41] | 38 [38, 38, 37] | +8 % | 43 | 39 |
| Text size at bottom (ms) | 41 [41, 41, 45] | 45 [49, 45, 39] | -9 % | 41 | 45 |
| Text size mid-list (ms) | 44 [44, 46, 42] | 48 [49, 48, 46] | -8 % | 42 | 46 |
| Peak memory (MB) | 54.8 [54.3, 54.8, 55.8] | 53.7 [53.1, 53.7, 54.2] | +2 % | 54.1 | 53.8 |
| App size (MB) | 0.76 | 0.84 | -10 % | 0.77 | 0.84 |

The control reproduces its E10 numbers closely this sitting (stream 6.44 s both times, memory 53.7 against 53.8 MB, load older 38 against 39 ms); its jump row moved most (51 against 42 ms, with passes 55, 51, 43), which is why the build looks 14 % better on jump here and 5 % worse in E10. Read jump as level.

## E7 to E11 side by side (Opus)

| Row | E9 build (v0.8.0) | E10 build (v0.9.0) | **E11 build (v0.9.0)** | Control, E11 sitting |
|---|---|---|---|---|
| Checks passed (sim) | 12, 12, 12 | 13, 13, 13 | **13, 13, 13** | 13 |
| Stream CPU (s) | 7.33 | 5.94 | **5.96** | 6.44 |
| Stream vs control | +14 % | -8 % | **-7 %** | |
| Jump to 2,500 (ms) | 48 | 44 | **44** | 51 |
| Text size bottom / mid (ms) | 50 / 47 | 41 / 42 | **41 / 44** | 45 / 48 |
| First 40 rows cold / repeated (ms) | 163 / 629 | 139 / 574 | **145 / 580** | 162 / 594 |
| Peak memory (MB) | 63.2 | 54.1 | **54.8** | 53.7 |
| Wall time (s) | 2094 | 2115 | **2221** | (2231 build) |
| Turns | 71 | 62 | **62** | (95 build) |
| Builds (failed) | 7 (0) | 11 (0) | **9 (1)** | (12 (0)) |
| Wall bar (at most 2,454 s) | met | met | **met** | |

## Agent facts (`meta.json`, transcript)

- Wall 2,221 s, 62 turns, 9 builds (1 failed), 0 commits, exit 0, no idle gaps over 20 minutes, `stopped_by_limit` false.
- Skill use: one Skill call, then it read `references/measuring-text.md` (three times) and `references/table-view.md` once. The same as E10.
- What v0.9 asked for is in the code: row positions rounded to the pixel grid (`rounded(toScale:)` in `Theme.swift`), text views built with `usingTextLayoutManager: false` in `MessageCell.swift`, `isPrefetchingEnabled = false` in `RoomViewController.swift`.
- Stack rule ok; `import SwiftUI` appears in no Swift file; `PBXShellScriptBuildPhase` count 0.
- Simulators: the agent made its own iPhone 17 simulator (`cf-v09b`) and left it booted when it stopped, a third booted device over the cap. I shut it down with `xcrun simctl shutdown` right after the build ended and before any scoring; `uvs-r3-a` and `uvs-r3-b` were untouched by the agent. The v0.8 line "close any simulator you made when you stop" is still not in the skill, and the habit is the agent's own: three builds in a row (v0.8, v0.9, v0.9b) left one booted.

## What this changes

1. **E10 is not a one-off.** Two independent Opus builds from the same skill pin agree on the pass, on stream CPU (5.94 and 5.96 s), on memory (54.1 and 54.8 MB), on text size (41 and 41 ms at the bottom) and on turns (62 and 62). The three v0.9 rules do what the spikes said.
2. **No skill change is needed for the list rules.** Do not tune v0.9 on two builds that both pass.
3. **Still open before a v1.0 tag:** phone passes for an Opus v0.9.0 build (iPhone 12), and Sol, which has not run on any skill after v0.6.2 (the Codex login needs Fernando to sign in again; the repeat of E9/E10's Sol attempt was not tried here). The proposal to add "close any simulator you made when you stop" to how-to-work stands (the uikit-skill repo is not edited here).

## Open items

- Phone passes for an Opus v0.9.0 build (iPhone 12), pending.
- Sol on v0.9.0: blocked on the Codex login (see E10).
- Raw material kept: `runs/opus-uikit-ours-chatlist-v09b/` (`e11-sim/` summaries and scorecards tracked; meta, transcript, stderr local), `runs/e11-control-quiet/uikit-swift-opus/baseline.json`. The Round 3 Opus control folder now holds the new baseline (the E10 one is saved at `runs/e10-control-quiet/uikit-swift-opus/baseline.json`).
