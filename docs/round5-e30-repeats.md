# Round 5, E30 repeats: Sol + thin6 (`v0.11.6-thin6`) three times

Linked from `docs/round5-e30-results.md`. Same launch, scoring and stopwatch method as E30, suffixes `-e30b` and `-e30c`, run one at a time. Launch: `UVS_CHATLIST_TAG=v0.11.6-thin6 UVS_NAME_SUFFIX=-e30b UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Scoring: stack check, Release simulator build, three `record.sh --sim` passes on `uvs-r3-a`, `scorecard.py --sim`, then the stopwatch (three passes, build and Sol control alternating). Raw data: `runs/sol-uikit-ours-chatlist-e30b/` (and `-e30c`), stopwatch in `runs/stopwatch-r5/e30b-thin6/`, `e30b-control-sol/` (and e30c).

## E30b (28 Oct, 02:29 to 03:07 UTC)

- Checks 13, 13, 13. Stack rule ok.
- Wall 2,282 s (meta), 101 turns, 21 builds (9 failed), 0 commits, exit 0, not stopped by the limit. 77.6 k output tokens.
- Model speed 38.0 tokens per second (E30 45.8; controls median 54.0); waiting on commands 236 s. Corrected to 54.0: about 1,674 s.
- Stopwatch medians (ms) build [passes] against control [passes]: jump 26.7 [26.7, 28.3, 26.7] / 33.3; load older 6.7 [10.0, 6.7, 5.0] / 31.7; text bottom 23.3 [23.3, 23.3, 21.7] / 18.3; text mid 23.3 [25.0, 23.3, 23.3] / 30.0.

## E30c (28 Oct)

- Checks 13, 13, 13. Stack rule ok. Wall 1,569 s (meta), 80 turns, 19 builds (9 failed), 0 commits, exit 0. 55.9 k output tokens.
- Model speed 41.3 tokens per second; waiting on commands 205 s. Corrected to 54.0: about 1,239 s.
- Stopwatch medians (ms) build [passes] against control [passes]: jump 23.3 [x3] / 33.3; load older 16.7 [x3] / 36.7; text bottom 21.7 [23.3, 21.7, 21.7] / 20.0; text mid 20.0 [x3] / 30.0.
- Scoring ran late (about 3.5 h after the agent stopped) because a wait loop stalled; nothing else ran in between, and the scoring itself was done as for E30 and E30b.

## Median of three

| Run | Checks (3 passes) | Wall (s) | Turns | Builds (failed) | Output tokens | Tokens/s (model time) | Waiting (s) | Speed-corrected (s) | Jump | Load older | Text bottom | Text mid |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| E30 | 13, 13, 13 | 1,938 | 95 | 16 (9) | 71,790 | 45.8 | 370 | 1,699 | 25.0 | 16.7 | 20.0 | 18.3 |
| E30b | 13, 13, 13 | 2,282 | 101 | 21 (9) | 77,612 | 38.0 | 236 | 1,674 | 26.7 | 6.7 | 23.3 | 23.3 |
| E30c | 13, 13, 13 | 1,569 | 80 | 19 (9) | 55,868 | 41.3 | 205 | 1,239 | 23.3 | 16.7 | 21.7 | 20.0 |
| **Median of three** | 13 x3 | **1,938** | 95 | 19 (9) | 71,790 | 41.3 | 236 | **1,674** | 25.0 | 16.7 | 21.7 | 20.0 |
| Sol control, same sittings (median of 9 passes) | | | | | | | | | 33.3 | 31.7 | 20.0 | 30.0 |

Stopwatch columns are ms, medians of three passes on `uvs-r3-a`. Wall in this table is `meta.json` (E30 1,938, E30b 2,282, E30c 1,569); the speed-corrected figure is waiting plus model time scaled to 54.0 tokens per second, same method as `docs/round5-e30-results.md` (reproduces E30's 1,699).

## Against the bars

| Bar | Result |
|---|---|
| 1. 13 of 13, text selection passing | **Yes**, all nine passes |
| 2. Wall at most 1,491 s (control median + 10 %) | **No.** Median raw wall 1,938 s (+30 %); median speed-corrected 1,674 s (+12 %). Only E30c is under the bar (1,569 raw is +5 %; corrected 1,239 s). |
| 3. No row slower than the Sol control by more than max(10 %, 17 ms) | **Yes.** Median build against control median: jump -8.3 ms, load older -15.0, text bottom +1.7 (allowed +17), text mid -10.0. No single build breaches it either (worst: E30b text bottom 23.3 against 18.3, +5.0 ms). |

Against the three same-day controls (1,355 / 1,244 / 1,996 s, median 1,355 s): the median build, 1,938 s raw, is 43 % over the control median and slower than two of three controls; E30c (1,569 s) sits between the two faster controls and the slow one. The spread inside the three builds (1,569 to 2,282 s) is as wide as the spread inside the three controls (1,244 to 1,996 s), and E30b ran at the slowest model speed (38.0 tokens per second), so the corrected figures (1,239 to 1,699 s) are the fairer comparison. Corrected, two of three are over the bar and the median is 12 % over.

Verdict: checks and speed rows hold across three builds; agent wall time does not meet bar 2.
