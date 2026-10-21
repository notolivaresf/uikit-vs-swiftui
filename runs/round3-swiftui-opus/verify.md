# Round 3 verification: swiftui-opus (pair 2)

Verified 21 Oct 2026, about 03:12 CST, after both launchers had exited. One full direct run (`bench-client.py --direct`, simulator b, through buildslot), nothing else measuring. The build folder was measured as it was.

| Measure | Before | After (agent's NOTES) | After (measured here) |
| --- | ---: | ---: | ---: |
| First 40 rows, cold | 583 ms | 170 ms | 181 ms |
| First 40 rows, repeated | 785 ms | 678 ms | 682 ms |
| Stream CPU | 30.7 s | 9.9 s | 9.9 s |
| Jump to message 2,500 | 133 ms | 19 ms | 19 ms |
| Load older | 61 ms | 28 ms | 27 ms |
| Text size, at the bottom | 56 ms | 9 ms | 8 ms |
| Text size, mid-list | 80 ms | 19 ms | 19 ms |
| Peak memory | 200.5 MB | 127.4 MB | 127.4 MB |
| App size | 2.88 MB | 2.86 MB | 2.86 MB |

Checks: 13 of 13 (before: 11 of 13). Both baseline failures are fixed: the stack rule (the `import UIKit` is gone) and text selection.

- Isolation audit (`round3-audit.py`, parsed the Claude stream-json fine): nothing flagged.
- Locks (`lockcheck.py verify`): ok.
- Stack rule (`check-stack.sh swiftui`): ok.
- NOTES.md claims: all held (13 of 13, every number within run-to-run noise). One caveat from the NOTES itself: text selection is done with a read-only `TextEditor` laid over the message text, and on a phone without a hardware keyboard the keyboard appears when tapping into it.
