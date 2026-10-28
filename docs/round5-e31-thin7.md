# Round 5, E31: Sol + thin7 (`v0.11.7-thin7`) against a same-day Sol control (28 Oct)

One build of each, one at a time, on 28 Oct, scored the E30 way (`docs/round5-e30-repeats.md`): stack check, Release simulator build, three `record.sh --sim` passes on `uvs-r3-a`, `scorecard.py --sim`, then the common stopwatch (three passes, the build and the Sol control alternating in the same sitting; `docs/round5-common-stopwatch.md`).

- **ctl28a** (control): `UVS_NAME_SUFFIX=-ctl28a UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-pair`, same as the 27 Oct controls. Agent ran 08:11 to 08:49 UTC.
- **e31a** (thin7): `UVS_CHATLIST_TAG=v0.11.7-thin7 UVS_NAME_SUFFIX=-e31a UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Skill folder hash `d1cccbfa...`. Agent ran 09:14 to 09:46 UTC.

Raw data: `runs/sol-uikit-ours-pair-ctl28a/`, `runs/sol-uikit-ours-chatlist-e31a/` (meta, transcript times, `sim/` scorecards), stopwatch in `runs/stopwatch-r5/ctl28a-ctl/` (the ctl28a build), `ctl28a-control-sol/`, `e31a-thin7/`, `e31a-control-sol/` (videos git-ignored).

## The table

Tokens per second and the corrected time use the same method as `docs/round5-sol-controls-27oct.md` (model time = wall minus intervals that end in a finished command; it reproduces 48.4 for ctl27c and 41.3 for E30c). Corrected = waiting + model time scaled to 54.0 tokens per second. Wall here is `meta.json`.

| Run | Checks (3 passes) | Wall (s) | Turns | Builds (failed) | Output tokens | Tokens/s | Waiting (s) | Corrected (s) |
|---|---|---|---|---|---|---|---|---|
| ctl27a / b / c (27 Oct controls) | 12, 13, 12 | 1,355 / 1,244 / 1,996 | 85 / 74 / 108 | 19 (5) / 16 (8) / 23 (10) | 64.2k / 55.0k / 82.7k | 56.7 / 54.0 / 48.4 | n/a | n/a |
| **ctl28a** (control, today) | 13, 13, 13 | **2,268** | 119 | 22 (13) | 95.3k | 46.9 | 235 | 2,001 |
| thin6 median of three (E30, b, c) | 13 x3 | 1,938 | 95 | 19 (9) | 71.8k | 41.3 | 236 | 1,674 |
| **e31a** (thin7) | 13, 13, 13 | **1,922** | 72 | 13 (3) | 60.4k | 32.9 | 81 | 1,200 |

Bar 2 (wall at most 1,491 s, 27 Oct control median + 10 %): e31a misses on raw wall (+29 %), passes corrected (1,200 s, -20 %). The model ran at 32.9 tokens per second, the slowest of any run so far, so 1,922 s is mostly service speed (the same tokens at 54.0 take about 1,200 s). Against today's control, e31a is 346 s faster raw (-15 %) and 801 s faster corrected. The control itself took 2,268 s today and 95k tokens; with ctl28a the four same-day controls have a median of 1,676 s (1,244, 1,355, 1,996, 2,268), and e31a is 15 % over that median raw, under it corrected.

## Simulator scorecard (median of three passes, app-reported)

| Row | ctl28a | e31a (thin7) | ctl27a | ctl27b | ctl27c | E30c (thin6) |
|---|---|---|---|---|---|---|
| Checks | 13 | 13 | 12 | 13 | 12 | 13 |
| First 40 rows, cold (ms) | 209 | 123 | 215 | 264 | 213 | n/a |
| First 40 rows, repeated (ms) | 659 | 571 | 661 | 708 | 659 | n/a |
| Stream CPU (s) | 11.6 | 6.8 | 11.5 | 10.5 | 11.9 | n/a |
| Jump, load older, text bottom, text mid (ms, app-reported) | 42, 35, 24, 41 | 13, 2, 15, 15 | 57, 26, 20, 43 | 81, 51, 55, 56 | 66, 61, 18, 31 | n/a |
| Peak memory (MB) | 58.5 | 57.6 | 63.9 | 56.6 | 52.9 | n/a |
| App size (MB) | 3.89 | 0.70 | 1.25 | 1.22 | 3.77 | n/a |

## Stopwatch medians (ms, three passes on `uvs-r3-a`, lower is faster)

Each build against the Sol control measured in the same sitting. Allowance: the larger of 10 % or 17 ms.

| Row | ctl28a build [passes] | Control, same sitting | e31a thin7 [passes] | Control, same sitting | thin6 median of three (E30 family) | Control (E30 family, 9 passes) |
|---|---|---|---|---|---|---|
| Jump to 2,500 | 46.7 [50.0, 46.7, 43.3] | 35.0 | 18.3 [18.3, 16.7, 18.3] | 35.0 | 25.0 | 33.3 |
| Load older | 36.7 [36.7, 41.7, 36.7] | 33.3 | 16.7 [16.7 x3] | 30.0 | 16.7 | 31.7 |
| Text size at the bottom | 28.3 [28.3, 30.0, 28.3] | 21.7 | 18.3 [18.3 x3] | 20.0 | 21.7 | 20.0 |
| Text size mid-list | 46.7 [46.7, 48.3, 45.0] | 30.0 | 21.7 [21.7 x3] | 30.0 | 20.0 | 30.0 |

e31a is level with or faster than the control on every row (jump -16.7 ms, load older -13.3, text bottom -1.7, text mid -8.3), so bar 3 holds. ctl28a's own build is slower than the control in the same sitting on three rows (jump +11.7, text bottom +6.6, text mid +16.7 ms), a reminder that the control build is not a reference: text mid-list (+16.7 ms) is right at the 17 ms allowance. The controls' own stopwatch passes (35.0, 30 to 33, 20 to 22, 30) match the E30 family, so the sitting was steady.

## Did thin7 remove the rerun loop and the downloads?

From the command lists in each `transcript.jsonl` (see `docs/round5-thin6-time-breakdown.md` for what to look for).

- **Live-messages test rerun loop: gone in e31a.** e31a ran 6 test commands in total: one whole suite, three runs of `ReferenceGeometryTests` (fast geometry checks), one run that included the live-stream test once among three tests, and one rerun of the anchor test only. The stream test was never rerun on its own, against 5 to 6 runs in E30. Waiting on commands fell to 81 s (thin6 236 s median, controls about 100 to 290 s). Builds failed 3 times, the fewest of any run in the family (thin6 9 each).
- **Image and icon downloads: gone in e31a.** No `git clone`, `curl`, web search, `sips` or icon work in e31a. Reference study time is zero.
- **Today's control still did both.** ctl28a ran 19 test commands, six of them reruns of the same single anchor test (`testPagingTextSizeAndRotationKeepAnchor`) and others of the whole suite, and also did a web search then `curl` of the upstream project's icons and logo images (about 900 to 1,000 s into the run), and image work with PIL. So the habit is Sol's, and thin7 removed it; the control keeps it.

## Verdict

| Item | Result |
|---|---|
| Both builds scored (checks x3, stopwatch x3) | Yes |
| 13 of 13 in all passes | Yes, both |
| Bar 2, raw wall at most 1,491 s | e31a **No** (1,922 s); corrected **Yes** (1,200 s) |
| Bar 3, rows no slower than control | e31a **Yes** |
| Rerun loop and downloads | Gone in e31a; present in ctl28a |

One build per arm and a slow service day (32.9 tokens per second for e31a): one sample is weak evidence for the raw wall, but the counts that do not depend on speed (72 turns, 3 failed builds, 81 s waiting, 6 test commands, no downloads) all moved the right way. A repeat or two of e31a would settle bar 2.

## E31b (28 Oct, 10:15 to 10:40 UTC)

`UVS_CHATLIST_TAG=v0.11.7-thin7 UVS_NAME_SUFFIX=-e31b ...` as e31a. Checks 13, 13, 13; stack ok. Wall 1,511 s, 68 turns, 13 builds (5 failed), 54.2k output tokens, 41.8 tokens/s, waiting 214 s, corrected 1,217 s. Stopwatch medians (ms) build [passes] against control in the same sitting: jump 20.0 [20.0, 25.0, 20.0] / 35.0; load older 16.7 [x3] / 35.0; text bottom 20.0 [x3] / 20.0; text mid 18.3 [x3] / 26.7. Raw data: `runs/sol-uikit-ours-chatlist-e31b/`, `runs/stopwatch-r5/e31b-thin7/`, `e31b-control-sol/`.

## E31c (28 Oct, 11:08 to 11:34 UTC)

Checks 13, 13, 13; stack ok. Wall 1,597 s, 60 turns, 14 builds (3 failed), 55.9k output tokens, 37.8 tokens/s, waiting 117 s, corrected 1,153 s. Stopwatch medians (ms) build [passes] / control in the same sitting: jump 18.3 [18.3, 18.3, 20.0] / 33.3; load older 15.0 [16.7, 15.0, 15.0] / 33.3; text bottom 23.3 [x3] / 20.0; text mid 21.7 [21.7, 23.3, 21.7] / 28.3. Raw data: `runs/sol-uikit-ours-chatlist-e31c/`, `runs/stopwatch-r5/e31c-thin7/`, `e31c-control-sol/`.

## Median of three (e31a, e31b, e31c)

| Run | Checks (3 passes) | Wall (s) | Turns | Builds (failed) | Output tokens | Tokens/s | Waiting (s) | Corrected (s) | Jump | Load older | Text bottom | Text mid |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| e31a | 13 x3 | 1,922 | 72 | 13 (3) | 60.4k | 32.9 | 81 | 1,200 | 18.3 | 16.7 | 18.3 | 21.7 |
| e31b | 13 x3 | 1,511 | 68 | 13 (5) | 54.2k | 41.8 | 214 | 1,217 | 20.0 | 16.7 | 20.0 | 18.3 |
| e31c | 13 x3 | 1,597 | 60 | 14 (3) | 55.9k | 37.8 | 117 | 1,153 | 18.3 | 15.0 | 23.3 | 21.7 |
| **Median of three** | 13 x3 | **1,597** | 68 | 13 (3) | 55.9k | 37.8 | 117 | **1,200** | **18.3** | **16.7** | **20.0** | **21.7** |
| Control, same sitting (median of the three sittings' medians) | | | | | | | | | 35.0 | 33.3 | 20.0 | 28.3 |

Simulator scorecard medians for e31b / e31c: first 40 cold 138 / 136 ms, repeated 586 / 586 ms, stream CPU 6.7 / 7.5 s, app-reported jump 17 / 14, load older 10 / 8, text bottom 17 / 18, text mid 15 / 16 ms, memory 56.8 / 52.8 MB, app size 0.72 / 0.74 MB.

## Against the bars (median of three)

| Bar | Result |
|---|---|
| 1. 13 of 13 | **Yes**, all nine passes |
| 2. Wall at most 1,491 s, raw and corrected | Corrected **Yes** (1,200 s, -20 %). Raw **No** (1,597 s, +7 % over the bar, 106 s); only e31b (1,511 s, 20 s over) came close, and none of the three is under 1,491 s. Model speed was 32.9 to 41.8 tokens/s against 54.0 for the 27 Oct controls, so the raw miss is service speed. |
| 3. No stopwatch row slower than control by more than max(10 %, 17 ms) | **Yes**: jump -16.7 ms, load older -16.6, text bottom 0.0, text mid -6.6. Worst single build: e31c text bottom 23.3 against 20.0 (+3.3). |

## Rerun loop and downloads

- **Downloads: stayed gone.** None of e31a, e31b, e31c ran a clone, curl, web fetch or image tool.
- **Live-stream rerun loop: mostly gone.** Test commands per build: 6, 8, 8. No build reran the live-stream test five or six times as E30 did. e31b ran the stream-pinned test on its own twice (after two whole-suite runs); e31c reran the reference geometry test four times. Waiting on commands: 81, 214, 117 s (thin6 median 236 s). Failed builds 3, 5, 3 (thin6 9).

Verdict: FAIL on bar 2 raw wall (median 1,597 s against 1,491 s); bars 1 and 3 and the speed-corrected wall pass.
