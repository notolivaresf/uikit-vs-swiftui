# Round 5, E15: validation round 8, the Opus build with skill v0.10.0

Run 27 Oct (local). Same method as E10 and E11 (`docs/round5-e10-results.md`, `docs/round5-e11-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.10.0` (commit `3e03223`, folder hash `796a9102...`), installed alone; the Opus init skill list was exactly `uikit-chat-list`. What changed in the skill: `docs/round5-v10-spikes.md`. Prompt unchanged. Pin: commit `67cebb5`. Launch: `UVS_NAME_SUFFIX=-v10 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: `runs/opus-uikit-ours-chatlist-v10/e15-sim/` (summaries and scorecards tracked), control in `runs/e15-control-quiet/uikit-swift-opus/baseline.json`.

## In plain words

- **Opus with v0.10.0 passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase.
- **But the three speed rows E9 to E11 had closed are open again.** Against the control measured the same sitting: stream CPU 8.09 against 6.29 s (+29 %; E10 -8 %, E11 -7 %), text size at the bottom 50 against 40 ms (+25 %), load older 44 against 39 ms (+13 %). Text size mid-list is +9 % and jump +2 %. Memory is level (53.2 against 53.8 MB, -1 %) and first 40 rows is level or better (cold -11 %, repeated 0 %).
- **Wall time missed the bar**: 2,914 s against at most 2,454 s (control 2,231 s, +31 %). 109 turns (E10 and E11: 62), 14 builds of which 1 failed. E10 and E11 took 2,115 and 2,221 s.
- **Skill use**: `SKILL.md` and `references/measuring-text.md` (three reads) and `references/table-view.md` (one read), as in the earlier builds. I did not read the code to see which v0.10 rules the agent used; the stream row (+29 %) is where v0.10 deliberately costs CPU (rule 8: next main-queue turn instead of the 0.1 s timer; the spikes measured +27 % CPU at 20 messages a second for about 60 ms less delay per message), so that part is consistent with what the skill now asks for. The scorecard does not count the delay gain.
- One build is one sample. Phone passes are still pending.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + skill v0.10.0 (E15) | **Does not pass** (misses bars 2 and 3) | 13 of 13 in 3 of 3 passes, but wall time 2,914 s against 2,454 s (+31 % over the control) and three simulator rows more than 10 % worse than the same-sitting control (stream +29 %, text bottom +25 %, load older +13 %). Phone pending. |
| v0.10.0 against v0.9.0 for Opus | **Worse on the scorecard** | Checks equal. Stream 8.09 against 5.94 and 5.96 s, wall time 2,914 against 2,115 and 2,221 s, turns 109 against 62. Memory, jump and first 40 rows are level. The one gain the spikes promised that the scorecard cannot see is live-message delay. |

## Against the pass bar (Opus)

| Bar item | E15 Opus v0.10.0 | E10 / E11 Opus v0.9.0 |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes / Yes |
| 1. Same on the phone | Pending | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **No** (2,914 s, +31 %) | Yes (2,115 s) / Yes (2,221 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (stream +29 %, text bottom +25 %, older +13 %) | Yes with one caveat / Yes |
| 3. Phone hitch rule | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets.

| Row | E15 Opus build (v0.10.0) | E15 Opus control (same sitting) | Diff | E10 build (v0.9.0) | E11 build (v0.9.0) |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 144 [144, 151, 144] | 162 [167, 159, 162] | -11 % | 139 | 145 |
| First 40 rows, repeated (ms) | 588 [589, 586, 588] | 589 [587, 589, 596] | 0 % | 574 | 580 |
| Stream CPU (s) | 8.09 [8.06, 8.09, 8.10] | 6.29 [6.29, 6.28, 6.36] | **+29 %** | 5.94 | 5.96 |
| Jump to 2,500 (ms) | 43 [43, 48, 41] | 42 [50, 42, 42] | +2 % | 44 | 44 |
| Load older (ms) | 44 [44, 47, 44] | 39 [36, 42, 39] | **+13 %** | 43 | 41 |
| Text size at bottom (ms) | 50 [50, 52, 49] | 40 [40, 38, 40] | **+25 %** | 41 | 41 |
| Text size mid-list (ms) | 50 [50, 50, 42] | 46 [46, 46, 42] | +9 % | 42 | 44 |
| Peak memory (MB) | 53.2 [53.2, 53.2, 53.4] | 53.8 [53.8, 53.9, 53.7] | -1 % | 54.1 | 54.8 |
| App size (MB, binary) | 0.79 | 0.84 | -6 % | 0.77 | 0.76 |

The control's own stream figure moved between sittings (6.29 s here, 6.44 s in E10 and E11), and its passes are tight (spread under 0.1 s), so the +29 % is not control noise.

## Agent facts (`meta.json`, transcript)

- Wall 2,914 s, 109 turns, 14 builds (1 failed), 0 commits, exit 0, `stopped_by_limit` false, skill isolation ok (`uikit-chat-list` only).
- Skill files read: `SKILL.md`, `measuring-text.md` (3), `table-view.md` (1).
- Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted after the build and during scoring (`simcap status` 2/2); nothing extra to shut down.

## What this changes

1. **v0.10.0 did not help either model on the scorecard.** Sol (E14) and Opus (E15) both pass 13 of 13, but both are slower to build and worse on rows v0.9.0 had under control. v0.9.0 stays the better tag for the benchmark's bars.
2. **Live-message delay is the one v0.10 gain the scorecard cannot see.** If it matters, the scorecard needs a delay row before v0.10 is judged; otherwise rule 8 trades 27 % CPU for nothing the bar counts.
3. Open: read this build's stream code against rule 8 (next-turn flush) to confirm that is where the +29 % comes from; second Opus build; phone passes.
