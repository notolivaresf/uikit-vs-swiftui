# Round 3 verification: uikit-swift-sol (pair 1)

Verified 21 Oct 2026, 00:51 CST, after both launchers had exited. One full direct run (`bench-client.py --direct`, simulator b, through buildslot), nothing else measuring.

| Measure | Before | After (agent's NOTES) | After (measured here) |
| --- | ---: | ---: | ---: |
| First 40 rows, cold | 195 ms | 129 ms | 130 ms |
| First 40 rows, repeated | 639 ms | 591 ms | 583 ms |
| Stream CPU | 9.8 s | 7.5 s | 7.5 s |
| Jump to message 2,500 | 38 ms | 31 ms | 32 ms |
| Load older | 33 ms | 30 ms | 31 ms |
| Text size, at the bottom | 20 ms | 18 ms | 18 ms |
| Text size, mid-list | 31 ms | 30 ms | 30 ms |
| Peak memory | 59.6 MB | 57.2 MB | 57.9 MB |
| App size | 1.20 MB | 0.79 MB | 0.79 MB |

Checks: 13 of 13 (before: 12 of 13; text selection now passes).

- Isolation audit (`round3-audit.py`): nothing flagged.
- Locks (`lockcheck.py verify`): ok.
- Stack rule (`check-stack.sh uikit`): ok.
- NOTES.md claims: all held (13 of 13, every number within run-to-run noise).
