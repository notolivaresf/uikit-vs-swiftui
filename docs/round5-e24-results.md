# Round 5, E24: validation round 16, the Opus build with no skill at all

Run 27 Oct (local). Same method as E22 (`docs/round5-e22-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), simulator build, three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). **No skill is installed**: the harness already had the arm, `--skills none` (Level 2 isolation with an empty skill set), so no harness change was needed. Bundled skills are off, and the init event listed no skills (`skill_isolation.expected` empty, `error` null). The prompt is the same as E22's, minus the one sentence "Agent skills are installed in this project; use any that help." (the launcher drops it when no skill is installed). Launch: `UVS_NAME_SUFFIX=-x UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills none`. Raw data: `runs/opus-uikit-none-x/` (meta, transcript) and `e24-sim/` (summaries and scorecards); control in `runs/e24-control-quiet/uikit-swift-opus/baseline.json`.

## In plain words

- **12 of 13 in all three passes: text selection fails** (long press does not bring up the system selection menu) in every pass. The skill builds E20 and E22 passed 13 of 13. Stack rule ok, no `import SwiftUI`, no script build phase, no crash.
- **Agent wall time is inside the bar**: 2,103 s against at most 2,454 s (control 2,231). 75 turns, 16 builds with none failed, no commits. That is faster than the skill builds E22 (2,737 s) and E20 (2,389 s).
- **Three speed rows miss the 10 % line against the same-sitting control**: stream CPU +54 % (9.41 against 6.11 s), text size mid-list +49 % (64 against 43 ms), peak memory +15 % (61.6 against 53.6 MB). Text size at the bottom +12 %. Level: cold +1 %, repeated +8 %, older +2 %; jump -14 %. App size 1.38 MB against 0.84 (+64 %).
- Phone passes were not run.

## What differs from the skill builds (E20 / E21 / E22)

Without the skill Opus builds quicker but is slower on the stream (9.4 s against 6.5 to 6.6 s), text size and memory, and fails text selection, which both Opus skill builds passed. The skill buys rows and a check, and costs agent time (E22 +634 s).

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus, no skill (E24) | **Does not pass** | Bar 1: 12 of 13 (text selection) in 3 of 3 passes; bar 3: stream +54 %, text mid-list +49 %, memory +15 %, text bottom +12 %. Bar 2 met (2,103 s). |

## Against the pass bar (Opus)

| Bar item | E24 no skill | E22 thin3 | E20 thin2 |
|---|---|---|---|
| 1. 13 of 13 on the sim median | **No** (12, 12, 12) | Yes | Yes |
| 1. Same on the phone | Not run | Not run | Not run |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (2,103 s, -6 %) | No (2,737 s) | Yes (2,389 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (4 rows) | Yes | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E24 build (no skill) | E24 control (same sitting) | Diff | E22 build (thin3) | E20 build (thin2) |
|---|---|---|---|---|---|
| Checks passed | 12, 12, 12 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 167 [184, 167, 167] | 165 [165, 167, 161] | +1 % | 129 | 136 |
| First 40 rows, repeated (ms) | 649 [649, 646, 654] | 600 [600, 603, 592] | +8 % | 599 | 604 |
| Stream CPU (s) | 9.41 [9.42, 9.38, 9.41] | 6.11 [6.07, 6.13, 6.11] | +54 % | 6.55 | 6.53 |
| Jump to 2,500 (ms) | 44 [41, 48, 44] | 51 [50, 53, 51] | -14 % | 13 | 28 |
| Load older (ms) | 43 [43, 42, 54] | 42 [39, 42, 46] | +2 % | 16 | 18 |
| Text size at bottom (ms) | 46 [45, 46, 52] | 41 [48, 39, 41] | +12 % | 7 | 23 |
| Text size mid-list (ms) | 64 [64, 61, 65] | 43 [42, 43, 48] | +49 % | 9 | 24 |
| Peak memory (MB) | 61.6 [62.4, 61.6, 61.5] | 53.6 [53.6, 53.6, 53.3] | +15 % | 58.7 | 56.5 |
| App size (MB, binary) | 1.38 | 0.84 | +64 % | 0.80 | 0.80 |

The control moved between sittings (stream 6.11 here, 6.30 in E22); the pre-run baseline file was kept outside the repo.

## Agent facts

Wall 2,103 s, 75 turns (`meta.json`), 16 builds (0 failed), 0 commits, exit 0, not stopped by the limit. The stream transcript holds three result events (the session was resumed twice after background-task wake-ups): summed, 12.5 M cache-read plus 0.28 M cache-write input tokens, 146 k output (68 k+ thinking), final cumulative cost $7.64 (E22 $7.83). No web search or fetch. No skill files (none installed). Only `uvs-r3-a` and `uvs-r3-b` were booted.

## What this changes

This is the Opus no-skill baseline for the validation rounds: it fails text selection and is 50 % slower on stream and mid-list text size than a same-day control, so the skill's gains are real on rows and on the text-selection check; its price is agent wall time. One sample per arm.
