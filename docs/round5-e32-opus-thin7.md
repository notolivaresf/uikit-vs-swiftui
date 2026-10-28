# Round 5, E32: Opus + thin7 (`v0.11.7-thin7`), one build (28 Oct)

thin7 passed the Sol repeats (`docs/round5-e31-thin7.md`), so it is now pinned: `uikit-skill` main is at `f4c7acc` (tag `v0.11.7-thin7` kept) and `Harness/skillset.py` has `CHATLIST_TAG = "v0.11.7-thin7"`. E32 is the first Opus build with it.

Launch: `UVS_CHATLIST_TAG=v0.11.7-thin7 UVS_NAME_SUFFIX=-e32 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. The init event listed exactly `uikit-chat-list` (folder hash `d1cccbfa...`), no time-limit stop, 13:22 to 13:57 UTC. Scored the usual way: stack check ok (no SwiftUI, no script build phase), Release simulator build, three `record.sh --sim` passes on `uvs-r3-a`, then the common stopwatch, three passes with the Opus control (Round 2 Opus tree) alternating in the same sitting.

Raw data: `runs/opus-uikit-ours-chatlist-e32/` (meta, skillset, `e32-sim/` scorecards), `runs/stopwatch-r5/e32-thin7-s/` and `e32-control-opus-s/`. The other `e32*` stopwatch folders there are failed attempts (see the note at the end) and hold no readings.

## The row

Output tokens are the run's final usage figure. Tokens per second is output over model time (wall minus the time between a command and its result; for Claude runs that waiting is under 20 s). Corrected wall = waiting + output tokens at 76.4 tokens per second, the median speed of the five earlier Opus chat-list builds, so runs from different service speeds compare.

| Run | Checks (3 passes) | Wall (s) | Turns | Builds (failed) | Output tokens | Tokens/s | Corrected (s) |
|---|---|---|---|---|---|---|---|
| v09 (27 Oct) | 13 | 2,115 | 62 | 11 (0) | 147.2k | 70.0 | 1,936 |
| v09b | 13 | 2,221 | 62 | 9 (1) | 130.4k | 59.0 | 1,715 |
| thin4 (E26) | 13 | 1,546 | 46 | 8 (0) | 121.0k | 78.7 | 1,591 |
| thin4b (E28) | 13 | 1,807 | 72 | 12 (1) | 136.8k | 76.4 | 1,806 |
| ours-pair control (19 Oct) | 13 | 2,231 | 95 | 12 (0) | 169.4k | 76.6 | 2,236 |
| **e32 (thin7)** | **13, 13, 13** | **2,108** | **55** | **11 (0)** | **108.3k** | **51.6** | **1,427** |

e32 used the fewest tokens of any Opus build in the family (108k, thin4 121k) and had no failed build. Its raw wall (2,108 s) is under the Opus bar of 2,454 s but not the fastest, because the model ran at 51.6 tokens per second, the slowest Opus speed in the table; corrected it is the fastest (1,427 s).

## Simulator scorecard (median of three passes, app-reported)

| Row | e32 | v09 | v09b | thin4 | thin4b |
|---|---|---|---|---|---|
| Checks | 13 | 13 | 13 | 13 | 13 |
| First 40 rows, cold / repeated (ms) | 135 / 546 | 139 / 574 | 145 / 580 | 122 / 496 | 152 / 617 |
| Stream CPU (s) | 6.58 | 5.94 | 5.96 | 6.57 | 6.31 |
| Jump, load older, text bottom, text mid (ms) | 69, 54, 58, 69 | 44, 43, 41, 42 | 44, 41, 41, 44 | 36, 17, 22, 25 | 44, 45, 45, 50 |
| Peak memory (MB) | 57.4 | 54.1 | 54.8 | 52.3 | 56.4 |
| App size (MB) | 0.80 | 0.77 | 0.76 | 0.79 | 0.77 |

The app-reported times start and stop at different moments in each build (`docs/round5-list-code-diff.md`), so compare the stopwatch rows below, not these four.

## Stopwatch medians (ms, three passes on `uvs-r3-a`, lower is faster)

Allowance: the larger of 10 % or 17 ms over the control in the same sitting.

| Row | e32 [passes] | Opus control, same sitting [passes] | Difference | thin4 (E26) | thin4b (E28) |
|---|---|---|---|---|---|
| Jump to 2,500 | 23.3 [23.3, 23.3, 25.0] | 33.3 [35.0, 33.3, 33.3] | -10.0 | 25.0 | 20.0 |
| Load older | 5.0 [6.7, 5.0, 5.0] | 18.3 [33.3, 18.3, 16.7] | -13.3 | 5.9 | 33.3 |
| Text size at the bottom | 21.7 [x3] | 18.3 [16.7, 18.3, 18.3] | +3.3 | 16.7 | 15.0 |
| Text size mid-list | 25.0 [x3] | 23.3 [x3] | +1.7 | 21.7 | 21.7 |

No row is slower than the control by more than the allowance (worst: text bottom +3.3 ms). Load older at 5.0 ms is the same very low reading E26 had; it is the first frame, since that row's list does not change and the label is read.

## Verdict

| Item | Result |
|---|---|
| 13 of 13 in all three passes | Yes |
| Stack rule | ok |
| Wall at most 2,454 s (Opus bar) | Yes, 2,108 s raw, 1,427 s corrected |
| No stopwatch row slower than control by more than the allowance | Yes |

One Opus build is one sample; E26 and E28 showed up to 28 ms of build-to-build spread on load older. What this shows: thin7 works for Opus as it did for Sol, with the lowest token use and no failed builds so far.

## Note on the stopwatch run

The first scoring attempt ran the record passes and the stopwatch at the same time on `uvs-r3-a` (the build queue has two slots), and I stopped both. The killed video recorder left the simulator in a "host recording already in progress" state, so two stopwatch attempts read nothing. I restarted `uvs-r3-a` (shutdown, boot; no erase) and reran the record passes (`e32r`) and the stopwatch (`-s` folders) alone, in that order. All numbers above are from those clean reruns. Lesson for the runbook: never queue two simulator jobs on one simulator.
