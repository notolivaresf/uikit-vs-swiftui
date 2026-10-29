# Round 6, E34: Sol + general list skill (`v1.1.0-general1`) against Sol + thin7 (`v1.0.0`), same sitting (28 Oct)

Question (card, 28 Oct): the chat-list skill was copied into a general list skill (message wording turned into item and row wording, 875 words against 826; diff notes are in the private skill repo). Does the general skill do what thin7 does? Tested exactly as E31 (`docs/round5-e31-thin7.md`): same task prompt (outcomes only, no framework or API names), same agent (Sol, `gpt-6.1-sol`, effort high, `codex-cli 0.162.1`), same launch line, stack check, Release simulator build, three `record.sh --sim` passes on `uvs-r3-a`, `scorecard.py --sim`, then the common stopwatch (three passes, the build and the Sol control alternating, one job on the simulator at a time). Corrected wall uses the E31 method (model time = wall minus intervals that end in a finished command, scaled to 54.0 tokens per second).

Runs, one at a time, 28 Oct 21:18 UTC onward, in this order: e34a, e34t, e34b, e34c.

- **e34a, e34b, e34c** (general1): `UVS_NAME_SUFFIX=-e34a UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-list`. The harness got a second pin next to `CHATLIST_TAG`: `LIST_TAG = "v1.1.0-general1"` (`UVS_LIST_TAG` overrides), kind `ours-list`, folder `uikit-list`. The default pin `CHATLIST_TAG = "v1.0.0"` is unchanged. Skill folder hash `e6955bad...`.
- **e34t** (thin7 reference): same line with `--skills ours-chatlist` (default pin v1.0.0). Skill folder hash `d1cccbfa...`, the same as e31a to e31c.
- Isolation: each transcript only reads its own skill's `SKILL.md`. Stack rule ok for all four. No SwiftUI.

Raw data: `runs/sol-uikit-ours-list-e34{a,b,c}/`, `runs/sol-uikit-ours-chatlist-e34t/` (meta, transcript times, `sim/` scorecards), stopwatch in `runs/stopwatch-r5/e34?-general1/`, `e34t-thin7/` and `e34?-control-sol/` (videos git-ignored).

## The table

| Run | Checks (3 passes) | Wall (s) | Turns | Builds (failed) | Output tokens | Tokens/s | Waiting (s) | Corrected (s) | Test commands | Downloads |
|---|---|---|---|---|---|---|---|---|---|---|
| e34a (general1) | 13, 13, 13 | 1,276 | 91 | 16 (0) | 54.5k | 48.6 | 154 | 1,163 | 8 | 0 |
| e34b (general1) | 13, 13, 13 | 1,061 | 68 | 17 (2) | 46.3k | 51.9 | 168 | 1,025 | 10 | 0 |
| e34c (general1) | 13, 13, 13 | 2,846 | 87 | 17 (6) | 62.0k | 23.4 | 197 | 1,345 | 10 | 0 |
| **general1 median of three** | 13 x3 | **1,276** | 87 | 17 (2) | 54.5k | 48.6 | 168 | **1,163** | 10 | 0 |
| **e34t (thin7, same sitting)** | 13, 13, 13 | **1,472** | 73 | 16 (5) | 62.0k | 49.6 | 222 | **1,370** | 8 | 0 |
| thin7 e31a / b / c (earlier same day) | 13 x3 each | 1,922 / 1,511 / 1,597 | 72 / 68 / 60 | 13 (3) / 13 (5) / 14 (3) | 60.4k / 54.2k / 55.9k | 32.9 / 41.8 / 37.8 | 81 / 214 / 117 | 1,200 / 1,217 / 1,153 | 6 / 8 / 8 | 0 |

Test commands are `xcodebuild test`, `test-without-building` and `swift test` calls; downloads are `git clone`, `curl`, `wget`, `sips` and web search calls (none in any run, as in E31).

## Simulator scorecard (median of three passes, app-reported)

| Row | e34a | e34b | e34c | e34t (thin7) |
|---|---|---|---|---|
| Checks | 13 | 13 | 13 | 13 |
| First 40 rows, cold (ms) | 144 | 125 | 130 | 116 |
| First 40 rows, repeated (ms) | 591 | 576 | 486 | 628 |
| Stream CPU (s) | 6.4 | 6.3 | 6.6 | 6.1 |
| Jump, load older, text bottom, text mid (ms) | 21, 14, 21, 17 | 19, 11, 20, 19 | 16, 11, 20, 18 | 23, 12, 18, 19 |
| Peak memory (MB) | 61.9 | 60.3 | 59.4 | 57.8 |
| App size (MB) | 0.72 | 0.68 | 0.73 | 0.75 |

