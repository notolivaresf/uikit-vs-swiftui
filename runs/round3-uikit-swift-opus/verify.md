# Round 3 verification: uikit-swift-opus (pair 2)

Verified 21 Oct 2026, about 03:16 CST, after both launchers had exited. One full direct run (`bench-client.py --direct`, simulator a, through buildslot), nothing else measuring. The build folder was measured as it was.

| Measure | Before | After (agent's NOTES) | After (measured here) |
| --- | ---: | ---: | ---: |
| First 40 rows, cold | 205 ms | 165 ms | 175 ms |
| First 40 rows, repeated | 671 ms | 630 ms | 638 ms |
| Stream CPU | 8.2 s | 4.9 s | 6.4 s |
| Jump to message 2,500 | 60 ms | 44 ms | 41 ms |
| Load older | 55 ms | 48 ms | 39 ms |
| Text size, at the bottom | 49 ms | 46 ms | 44 ms |
| Text size, mid-list | 67 ms | 44 ms | 42 ms |
| Peak memory | 117.6 MB | 53.4 MB | 53.9 MB |
| App size | 1.34 MB | 0.84 MB | 0.84 MB |

Checks: 13 of 13 (before: 13 of 13).

- Isolation audit (`round3-audit.py`, parsed the Claude stream-json fine): nothing flagged.
- Locks (`lockcheck.py verify`): ok.
- Stack rule (`check-stack.sh uikit`): ok.
- NOTES.md claims: everything held except stream CPU. The NOTES table says 4.9 s; measured here 6.4 s (the same NOTES text mentions 7.2 to 6.5 s after the 100 ms coalescing change, so 6.4 s fits that and the 4.9 s looks like a best run). Still 1.8 s below the 8.2 s baseline. Note also that the agent coalesced stream events every 100 ms (was 50 ms), so the stream does less work per second by design.
