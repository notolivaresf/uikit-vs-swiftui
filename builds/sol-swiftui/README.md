# Campfire

A single-room, iOS 18 SwiftUI app. Open `Campfire.xcodeproj` and run the **Campfire** scheme. The bundle identifier is `campfire.bench`.

The shared scheme uses Release builds so the 50,000-message generation and launch benchmark run with optimizations, including the unchanged local CampfireKit package. No network service or downloaded content is required.

Add `-uvsBenchmark YES` to the scheme's launch arguments for the benchmark controls and live state label. The normal launch has only the room UI. The composer and room controls are intentionally inert.

The room uses CampfireKit's generated history, UTC grouping, windowing, and live feed. A measured SwiftUI scroll position preserves the visible message through page loads, text-size changes, rotation, and boost updates. At most 300 message views are retained. Images are the package's solid-colour placeholders. Long-press text for range selection, draggable handles, Copy, and Reply. All views and selection controls are SwiftUI; the only UIKit API used is the system clipboard, `UIPasteboard`.

Build or test with an available iPhone simulator:

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test

xcodebuild -project Campfire.xcodeproj -scheme CampfireLayout \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' test

swift test --package-path CampfireKit -c release
```

The CampfireLayout scheme renders all ten reference rows in both appearances and verifies row heights and bubble positions and widths within 2 points. UI tests cover startup timing, exact jump positioning, prepend preservation, partial-row preservation, Dynamic Type, rotation, automatic pagination, the full 600-message stream, boost bursts, and text selection. `project.yml` is the XcodeGen source for the checked-in project.
