# Round 5: results

Spike apps and the shared package are in `spikes/round5/` (`SpikeKit`, one `project.yml`). Measured on the iPhone 17 simulator (iOS 26.4, one kept simulator), Release builds, through the Round 3 harness (`Harness/record.sh --sim ... --only testLiveStream`, the same tests `./bench stream` runs). Three alternating passes (A B A B A B). Nothing was run on the iPhone 12.

## E1: table view or custom collection view, for streaming text

Question: which list view costs less to keep a growing chat pinned to the bottom while 600 messages stream in (20 a second, 30 seconds, applied one at a time as they arrive)?

| Pass | A: table view | B: collection view, custom layout |
|---|---|---|
| 1 | 7.734 s | 7.837 s |
| 2 | 7.700 s | 7.861 s |
| 3 | 7.856 s | 7.759 s |
| **Median** | **7.734 s** | **7.837 s** |

Stream CPU, seconds of app CPU over the stream. All six passes added 600 messages and ended pinned to the bottom (the pinning check passed for both).

Verdict against the plan:
- Expected: within 10 % of each other, near the bottom of Round 3's 4.6 to 8.8 s range. **Confirmed**: the medians differ by 1.3 %, and both sit at the upper end of the range, 7.7 to 7.9 s (not the lower end the plan guessed).
- Proved wrong if one is more than 15 % lower in all three passes. **Not proved wrong**: the lead changes hands (table lower in passes 1 and 2, collection in pass 3), the largest gap in any pass is 2.0 %.
- Next, per the plan: within 10 %, so the base for E2 to E4 is the one with fewer lines of list code, the **table view** (61 lines of adapter against 119 for the custom layout). The skill says either view is fine for streaming text; the table view is the shorter way to get there.

What it means for the skill:
- Do not pick the custom collection layout "for speed" on a streaming chat list: at equal row code, with saved heights in both, the table costs the same. The custom layout earns its keep only if something else needs it (E3's layout-owned anchor, if that wins).
- Table view pin rule (found while fixing the spike, not a planned experiment): when a row is inserted at the end of a pinned table, scroll with `scrollToRow(at: last, at: .bottom, animated: false)` inside the same `performWithoutAnimation` as the insert. Setting `contentOffset` after `performBatchUpdates` or `beginUpdates/endUpdates` is undone at the table's next layout pass (the offset fell back by one row, the list stopped being pinned after the third message, and stayed unpinned: 0 of 600 followed in the first run). The collection view took a plain `setContentOffset` after the insert and stayed pinned.
- Debug-bar cost is not list cost: a state label with `adjustsFontSizeToFitWidth` redrawn 20 times a second took the stream CPU from 7.8 s to 31 s in the same app (it was in the first run; removed from the bar). Any measuring rig must keep its own label cheap, or it measures itself.

Notes and limits:
- Both spikes show the same row (text view, bubble, avatar, boost pills), use the same saved-height measurer (height by message id, emptied on a width or text size change), the same pinning rule (last row within 100 pt of the bottom) and the same debug bar. Only the adapter (`Apps/E1Table`, `Apps/E1Collection`) differs.
- Rows are not trimmed (the app keeps all 640 loaded rows); a real app that trims to 300 rows would make both cheaper.
- The first run of each spike (before the label fix and the table pin fix) is kept out of the numbers; the six passes above were made after both fixes. The E1 apps were built before two later additions to `SpikeKit` (a per-id height-invalidated call and a message-id lookup, both used only by the E2 spikes); they do not change the E1 code path.
- Raw passes live in the session scratchpad only (`summary.json` per pass); the numbers above are copied from them.

## E2 and E3

Not run. The coordinator moved them to a separate lane on 26 Oct; see `docs/round5-handoff.md` for where the code stands.