## Stopwatch medians (ms, three passes on `uvs-r3-a`, lower is faster)

Allowance: the larger of 10 % or 17 ms. Build [passes] and the Sol control measured alongside it in the same sitting.

| Row | e34a [passes] | e34b [passes] | e34c [passes] | **general1 median** | **e34t thin7 [passes]** | general1 minus thin7 |
|---|---|---|---|---|---|---|
| Jump to 2,500 | 25.0 [25.0, 23.3, 25.0] | 25.0 [28.3, 25.0, 25.0] | 21.7 [23.3, 21.7, 21.7] | **25.0** | 26.7 [26.7 x3] | -1.7 |
| Load older | 16.7 [13.3, 16.7, 18.3] | 13.3 [13.3 x3] | 16.7 [16.7, 18.3, 16.7] | **16.7** | 15.0 [15.0, 11.7, 16.7] | +1.7 |
| Text size at the bottom | 23.3 [23.3 x3] | 25.0 [25.0 x3] | 23.3 [23.3, 25.0, 23.3] | **23.3** | 23.3 [23.3, 21.7, 23.3] | 0.0 |
| Text size mid-list | 20.0 [21.7, 18.3, 20.0] | 25.0 [25.0, 26.7, 25.0] | 23.3 [23.3 x3] | **23.3** | 23.3 [23.3, 25.0, 23.3] | 0.0 |

Sol control in the same sitting (medians, ms): e34a 38.3 / 38.3 / 23.3 / 33.3; e34b 38.3 / 33.3 / 18.3 / 31.7; e34c 35.0 / 35.0 / 21.7 / 31.7; e34t 40.0 / 38.3 / 21.7 / 31.7 (jump / load older / text bottom / text mid). Both skills are faster than the control on jump and load older (by 10 to 25 ms) and level or a few ms slower on the text rows. The worst single general1 build against its own sitting's control is e34b text bottom, 25.0 against 18.3 (+6.7 ms), inside the allowance. The general1 median is within 1.7 ms of thin7 on every row, a tenth of a frame step.

## Rerun loop and downloads

Test commands were 8, 10 and 10 for general1 against 8 for thin7 (E31: 6, 8, 8). Waiting on commands was 154, 168 and 197 s against 222 s (E31: 81, 214, 117). Nobody downloaded anything. The rerun loop that thin6 had did not come back.

## What misbehaved

- **e34c** took 2,846 s raw, the longest build of the sitting, but not because of the skill or a stall: model speed was 23.4 tokens per second (the others 48.6 to 51.9), with five waits of 150 to 370 s between events (no idle gap over 20 minutes). Its token count (62.0k) is the same as thin7's e34t, and corrected to 54.0 tokens per second it is 1,345 s, inside the thin7 range (1,153 to 1,370). It also had 6 failed builds (thin7: 5 in e34t, 3 to 5 in E31).
- Nothing else. No run hit the time limit, all exited 0, no build skipped a step. A simulator-booting mistake in the harness's shell loop made empty folders under `runs/` (ignored by git).

## Verdict

| Item | Result |
|---|---|
| Both skills scored (checks x3, stopwatch x3) | Yes, four builds |
| 13 of 13 in all passes | **Yes**, general1 nine of nine passes, thin7 three of three |
| Stopwatch, general1 within the larger of 10 % or 17 ms of thin7 | **Yes**, all four rows within 1.7 ms |
| Stopwatch, no row slower than the same-sitting control by more than the allowance | **Yes** |
| Wall and tokens within noise | **Yes**. Raw median 1,276 s against 1,472 s (e34t) and 1,511 to 1,922 s (E31); corrected 1,163 s against 1,370 s (e34t) and 1,153 to 1,217 s (E31); tokens 54.5k against 62.0k (E31 54.2k to 60.4k); turns 87 against 73 (E31 60 to 72) |
| Rerun loop and downloads | Not back (8 to 10 test commands, 0 downloads) |

general1 matches thin7. All 13 checks in every pass, every stopwatch row within 2 ms of thin7 and ahead of the control on jump and load older, and the agent cost sits inside the spread thin7 itself shows (the three E31 builds ranged 1,511 to 1,922 s raw and 54.2k to 60.4k tokens). The one slow run (e34c) is model service speed, not the skill. Turns are the only figure on the high side (87 median, thin7 60 to 73), driven by e34a and e34c, with no matching rise in tokens, waiting or failed builds; three builds cannot say whether that is real. A claim stronger than "matches" would need more than one thin7 build per sitting.
