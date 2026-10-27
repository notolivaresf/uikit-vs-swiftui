# Round 5: why the E12 Sol build is slow where it is, and what changes in skill v0.10

## In plain words

- **Jump and text size mid-list: Sol measures twice as many rows as it needs.** Its jump loads a window of 81 rows around the target (the windowing helper's default size), where the E11 Opus build loads 41. Measuring is the biggest part of both operations: 23 to 25 ms for 81 rows, 15 to 16 ms for 41. Text size mid-list re-measures that same 81-row window. With a 41-row window the jump drops from 49 ms to 33 ms median (two frames instead of three) and text size mid-list from 49 ms to 33 ms. Confidence: high (3 passes, every pass the same).
- **Each row's measure is dear.** Sol runs two layout-manager passes per row (a one-line header, then the body) and makes a new paragraph style per row: about 0.4 ms a row on the simulator. Measuring the one-line header from the string's own size instead of a layout manager pass cuts the measure by about 10 % (81 rows: 23.1 to 20.6 ms). Load older and text size at the bottom measure 40 rows (15 to 19 ms) and land in two frames in every arm, so this spike cannot split them further. Confidence: high on the measure share, medium on why the bottom text size row is slower than E11's: E11 defers its re-layout into the trait change's own layout pass, Sol re-measures, reloads and restores the offset twice in the trait callback (read from the code, E11 not rebuilt here).
- **Memory: no single cause found.** Sol registers eight cell classes, one per message kind, so each kind keeps its own reuse pool. One cell class lowers the footprint at the end of the stream from 51.4 to 44.6 MB, but the peak is unchanged (60.2 against 58.4 MB). Cell prefetching on raises the peak by about 2.5 MB. The lead that Sol copies the whole 50,000-message array on the first streamed append is real but E11 does the same, so it does not explain the gap. Confidence: low.
- **Live messages: the 0.1 s timer delays every message by about 66 ms.** Applying on the next main-queue turn (one flush scheduled at a time) brings the median delay to 7.5 ms and p95 from 103 to 11 ms. It costs CPU at 20 messages a second (4.96 to 6.30 s, +27 %), because nothing arrives within one turn to group; at 1 message a second it costs nothing (0.41 against 0.44 s). A display-link flush groups no more than the next turn at these rates and costs slightly more (6.47 s, p95 18 ms).
- **Trim: one batch with the right indexes beats reloadData plus a second batch.** Deleting the trimmed rows at their old positions and inserting the new ones at `oldCount - k` in one `performBatchUpdates` ran 600 messages and 170 trims with no assertion, cut stream CPU from 4.96 to 4.15 s (-16 %) and cells configured from 1,550 to 678. Together with next-turn grouping (SolFix2), CPU is 5.41 s: 9 % over the shipped timer build for a ninth of the delay.
- **The text size callback:** `targetContentOffset(forProposedContentOffset:)` is never called after `invalidateLayout()` plus `layoutIfNeeded()` or after `reloadData()`, and is called once inside `performBatchUpdates`. So a text size change must set the anchored offset itself.
- **Prefetching on or off:** no difference in fling hitches (6 against 6) or CPU (4 % more with it on); the peak is about 2.4 MB higher with it on. The fling scrolls by setting the offset, which made no prefetch calls in either arm, so this says nothing about prefetching under a real finger fling.

## What v0.10 changes

Skill tag `v0.10.0` in the private uikit-skill repo. Every change, with its evidence:

1. Rule 2 (offset after removals): the final offset is set by the code in the same pass; the layout callback runs only inside batch updates. Evidence: the callback probe above; review H4.
2. Rule 6 is new: keep each row's measure cheap (one layout pass per text, none for a one-line header, fonts and styles made once per text size, only the rows the window needs). Evidence: the measure phases and the header arm above. The v0.9 rule 6 (no shrink-to-fit labels) folds into rule 5.
3. Rule 7 (jump): a small window, about 10 rows above and 30 below, and keep image caches. Evidence: the jump and mid-list text size rows above; review M9. The separate jump section is merged into the rule.
4. Rule 8 (live changes): the next main-queue turn, no timer; your own sends at once. Evidence: the stream rows above; review H1. This reverses v0.8 on purpose: the CPU cost E8 found is still there at 20 messages a second, in exchange for about 60 ms less delay per message.
5. Rule 12 (batch indexes): states the rule correctly (inserts at `oldCount - k`) and keeps the trim in the append's batch. Evidence: the trim rows above; review H2.
6. Prefetching is a note, not a rule: little difference, and turning it off also disables `prefetchDataSource`. Evidence: the fling and stream rows above; review H3.
7. One cell class is not a rule: the one-cell arm gave no speed gain and a mixed memory result. It survives as "make rarely used cell parts lazily".
8. New, short and not measured here: keyboard and input bar (`keyboardLayoutGuide`, inset re-pin, interactive dismiss without per-frame re-pins; review H5), Dynamic Type (rebuild stored strings, legibility weight and display scale traits, `adjustsFontForContentSizeCategory = false`; H6), right-to-left (`flipsHorizontallyInOppositeLayoutDirection`, `.natural`; M4), VoiceOver (one element per row, custom actions, announcements only while pinned; M5), image rows (height from stored size, thumbnails at display size, capped cache; M7), growing streamed replies (L4).
9. Fixes from the review: TextKit 1 scoped to read-only cells and never reading `.layoutManager` on a TextKit 2 view (M1); self-sizing "as fast but loses the pin", no crash claim (M2); pixel scale from `traitCollection.displayScale` (M3); one section per day allowed (M6); animated deletes allowed when not pinned (M8); heights keyed by width (L3); "second page" iPhone-only (L5); the table pin claim stated as observed (L6); the release strip settings scoped to the app target (L1).
10. Removed wording that described being scored rather than building the screen: Reset, UI tests waiting on elements, "the given numbers", "the device size you were given", "stop when the checks pass", "Shortcuts that do not count". What is left is one line: a change that improves a timing but not the screen is a fault. Added: close any simulator you started when you stop.
11. The `uikit-list-reviewer` checklist is the skill's checklist word for word, with item 8 now keyboard, right-to-left and VoiceOver.
12. Words: SKILL.md 1,915 to 1,548; references 1,108 to 1,213 (the image rows and growing replies sections); reviewer 1,145 to 1,163. The skill folder names no benchmark, app, round, check or measured number.

## The numbers

All arms are copies of the E12 Sol build with one compile flag each (`spikes/round5/E13/project.yml`). Medians of 3 passes; each pass runs every arm in turn. Operation times are from the action to the next display frame, medians of 12 rounds per pass, so they fall on frame steps (about 16.7 ms); the measure phase is the finer number.

Jump to message 2,500 and text size:

| Arm | Jump | Jump measure | Text size mid | Mid measure | Text size bottom | Bottom measure | Load older | Older measure |
|---|---|---|---|---|---|---|---|---|
| Shipped (81-row jump window) | 49.0 ms | 81 rows 24.0 ms | 48.9 | 81 rows 25.1 | 33.2 | 40 rows 19.7 | 33.1 | 15.5 |
| Jump20 (41-row window) | 32.9 | 41 rows 16.0 | 33.0 | 16.2 | 33.2 | 18.7 | 33.1 | 15.8 |
| OneCell (one reuse pool) | 48.2 | 23.4 | 44.9 | 23.9 | 32.9 | 19.3 | 33.1 | 15.1 |
| Header (one-line header from `size()`) | 36.3 | 81 rows 20.6 | 33.4 | 22.7 | 33.2 | 17.5 | 33.1 | 14.4 |
| SolFix (Jump20, OneCell, display-link flush, one-batch trim) | 34.7 | 15.9 | 32.9 | 16.4 | 33.2 | 18.2 | 32.9 | 16.2 |
| SolFix2 (Jump20, OneCell, next-turn flush, one-batch trim, Header) | 33.2 | 15.3 | 33.1 | 15.2 | 33.2 | 16.5 | 33.2 | 14.3 |

The Header row and SolFix2 come from a second sitting with its own Shipped run (jump 45.0, measure 23.1; mid 40.1, measure 24.4; bottom measure 18.7; older measure 16.1); the header cut is against that run.

Live stream, 30 s, 600 messages (20 a second) with reactions:

| Arm | CPU | Delay median | Delay p95 | Cells configured | End footprint | Peak footprint |
|---|---|---|---|---|---|---|
| Shipped (0.1 s timer, trim by reloadData) | 4.96 s | 65.8 ms | 103.0 ms | 1,550 | 51.4 MB | 58.4 MB |
| PerMsg (one batch per message) | 6.31 | 7.7 | 10.7 | 2,511 | 52.2 | 60.4 |
| NextTurn (next main-queue turn) | 6.30 | 7.5 | 10.6 | 2,511 | 52.4 | 60.9 |
| Frame (first at once, then per display frame) | 6.47 | 8.3 | 17.8 | 2,511 | 51.7 | 60.0 |
| TrimBatch (timer, one-batch trim) | 4.15 | 63.4 | 102.8 | 678 | 53.1 | 58.2 |
| PrefetchOn | 5.05 | 68.7 | 103.4 | 1,550 | 54.0 | 60.9 |
| OneCell | 5.09 | 67.2 | 103.3 | 1,550 | 44.6 | 60.2 |
| SolFix | 5.62 | 8.1 | 17.0 | 711 | 50.4 | 57.3 |
| SolFix2 | 5.41 | 6.4 | 11.4 | 711 | 50.0 | 57.0 |

Second sitting: Shipped 4.88 s, delay 66.1 / 103.0 ms; NextTurn 6.49 s, 8.0 / 10.9 ms.

Live stream at 1 message a second (30 messages): Shipped 0.44 s, delay 55 / 104 ms; PerMsg 0.41 s, 9.5 / 14.9; NextTurn 0.42 s, 9.4 / 14.8; Frame 0.43 s, 9.3 / 13.3; SolFix2 0.38 s, 9.2 / 12.8.

Fling, 480 frames at 40 pt a frame up through history, loading older pages as it goes (per pass medians): Shipped 6 hitches, 118 ms of hitch, CPU 1.65 s, peak 50.4 MB, 17 cells made; PrefetchOn 6, 149 ms, 1.72 s, 52.8 MB, 20 cells; OneCell 6, 135 ms, 1.68 s, 50.7 MB, 12 cells; SolFix 5, 125 ms, 1.62 s, 50.9 MB, 12 cells. Hitch counts vary by 2 to 3 between passes of the same arm. Prefetch calls: 0 in every arm.

Text size callback (one run, bottom and mid-list; `calls` is how often the layout's `targetContentOffset(forProposedContentOffset:)` ran):

| Change | Calls | Offset | Top row before, after |
|---|---|---|---|
| invalidate + `layoutIfNeeded`, no text change | 0 | unchanged | same |
| text change, invalidate + `layoutIfNeeded` | 0 | unchanged | 49,998 to 49,997 (bottom); 2,500 to 2,496 (mid) |
| text change, `reloadData` + `layoutIfNeeded` | 0 | unchanged | same drift |
| text change, empty `performBatchUpdates` | 1 | unchanged | same drift |
| text change, `invalidateLayout()` inside `performBatchUpdates` | 1 | unchanged | same drift |

(Sol's layout returns the proposed offset when no anchor is set, so the batch-update rows keep the offset too; what matters is that only batch updates call it at all.)

## How it was measured

- Arms: `spikes/round5/E13/Sol/` is the E12 Sol build's source with probe marks; `Shared/Probe.swift` is the probe; flags `JUMP20`, `ONE_CELL`, `PREFETCH_ON`, `FLUSH_PERMSG`, `FLUSH_NEXTTURN`, `FLUSH_FRAME`, `TRIM_BATCH`, `CHEAP_HEADER` select the change. `build.sh` builds Release arms with xcodegen and xcodebuild; `measure.sh` and `run-all.sh` / `run-extra.sh` run them.
- No UI test is attached: the app runs its own probe from a launch argument and prints lines to stdout (CPU from `getrusage`, footprint from `TASK_VM_INFO`, operation time to the next `CADisplayLink` frame, delay from feed arrival to the batch that applies it).
- One iPhone 17 simulator on iOS 26.4, nothing else testing on the Mac. Only iOS 26.3 and 26.4 runtimes are installed, so nothing here was run on iOS 18.
- Two sittings: the first ran every arm except Header and SolFix2; the second ran those two with Shipped and NextTurn again as the reference. Within each sitting the arms ran in turn, three passes.
