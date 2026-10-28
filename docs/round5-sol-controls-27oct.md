# Round 5: three same-day Sol control runs (27 Oct) and the new wall-time bar

Why: `docs/round5-sol-agent-time.md` showed the original control (1,233 s, 19 Oct) ran at a service speed the Round 5 builds never saw, and one control cannot set a 10% bar. This note re-runs the control three times on 27 Oct, one at a time, and rebuilds the bar from their median.

## Setup

- **Which control.** The original control is `runs/sol-uikit-ours-pair`: Sol, UIKit, with the skill pair `uikit-specialist` + `uikit-whats-new-27` (tag `v0.3-pair`), not "no skill". To match the original setup, the three re-runs use `--skills ours-pair`. (The no-skill Sol build is E25, `sol-uikit-none-x`, 1,954 s; it is a different arm.) The prompt, inputs tag (`v2-inputs`), model (`gpt-6.1-sol`, effort high) and CLI (`codex-cli 0.162.1`) are the same.
- **Launch line**, one run at a time, after `codex-pace` (weekly 1% each time; the reading itself was 1,200+ minutes old, so it is a weak check):
  `UVS_NAME_SUFFIX=-ctl27a UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-pair` (then `-ctl27b`, `-ctl27c`). Each had a dry run first.
- **Scoring.** After each agent stopped (nothing else ran on the Mac during an agent run): stack check (ok for all), Release simulator build, three full `Harness/record.sh --sim` passes on `uvs-r3-a`, `scorecard.py` per pass and the median. Speed rows were not wanted; the app-reported rows are in `runs/sol-uikit-ours-pair-ctl27*/sim/`.
- **Simulators.** The agent in ctl27a created `Campfire-ctl27a` (iPhone 15) and left it booted; I shut it down. ctl27b left `Campfire-Solo` booted; shut down. ctl27c left nothing booted. Only `uvs-r3-a` and `uvs-r3-b` were booted by me. No delete, no erase.
- **Tokens per second** is output tokens over model time (wall minus waiting on commands), the same method as `round5-sol-agent-time.md`; it reproduces that note's figures for the old runs (58.6, 39.2, 41.7, 43.1, 44.1). Wall-based figures are in the second table.

## The runs

| Run | Wall (s) | Turns | Builds (failed) | Output tokens | Tokens/s (model time) | Tokens/s (wall) | Checks, 3 passes |
|---|---|---|---|---|---|---|---|
| Original control (19 Oct) | 1,233 | 90 | 14 (7) | 61,759 | 58.6 | 50.1 | 12, 12, 12 (earlier baseline: text selection fails) |
| ctl27a | 1,355 | 85 | 19 (5) | 64,203 | 56.7 | 47.4 | 12, 12, 12 (text selection fails) |
| ctl27b | 1,244 | 74 | 16 (8) | 55,037 | 54.0 | 44.2 | 13, 13, 13 |
| ctl27c | 1,996 | 108 | 23 (10) | 82,738 | 48.4 | 41.5 | 12, 12, 12 (text selection fails) |

All three exited 0, none hit the 7,200 s limit, none committed. Input tokens: 7.3 M, 5.4 M, 9.6 M (nearly all cached).

Simulator medians (ms unless noted; one sample per run, simulator numbers only compare with the same simulator):

| Row | ctl27a | ctl27b | ctl27c |
|---|---|---|---|
| First 40 rows, cold | 215 | 264 | 213 |
| First 40 rows, repeated | 661 | 708 | 659 |
| Stream CPU (s) | 11.5 | 10.5 | 11.9 |
| Jump to 2,500 | 57 | 81 | 66 |
| Load older | 26 | 51 | 61 |
| Text size at bottom | 20 | 55 | 18 |
| Text size mid-list | 43 | 56 | 31 |
| Peak memory (MB) | 63.9 | 56.6 | 52.9 |
| App size (MB, .app) | 1.25 | 1.22 | 3.77 |

(The rows were not the goal here. Load older and text size vary by 2 to 3x between runs, so these builds differ in how they do it, not just in noise. Full rows: each run's `sim/sim-median.json`.)

## The new bar

- **Median wall of the three same-day runs: 1,355 s** (1,244, 1,355, 1,996). Mean 1,532 s.
- **New bar: median + 10% = 1,491 s.** (Old bar 1,356 s; the median of all four including the original is 1,300 s, for information only.)
- **Spread is the headline.** The three same-day runs range from 1,244 to 1,996 s, 60% from fastest to slowest, with the same skill and prompt. ctl27c wrote 82.7k output tokens against ctl27b's 55.0k and also ran slower per token (48.4 against 54.0). A 10% allowance is well inside this noise, so a single build over or under 1,491 s is weak evidence either way.
- **Speed today.** The median same-day tokens per second is 54.0, much faster than the 39 to 44 of the Round 5 builds earlier in the week and near the 19 Oct figure of 58.6. So the service was fast this evening; the earlier slowness was not constant.

## Where E21, E25, E27 and E29 land against 1,491 s

"Adjusted" replays each build's model time at 54.0 tokens per second (waiting on commands unchanged): adjusted = waiting + model time x (run speed / 54.0). This is the model in `round5-sol-agent-time.md` section 3; it holds token counts fixed and only changes speed.

| Build | Wall as measured (s) | vs bar 1,491 s | Speed (tok/s) | Adjusted to 54.0 tok/s (s) | Adjusted vs bar |
|---|---|---|---|---|---|
| E21 thin2 | 1,593 | +6.9% (over) | 39.2 | 1,222 | -18.0% (under) |
| E25 no skill | 1,954 | +31.1% (over) | 41.7 | 1,557 | +4.5% (over, slightly) |
| E27 thin4 | 2,276 | +52.7% (over) | 43.1 | 1,862 | +24.9% (over) |
| E29 thin5 | 1,797 | +20.6% (over) | 44.1 | 1,491 | 0.0% (on the bar) |

Reading it:

- **As measured, none of the four meets the new bar**, but E21 is within 7%, and that gap is inside the spread of the controls.
- **Adjusted for speed, E21 passes clearly and E29 sits exactly on the bar.** E25 is 4.5% over and E27 is 25% over; E27's problem is tokens (88.7k) and its test habit, not speed.
- The control is not just a speed difference: ctl27c shows the control itself can use 83k tokens and take 1,996 s. If the bar is judged against the median of three, a build with 74k tokens (E29) is at the bar only because today's speed is high; against the best control run (1,244 s) every build misses.
- Caveat: tokens per second differs per run by 10 to 20% within the same day (48.4 to 56.7 here), so the adjustment has an error of that size.

## What to do next

- Judge future Sol builds against a same-day control median, three runs, with output tokens and tokens per second reported next to wall time.
- The checks: text selection fails in 2 of 3 controls and in the original baseline, so a build that passes it (E29) is above the control on that item. Control ctl27b passed all 13, so the control is not stably 12.
- Raw data: `runs/sol-uikit-ours-pair-ctl27a|b|c/` (meta, `transcript.times`, `sim/` scorecards). Transcripts are git-ignored.
