# Round 5, E14: validation round 7, the Sol build with skill v0.10.0

Run 27 Oct (local). Same method as E12 (`docs/round5-e12-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Sol build with nothing else scoring, three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` tag `v0.10.0` (commit `3e03223`, folder hash `796a9102...`; the version line inside the folder still reads 0.9.0), installed alone. What changed in the skill: `docs/round5-v10-spikes.md`. Prompt unchanged. Pin: commit `67cebb5`. Launch: `UVS_NAME_SUFFIX=-v10 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-v10/e14-sim/` (summaries and scorecards tracked), control in `runs/e14-control-quiet/uikit-swift-sol/baseline.json`.

## In plain words

- **Sol with v0.10.0 passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase. Codex signed in without trouble.
- **It is clearly worse than v0.9.0 and than the control on speed.** Against the control measured the same sitting: jump 50 against 25 ms (+100 %), load older 45 against 26 (+73 %), text size at the bottom 47 against 15 (+213 %), mid-list 48 against 25 (+92 %), peak memory 76.0 against 58.0 MB (+31 %), first 40 rows cold 169 against 132 ms (+28 %). Stream CPU is the one row that is better (7.13 against 7.60 s, -6 %).
- **First 40 rows, repeated, lost the E12 gain**: 615 ms against 578 for the control (+6 %), where v0.9.0 had 178 ms. That was luck of the design, not the skill.
- **Wall time missed the bar by a wide margin**: 2,013 s against at most 1,356 s (+63 % over the control's 1,233 s). 96 turns (E12: 74), 22 builds, 8 failed (E12: 11 and 4), 0 commits.
- **Skill use**: `SKILL.md` read twice, `references/measuring-text.md` three times, `references/table-view.md` once. I did not read the code to see which v0.10 rules (small jump window, cheap measure, next-turn flush) were applied; the numbers (jump and mid-list text size still about 50 ms) suggest the 81-row window or an equivalent cost stayed.
- One Sol build is one sample. Phone passes are still pending.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + skill v0.10.0 (E14) | **Does not pass** (misses bars 2 and 3) | 13 of 13 in 3 of 3 passes, but wall time 2,013 s against 1,356 s (+63 % over the control), and six simulator rows more than 10 % worse than the same-sitting control. Phone pending. |
| v0.10.0 against v0.9.0 for Sol | **Not better, probably worse** | Checks equal (13 of 13). Wall time 2,013 against 1,380 s, memory 76.0 against 71.2 MB, jump 50 against 49, text bottom 47 against 40, mid 48 against 42, first 40 repeated 615 against 178. Only stream CPU is slightly better (7.13 against 7.14 s, level). |

## Against the pass bar (Sol)

| Bar item | E14 Sol v0.10.0 | E12 Sol v0.9.0 |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes (13, 13, 13) |
| 1. Same on the phone | Pending | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (2,013 s, +63 %) | No (1,380 s, +12 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (6 rows) | No (5 rows) |
| 3. Phone hitch rule | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The control is the Round 2 Sol UIKit tree (Round 3 folder), measured after the build was scored, same simulator and method.

| Row | E14 Sol build (v0.10.0) | E14 Sol control (same sitting) | Diff | E12 Sol build (v0.9.0) | E12 Sol control |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 169 [169, 189, 166] | 132 [134, 132, 131] | **+28 %** | 122 | 133 |
| First 40 rows, repeated (ms) | 615 [605, 624, 615] | 578 [583, 577, 578] | +6 % | 178 | 580 |
| Stream CPU (s) | 7.13 [7.49, 6.44, 7.13] | 7.60 [7.64, 7.44, 7.60] | -6 % | 7.14 | 7.31 |
| Jump to 2,500 (ms) | 50 [45, 56, 50] | 25 [24, 26, 25] | **+100 %** | 49 | 25 |
| Load older (ms) | 45 [45, 49, 44] | 26 [26, 26, 24] | **+73 %** | 40 | 26 |
| Text size at bottom (ms) | 47 [43, 47, 49] | 15 [15, 14, 15] | **+213 %** | 40 | 15 |
| Text size mid-list (ms) | 48 [48, 48, 46] | 25 [26, 25, 25] | **+92 %** | 42 | 26 |
| Jump to 2,500 (ms) | 50 [45, 56, 50] | 25 [24, 26, 25] | **+100 %** | 49 | 25 |
| Load older (ms) | 45 [45, 49, 44] | 26 [26, 26, 24] | **+73 %** | 40 | 26 |
| Text size at bottom (ms) | 47 [43, 47, 49] | 15 [15, 14, 15] | **+213 %** | 40 | 15 |
| Text size mid-list (ms) | 48 [48, 48, 46] | 25 [26, 25, 25] | **+92 %** | 42 | 26 |
| Peak memory (MB) | 76.0 [76.0, 75.7, 76.0] | 58.0 [58.3, 58.0, 57.5] | **+31 %** | 71.2 | 57.6 |
| App size (MB, binary) | 0.74 | 0.79 | -6 % | 0.73 | 0.79 |

## Agent facts (`meta.json`, transcript)

- Wall 2,013 s, 96 turns, 22 builds (8 failed), 0 commits, exit 0, `stopped_by_limit` false.
- Skill files read: `SKILL.md` (2), `measuring-text.md` (3), `table-view.md` (1).
- Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted after the build (`simcap status` 2/2); nothing extra to shut down.

## What this changes

1. **v0.10.0 did not move Sol on any row the spikes targeted** (jump, mid-list text size, memory). The spike gains (jump 49 to 33 ms with a 41-row window, and so on) did not appear in the agent's build, so either the agent did not take the rules, or the rules are not strong enough as written. This needs the code read: window size in the jump, header measure, flush.
2. **Slower to build** than v0.9.0 by 633 s and 22 turns; more words in the skill's references may cost time, one sample.
3. Open: read `runs/sol-uikit-ours-chatlist-v10` transcript against the v0.10 rules; second Sol build; phone passes.
