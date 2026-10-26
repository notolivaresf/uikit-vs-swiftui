# Round 5 hand-off (E1 done; E2 and E3 for another lane)

Done and committed: the shared package `spikes/round5/SpikeKit`, E1 spikes `Apps/E1Table` and `Apps/E1Collection`, E1 results in `docs/round5-results.md`. E1 winner (within 10 %, so by fewer lines of list code): the table view.

Started but NOT built or run: E2 self-sizing spikes `Apps/E2TableSelf` (table, `UITableView.automaticDimension`, estimate 120, cells answer `systemLayoutSizeFitting`) and `Apps/E2CollectionSelf` (collection, layout with preferred attributes and offset adjustment). Both targets are in `project.yml`. The E2 pair is `E1Table` (saved heights) against `E2TableSelf`. Run `xcodegen generate` in `spikes/round5`, build Release for the simulator, then `Harness/record.sh --sim <udid> --app-path <app> --only testTextSizeMidScroll` (set `UVS_ITER=2` as `./bench` does) and `testJumpTo2500`, three alternating passes.

Things to know:
- `Harness/record.sh --build x --round y --out-dir <new dir> --derived <dir> --app-path <.app> --sim <udid> --only <tests>`; the app's bundle id is `campfire.bench` for every spike (they replace each other on a simulator).
- Table: pin with `scrollToRow(.bottom)` inside the insert's `performWithoutAnimation` (see results doc), otherwise the offset snaps back.
- E3 anchoring approaches (a) top row and (b) offset delta already exist in `RoomViewController.applyPrepend` behind `prependAnchor`; (c) layout anchor is not written and is dropped anyway because the table won E1. `prependAnchor` is set in the spike's AppDelegate (not yet wired; add `vc.prependAnchor = ...`).
- Self-sizing cells measure the row on every ask; saved-height spikes measure once per id.
