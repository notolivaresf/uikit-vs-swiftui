# Round 5: why E26 and E28 differ on screen speed (list code compared)

Read-only comparison, 27 Oct. Two Opus builds with the same skill (`v0.11.4-thin4`): E26 reports load older in about 17 ms and text size in 22 to 26 ms; E28 reports 44 to 45 ms on both, level with the Opus control (39 to 48 ms). The re-score in `docs/round5-e28-results.md` ruled out the simulator. Sources read: E26 `~/uvs-builds/opus-uikit-ours-chatlist-thin4/App/`, E28 `~/uvs-builds/opus-uikit-ours-chatlist-thin4b/Campfire/`, E27 `~/uvs-builds/sol-uikit-ours-chatlist-thin4/App/`, E23 `~/uvs-builds/sol-uikit-ours-chatlist-thin3/CampfireApp/`, controls `~/uvs-builds/round3-uikit-swift-opus/` and `round3-uikit-swift-sol/`. No micro-test was timed: reading the code settled it.

## In plain words

- **The gap is mostly in the app's own stopwatch, not in the list code.** Every speed row of the scorecard (load older, jump, both text size rows) is the `ms` figure the app writes on its own state label (`app_ms` in `Harness/Tests/ChatBenchmarks.swift` and `StressBenchmarks.swift`). The builds stop that clock at different moments:

  | Build | Clock starts | Clock stops |
  |---|---|---|
  | E26 (Opus thin4) | touch-up time (the event's timestamp) | straight after `layoutIfNeeded()` in the tap handler, before Core Animation commits and before any frame is drawn |
  | E28 (Opus thin4 repeat) | touch-up time | in the first callback of a **new** `CADisplayLink` made at the end of the handler, so after the commit and at least one frame later |
  | Opus control | touch-up time | first display-link frame after the commit (one link kept alive and paused; a run-loop observer after the commit gates it; its comment says a link made at the moment of measuring skips a frame) |
  | E27, E23 (Sol), Sol control | when the button's action runs (`CACurrentMediaTime()`), so touch delivery is not counted | E27/E23: straight after `layoutIfNeeded()`; Sol control: after its batch update completes |

  E28 and the Opus control both wait for a frame, which is why they land together at 38 to 50 ms. E26 stops before any frame, which removes one to two frames (about 17 to 33 ms on a 60 Hz display) from each figure: that is the 17 against 44 ms gap. The Sol builds start later still (at the handler) and also stop before a frame, which is why they report 10 to 16 ms. Confidence: high. The shape of the data agrees: E28's rows sit on frame steps (jump 44, older 45, text 45, all alike although the work differs), while E26's rows vary with the work (older 17, jump 36, text 22 to 25). The outside clock the tests also record (`xctest_clock_upper_bound_ms`, dominated by the test's polling) does not show E28 slower: load older 398 ms against E26's 623 ms in pass 1.

- **The list code itself is nearly the same in E26 and E28.** Both use one section, a hand-written `UICollectionViewLayout` fed by heights measured ahead of time with one shared TextKit 1 stack (`NSLayoutManager`), TextKit 1 `UITextView`s in the cells, frames set by hand in `configure` (no Auto Layout, no self-sizing, `selfSizingInvalidation = .disabled`, prefetching off), measurements cached by message id and width. No difference here explains a 2x gap.

- **One real work difference on text size:** E28 calls `updateTraitsIfNeeded()` inside the timed tap, so the trait change spreads through the view tree (every cell, label and text view) before its clock stops; E26 sets the trait override and re-lays out at once, and the trait spread happens in the next layout pass, after its clock has stopped. This adds real time to E28's figure but is secondary to the frame wait. Confidence: medium (read from the code, not timed).

- **E27's failed text size check is a top-row edge case, not speed.** In all three passes the second step (from extra large to extra extra large) at message 2,500 reported the top row as 2,499 instead of 2,500, every time. E27 trims threaded rows so they touch exactly and picks the top row as the first whose bottom is `> contentOffset.y`, with no tolerance; after the offset is restored to the anchor row's top, the row above can end a fraction of a point (a float remainder of pixel rounding) below the edge and counts as the top row. Every build that passed has a margin here: E26 adds the bubble's bottom margin, E28 adds 0.25 pt, E23 subtracts 1.6 pt, the Sol control requires the message part itself to show. Confidence: high on where it fails (the per-step data), medium on the float remainder as the exact trigger (not re-run).

## (a) Loading older messages

- **E26:** captures the top row and its distance below the header, moves the window start, rebuilds the whole row list (cached rows reused, only new rows measured), then one `performBatchUpdates` inside `UIView.performWithoutAnimation` with `deleteItems`/`insertItems` from an id diff. The layout rebuilds every attribute in `prepare(forCollectionViewUpdates:)` and returns the anchored offset from `targetContentOffset(forProposedContentOffset:)`; afterwards the offset is set again, then `layoutIfNeeded()`, then the clock stops.
- **E28:** the same idea: one non-animated batch with `insertItems` at index 0, new heights inserted, tops recomputed, the anchored offset from `targetContentOffset(forProposedContentOffset:)` and set again after the batch. Attributes are made on demand in `layoutAttributesForElements(in:)` by binary search. Then the new display link.
- **E27 (Sol):** one non-animated batch with inserts and the far-end trim in the same batch; the restore and `layoutIfNeeded()` run in the batch's completion, then the clock stops.
- **E23 (Sol):** same shape as E27.
- **Controls:** the Opus control batches the same way; the Sol control uses a diffable data source and ends after its render pass completes.

## (b) Text size change

- **E26:** sets `traitOverrides.preferredContentSizeCategory`, new metrics, clears the row cache, re-measures the loaded window, `reloadData()`, `prepare()`, restores the offset, `layoutIfNeeded()`, restores again. The trait-change callback later sees the same metrics and does nothing.
- **E28:** sets the trait override, `updateTraitsIfNeeded()`, new metrics, re-measures, `invalidateLayout()` + `reloadData()` + restore + `layoutIfNeeded()` inside `performWithoutAnimation`.
- **E27:** re-measures, `reloadData()`, `layoutIfNeeded()`, restore with `setContentOffset` and `layoutIfNeeded()` again; the top-row read has no tolerance (above).
- **E23:** same flow; passed because its top-row read ignores the 1.6 pt margin.

## (c) Row sizing and cell setup

All six builds size rows ahead of time from a measuring object and lay them out in a custom layout; none uses self-sizing cells or Auto Layout in the cells. Opus builds snap tops to the pixel grid and keep one TextKit 1 measuring stack; the Sol builds do the same with their own measurer. Cell setup sets frames from the measured geometry. Differences are small (E28 creates code, image and file subviews on first use; E26 keeps them all and hides them) and none is large enough to show at frame resolution.

## Candidate skill rules

1. When the app reports how long a user action took, start at the touch's event timestamp and stop at the first display frame that can show the result: after the run loop has committed the change, not straight after `layoutIfNeeded()`. Keep one `CADisplayLink` alive and paused between measurements and resume it for each one, rather than creating a new link per action, so the reading does not wait an extra frame; do not force trait or layout work into the measured span that the next layout pass would do anyway.

2. When you decide which row is at the top of the visible area, count a row only once its visible content is below the top edge: ignore its transparent margin and any sub-point remainder from pixel rounding (compare with a small tolerance). Use exactly the same rule to capture the anchor before a change and to read the top row after restoring it, so a re-layout never names the row above.

Note on rule 1: it makes the figure honest and stable, not smaller; a build following it would report about what E28 and the Opus control report. The fair reading of E26's 17 ms is that it measured less of the action, not that its list is faster.
