# Round 3 verification: uikit-objc-sol (pair 3)

Verified 21 Oct 2026, about 05:12 CST, after both launchers had exited. One full direct run (`bench-client.py --direct`, simulator a, through buildslot), nothing else measuring. The build folder was measured as it was.

| Measure | Before | After (agent's NOTES) | After (measured here) |
| --- | ---: | ---: | ---: |
| First 40 rows, cold | 175 ms | 160 ms | 161 ms |
| First 40 rows, repeated | 649 ms | 632 ms | 636 ms |
| Stream CPU | 15.6 s | 8.7 s | 8.8 s |
| Jump to message 2,500 | 65 ms | 40 ms | 40 ms |
| Load older | 59 ms | 5 ms | 4 ms |
| Text size, at the bottom | 18 ms | 12 ms | 12 ms |
| Text size, mid-list | 29 ms | 21 ms | 22 ms |
| Peak memory | 45.6 MB | 44.2 MB | 44.4 MB |
| App size | 3.13 MB | 2.77 MB | 2.77 MB |

Checks: 13 of 13 (before: 12 of 13; text selection now passes). All nine numbers print "better".

- Isolation audit (`round3-audit.py`, Codex transcript): nothing flagged.
- Locks (`lockcheck.py verify`): ok.
- Stack rule (`check-stack.sh objc`): ok. No Swift or SwiftUI outside CampfireKit (the supplied package): the app and tests are only .h/.m files.
- NOTES.md claims: all held (13 of 13, every number within run-to-run noise).

Changes that alter what the test exercises:

- Loaded messages are kept instead of trimmed to 300, so the stream test ends with 640 messages loaded. The same stream now costs less CPU despite holding more rows, but memory and later steps work on a longer list than the baseline did.
- The list keeps one collection section with explicit insert batches and a custom layout holding a balanced height index (instead of one section per message and whole-room snapshots). Appends, prepends and boost height changes no longer touch every row.
- Load older measures only the new page's messages (59 ms to 4 ms is mostly this).
- Reset and Jump build a fresh collection; Reset reuses an unchanged newest page at the default size (this helped peak memory).
- Symbol stripping is on for Release (app size).
- Text selection fix: the menu keeps the system actions with Reply first.
- The NOTES warn that single-number runs can measure a stale install; the full run used here rebuilds, so it is not affected.
