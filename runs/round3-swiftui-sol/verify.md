# Round 3 verification: swiftui-sol (pair 1)

Verified 21 Oct 2026, 00:47 CST, after both launchers had exited. One full direct run (`bench-client.py --direct`, simulator a, through buildslot), nothing else measuring.

| Measure | Before | After (agent's NOTES) | After (measured here) |
| --- | ---: | ---: | ---: |
| First 40 rows, cold | 370 ms | 290 ms | 278 ms |
| First 40 rows, repeated | 883 ms | 762 ms | 755 ms |
| Stream CPU | 19.8 s | 12.4 s | 12.5 s |
| Jump to message 2,500 | 174 ms | 76 ms | 76 ms |
| Load older | 114 ms | 71 ms | 71 ms |
| Text size, at the bottom | 89 ms | 55 ms | 55 ms |
| Text size, mid-list | 111 ms | 75 ms | 73 ms |
| Peak memory | 95.3 MB | 75.4 MB | 77.2 MB |
| App size | 2.28 MB | 0.89 MB | 0.89 MB |

Checks: 12 of 13 (before: 11 of 13). Failed: "Long-press a message: select any range of its text and copy it" (text selection). The stack-rule failure from the baseline is fixed.

- Isolation audit (`round3-audit.py`): nothing flagged.
- Locks (`lockcheck.py verify`): ok.
- Stack rule (`check-stack.sh swiftui`): ok.
- NOTES.md claims: all held (12 of 13, text selection still failing, every number within run-to-run noise; peak memory 1.8 MB above the claim).
