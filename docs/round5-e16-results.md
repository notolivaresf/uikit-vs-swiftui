# Round 5, E16: validation round 9, the Opus build with the thin skill (`v0.11.0-thin`)

Run 27 Oct (local). Same method as E15 (`docs/round5-e15-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.11.0-thin` (the private skill repo's `thin` branch, commit `b951349`, folder hash `e6faf41f...`, 4 files, 1,523 words in the folder against 2,765 for v0.10.0; the version line inside the folder still reads 0.9.0), installed alone; the Opus init skill list was exactly `uikit-chat-list` (`skill_isolation.error` null). The harness pin `CHATLIST_TAG` in `Harness/skillset.py` was set to the tag for this run. Prompt unchanged. Launch: `UVS_NAME_SUFFIX=-thin UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: `runs/opus-uikit-ours-chatlist-thin/e16-sim/` (summaries and scorecards tracked; meta and transcript stay local), control in `runs/e16-control-quiet/uikit-swift-opus/baseline.json`.

Rule 6 check (asked for, skill not changed): **thin keeps v0.10's rule of flushing live messages on the next main-queue turn** ("schedule one flush on the next main-queue turn if none is pending (no timer)"). The agent's code does it: `RoomViewController.swift` line 425 is `DispatchQueue.main.async { [weak self] in self?.flush() }`. The stream row came back +29 % over the control, the same figure as E15.

## In plain words

- **Opus with the thin skill passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase.
- **The agent was the fastest of the three skill versions**: 1,731 s (v0.9.0 2,115 and 2,221 s, v0.10.0 2,914 s, control 2,231 s, bar 2,454 s), 74 turns (62, 62, 109), 13 builds with none failed. Input tokens including cache: 11.0 M (v0.9.0 10.0 M both, v0.10.0 23.3 M). Cost $6.20 (v0.9.0 $6.90 and $6.26, v0.10.0 $10.94).
- **Stream CPU is still +29 % over the control**: 8.31 against 6.45 s (E15: +29 %, E10 and E11: -8 % and -7 %). Same cause as E15 by the code: next-turn flush. This is the one row that fails the bar.
- **Everything else is level or better than the control**: first 40 rows cold -12 %, repeated +3 %, jump -16 %, load older -56 %, text size at the bottom -43 %, mid-list -28 %. The three rows that failed in E15 (text bottom, load older, stream) now pass except stream. Peak memory 57.4 against 53.7 MB (+7 %, inside the 10 % line; E15 -1 %, E10 +0.6 %).
- One build is one sample. Phone passes are still pending.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + thin skill (E16) | **Does not pass** (misses bar 3 on one row) | 13 of 13 in 3 of 3 passes and wall time 1,731 s, but stream CPU +29 % over the same-sitting control. Phone pending. |
| Thin against v0.10.0 for Opus | **Better on everything but stream** | Same checks; wall 1,731 against 2,914 s; turns 74 against 109; input tokens 11.0 against 23.3 M; text bottom 26 against 50 ms; older 17 against 44 ms; stream level (8.31 against 8.09 s). |
| Thin against v0.9.0 for Opus | **Faster to build, one row worse** | Wall 1,731 against 2,115 and 2,221 s, turns 74 against 62, tokens 11.0 against 10.0 M. Stream 8.31 against 5.94 and 5.96 s; memory 57.4 against 54.1 and 54.8 MB. |

## Against the pass bar (Opus)

| Bar item | E16 Opus thin | E15 Opus v0.10.0 | E10 / E11 Opus v0.9.0 |
|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes | Yes / Yes |
| 1. Same on the phone | Pending | Pending | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (1,731 s, -22 % against the control) | No (2,914 s) | Yes / Yes |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (stream +29 %) | No (stream +29 %, text bottom +25 %, older +13 %) | Yes with one caveat / Yes |
| 3. Phone hitch rule | Pending | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets.

| Row | E16 Opus build (thin) | E16 Opus control (same sitting) | Diff | E15 build (v0.10.0) | E10 build (v0.9.0) | E11 build (v0.9.0) |
|---|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 145 [148, 142, 145] | 165 [165, 163, 166] | -12 % | 144 | 139 | 145 |
| First 40 rows, repeated (ms) | 614 [614, 613, 614] | 594 [591, 594, 605] | +3 % | 588 | 574 | 580 |
| Stream CPU (s) | 8.31 [8.31, 8.39, 8.22] | 6.45 [6.45, 6.45, 6.47] | **+29 %** | 8.09 | 5.94 | 5.96 |
| Jump to 2,500 (ms) | 38 [40, 32, 38] | 45 [46, 40, 45] | -16 % | 43 | 44 | 44 |
| Load older (ms) | 17 [17, 11, 22] | 39 [48, 39, 28] | -56 % | 44 | 43 | 41 |
| Text size at bottom (ms) | 26 [24, 26, 31] | 46 [46, 46, 45] | -43 % | 50 | 41 | 41 |
| Text size mid-list (ms) | 31 [33, 29, 31] | 43 [46, 42, 43] | -28 % | 50 | 42 | 44 |
| Peak memory (MB) | 57.4 [57.3, 57.4, 57.4] | 53.7 [54.4, 53.1, 53.7] | +7 % | 53.2 | 54.1 | 54.8 |
| App size (MB, binary) | 0.80 | 0.84 | -5 % | 0.79 | 0.77 | 0.76 |

The control's stream figure is 6.45 s here (6.29 in E15, 6.44 in E10 and E11), passes tight, so +29 % is not control noise. Load older at 11 to 22 ms is far under every earlier build (41 to 44 ms); the control's own passes ran 28 to 48 ms. I did not read the load-older code to see why.

## Agent facts (`meta.json`, transcript)

| | Thin (E16) | v0.9.0 (E10) | v0.9.0 (E11) | v0.10.0 (E15) | Control (Round 2) |
|---|---|---|---|---|---|
| Wall (s) | 1,731 | 2,115 | 2,221 | 2,914 | 2,231 |
| Turns | 74 | 62 | 62 | 109 | 95 |
| Builds (failed) | 13 (0) | 11 (0) | 9 (1) | 14 (1) | 12 (0) |
| Input tokens incl. cache (M) | 11.0 | 10.0 | 10.0 | 23.3 | n/a |
| Cost ($) | 6.20 | 6.90 | 6.26 | 10.94 | n/a |

(E10 and E11 here are the `v09` and `v09b` runs. Turns and builds are the supervisor's `meta.json` counts; tokens and cost are the stream's final result line.)

- 0 commits, exit 0, `stopped_by_limit` false.
- Skill files read: the Skill call at the third turn (`SKILL.md`), and `references/more-surfaces.md` once, at about the 47th message (it ran `head -80` on it). It never opened `measuring-text.md` or `table-view.md`; v0.9.0 and v0.10.0 read `measuring-text.md` three times and `table-view.md` once.
- The code has what the thin rules ask for: `isPrefetchingEnabled = false` and `UITextView(usingTextLayoutManager: false)` (TextKit 1) in `RoomViewController.swift` and `MessageCell.swift`.
- Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted after the build and during scoring (`simcap status` 2/2); nothing extra to shut down.

## What this changes

1. **The thin skill kept every gain except one and removed the build-time cost.** Thinning (-45 % words in the folder) made the Opus build 40 % faster than v0.10.0 with a third of the tokens, and it recovered the text size and load-older rows.
2. **The one failing row is rule 6.** Both v0.10.0 and thin flush on the next main-queue turn and both land +29 % stream CPU; v0.9.0 (timer) was -8 %. The thinning plan's optional arm 3 (thin with the 0.1 s timer) is now the obvious next build: it tests exactly this row. I did not change the skill.
3. Open: Sol with thin (E17); second Opus build; phone passes.
