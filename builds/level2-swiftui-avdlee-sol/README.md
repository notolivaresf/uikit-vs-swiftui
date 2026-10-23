# Campfire

A single-room iPhone UI built with SwiftUI, targeting iOS 18+, with bundle identifier `campfire.bench`.

Open `Campfire.xcodeproj` and run the **Campfire** scheme. The shared scheme uses Release for running and testing so the unchanged local CampfireKit package generates its 50,000-message dataset with optimization enabled. No network or external package download is required. `project.yml` is the optional XcodeGen source for the checked-in project.

To show the benchmark controls, add `-uvsBenchmark YES` to the scheme's launch arguments, or launch an installed simulator build:

```sh
xcrun simctl launch booted campfire.bench -uvsBenchmark YES
```

The debug controls scroll horizontally. Reset also rearms the fixed live-stream script. Their state label reports actual loaded IDs and measured row geometry; `ms` measures from app initialization or a timed button action through committed scroll layout. Stream and boost actions leave that timing unchanged.

## Behavior

- Opens on the newest 40 package messages; all message, person, attachment, grouping, and live-feed data comes from CampfireKit.
- Retains one page at the live tail and a bounded history window during ordinary paging. Paging temporarily keeps additional rows when trimming would remove the current reading position.
- Tracks the visible message and its point offset across page inserts, Dynamic Type, rotation, and changing boosts. Incoming messages remain in history while an unpinned reader stays in an older window; the jump button returns to the live tail.
- Long-press a row for Copy, Reply, or Select text. Select text activates a constant-bound SwiftUI TextEditor with native range handles and a keyboard toolbar for copying the selection or ending selection. Messages cannot be changed through its binding. This fallback is necessary because [SwiftUI Text selection copies the whole view on iOS 18–26](https://developer.apple.com/documentation/swiftui/view/textselection(_:)).
- The room, composer, attachment actions, and boost buttons are visual controls as specified; Reply does nothing.

All app views, layouts, text selection, context menus, and scrolling use SwiftUI. UIKit is imported solely for the system clipboard (`UIPasteboard`); no UIKit views, representables, hosting controllers, or view introspection are used.

## Validation

```sh
swift test --package-path CampfireKit -c release
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=uvs-avdlee-16' \
  -parallel-testing-enabled NO test
```

UI tests cover startup latency, pagination and point offsets, jumping to message 2,500, pinned and unpinned Dynamic Type and rotation, boost growth, both reading modes during the full 600-message feed, and the context menu/range-selection editor. Tests attach room screenshots to their `.xcresult`.

The supplied screenshots and constants supply the visual style. Their example names, message text, and dates differ from the immutable package dataset, which the running app preserves. The welcome artwork and template icon masks are extracted from the supplied reference screenshots; Campfire/37signals artwork and the reference UI are credited to 37signals. Screenshot assets and constants are not loaded or parsed by the app.

For native reference snapshots, boot an iPhone simulator and run:

```sh
scripts/verify-references.sh
python3 scripts/check-reference-renders.py
```

The standalone validation probe compiles the unchanged package models with the production row and chrome views to construct the supplied reference examples. It is separate from the app target and writes light/dark PNGs to `build/reference-renders`. The checker requires Pillow and verifies all ten row heights and the nine visible bubble rectangles in both appearances against the 2 pt tolerance. Full-room renders support visual review. The measured geometry report is saved alongside the PNGs.
