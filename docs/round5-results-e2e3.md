# Round 5: results for E2 (saved row heights) and E3 (keeping the place on load older)

Spike apps: `spikes/round5/Apps/` (targets `R5SavedTop`, `R5SelfTop`, ... for the table view, `R5CSavedTop`, `R5CSelfTop`, ... for the collection view with a custom layout). Measured on the iPhone 17 simulator (iOS 26.4, one kept simulator), Release builds, through the Round 3 harness (`Harness/record.sh --sim ... --only <tests>,launch`). Three alternating passes, A B A B A B. Nothing was run on the iPhone 12.

**Base.** E1 tied (table 7.73 s, collection 7.84 s stream CPU), and Fernando then chose the custom-layout collection view as the base. Both views are reported, collection view first.

**Clock.** Time is from the touch up (the touch's own timestamp) to the first display-link frame after the result is laid out (the plan's touch-to-next-frame clock; it is opt-in in the shared debug bar, `DebugBar.nextFrameClock`). A second reading, "work", is the app's own time from the button action to the end of layout, with no frame wait (`defaults write -g uvsClock work` in the simulator). The frame reading includes about 25 to 30 ms of event delivery and frame wait that no list can remove, so compare apps by the work column as well.

**Harness fault found.** `record.sh --only <tests>` does not install the app unless `launch` is in the list, so a run with only test names measures whichever app was installed before. The first two sets of runs of this lane (about 80 runs) did this and are discarded. Every number below was made with `launch` in `--only`. `./bench <number>` for `textsize-*`, `older`, `jump` and `stream` had the same problem (`bench-inner.sh` passes `only=testTextSizeMidScroll`, no `launch`). **Fixed (follow-up lane, 26 Oct):** `record.sh --sim ... --only <tests>` now always terminates and installs the `--app-path` app; only the cold-launch read still needs `launch`. `bench-inner.sh` passes `--app-path`, so it is fixed by the same change. Checked: a run with `--only testLiveStream` now has `logs/install.1.log`.

## E2: saved row heights or self-sizing rows

Deciding measure: time to apply a text size change in the middle of the list (message 2,500 at the top), ms, median of three passes (each pass: 2 iterations of 3 steps).

| View | Saved heights, frame | Self-sizing, frame | Saved, work | Self-sizing, work |
|---|---|---|---|---|
| **Collection, custom layout** | 54.5 | 47 | 25.5 | 17 |
| Table | 64 | 80 | 22.5 | 17 |

Per-pass medians: collection saved 54, 55.5, 54.5; collection self-sizing 46, 47, 44; table saved 65.5, 60, 64; table self-sizing 63, 86, 68.

Alongside (not deciding):

| View | Text size at the bottom (frame) saved / self | Jump to 2,500 (frame) saved / self | Stream CPU saved / self | Drift after the text size change, mid-list |
|---|---|---|---|---|
| Collection | 42 / 40 (after the fix) | 59 / 56.5 | 8.25, 8.30 s / 8.27, 8.38 s | 0 / 0 |
| Table | 45.5 / 45 | 60 / 70 | 30.7 s (test-inflated, see below) / **not pinned, no number** | 0 / up to 17 pt |

- Jump to 2,500 landed on message 2,500 with at most 0.2 pt of drift in every app, including both self-sizing ones.
- The self-sizing collection layout (`E2CollectionSelf`) crashed in `UICollectionView` (`_updateVisibleCellsNow`) in the text size at the bottom test, in all three passes. **Cause (found in the follow-up lane): the exception text is "Expected dequeued view to be returned to the collection view ... Avoid flushing layout before returning the view". The adapter's `scrollViewDidScroll` refreshed the debug label, which read row frames through `collection.layoutIfNeeded()`. With self-sizing rows a cell's real height moves the offset (`contentOffsetAdjustment`) in the middle of the collection view's own layout pass, so `scrollViewDidScroll` fires there and the flush ran before the dequeued cell was handed back.** Fix: the adapter skips `layoutIfNeeded` while it is inside `scrollViewDidScroll` (the layout is current there). After the fix the test runs: 6 steps of text size at the bottom, median 40 ms, max 47 ms, no crash, pinned after 4 of 6 steps (the third step of each iteration ends unpinned, the same loss of the bottom pin the self-sizing table shows). Skill rule: never call `layoutIfNeeded` (or anything that flushes layout, such as reading frames through it) from `scrollViewDidScroll`, `cellForItemAt` or a layout invalidation callback; read the cached geometry.
- The self-sizing table does not stay pinned to the bottom: after Reset it reported "not pinned" (the load older test failed on its second iteration), and the stream ended unpinned in both passes. Saved heights stayed pinned.
- **The 30.7 s is explained: it is the test, not the table.** Reruns on one simulator, same harness, with `launch`-less `--only` now installing the app: R5SavedTop (the table with this lane's additions) 31.3, 30.7, 29.8 s over three passes (median 30.7); E1Table built from the E1 commit (`ba78558`, before any E2/E3 change) 30.0 s; E1Table built from current main 35.2 s. So the E2/E3 additions (timing probe, opt-in clock) are not the cause: the original E1 code gives 30 s too. Then the app was run with no test attached (`simctl launch -uvsAutoStream`, app CPU from `ps` after the 30 s stream, three alternating passes): **table 6.92, 6.75, 6.87 s; collection 6.53, 6.63, 6.57 s** (includes launch; the table is 4 % above the collection). The stream test costs the table about 23 s more because `testLiveStream` waits for the "Stream done" label with `waitForExistence`, which makes XCUITest take an accessibility snapshot of the app over and over for 30 s, and that is what costs a `UITableView` far more than a `UICollectionView` (likely because the table's accessibility support builds cells for rows that are off screen; not proven). A row-height cache keyed by message id in the table adapter changed nothing (35.1 s), so it is not the adapter's height calls.
- **Does the E1 tie stand? On the app's own work, yes**: 6.8 against 6.6 s with nothing polling it, within 4 %. **The E1 numbers themselves are not reproducible**: E1 reported 7.73 s for the table through this harness, but the same harness now gives 30 s for the E1 code; the E1 table passes ran under the harness fault above (`--only testLiveStream` without `launch`, so most likely the collection app was installed and measured twice). Read E1 as "tie on app CPU" from the unpolled numbers here, not from the old table column. For the skill: stream CPU measured through XCUITest includes the cost of the test's own accessibility queries, which is large for a table view with many rows and small for a collection view; measure unpolled when comparing the two.
Verdict against the plan:
- Expected: saved heights at least a third faster. **Wrong for both views.** Collection: saved is 16 % *slower* than self-sizing on the frame clock (54.5 against 47 ms; 25.5 against 17 ms of work). Table: saved is 20 % faster on the frame clock (64 against 80 ms) but 32 % *slower* on work (22.5 against 17 ms).
- Proved wrong if self-sizing comes within 20 %: **yes for the collection view** (self-sizing is faster); for the table it is 25 % behind on the frame clock, but the gap is in rows following the place, not in the measuring.
- Proved wrong if self-sizing jumps to the wrong spot: **no**, both land exactly.

