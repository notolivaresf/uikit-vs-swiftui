# Level 2: best Swift UIKit, best Objective-C UIKit and best SwiftUI

Fernando asked (20 Oct) for the best UIKit build against the best SwiftUI build of Level 2, then for UIKit split into Swift and Objective-C. Every number is from `docs/results-l2.md` (round 1, iPhone 12). Each pick is the build that passes the most behaviours, then wins the performance tie-breakers (fling and stream hitches and fps, memory, launch, agent cost).

![Best Swift UIKit, Objective-C UIKit and SwiftUI, Level 2](images/results-l2-best.png)

(Dark version: `images/results-l2-best-dark.png`; rendered with `python3 Harness/tools/results_table.py --l2-best`.)

## The picks

- **Best Swift UIKit: opus-uikit-ours-pair.** It passes every behaviour and the stack rule, the only one of the six Level 2 builds that does.
- **Best Objective-C UIKit: opus-objc-ours-objc-pair.** It and sol-objc-ours-objc-pair both miss only text selection, and Opus has the smoother stream (3 hitches and 11.9 s of CPU against 9 and 18.7 s) and wins first content, jump, load older and app size, while Sol wins memory (35.0 against 52.0 MB), launch and agent time, so Sol is close.
- **Best SwiftUI: sol-swiftui-apple.** Both SwiftUI builds fail the same two behaviours (stack rule, text selection), so the tie-breakers decide: 0 fling hitches against 5, 242 stream hitches against 425, 103.4 MB against 215.4 MB, and 1209 s of agent time against 4301 s; cold launch was not measured for either.

## Head to head

| Row | UIKit, Swift: opus-uikit-ours-pair | UIKit, Objective-C: opus-objc-ours-objc-pair | SwiftUI: sol-swiftui-apple | Winner |
|---|---|---|---|---|
| Passes everything | pass | 1 fail (text selection) | 2 fails (stack rule, text selection) | Swift UIKit |
| Stack rule | pass | pass | fail: imports UIKit's UIPasteboard | Swift and Objective-C UIKit |
| First content (time to 40 rows) | 252 ms cold | 158 ms cold | 314 ms cold | Objective-C UIKit |
| Cold launch (Instruments) | 843 ms (1 of 3 samples) | not measured: 0 of 3 traces saved before the 300 s cap | not measured: same | none |
| Fling | 58.0 fps, 2 hitches (33 ms in 51 s) | 58.7 fps, 2 hitches (33 ms in 52 s) | 58.0 fps, 0 hitches (41 s) | SwiftUI (hitches) |
| Jump to message 2500 | 90 ms | 67 ms | 191 ms | Objective-C UIKit |
| Load older keeps place | 93 ms | 34 ms | 143 ms | Objective-C UIKit |
| Live stream, 600 messages | 15.2 fps, 1 hitch (17 ms), CPU 12.2 s | 27.3 fps, 3 hitches (67 ms), CPU 11.9 s | 33.2 fps, 242 hitches (4.9 s), CPU 22.1 s | Swift UIKit (hitches) |
| Text size change | 83 / 103 ms | 77 / 93 ms | 123 / 139 ms | Objective-C UIKit |
| Rotation, boost burst, context menu | pass | pass | pass | tie |
| Text selection | pass | fail | fail | Swift UIKit |
| Peak memory | 107.9 MB | 52.0 MB | 103.4 MB | Objective-C UIKit |
| App size | 0.71 MB | 0.66 MB | 1.20 MB | Objective-C UIKit |
| Agent wall time / turns / builds (failed) | 2231 s / 95 / 12 (0) | 2884 s / 106 / 12 (0) | 1209 s / 113 / 15 (8) | SwiftUI on time |

## Takeaways

- Of 14 rows, Objective-C UIKit wins 7 (one shared), Swift UIKit 4 (one shared), SwiftUI 2; one row is a tie and one is not measured.
- Only the Swift UIKit build passes everything; the Objective-C build misses text selection, and the SwiftUI build also fails the stack rule (it uses UIKit's UIPasteboard for Copy).
- Objective-C UIKit is the quickest and leanest: first content 158 ms, load older 34 ms, 52.0 MB against 107.9 MB (Swift) and 103.4 MB (SwiftUI).
- The stream is where SwiftUI is clearly behind: 242 dropped frames and 22.1 s of CPU against 1 to 3 hitches and about 12 s for both UIKit builds. Its higher fps (33.2) is not smoothness; read fps together with hitches.
- SwiftUI wins fling hitches (0 against 2 for both UIKit builds, though the Objective-C build has the highest fling fps, 58.7) and agent time (1209 s), but needed 8 failed builds against none for both UIKit builds.
