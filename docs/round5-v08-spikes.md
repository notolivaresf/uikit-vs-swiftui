# Round 5: what the E8 build's three misses come from, and what changes in skill v0.8

## In plain words

- **Stream CPU: most of the gap is applying every message as its own update.** The E8 build makes one batch update per incoming message or reaction (656 in a 30 s stream); the control collects what arrives and applies it every tenth of a second (about 225). Copying only that grouping into the E8 build cuts its stream CPU from 6.49 s to 4.92 s (-24 %), three passes each within 3 %. Grouping on the next run-loop turn instead of a timer gains nothing (6.55 s, still about 700 updates: the messages arrive on separate turns). Refreshing the header and status chrome less often gains nothing either (6.48 s). Confidence: high.
- **What is left of the stream gap is not the trims.** With grouping, the build reads about 4.9 s against the control's 3.97 s. The trims (the oldest rows dropped about 15 times per stream) cost only about 0.33 s in total, and neither setting the trim's offset before layout (4.87 s) nor dropping every forced layout pass from the batch and the trim (4.89 s, against 4.97 s in the same sitting) moves the total. A sample of the main thread points at the cells instead: with the same number of cells provided, the E8 build spends more time configuring them, mostly in setting each text view's frame (about 3.7 times the control's samples) and text (about 1.8 times; the control skips the assignment when the text is unchanged). That is a lead, not a measured cause, and v0.8 makes no rule from it. Confidence: high that trims and forced layout are not the gap; low on the cell lead.
- **Jump: the build lays out the new page twice.** After `reloadData` it lays the list out at the old offset, then moves to the target, which builds every visible cell a second time. Setting the final offset right after `reloadData`, before the one layout pass, brings the jump from 65 ms to 33 to 44 ms (control: 50 ms in the same unpolled sitting), and the CPU for 12 jumps from 1.70 s to 1.20 s. Confidence: high.
- **The extra 22 turns were polish after the checks already passed, and repeated full test runs.** The E8 agent's tests first passed at turn 91; turns 91 to 117 (about 560 s) went to matching per-row padding against the reference, redrawing the logo three times, rechecking dark mode, and two more full UI suite runs (about 150 s each) after changes that only touched drawing. It ran the 11-check suite 4 times (about 610 s) against the control's 2 (about 400 s), and made a simulator of the wrong width, deleted it and remade it (about 65 s). The skill's "judge it only on a build you just installed" and its 9-item checklist "before you stop" read as "rerun everything", and nothing said when to stop. Confidence: high on where the time went, medium on how much the wording caused.

## What v0.8 changes

1. Core rule 8: group live changes (messages and reactions) that arrive within a tenth of a second into one batch update; the next run-loop turn is not enough. Each batch still costs only its rows. The "shortcuts" line and the reviewer now say that holding changes back longer than a tenth of a second does not count, instead of "apply messages as they arrive".
2. Jump: set the target offset right after `reloadData`, then lay out once; laying out and then moving builds the cells twice.
3. How to work: make the test simulator once at the given size; rerun the suite only after behaviour changes (a drawing-only change needs one screenshot); stop when the checks pass and the screen matches the given numbers; the checklist is one pass by reading the code.
4. Not changed: trimming (rule 12) and forced layout after a batch. Both were measured as arms and gain nothing on stream CPU.
5. SKILL.md is 1,915 words (v0.7: 1,923); the words came from shortening lines that repeated a core rule.

## How it was measured

Spike: `spikes/round5/E8Stream/`. `App/` is the E8 Opus build's `App/` and `Control/` the Round 3 Opus control, each with a small probe (`Shared/Probe.swift`) and compile flags for the arms; `project.yml` (xcodegen) makes one target per arm, all Release with the benchmark's strip settings, same bundle id. `measure.sh` installs and launches each arm in turn, A B C, A B C, with a launch argument that makes the app start the 30 s stream (or 12 jump round trips) by itself: no UI test attached, so nothing polls the accessibility tree. The probe reads the process's own CPU time (`getrusage`) from stream start to stream end, and for jumps the time from the call to the next display-link frame.

One simulator (iOS 26.4, an otherwise idle iPhone simulator, the same one the benchmark uses), Release builds, one arm at a time. The polled harness numbers (E8: 8.67 s against 6.33 s) are higher than these because the UI test's queries cost the app CPU too; the ratios are what carry over.

Arms:

| Target | What differs from the E8 build |
|---|---|
| E8PerMessage | nothing (the E8 build as shipped, plus the probe) |
| E8Timer | messages and reactions queued, applied every 0.1 s as one batch update (reconfigure changed rows, append new rows) |
| E8RunLoop | the same queue, flushed on the next main-queue turn |
| E8ChromeThrottle | header and status chrome refreshed at most every 0.1 s while streaming |
| E8JumpFix | after `reloadData` in the jump and the trim, the final offset is set before `layoutIfNeeded` |
| E8TimerOffsetFirst | E8Timer and E8JumpFix together |
| E8TimerNoForce | E8Timer, and neither the batch nor the trim calls `layoutIfNeeded`: each sets the final offset and leaves the layout to the next display pass |
| E8Ctrl | the Round 3 Opus control (diffable data source, 0.1 s flush) |

