# Round 3 verification: uikit-objc-opus (pair 3)

Verified 21 Oct 2026, about 05:18 CST, after both launchers had exited. One full direct run (`bench-client.py --direct`, simulator b, through buildslot), nothing else measuring. The build folder was measured as it was.

| Measure | Before | After (agent's NOTES) | After (measured here) |
| --- | ---: | ---: | ---: |
| First 40 rows, cold | 165 ms | 118 ms | 135 ms |
| First 40 rows, repeated | 640 ms | 597 ms | 598 ms |
| Stream CPU | 8.4 s | 4.6 s | 4.6 s |
| Jump to message 2,500 | 37 ms | 47 ms | 40 ms |
| Load older | 41 ms | 41 ms | 42 ms |
| Text size, at the bottom | 44 ms | 47 ms | 46 ms |
| Text size, mid-list | 45 ms | 46 ms | 44 ms |
| Peak memory | 67.9 MB | 52.9 MB | 52.8 MB |
| App size | 1.18 MB | 0.71 MB | 0.71 MB |

Checks: 13 of 13 (before: 12 of 13; text selection now passes). Rows cold, repeated, stream CPU, mid-list text size, memory and size print "better"; jump, load older and bottom text size print "to beat" (3 to 4 ms above the baseline), as the agent said.

- Isolation audit (`round3-audit.py`, Claude stream-json): 4 lines flagged, all false positives. Two Reads of the harness's own overflow files (`tool-results/*.txt`) under the agent's own Claude project folder, whose path contains the build name `round3-uikit-objc-opus` and `uvs-builds`, so the sibling pattern matched. Each is flagged once as "path" and once as "sibling". No other build folder or repo was touched.
- Locks (`lockcheck.py verify`): ok.
- Stack rule (`check-stack.sh objc`): ok. No Swift or SwiftUI outside CampfireKit (the supplied package): the app and UI tests are only .h/.m files.
- NOTES.md claims: held except first-40-rows cold: NOTES says 118 ms, measured 135 ms (the NOTES' previous near-final run was 126 ms; still 30 ms under the 165 ms baseline). Everything else is within run-to-run noise. The agent's own statement that jump, load older and the text-size rows do not reliably beat the baseline held.

Changes that alter what the test exercises:

- The list is no longer a `UICollectionView`: it is a `UIScrollView` that places and recycles row views itself.
- Message bodies are drawn from a pre-measured TextKit 1 layout; the real selectable `UITextView` is filled and swapped in from `hitTest:` when a touch lands on the text. Text-size steps therefore no longer set text on about 12 text views (9 of the 10.5 ms), and selection checks pass through the swap.
- Live stream changes are applied at most every 100 ms (was per event), and the state label follows at most every 100 ms, so the stream does less work per second by design. The label's font is fitted once per width.
- Jump loads one page (10 rows above, 29 below message 2,500) instead of 81 rows.
- The next older page is prefetched (wrapped and laid out in the background) after launch, jump, reset and each older page, so Load older mostly inserts ready rows.
- Launch work (dataset, store, newest page and its layout) runs on a background thread using the row width and text size saved in user defaults from the previous launch; this is state carried between launches, relevant to the cold and repeated launch numbers.
- Row layout runs in parallel (`dispatch_apply`), and appends, prepends and boost growth lay out only the affected rows.
- Image placeholders are a plain filled view instead of a generated PNG with a 64 MB bitmap cache (same pixels).
- Symbol and dead code stripping are on for Release (app size).
- Text selection fix: the menu returns Reply followed by the system's suggested actions.
