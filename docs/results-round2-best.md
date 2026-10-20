# Round 2: best of UIKit against best of SwiftUI

Fernando's brief (20 Oct): "The best should be the best of each metric regardless if we mix and match", then "just best of UIKit vs. best of SwiftUI and mark in each row if it's Swift/ObjC". So each column shows, row by row, the best value among that stack's builds, and each cell names where it came from. UIKit is the best of four builds (Swift and Objective-C, each by Opus and by Sol); SwiftUI is the best of two (Opus and Sol). A column is therefore not one build. Every number is from `docs/results-round2.md` (pass 1, iPhone 12).

![Best of UIKit vs best of SwiftUI per row, Round 2](images/results-round2-best.png)

(Dark version: `images/results-round2-best-dark.png`; rendered with `python3 Harness/tools/results_table.py --round2-best`.)

How a cell is chosen: lowest time, hitches, memory or size; pass if any build of that stack passed. Fling and stream lead with hitches (late frames you can see), fps second: fps counts redraws, so a build that redraws only when a message lands shows fewer frames without stuttering. The winner of a row is the better of the two columns; ties both win.

## Head to head (source build in brackets)

| Row | UIKit (best of 4) | SwiftUI (best of 2) | Winner |
|---|---|---|---|
| Passes everything | pass (Swift, Opus) | 2 fails (Opus and Sol) | UIKit |
| Stack rule | pass (all four builds) | fail, UIPasteboard (Opus and Sol) | UIKit |
| First 40 rows, cold | 158 ms (Objective-C, Opus) | 314 ms (Sol) | UIKit |
| Cold launch (Instruments) | 736 ms, 2 of 3 traces (Objective-C, Sol) | not measured: 0 of 3 traces saved | UIKit |
| Fling | 0 hitches, 58.2 fps, 49 s (Swift, Sol) | 0 hitches, 58.0 fps, 41 s (Sol) | tie |
| Live stream, 600 messages | 1 hitch (17 ms), 15.2 fps, CPU 12.2 s (Swift, Opus) | 242 hitches (4.9 s), 33.2 fps, CPU 22.1 s (Sol) | UIKit |
| Jump to message 2500 | 67 ms (Objective-C, Opus) | 154 ms (Opus) | UIKit |
| Load older | 34 ms, drift 0.1 pt (Objective-C, Opus) | 86 ms, drift 0.2 pt (Opus) | UIKit |
| Text size change (bottom / mid-list) | 53 / 70 ms (Swift, Sol) | 76 / 108 ms (Opus) | UIKit |
| Rotation, boost burst, context menu | pass (all builds) | pass (both builds) | tie |
| Text selection | pass (Swift, Opus) | fail (Opus and Sol) | UIKit |
| Peak memory | 35.0 MB (Objective-C, Sol) | 103.4 MB (Sol) | UIKit |
| App size | 0.64 MB (Swift, Sol) | 1.20 MB (Sol) | UIKit |
| Agent wall time, turns, builds (failed) | 1233 s, 90, 14 (7) (Swift, Sol) | 1209 s, 113, 15 (8) (Sol) | SwiftUI |

Cold launch is not comparable to Round 1: only 2 of 3 traces saved for the measured UIKit build, and none for SwiftUI before the 300 s cap.

## Win counts

Of 14 rows: UIKit wins 11 outright and shares fling (12 in all), SwiftUI wins 1 outright (agent time) and shares fling (2 in all), and one row, rotation, boost burst and context menu, is a tie. Of UIKit's 12 winning cells, Swift supplies 6 (passes everything, fling, stream, text size, text selection, app size), Objective-C supplies 5 (first content, cold launch, jump, load older, peak memory), and the stack rule comes from all four builds.

## Takeaways

- UIKit wins 11 of 14 rows outright and ties fling; SwiftUI wins only agent time (1209 against 1233 s, a 24 s gap).
- Neither language sweeps UIKit's side: Swift gives the cleanest correctness and smoothness (the only build that passes everything and selects text, 1 stream hitch, 0 fling hitches), Objective-C gives the quickest and leanest (first content 158 ms, jump 67 ms, load older 34 ms, 35.0 MB).
- The stream is the biggest gap: 242 hitches and 22.1 s of CPU for SwiftUI against 1 hitch and 12.2 s for the best UIKit. SwiftUI's higher fps (33.2) is redraws, not smoothness.
- SwiftUI is level on fling (0 hitches both) and loses everywhere else except agent time, and even its best build fails the stack rule (it uses UIKit's UIPasteboard for Copy) and text selection.
- SwiftUI's agent-time win is thin: 1209 s took 113 turns and 8 failed builds, against 90 turns and 7 failed for UIKit's 1233 s.