One-line verdict: on time alone, saved heights are not worth the code in either view (they never beat self-sizing by a third), but self-sizing is not free: the table loses the bottom pin and drifts up to 17 pt on a text size change, and the hand-written self-sizing collection layout crashed.

Rule for the skill: do not choose saved heights for speed. Choose them for correctness: with saved heights the list stays pinned, never drifts and cannot crash in the layout, so keep the measurer (height by message id, emptied on width and text size change) when the list must pin to the bottom or hold a place; let the system size rows only for a simple list and then still verify the pin.

## E3: keeping the place when older messages load

Deciding measure: drift in points after Load older (must be 0). The reading is the first run of each pass (the later runs of a pass reuse heights saved by the first and flatter approach (b)). Median of three passes. Load older is measured from a list that sits at the bottom (the harness's own test); mid-list loading was not run.

| Approach | Collection, saved heights: drift / ms | Collection, self-sizing | Table, saved heights | Table, self-sizing |
|---|---|---|---|---|
| (a) top row id and offset, put back after the insert | 0 / 62, 59, 62 | 0 / 65, 67, 69 | 0 / 67, 58, 71 | 1 pt / 86, 62, 80 |
| (b) add the inserted rows' heights to the offset | **42 pt** / 72, 66, 62 | lost the place: top row moved 2 rows / 68, 56, 61 | **42 pt** / 60, 65, 55 | lost the place: top moved 4 rows / 74, 83, 86 |
| (b') add the change in content height | 0 / 72, 83, 66 | lost the place: moved 3 rows / 66, 74, 59 | 0 / 73, 70, 65 | 1 pt / 63, 62, 87 |
| (c) the layout keeps the anchor itself (`targetContentOffset(forProposedContentOffset:)`; collection only) | **0 / 39, 46, 44** | not run | n/a | n/a |

- (b) drifts 42 pt with saved heights because the old first message is threaded under a new neighbour and changes height, which the sum of the new rows does not include. (b') sees it.
- With self-sizing rows, (b) and (b') lose the place by 2 to 4 rows: the new rows are counted at the estimate and settle later. (a) held in the collection (0 pt) and drifted 1 pt in the table.
- (c) was the only approach that was both at 0 pt and clearly cheaper: 39 to 46 ms against 59 to 62 ms for (a), because the right offset is given before UIKit makes cells for a wrong place.
- Proved wrong if (a), the simplest, drifts with saved heights: **no**, it is 0 pt in both views.

One-line verdict: (a) is the simplest approach that reaches 0 pt in both views and with both row sizing styles; (c) reaches 0 pt too and is about a quarter cheaper, in the collection view only.

Rules for the skill: (1) keep the place by message id plus offset (approach a); never by adding up the new rows' heights; (2) if you add heights, use the change in the list's content height, and not with self-sizing rows; (3) in a custom collection layout, do it in the layout with `targetContentOffset(forProposedContentOffset:)` (approach c); (4) the old first row can change height when older rows arrive, so invalidate its saved height.

## Not measured, and limits

- (c) with the self-sizing collection layout; E3 from the middle of the list; the iPhone 12.
- Hitches while the text size settles: the simulator pass has no hitch metric (`xctest_hitch_metrics` is empty), so "scroll smoothness while it settles" is not measured.
- Stream CPU for E2 was two passes, not three (the table now has three, above); the self-sizing apps' stream and the collection's third pass were not rerun.
- The frame clock quantizes to the display's frames (about 8 ms); the work column does not.
- The debug bar's probe (`DebugBar.probes`, `HeightStore.measureCalls`) is a debugging aid left in the shared package; it changes no behaviour.
