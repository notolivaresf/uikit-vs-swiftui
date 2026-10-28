# Round 5, E30: validation round 18, the Sol build with the thin6 skill (`v0.11.6-thin6`)

Run 27 to 28 Oct (local; the agent ran 01:27 to 01:59 UTC on 28 Oct). Same method as E29 (`docs/round5-e29-results.md`): Sol build (nothing scoring), stack check, Release simulator build, three scored passes on `uvs-r3-a`, and the common stopwatch (`docs/round5-common-stopwatch.md`) for the four timed rows, three passes, with the Sol control (Round 3 UIKit Swift Sol folder) re-measured on the film in the same sitting. Skill `uikit-chat-list` tag `v0.11.6-thin6`. Pin in `Harness/skillset.py` unchanged; prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.6-thin6 UVS_NAME_SUFFIX=-e30 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-e30/` (meta, transcript times, `e30-sim/` summaries and scorecards); stopwatch passes in `runs/stopwatch-r5/e30-thin6/` and `runs/stopwatch-r5/e30-control-sol/` (videos are git-ignored).

## In plain words

- **13 of 13 in all three passes.** Stack rule ok. The text-size check that keeps the top row in place passes again (second sample in a row after E29).
- **Agent wall time misses the new bar**: 1,938 s against at most 1,491 s (+30 %). Slower than E29 (1,799 s). 95 turns, 16 builds with 9 failed, 0 commits, exit 0, not stopped by the limit. 7.5 M input tokens including 7.3 M cached, 71.8 k output (34 k reasoning).
- **Speed-corrected, still over**: the model ran at 45.8 tokens per second against the controls' 54.0 median. Replayed at 54.0 the wall would be about 1,699 s, still 14 % over the bar. The build also spent 370 s waiting on commands (E29: 128 s), which speed does not change.
- **Stopwatch rows: none slower than the control** (bar 3 met). Jump -29 %, load older -47 %, text mid-list -39 %, text at the bottom level.
- Phone passes not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin6 (E30) | **MISS (bar 2)** | 13 of 13 in 3 of 3 passes, every stopwatch row level or better than the control, wall 1,938 s against 1,491 s. |
| Against thin5 (E29) | **Same checks, rows level, slower to build** | Wall +139 s, turns -4, builds failed 9 against 4. App-reported rows level or better (cold 117 against 134 ms, repeated 470 against 545 ms, stream 6.35 against 6.89 s). |

## Against the pass bar (Sol)

| Bar item | E30 thin6 | E29 thin5 |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes |
| 2. Wall time at most 1,491 s (median of three same-day controls + 10 %) | **No** (1,938 s, +30 %; corrected 1,699 s, +14 %) | No (1,797 s; corrected 1,491 s, on the bar) |
| 3. No row slower than the control by more than 10 % or 17 ms, whichever is larger | **Yes** (worst: text at the bottom 20.0 against 20.0, level) | Yes |

## Wall time against the controls

| Run | Wall (s) | Turns | Output tokens | Tokens/s (model time) | Tokens/s (wall) | Waiting on commands (s) |
|---|---|---|---|---|---|---|
| ctl27a | 1,355 | 85 | 64,203 | 56.7 | 47.4 | n/a |
| ctl27b | 1,244 | 74 | 55,037 | 54.0 | 44.2 | n/a |
| ctl27c | 1,996 | 108 | 82,738 | 48.4 | 41.5 | n/a |
| E29 thin5 | 1,797 | 99 | 73,613 | 44.1 | 41.0 | 128 |
| **E30 thin6** | **1,936** | **95** | **71,790** | **45.8** | **37.1** | **370** |

Same method as `docs/round5-sol-controls-27oct.md` (model time = wall minus intervals that end in a finished command; it reproduces 44.1 for E29). Wall by the transcript is 1,936 s; `meta.json` says 1,938 s. Adjusted to 54.0 tokens per second: waiting 370 + model time 1,567 x 45.8 / 54.0 = about 1,699 s. Tokens are close to E29 (71.8 k against 73.6 k); the extra time is mostly waiting on commands (+242 s) with 9 failed builds, and the lower tokens per second.

## Stopwatch rows, median of three passes (ms, lower is faster)

Both columns measured in this sitting on `uvs-r3-a`. Allowance per row: the larger of 10 % or 17 ms.

| Row | E30 thin6 [passes] | Control, same sitting [passes] | Diff | Allowed | E29 thin5 | E29 control |
|---|---|---|---|---|---|---|
| Jump to 2,500 | 25.0 [25.0, 26.7, 25.0] | 35.0 [35.0, 35.0, 35.0] | -10.0 ms (-29 %) | +17 | 25.0 | 35.0 |
| Load older | 16.7 [16.7, 16.7, 15.0] | 31.7 [31.7, 30.0, 35.0] | -15.0 ms (-47 %) | +17 | 16.7 | 31.7 |
| Text size at the bottom | 20.0 [20.0, 18.3, 20.0] | 20.0 [20.0, 20.0, 20.0] | 0.0 ms (level) | +17 | 21.7 | 21.7 |
| Text size mid-list | 18.3 [18.3, 18.3, 18.3] | 30.0 [30.0, 26.7, 31.7] | -11.7 ms (-39 %) | +17 | 21.7 | 26.7 |

App-reported `ms` from the same taps: thin6 17 / 10 / 15 / 14 (jump, older, bottom, mid), control 26 / 26 / 15 / 26.

## Simulator scorecard, median of three passes, quiet

| Row | E30 build (thin6) | E29 build (thin5) | E27 control (earlier sitting) |
|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 117 [117, 117, 114] | 134 | 132 |
| First 40 rows, repeated (ms) | 470 [470, 471, 470] | 545 | 582 |
| Stream CPU (s) | 6.35 [6.27, 6.35, 6.39] | 6.89 | 7.37 |
| Jump to 2,500 (ms, app-reported) | 17 | 18 | 25 |
| Load older (ms, app-reported) | 10 | 10 | 26 |
| Text size at bottom (ms, app-reported) | 15 | 16 | 15 |
| Text size mid-list (ms, app-reported) | 14 | 15 | 26 |
| Peak memory (MB) | 55.1 [55.1, 55.1, 55.1] | 57.6 | 57.3 |
| App size (MB, binary) | 0.74 | 1.40 | 0.79 |

The control scorecard (`round3-baseline.sh` rows) was not re-measured in this sitting; only the stopwatch rows were, as the stopwatch doc asks.

## Agent facts

Wall 1,938 s, 95 turns, 16 builds (9 failed), 0 commits, exit 0, not stopped by the limit; 7.5 M input tokens including 7.3 M cached, 71.8 k output (34 k reasoning). Only `uvs-r3-a` and `uvs-r3-b` were booted for scoring; nothing was shut down, deleted or erased.

## What this changes

1. thin6 holds what thin5 gained: 13 of 13 three times, every stopwatch row level with or better than the control, and the app-reported rows and memory a little better than thin5.
2. Wall time is the only open bar, and E30 is further from it than E29: 1,938 s against 1,491 s, 14 % over even when corrected for speed. The extra cost is waiting on commands (370 s, 9 failed builds), not tokens.
3. Against the best control run (1,244 s) every build misses; against the control median the spread of the controls (1,244 to 1,996 s) is wider than the gap, so one sample either way is weak evidence.
