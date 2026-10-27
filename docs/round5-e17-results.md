# Round 5, E17: validation round 10, the Sol build with the thin skill (`v0.11.0-thin`)

Run 27 Oct (local). Same method as E14 (`docs/round5-e14-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Sol build with nothing else scoring, three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` tag `v0.11.0-thin` (private skill repo `thin` branch, commit `b951349`, folder hash `e6faf41f...`, 4 files; version line inside still reads 0.9.0), installed alone. The Codex login worked this time. Prompt unchanged. Pin: `CHATLIST_TAG` in `Harness/skillset.py` (commit `28db431`; restored to `v0.10.0` after this run because thin did not pass both models). Launch: `UVS_NAME_SUFFIX=-thin UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-thin/e17-sim/` (summaries and scorecards tracked), control in `runs/e17-control-quiet/uikit-swift-sol/baseline.json`.

Rule 6 check (skill not changed): thin keeps v0.10's next-main-queue-turn flush. The Sol build's `RoomViewController.swift` also schedules its flush with `DispatchQueue.main.async` (line 413) and no timer, so the rule was taken here too.

## In plain words

- **Sol with the thin skill passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase.
- **Five of the six rows that were bad in E14 are now better than the control**, and by a lot: jump 12 against 26 ms (-54 %), load older 5 against 26 (-81 %), text size at the bottom 9 against 14 (-36 %), mid-list 9 against 26 (-65 %), repeated first 40 rows level (+1 %). Peak memory 58.5 against 57.2 MB (+2 %; E14 +31 %). Stream CPU 7.87 against 7.39 s (+7 %; E14 -6 %, E12 -2 %).
- **One row fails the 10 % line: first 40 rows, cold**: 172 against 133 ms (+29 %). E14 had the same miss (+28 %); E12 (v0.9.0) had 122 ms.
- **Wall time still misses the bar**: 1,445 s against at most 1,356 s (control 1,233 s, +17 %). Much better than v0.10.0 (2,013 s) and level with v0.9.0 (1,380 s, +12 %). 77 turns (74, 96), 15 builds with 3 failed (11 with 4, 22 with 8).
- **Skill use**: only `SKILL.md`, read twice (the shell command shows twice in the transcript, as in E14). It never opened any reference file. In E14 it also read `measuring-text.md` three times and `table-view.md` once.
- One Sol build is one sample. Phone passes are still pending.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin skill (E17) | **Does not pass** (misses bars 2 and 3 by narrow margins) | 13 of 13 in 3 of 3 passes, but wall time 1,445 s against 1,356 s (+7 % over the bar, +17 % over the control) and first 40 rows cold +29 % over the control. Phone pending. |
| Thin against v0.10.0 for Sol | **Better** | Wall 1,445 against 2,013 s; turns 77 against 96; builds 15 (3 failed) against 22 (8); input tokens 4.6 against 9.0 M. Jump 12 against 50 ms, older 5 against 45, text bottom 9 against 47, mid 9 against 48, memory 58.5 against 76.0 MB, cold 172 against 169 (level). Stream 7.87 against 7.13 s (worse). |
| Thin against v0.9.0 (E12 build) for Sol | **Faster rows, same build time, one row worse** | Wall 1,445 against 1,380 s, turns 77 against 74, input tokens 4.6 against 3.6 M. Jump 12 against 49, older 5 against 40, text bottom 9 against 40, mid 9 against 42, memory 58.5 against 71.2 MB. Cold 172 against 122 ms and stream 7.87 against 7.14 s are worse. |

## Against the pass bar (Sol)

| Bar item | E17 Sol thin | E14 Sol v0.10.0 | E12 Sol v0.9.0 |
|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes | Yes |
| 1. Same on the phone | Pending | Pending | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (1,445 s, +17 %) | No (2,013 s, +63 %) | No (1,380 s, +12 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (1 row: cold +29 %) | No (6 rows) | No (5 rows) |
| 3. Phone hitch rule | Pending | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The control is the Round 2 Sol UIKit tree (Round 3 folder), measured after the build was scored, same simulator and method.

| Row | E17 Sol build (thin) | E17 Sol control (same sitting) | Diff | E14 build (v0.10.0) | E12 build (v0.9.0) |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 172 [172, 168, 172] | 133 [133, 131, 133] | **+29 %** | 169 | 122 |
| First 40 rows, repeated (ms) | 585 [593, 585, 583] | 580 [580, 579, 593] | +1 % | 615 | 178 |
| Stream CPU (s) | 7.87 [7.87, 6.76, 8.09] | 7.39 [7.45, 7.38, 7.39] | +7 % | 7.13 | 7.14 |
| Jump to 2,500 (ms) | 12 [12, 12, 15] | 26 [24, 26, 26] | -54 % | 50 | 49 |
| Load older (ms) | 5 [5, 5, 5] | 26 [26, 26, 26] | -81 % | 45 | 40 |
| Text size at bottom (ms) | 9 [9, 8, 9] | 14 [15, 14, 14] | -36 % | 47 | 40 |
| Text size mid-list (ms) | 9 [9, 8, 10] | 26 [26, 26, 26] | -65 % | 48 | 42 |
| Peak memory (MB) | 58.5 [58.4, 58.5, 58.5] | 57.2 [57.1, 57.4, 57.2] | +2 % | 76.0 | 71.2 |
| App size (MB, binary) | 0.84 | 0.79 | +6 % | 0.74 | 0.73 |

Stream CPU varies between passes in this build (6.76 to 8.09 s); the median is the middle pass. The very low jump, older and text size figures (5 to 12 ms) are a different design from every earlier Sol build; I did not read the code to see why. Control stream moved from 7.60 s (E14) to 7.39 s.

## Agent facts (`meta.json`, transcript)

| | Thin (E17) | v0.9.0 (E12 / `v09r`) | v0.10.0 (E14) | Control (Round 2) |
|---|---|---|---|---|
| Wall (s) | 1,445 | 1,380 | 2,013 | 1,233 |
| Turns | 77 | 74 | 96 | 90 |
| Builds (failed) | 15 (3) | 11 (4) | 22 (8) | 14 (7) |
| Input tokens incl. cached (M) | 4.6 | 3.6 | 9.0 | n/a |
| Output tokens (k) | 51 | 49 | 72 | n/a |

- 0 commits, exit 0, `stopped_by_limit` false, no idle gaps over 20 minutes.
- Skill files read: `SKILL.md` only. The mentions of `references/more-surfaces.md` and others in the transcript are the pointers inside `SKILL.md`, not file reads.
- The code has `isPrefetchingEnabled = false`, a TextKit 1 text view (`init(usingTextLayoutManager: false)`), and a `DispatchQueue.main.async` flush.
- Stack rule ok, `PBXShellScriptBuildPhase` count 0. Isolation: Codex has no skill list; no `SKILL.md` other than `uikit-chat-list` was read.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted after the build and during scoring (`simcap status` 2/2); nothing extra to shut down.

## What this changes

1. **The thin skill helps Sol most.** It undoes v0.10.0's cost (568 s and 19 turns less, 7 fewer builds) and gives the best Sol speed rows of any skill version, ahead of the control on five rows. What is left against the bar is 89 s of wall time (a v0.9.0-sized miss) and the cold first 40 rows.
2. **Across E16 and E17, the thin skill is the best build-time and speed result so far, but neither model passes the bar:** Opus misses on stream CPU (+29 %), Sol on cold first 40 rows (+29 %) and wall time (+7 % over the bar).
3. Open: second Sol build to see whether wall time and cold rows are noise; the timer arm (thin with a 0.1 s flush timer) for the Opus stream row; phone passes.
