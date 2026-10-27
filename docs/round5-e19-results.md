# Round 5, E19: validation round 12, the Sol build with the thin skill plus the 0.1 s flush timer (`v0.11.1-thin-timer`)

Run 27 Oct (local). Same method as E17 (`docs/round5-e17-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Sol build with nothing else scoring, three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` tag `v0.11.1-thin-timer` (private skill repo, branch `thin-timer` from `thin`, commit `b063ad3`, folder hash `083f8b95...`, 4 files): `v0.11.0-thin` with rule 6 changed back to v0.9.0's wording, a flush on a 0.1 s timer. Installed alone; Codex has no skill list. The committed pin in `Harness/skillset.py` was not changed; the run used `UVS_CHATLIST_TAG=v0.11.1-thin-timer`. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.1-thin-timer UVS_NAME_SUFFIX=-thintimer UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-thintimer/e19-sim/` (summaries and scorecards tracked), control in `runs/e19-control-quiet/uikit-swift-sol/baseline.json`. This run also serves as a second sample of Sol with a thin skill, to see whether E17's misses were noise.

Rule 6 check: the Sol build's `RoomViewController.swift` flushes on `Timer(timeInterval: 0.1, repeats: true)`, so the timer wording was taken. (It also keeps a separate 0.2 s timer for boosts.)

## In plain words

- **Sol passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase.
- **Stream CPU is better than the control with the timer**: 7.00 against 7.54 s (-7 %). E17 (thin, next-turn flush) was 7.87 against 7.39 s (+7 %).
- **Five rows are far better than the control**: jump 21 against 25 ms (-16 %), load older 6 against 26 (-77 %), text size mid-list 15 against 26 (-42 %), text size at the bottom 14 against 15 (-7 %), repeated first 40 rows level (580 against 581).
- **Two rows fail the 10 % line**: first 40 rows cold 175 against 133 ms (**+32 %**, the same miss as E17 +29 % and E14 +28 %, so it is not noise; E12 with v0.9.0 had 122 ms), and **peak memory 86.5 against 57.8 MB (+50 %)**, worse than E17 (58.5 MB) and level with E14 (76.0 MB) and E12 (71.2 MB). I did not read the code to see why.
- **Wall time misses the bar again**: 1,749 s against at most 1,356 s (+42 % over the control's 1,233 s). E17 had 1,445 s. Turns 93 (77 in E17), builds 17 with 5 failed (15 with 3).
- App size: 1.98 MB for the whole `.app` folder against 0.79 MB for the control, but 1.2 MB of that is the asset catalog (app icons); the executable is 0.73 MB. The earlier docs list the executable, so this row is not comparable until measured the same way; I report both and do not count it.
- One Sol build is one sample. Phone passes are pending.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin + timer (E19) | **Does not pass** (misses bars 2 and 3) | 13 of 13 in 3 of 3 passes, but wall 1,749 s against 1,356 s, first 40 rows cold +32 % and peak memory +50 % over the same-sitting control. Phone pending. |
| Against thin (E17) for Sol | **Not better** | Stream is better (7.00 against 7.87 s) and jump, older and text size are as good or better. Wall 1,749 against 1,445 s, turns 93 against 77, builds failed 5 against 3, tokens 7.0 against 4.6 M, memory 86.5 against 58.5 MB. The cold-rows miss repeats (172, 175 ms), so that one is real. |
| Against v0.9.0 (E12) for Sol | **Faster rows, slower build** | Wall 1,749 against 1,380 s, turns 93 against 74, tokens 7.0 against 3.6 M. Jump 21 against 49, older 6 against 40, text 14 and 15 against 40 and 42. Cold 175 against 122 ms and memory 86.5 against 71.2 MB are worse; stream 7.00 against 7.14 s is level. |
| Against v0.10.0 (E14) for Sol | **Better** | Wall 1,749 against 2,013 s, turns 93 against 96, builds 17 (5 failed) against 22 (8), tokens 7.0 against 9.0 M, every speed row better except cold (175 against 169, level) and memory (86.5 against 76.0 MB). |

## Against the pass bar (Sol)

| Bar item | E19 thin + timer | E17 thin | E14 v0.10.0 | E12 v0.9.0 |
|---|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes | Yes | Yes |
| 1. Same on the phone | Pending | Pending | Pending | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (1,749 s, +42 %) | No (1,445 s, +17 %) | No (2,013 s) | No (1,380 s, +12 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (2 rows: cold +32 %, memory +50 %) | No (1 row: cold +29 %) | No (6 rows) | No (5 rows) |
| 3. Phone hitch rule | Pending | Pending | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The control is the Round 2 Sol UIKit tree (Round 3 folder), measured after the build was scored, same simulator and method.

| Row | E19 Sol build (thin + timer) | E19 Sol control (same sitting) | Diff | E17 build (thin) | E14 build (v0.10.0) | E12 build (v0.9.0) |
|---|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 175 [182, 175, 172] | 133 [133, 133, 131] | **+32 %** | 172 | 169 | 122 |
| First 40 rows, repeated (ms) | 580 [579, 589, 580] | 581 [580, 581, 581] | 0 % | 585 | 615 | 178 |
| Stream CPU (s) | 7.00 [6.63, 7.00, 7.09] | 7.54 [7.55, 7.48, 7.54] | -7 % | 7.87 | 7.13 | 7.14 |
| Jump to 2,500 (ms) | 21 [21, 22, 21] | 25 [25, 25, 27] | -16 % | 12 | 50 | 49 |
| Load older (ms) | 6 [6, 6, 6] | 26 [26, 26, 26] | -77 % | 5 | 45 | 40 |
| Text size at bottom (ms) | 14 [14, 14, 14] | 15 [15, 15, 15] | -7 % | 9 | 47 | 40 |
| Text size mid-list (ms) | 15 [15, 16, 15] | 26 [26, 26, 25] | -42 % | 9 | 48 | 42 |
| Peak memory (MB) | 86.5 [86.5, 86.1, 86.9] | 57.8 [57.8, 58.2, 57.3] | **+50 %** | 58.5 | 76.0 | 71.2 |
| App size (MB) | 1.98 (whole `.app`; executable 0.73) | 0.79 | see text | 0.84 | 0.74 | 0.73 |

## Agent facts (`meta.json`, transcript)

| | Thin + timer (E19) | Thin (E17) | v0.9.0 (E12) | v0.10.0 (E14) | Control (Round 2) |
|---|---|---|---|---|---|
| Wall (s) | 1,749 | 1,445 | 1,380 | 2,013 | 1,233 |
| Turns | 93 | 77 | 74 | 96 | 90 |
| Builds (failed) | 17 (5) | 15 (3) | 11 (4) | 22 (8) | 14 (7) |
| Input tokens incl. cached (M) | 7.0 | 4.6 | 3.6 | 9.0 | n/a |
| Output tokens (k) | 61 | 51 | 49 | 72 | n/a |

- 0 commits, exit 0, `stopped_by_limit` false.
- Skill files read: `SKILL.md` (a `cat` at the start of the run) and `references/more-surfaces.md` once (a full `cat` in the 16th item). Never `measuring-text.md` or `table-view.md`; the other mentions in the transcript are pointers inside the files. E17 read `SKILL.md` only.
- The code has the 0.1 s flush timer, a separate 0.2 s boost timer, `isPrefetchingEnabled = false` and the release strip settings. Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted; nothing extra to shut down.

## What this changes

1. **E17's two misses were not both noise.** Cold first 40 rows is a repeatable +28 to +32 % for Sol across three thin or v0.10 builds (E14, E17, E19) and is not caused by the flush rule. Wall time missed in all four Sol builds with a skill (+12 % to +63 %); this one was the slowest of the thin pair (1,749 against 1,445 s), so the spread between two builds of the same skill is about 300 s, larger than the 89 s E17 missed by.
2. **The timer helps Sol's stream row** (-7 % against +7 % in E17), which is the direction the Opus E16 result predicted. For Opus the timer arm (E18) could not be read because that build crashed.
3. **Peak memory moved a lot between two builds of the same skill** (58.5 then 86.5 MB), so one build is not enough to call a memory result either way.
4. Open: a second Opus timer build with a finished stream; the cold-rows cause for Sol; phone passes.
