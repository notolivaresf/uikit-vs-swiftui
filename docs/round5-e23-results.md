# Round 5, E23: validation round 15, the Sol build with the thin3 skill (`v0.11.3-thin3`)

Run 27 Oct (local). Same method as E21 (`docs/round5-e21-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Sol build (nothing scoring), simulator build, three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` tag `v0.11.3-thin3` (commit `bd32a40`, a single `SKILL.md`, folder hash `3f43521e...`), the same skill as Opus E22. The pin in `Harness/skillset.py` was not changed. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.3-thin3 UVS_NAME_SUFFIX=-thin3 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-thin3/` (meta, transcript) and `e23-sim/` (summaries and scorecards); control in `runs/e23-control-quiet/uikit-swift-sol/baseline.json`.

## In plain words

- **13 of 13 in all three passes**, stack rule ok, no `import SwiftUI`, no script build phase, no crash.
- **Every speed row is better than the same-sitting control**: cold -11 %, repeated -20 %, stream CPU -10 % (6.63 against 7.35 s), jump -31 %, load older -69 %, text size at the bottom -20 %, mid-list -62 %, peak memory -5 %, app size -4 %.
- **Agent wall time misses the bar**: 2,369 s against at most 1,356 s (+92 % on the control's 1,233). The slowest Sol skill build so far (E21 1,595 s, E19 1,749 s). 123 turns (E21 77), 14 builds with 4 failed, 8.4 M input tokens including 8.26 M cached, 80 k output (E21 6.5 M input, 53 k output). The Codex transcript gives no dollar cost.
- The agent read `SKILL.md` through the skill folder and fetched the public Campfire repository tree with `curl` (as E21 did for the icon set); the app's asset catalog is 0.5 MB this time, the executable 0.76 MB. Noted, not scored.
- Phone passes were not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin3 (E23) | **Does not pass** (misses bar 2 only) | 13 of 13 in 3 of 3 passes, no simulator row worse than the control, but wall 2,369 s against 1,356 s. |
| Against thin2 (E21) | **Rows level, much slower agent** | Cold 117 against 119, repeated 466 against 468, stream 6.63 against 6.46 s, jump 18 against 14, older 8 against 6, text 12 / 10 against 10 / 10 ms, memory 54.9 against 55.1 MB; wall +774 s, turns +46. |

## Against the pass bar (Sol)

| Bar item | E23 thin3 | E21 thin2 |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes |
| 1. Same on the phone | Not run | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (2,369 s, +92 %) | No (1,595 s, +29 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (all better) | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E23 build (thin3) | E23 control (same sitting) | Diff | E21 build (thin2) |
|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 |
| First 40 rows, cold (ms) | 117 [118, 117, 116] | 132 [135, 131, 132] | -11 % | 119 |
| First 40 rows, repeated (ms) | 466 [466, 559, 463] | 579 [577, 579, 586] | -20 % | 468 |
| Stream CPU (s) | 6.63 [6.63, 5.22, 6.66] | 7.35 [7.35, 7.39, 7.29] | -10 % | 6.46 |
| Jump to 2,500 (ms) | 18 [18, 18, 18] | 26 [26, 24, 27] | -31 % | 14 |
| Load older (ms) | 8 [9, 8, 8] | 26 [26, 26, 26] | -69 % | 6 |
| Text size at bottom (ms) | 12 [11, 12, 12] | 15 [14, 15, 15] | -20 % | 10 |
| Text size mid-list (ms) | 10 [10, 10, 10] | 26 [26, 25, 26] | -62 % | 10 |
| Peak memory (MB) | 54.9 [54.9, 55.1, 53.5] | 57.7 [57.3, 57.7, 58.3] | -5 % | 55.1 |
| App size (MB, binary) | 0.76 | 0.79 | -4 % | |

The control's earlier baseline (E21 sitting) was cold 134, repeated 582, stream 7.60, jump 26, older 26, text 15 / 25, memory 57.6, so the control held steady.

## Agent facts

Wall 2,369 s, 123 turns, 14 builds (4 failed), 0 commits, exit 0, not stopped by the limit; 8.4 M input tokens including 8.26 M cached, 80 k output (38 k reasoning). Only `uvs-r3-a` and `uvs-r3-b` were booted.

## What this changes

Thin3 keeps Sol's row results level with thin2 at a third fewer words, so the cut did no harm to the screen. The wall-time miss is the same one every Sol skill build has, and this one is the widest; with one sample per arm it may be noise, and E25 (Sol, no skill) shows what the Sol baseline time is without any skill.
