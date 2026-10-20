# Level 2: best UIKit against best SwiftUI

Fernando asked (20 Oct) for the best UIKit build against the best SwiftUI build of Level 2. Every number is from `docs/results-l2.md` (round 1, iPhone 12). Swift and Objective-C UIKit builds were both candidates.

![Best of UIKit vs best of SwiftUI, Level 2](images/results-l2-best.png)

(Dark version: `images/results-l2-best-dark.png`; rendered with `python3 Harness/tools/results_table.py --l2-best`.)

## The picks

- **Best UIKit: opus-uikit-ours-pair (Swift).** It is the only one of the six Level 2 builds that passes every behaviour and the stack rule, so nothing else is needed to break the tie.
- **Best SwiftUI: sol-swiftui-apple.** Both SwiftUI builds fail the same two behaviours (stack rule, text selection), so the tie-breakers decide: it has 0 fling hitches against 5, 242 stream hitches against 425, half the peak memory (103.4 against 215.4 MB) and about a quarter of the agent time (1209 s against 4301 s); cold launch was not measured for either.
- Objective-C note: the best Objective-C build, opus-objc-ours-objc-pair, is close on speed (158 ms first content, 34 ms load older, 52.0 MB) but fails text selection (1 fail against 0), so it ranks second among UIKit.

## Head to head

| Row | UIKit: opus-uikit-ours-pair | SwiftUI: sol-swiftui-apple | Winner |
|---|---|---|---|
| Passes everything | pass | 2 fails (stack rule, text selection) | UIKit |
| Stack rule | pass | fail: imports UIKit's UIPasteboard | UIKit |
| First content (time to 40 rows) | 252 ms cold, 256 ms repeated | 314 ms cold, 408 ms repeated | UIKit |
| Cold launch (Instruments) | 843 ms (1 of 3 samples) | not measured: 0 of 3 traces saved before the 300 s cap | none |
| Fling | 58.0 fps, 2 hitches (33 ms in 51 s) | 58.0 fps, 0 hitches (41 s) | SwiftUI |
| Jump to message 2500 | 90 ms, drift 0.0 pt | 191 ms, drift 0.1 pt | UIKit |
| Load older keeps place | 93 ms, drift 0.0 pt | 143 ms, drift 0.1 pt | UIKit |
| Live stream, 600 messages | pass, pinned; 15.2 fps, 1 hitch (17 ms); CPU 12.2 s | pass, pinned; 33.2 fps, 242 hitches (4.9 s); CPU 22.1 s | UIKit (hitches, CPU) |
| Text size change | 83 ms bottom, 103 ms mid-list | 123 / 139 ms | UIKit |
| Rotation, boost burst, context menu | pass | pass | tie |
| Text selection | pass (also long press) | fail | UIKit |
| Peak memory | 107.9 MB | 103.4 MB | SwiftUI (4% less) |
| App size | 0.71 MB | 1.20 MB | UIKit |
| Agent wall time / turns / builds (failed) | 2231 s / 95 / 12 (0) | 1209 s / 113 / 15 (8) | SwiftUI on time; UIKit on turns and builds |

## Takeaways

- UIKit wins 9 of 14 rows; SwiftUI wins 3 (fling hitches, peak memory by 4%, agent time); one is a tie and one is not measured.
- The clearest gap is correctness: the best UIKit build passes everything, while even the best SwiftUI build still uses UIKit's UIPasteboard for Copy and cannot select text.
- The stream is the other big gap: SwiftUI shows more frames per second (33.2 against 15.2) but drops 242 frames and burns 22.1 s of CPU against 12.2 s; UIKit redraws only when a message lands, so read fps together with hitches.
- UIKit is faster in every timed action (first content, jump, load older, text size), by about 60 to 100 ms.
- SwiftUI was cheaper for the agent in wall time (1209 s against 2231 s) but needed more turns and 8 failed builds against none, so the saving is not clean.
