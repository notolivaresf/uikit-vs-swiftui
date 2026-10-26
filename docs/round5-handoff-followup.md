# Round 5 follow-up hand-off

Done: record.sh `--only` installs the app (commit 3da9ff2); E2CollectionSelf crash fixed (same commit); the 30.7 s explained (test polling, see `docs/round5-results-e2e3.md`).

Left:
1. Third E2 stream pass for the four E2 apps (use the XCUITest harness only for comparing like with like; for table against collection also run the unpolled `simctl launch -uvsAutoStream` + `ps -o cputime` read).
2. (c) on the self-sizing collection layout; Load older from mid-list.
3. Prove why UITableView costs XCUITest polling so much (Time Profiler on the app while `testLiveStream` runs), if it matters for the skill.
4. Self-sizing collection now ends unpinned after 2 of 6 text size steps at the bottom (same as the self-sizing table).
Diagnostic left in `Apps/E1Table/TableAdapter.swift`: `defaults write -g uvsCache 1` (height cache by id; no effect on CPU).
