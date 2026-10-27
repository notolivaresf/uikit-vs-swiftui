# Round 5, E12: validation round 6, the first Sol build with skill v0.9.0

Run 26 to 27 Oct (local evening). The Sol half of E10 and E11 (`docs/round5-e10-results.md`, `docs/round5-e11-results.md`), which could not run because the Codex login was rejected. Cause and fix: the launchers copied `~/.codex/auth.json` into each build's own Codex folder, so a token refreshed during a build was saved only in that copy and the next build started from a used token. `Harness/codex-auth-sync.sh`, called by `launch-build.sh` and `round3-launch.sh` after the Codex run ends, copies the newer login back (commit `44af7a4`). This build signed in without trouble.

Same method as E7 to E11 (runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Sol build (nothing scoring), three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` v0.9.0 (commit `44afca3`, folder hash `0521b290...`, same as E10 and E11), installed alone. Prompt unchanged. Launch: `UVS_NAME_SUFFIX=-v09r UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist` (`-v09` already held the failed stub). Raw data: scored passes in `runs/sol-uikit-ours-chatlist-v09r/e12-sim/`, control re-measure in `runs/e12-control-quiet/uikit-swift-sol/`; meta, transcript and stderr stay local under `runs/`.

## In plain words

- **Sol with v0.9.0 passes every check**: 13 of 13 in all three passes, text selection and both text size checks included. Stack rule ok, no `import SwiftUI`, no script build phase.
- **But it is slower and heavier than the Sol control on the list numbers.** Against the control measured the same sitting: jump to 2,500 49 ms against 25 ms, load older 40 against 26 ms, text size at the bottom 40 against 15 ms and mid-list 42 against 26 ms, peak memory 71.2 against 57.6 MB (+24 %). Stream CPU is level (7.14 s against 7.31 s, -2 %). The Sol control is a very fast tree on these rows; the ms gaps are small in absolute terms (10 to 25 ms) but they are large in percent and beyond the 10 % bar.
- **One row is far better than the control**: first 40 rows, repeated, 178 ms against 580 ms (-69 %); cold 122 against 133 ms (-8 %). The E7 Sol build (skill v0.6.2) was at 618 ms on that row, so v0.9.0 moved it. I did not look into why.
- **Wall time missed the bar by 24 seconds**: 1,380 s against at most 1,356 s (control 1,233 s, +12 %). 74 turns (control 90), 11 builds of which 4 failed (control 14, 7 failed). E7's Sol build took 1,669 s, so this is faster than before.
- **Against E7's Sol (v0.6.2), v0.9.0 is not better on the rows the skill's new rules target.** Jump 49 against 56 ms, text bottom 40 against 31 ms, memory 71.2 against 59.8 MB, stream 7.14 against 8.37 s. The agent did apply the three v0.9 rules (pixel-snapped row positions in `ChatLayout.swift`, `usingTextLayoutManager: false` in `MessageCell.swift`, `isPrefetchingEnabled = false` in `RoomViewController.swift`), so the rules were found and used; Sol's own tree simply starts from a much lower floor than the Opus control did, and memory went up with this build's design.
- **Phone passes are still pending.** Everything here is simulator (iPhone 17, iOS 26.4) plus the agent's own facts. One Sol build is one sample.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + skill v0.9.0 (E12) | **Does not pass** (misses bars 2 and 3) | 13 of 13 in 3 of 3 passes, but wall time 1,380 s against 1,356 s allowed (+12 %), and five simulator rows more than 10 % worse than the same-sitting control (jump +96 %, load older +54 %, text bottom +167 %, text mid +62 %, memory +24 %). Phone pending. |
| Did v0.9.0 help Sol? | **Not visibly** | Checks were already 13 of 13 at v0.6.2. Stream, wall time and first-40 improved; jump, text bottom and memory did not. |

## Against the pass bar (Sol)

| Bar item | E12 Sol v0.9.0 | E7 Sol v0.6.2 |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes (13, 13, 13) |
| 1. Same on the phone | Pending | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (1,380 s, +12 %) | No (1,669 s, +35 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (5 rows, see below) | No (jump +81 %, text bottom +72 %) |
| 3. Phone hitch rule | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The control is the Round 2 Sol UIKit tree (Round 3 folder), measured after the build was scored, same simulator, same method.

| Row | E12 Sol build (v0.9.0) | E12 Sol control (same sitting) | Diff | E7 Sol build (v0.6.2) | E7 Sol control |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 122 [122, 124, 103] | 133 [134, 133, 131] | -8 % | 144 | 148 |
| First 40 rows, repeated (ms) | 178 [178, 172, 182] | 580 [580, 597, 576] | -69 % | 618 | 594 |
| Stream CPU (s) | 7.14 [7.05, 7.14, 7.18] | 7.31 [7.24, 7.31, 7.54] | -2 % | 8.37 | 7.61 |
| Jump to 2,500 (ms) | 49 [45, 55, 49] | 25 [26, 25, 25] | **+96 %** | 56 | 31 |
| Load older (ms) | 40 [40, 37, 42] | 26 [26, 26, 26] | **+54 %** | 24 | 31 |
| Text size at bottom (ms) | 40 [40, 36, 42] | 15 [14, 15, 15] | **+167 %** | 31 | 18 |
| Text size mid-list (ms) | 42 [42, 42, 48] | 26 [26, 25, 26] | **+62 %** | 32 | 31 |
| Peak memory (MB) | 71.2 [71.2, 71.6, 70.6] | 57.6 [57.6, 57.4, 57.6] | **+24 %** | 59.8 | 58.0 |
| App size (MB) | 0.73 | 0.79 | -8 % | 0.70 | 0.79 |

The control's passes are very tight this sitting (1 to 2 ms spread on the ms rows), so the gaps are not noise from the control. The old single-run baseline of the same tree (Round 3 setup) was jump 38, load older 33, text 20 / 31, memory 59.6 MB, stream 9.84 s, and it failed text selection (12 of 13); the three-run median passes it, as in E7.

## Opus and Sol side by side (skill v0.9.0)

| Row | Opus E10 | Opus E11 | **Sol E12** | Sol control, E12 sitting |
|---|---|---|---|---|
| Checks passed (sim) | 13, 13, 13 | 13, 13, 13 | **13, 13, 13** | 13 |
| Stream CPU (s) | 5.94 | 5.96 | **7.14** | 7.31 |
| Stream vs its control | -8 % | -7 % | **-2 %** | |
| Jump to 2,500 (ms) | 44 | 44 | **49** | 25 |
| Text size bottom / mid (ms) | 41 / 42 | 41 / 44 | **40 / 42** | 15 / 26 |
| First 40 rows cold / repeated (ms) | 139 / 574 | 145 / 580 | **122 / 178** | 133 / 580 |
| Peak memory (MB) | 54.1 | 54.8 | **71.2** | 57.6 |
| Wall time (s) | 2115 | 2221 | **1380** | (1233 build) |
| Turns | 62 | 62 | **74** | (90 build) |
| Builds (failed) | 11 (0) | 9 (1) | **11 (4)** | (14 (7)) |
| Wall bar | met | met | **missed by 24 s** | |

The Opus builds absolute numbers on the Sol-sized rows (jump, text size) are close to Sol's v0.9.0 build (44 and 41 ms against 49 and 40 ms); the difference is the control each is judged against. Opus's control was slow on those rows, Sol's is fast.

## Agent facts (`meta.json`, transcript)

- Wall 1,380 s, 74 turns, 11 builds (4 failed), 0 commits, exit 0, `stopped_by_limit` false. Codex signed in at the first call; no 401.
- Skill use: the transcript shows reads of `SKILL.md` (from `.agents/skills/uikit-chat-list/`), `references/measuring-text.md` (three times) and `references/table-view.md` (once). No other skill file was read.
- In the code: pixel-aligned geometry in `ChatLayout.swift` (`aligned`, 3 px per point), TextKit 1 text views (`usingTextLayoutManager: false`) in `MessageCell.swift`, `isPrefetchingEnabled = false` in `RoomViewController.swift`; a custom layout under the collection view.
- Stack rule ok (`Harness/check-stack.sh uikit`), `PBXShellScriptBuildPhase` count 0.
- Simulators: the agent left a third booted device (`Campfire-Verification`); I shut it down with `xcrun simctl shutdown` right after the build ended and before any scoring. `uvs-r3-a` and `uvs-r3-b` were the only booted devices during scoring (`simcap status`: 2/2).

## What this changes

1. **The Codex login problem is solved in the launcher**, not by logging in again: a refreshed token now flows back to `~/.codex` after every Sol build (both launchers).
2. **v0.9.0 works for Sol on correctness, not on speed.** It passes every check, but a skill aimed at list speed did not close the gap to a Sol control that was already fast on jump, text size and memory. That is one build; Opus shows the same skill gives a clear win against a slower control, so the skill is not wrong, but it has not shown a gain for Sol.
3. **Open for a v1.0 tag:** phone passes for both models, and a second Sol build to see whether the jump, text size and memory rows are the agent's design luck or the skill. If memory (+24 %) repeats, look at what the Sol build keeps per row (its transcript and `ChatLayout.swift` cache) before touching the skill.

## Open items

- Phone passes (iPhone 12), pending for Opus E10, E11 and Sol E12.
- Second Sol build with v0.9.0 (suffix `-v09r2`).
- Not investigated: why first 40 rows, repeated is 178 ms in this build.
- Raw material kept: `runs/sol-uikit-ours-chatlist-v09r/e12-sim/` (summaries and scorecards tracked; meta, transcript, stderr local), `runs/e12-control-quiet/uikit-swift-sol/baseline.json`. The Round 3 Sol control folder now holds this baseline.
