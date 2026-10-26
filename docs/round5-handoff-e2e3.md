# Round 5 E2/E3 hand-off

Done: spikes, runs and `docs/round5-results-e2e3.md`. All numbers there are real; the first two run sets were discarded (harness did not install the app, see the results page).

Remaining (none started):
1. **Explain the table stream CPU** (30.7 s here, 7.73 s in E1; collection agrees with E1). Suspects: this lane's changes to `DebugBar` and `RoomViewController`, the simulator used (E1 used uvs-r3-a, this lane uvs-r3-b). Rerun E1Table, R5SavedTop on both simulators: `Harness/record.sh --build x --round 1 --out-dir <new dir> --derived <dir> --app-path <dd>/Build/Products/Release-iphonesimulator/R5SavedTop.app --sim <udid> --only testLiveStream,launch` (build first with `xcodebuild build -project spikes/round5/Round5Spikes.xcodeproj -scheme R5SavedTop -configuration Release -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath <dd> CODE_SIGNING_ALLOWED=NO`, inside `buildslot run`). `launch` must be in `--only`.
2. A third stream pass for the four E2 apps.
3. (c) on the self-sizing collection layout, and load older from the middle of the list.
4. Fix `E2CollectionSelf` (crash in `_updateVisibleCellsNow` at text size at the bottom).
5. Fix `bench-inner.sh` so `--only` includes `launch`.

Clock mode: `xcrun simctl spawn <udid> defaults write -g uvsClock frame|work`.
