# Round 5, E25: validation round 17, the Sol build with no skill at all

Run 27 Oct (local). Same method as E23 (`docs/round5-e23-results.md`) and E24 (`docs/round5-e24-results.md`), strictly one thing at a time: Sol build (nothing scoring), simulator build, three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). **No skill is installed** (`--skills none`, no harness change needed): the Codex config turns the bundled and host skills off, and the prompt drops the sentence "Agent skills are installed in this project; use any that help." Launch: `UVS_NAME_SUFFIX=-x UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills none`. Raw data: `runs/sol-uikit-none-x/` (meta, transcript) and `e25-sim/` (summaries and scorecards); control in `runs/e25-control-quiet/uikit-swift-sol/baseline.json`.

## In plain words

- **12 of 13 in all three passes: text selection fails** every time, as E24 did for Opus. The Sol skill builds (E21, E23) passed 13 of 13. Stack rule ok, no `import SwiftUI`, no script build phase, no crash.
- **Agent wall time misses the bar**: 1,956 s against at most 1,356 s (+59 % on the control's 1,233). 85 turns, 14 builds with 5 failed, 7.87 M input tokens including 7.76 M cached, 73 k output. Faster than the Sol thin3 build (2,369 s) and thin2 (1,595 s is faster still); no Sol build has met this bar with or without a skill.
- **Speed rows against the same-sitting control**: cold +53 % (203 against 133 ms), repeated +12 %, stream CPU +13 % (8.48 against 7.48 s), jump +8 %; better on load older -12 %, text size -7 % and -12 %, peak memory -9 % (52.9 against 57.9 MB). App size 1.15 against 0.79 MB (+46 %).
- Phone passes were not run.

## What differs from the skill builds (E19 / E21 / E23)

Without the skill Sol is slower to first rows (cold 203 ms against 117 to 119 with thin2 and thin3), slower on the stream (8.5 s against 6.5 to 6.6 s), and fails text selection; memory and the older and text-size rows are close to or better than the control either way. Its wall time (1,956 s) sits between thin2 (1,595 s) and thin3 (2,369 s).

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol, no skill (E25) | **Does not pass** | Bar 1: 12 of 13 (text selection) in 3 of 3 passes; bar 2: 1,956 s against 1,356 s; bar 3: cold +53 %, stream +13 %, repeated +12 %. |

## Against the pass bar (Sol)

| Bar item | E25 no skill | E23 thin3 | E21 thin2 |
|---|---|---|---|
| 1. 13 of 13 on the sim median | **No** (12, 12, 12) | Yes | Yes |
| 1. Same on the phone | Not run | Not run | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (1,956 s, +59 %) | No (2,369 s) | No (1,595 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **No** (3 rows) | Yes | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E25 build (no skill) | E25 control (same sitting) | Diff | E23 build (thin3) | E21 build (thin2) |
|---|---|---|---|---|---|
| Checks passed | 12, 12, 12 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 203 [202, 203, 203] | 133 [133, 131, 133] | +53 % | 117 | 119 |
| First 40 rows, repeated (ms) | 652 [655, 652, 641] | 582 [584, 580, 582] | +12 % | 466 | 468 |
| Stream CPU (s) | 8.48 [8.47, 8.48, 8.51] | 7.48 [7.50, 7.31, 7.48] | +13 % | 6.63 | 6.46 |
| Jump to 2,500 (ms) | 27 [27, 27, 27] | 25 [27, 25, 25] | +8 % | 18 | 14 |
| Load older (ms) | 23 [23, 24, 23] | 26 [25, 27, 26] | -12 % | 8 | 6 |
| Text size at bottom (ms) | 14 [14, 14, 14] | 15 [15, 14, 15] | -7 % | 12 | 10 |
| Text size mid-list (ms) | 23 [23, 23, 22] | 26 [26, 26, 26] | -12 % | 10 | 10 |
| Peak memory (MB) | 52.9 [52.9, 52.9, 53.0] | 57.9 [57.9, 58.1, 57.4] | -9 % | 54.9 | 55.1 |
| App size (MB, binary) | 1.15 | 0.79 | +46 % | 0.76 | |

## Agent facts

Wall 1,956 s, 85 turns, 14 builds (5 failed), 0 commits, exit 0, not stopped by the limit; 7.87 M input tokens including 7.76 M cached, 73 k output (34 k reasoning). The Codex transcript gives no dollar cost. The only `curl` calls were against a placeholder host to test the app's server check. Only `uvs-r3-a` and `uvs-r3-b` were booted.

## What this changes

Across both models the no-skill builds fail text selection (the check the skill's rule 1 covers) and are slower on the stream and the first rows; the skill's price is agent time on Opus (E22 +634 s over no skill) and, on Sol, a mixed picture (thin2 faster than no skill, thin3 slower). One sample per arm.