## Stream CPU, unpolled

First sitting, 3 passes each (s of CPU from stream start to end):

| Arm | Passes | Median | Batch updates |
|---|---|---|---|
| E8PerMessage | 6.548, 6.493, 6.484 | 6.49 | 656 |
| E8Timer | 4.915, 4.953, 4.862 | 4.92 (-24 %) | 221 to 230 |
| E8RunLoop | 6.549, 6.434, 6.772 | 6.55 (+1 %) | about 700 |
| E8ChromeThrottle | 6.662, 6.480, 6.432 | 6.48 (0 %) | 656 |
| E8Ctrl | 3.926, 3.995, 3.970 | 3.97 | 223 to 229 |

`ps` CPU time including launch tells the same story: about 7.0 s, 5.4 s and 4.5 s for PerMessage, Timer and Ctrl.

Second sitting, with the trim timed (trims per stream and their total time in ms):

| Arm | Passes (s) | Median | Trims, total trim time |
|---|---|---|---|
| E8PerMessage | 6.581, 6.579, 6.587 | 6.58 | 16, 319 to 342 ms |
| E8JumpFix | 6.633, 6.657, 6.844 | 6.66 | 16, 327 to 357 ms |
| E8Timer | 4.777, 4.833, 4.875 | 4.83 | 15, 316 to 356 ms |
| E8TimerOffsetFirst | 4.918, 4.873, 4.867 | 4.87 | 15, 329 to 377 ms |
| E8Ctrl | 3.987, 3.610, 4.018 | 3.99 | |

Third sitting, forced layout removed:

| Arm | Passes (s) | Median | Total trim time |
|---|---|---|---|
| E8Timer | 4.965, 4.834, 5.121 | 4.97 | 331 to 371 ms |
| E8TimerNoForce | 4.831, 4.921, 4.888 | 4.89 (-2 %, inside spread) | 106 to 114 ms (the rest moves to the display pass) |
| E8Ctrl | 4.154, 4.060, 3.946 | 4.06 | |

Main-thread sample (`sample`, 20 s inside the stream, `profile.sh`; sampling itself raises CPU, so only the split counts): the E8Timer stream path held about 3,280 samples against the control's 2,530. Cell provisioning: E8Timer 1,671 samples in the data source's cell method against the control's 1,015; inside it, `UITextView` frame setting 589 against 160 and text setting 386 against 213. Layout `prepare` is small in both (control 321; E8 not listed above 5). Commit of the render transaction is the same (491 against 509).

## Jump to an old message, unpolled

12 jump round trips per pass (jump to message 2,500, back to the newest), median of the 12, 3 passes:

| Arm | Pass medians (ms) |
|---|---|
| E8PerMessage | 66, 65, 65; again 66, 64, 65 |
| E8JumpFix | 44, 33, 39 |
| E8Ctrl | 50, 50, 49 |

Phases inside the E8 build's jump: measuring the new page 6 to 12 ms, `reloadData` plus layout 15 to 27 ms, then moving to the target 16 to 24 ms, which is a second layout pass that makes the visible cells again (the layout's `targetContentOffset` is not consulted on `reloadData`, so the first pass happens at the old offset). With the offset set first, the moving phase is 0.0 ms. CPU for the 12 jumps: 1.70 s, 1.20 s with the fix. The control's phases: snapshot 12 to 25 ms, layout and reconfigure 11 to 23 ms, offset restore 0 ms. Jump times step in 16.7 ms frames, so a single pass median moves by a frame; the three passes agree.

## Turns: E8 build (A, 117 turns, 2,600 s) against its control (B, 95 turns)

From the two agents' transcripts, tool calls grouped by kind (calls / seconds):

| Kind | A | B |
|---|---|---|
| Screenshots and looking at them | 66 / 866 | 56 / 626 |
| Test runs | 6 / 736 | 6 / 556 |
| Builds | 22 / 270 | 13 / 184 |
| Writing code | 23 / 507 | 25 / 596 |

- After its checks first passed (turn 91), A spent turns 91 to 117, about 563 s: per-row padding against the reference screenshot, the logo redrawn 3 times, a full UI suite rerun after a cosmetic change (148 s), a re-read "for edge cases", dark mode rechecks, a final suite run (150 s). B's tail after its checks passed was about 40 s.
- A ran the full 11-check suite 4 times (about 612 s), B twice (about 400 s).
- A made an iPhone simulator of the wrong width (402 pt), deleted and remade it (about 65 s).
- Not from the skill: one failed build was a type-check timeout on a long array literal, fixed in 2 turns; the text-measuring reference was read twice because the first read came back cut short.

## Noise and limits

- One simulator, one machine, two sittings. Stream passes sit within 3 % of their median; jump medians within one frame.
- The unpolled numbers leave out the UI test's polling, which is part of the scored number. The coalescing gain should carry over (fewer updates means fewer accessibility tree changes too), but the size of the gain under polling is not measured here.
- The turn analysis is one build against one control. The how-to-work changes target behaviour seen once.
