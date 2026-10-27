# Round 5, E29: validation round 17, the Sol build with the thin5 skill (`v0.11.5-thin5`)

Run 27 Oct (local). Same method as E27 (`docs/round5-e27-results.md`): Sol build (nothing scoring), stack check, Release simulator build, three scored passes on `uvs-r3-a`, and the common stopwatch (`docs/round5-common-stopwatch.md`) for the four timed rows, three passes, with the Sol control (Round 3 UIKit Swift Sol folder) re-measured on the film in the same sitting. Skill `uikit-chat-list` tag `v0.11.5-thin5` (commit `0c9fc8c`, one `SKILL.md`, version 0.9.0, folder hash `fb08a2fb...`); thin5 adds a top-row margin rule meant to fix E27's failed text-size check. Pin in `Harness/skillset.py` unchanged; prompt unchanged. Codex weekly use was 1 % before the launch. Launch: `UVS_CHATLIST_TAG=v0.11.5-thin5 UVS_NAME_SUFFIX=-thin5 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-thin5/` (meta, transcript, times, `e29-sim/` summaries and scorecards); stopwatch passes in `runs/stopwatch-r5/e29-thin5/` and `runs/stopwatch-r5/e29-control-sol/` (videos are git-ignored).

## In plain words

- **13 of 13 in all three passes.** The text-size check that keeps the top row in place **now passes** (it failed 3 of 3 in E27). Stack rule ok. One sample per arm, so this is consistent with the margin rule working but does not prove it.
- **Agent wall time misses the bar**: 1,799 s against at most 1,356 s (+33 % on the bar, +46 % on the control's 1,233 s). Better than E27 (2,279 s), E23 (2,366 s) and E25 no skill (1,954 s); worse than E21 (1,593 s). 99 turns (E27 108), 21 builds with 4 failed, 0 commits, exit 0, not stopped by the limit. 8.8 M input tokens including 8.7 M cached, 74 k output (35 k reasoning).
- **Stopwatch rows: none slower than the control** (bar 3 met). Jump -29 %, load older -47 %, text mid-list -19 %, text at the bottom level.
- The agent read `SKILL.md` once with `cat` (turn 4). It created its own simulator with `simctl create` and used `curl` for reference assets as in earlier Sol builds; nothing deleted. Phone passes not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin5 (E29) | **MISS (bar 2)** | 13 of 13 in 3 of 3 passes, rows level or better than the control on the stopwatch, wall 1,799 s against 1,356 s. |
| Against thin4 (E27) | **Check regained, 480 s faster** | Check 12 to 13; wall -480 s, turns -9. App-reported rows level (cold 134 against 122, repeated 545 against 478, stream 6.89 against 6.66 s, memory 57.6 against 52.0 MB). |

## Against the pass bar (Sol)

| Bar item | E29 thin5 | E27 thin4 | E23 thin3 |
|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | No (12) | Yes |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (1,799 s, +33 %) | No (2,279 s) | No (2,369 s) |
| 3. No row slower than the control by more than 10 % or 17 ms, whichever is larger (rule of 27 Oct) | **Yes** (worst: text at the bottom 21.7 against 21.7, level) | Yes | Yes |

## Stopwatch rows, median of three passes (ms, lower is faster)

Both columns measured in this sitting on `uvs-r3-a`. Allowance per row: the larger of 10 % or 17 ms.

| Row | E29 thin5 [passes] | Control, same sitting [passes] | Diff | Allowed | Control earlier (stopwatch doc) |
|---|---|---|---|---|---|
| Jump to 2,500 | 25.0 [25.0, 26.7, 25.0] | 35.0 [36.7, 33.3, 35.0] | -10.0 ms (-29 %) | +17 | 35.0 |
| Load older | 16.7 [16.7, 16.7, 16.7] | 31.7 [31.7, 33.3, 31.7] | -15.0 ms (-47 %) | +17 | 35.0 |
| Text size at the bottom | 21.7 [21.7, 21.7, 21.7] | 21.7 [20.0, 21.7, 21.7] | 0.0 ms (level) | +17 | 20.0 |
| Text size mid-list | 21.7 [21.7, 23.3, 21.7] | 26.7 [26.7, 26.7, 28.3] | -5.0 ms (-19 %) | +17 | 30.0 |

App-reported `ms` from the same taps: thin5 18 / 10 / 16 / 14 (jump, older, bottom, mid), control 26 / 26 / 15 / 26.

## Simulator scorecard, median of three passes, quiet

| Row | E29 build (thin5) | E27 build (thin4) | E27 control (earlier sitting) |
|---|---|---|---|
| Checks passed | 13, 13, 13 | 12, 12, 12 | 13, 13, 13 |
| First 40 rows, cold (ms) | 134 [136, 133, 134] | 122 | 132 |
| First 40 rows, repeated (ms) | 545 [543, 545, 545] | 478 | 582 |
| Stream CPU (s) | 6.89 [6.79, 6.89, 7.00] | 6.66 | 7.37 |
| Jump to 2,500 (ms, app-reported) | 18 | 17 | 25 |
| Load older (ms, app-reported) | 10 | 10 | 26 |
| Text size at bottom (ms, app-reported) | 16 | 16 | 15 |
| Text size mid-list (ms, app-reported) | 15 | 14 | 26 |
| Peak memory (MB) | 57.6 [58.4, 57.0, 57.6] | 52.0 | 57.3 |
| App size (MB, binary) | 1.40 | 0.76 | 0.79 |

The control scorecard (the `round3-baseline.sh` rows) was not re-measured in this sitting; only the stopwatch rows were, as the stopwatch doc asks. App size here is the size of the `Campfire` executable of the Release simulator build (1,400,040 bytes), which may not be the same measure as the 0.76 shown for E27; not compared.

## Agent time by phase (seconds, approximate)

Method: every event in `transcript.times` charged to the command it belongs to (model time before a call plus its run time), classified by command text with a quick script (rougher than the E27 pass: code written through heredocs and patch commands mostly lands under Reading, and chained edit-and-test commands under Own UI tests). Treat rows as good to a few tens of seconds, and compare thin5 with E27 using the same script below, not with the older E27 table.

| Phase | E29 Sol thin5 (this script) | E27 Sol thin4 (this script) | E27 as published | E23 Sol thin3 | E21 Sol thin2 | E25 Sol none |
|---|---|---|---|---|---|---|
| Reading (prompt, skill, kit, logs; includes some code writing) | 446 | 734 | 408 | 421 | 156 | 197 |
| Reference study (screenshot pixels, icon fetch) | 338 | 354 | 187 | 299 | 5 | 78 |
| Writing app code | 38 | 0 | 354 | 672 | 188 | 306 |
| Builds | 51 | 14 | 209 | 77 | 116 | 51 |
| Simulator by hand | 70 | 34 | 146 | 117 | 102 | 93 |
| Own UI tests (write, build, run, read) | 582 | 858 | 659 | 759 | 898 | 1,174 |
| Messages, final report, other | 273 | 282 | 314 | 20 | 34 | 12 |
| **Wall** | **1,799** | **2,276** | **2,279** | **2,366** | **1,593** | **1,954** |

What it shows: against thin4 on the same script, the saving is in own UI tests (-276 s) and reading (-288 s). The longest single command was 19 s; no hung test run. Reference study (rendering against the screenshots, icon fetch) is still about 340 s, as in every Sol build except E21. The wall time is 443 s over the bar, mostly those three rows.

## Agent facts

Wall 1,799 s, 99 turns, 21 builds (4 failed), 0 commits, exit 0, not stopped by the limit; 8.8 M input tokens including 8.7 M cached, 74 k output (35 k reasoning). The agent created its own simulator with `simctl create`; only `uvs-r3-a` and `uvs-r3-b` were booted for scoring.

## What this changes

1. The thin5 top-row margin rule fixes the text-size check in this sample (13 of 13 three times), with both text-size rows level with or better than the control on the film.
2. Wall time is still the open bar: 1,799 s against 1,356 s. Remaining cost sits in own UI tests (about 580 s), reading (about 450 s) and reference study (about 340 s).
3. Next: a second Sol thin5 sample would tell whether the check holds; separately decide whether the wall bar can be met without telling the agent how to test.
