# Campfire

A single-window, SwiftUI Mac implementation of the supplied Campfire benchmark. Requires macOS 15 or later. The Xcode project is ready to open and uses **Sign to Run Locally**; no development team is needed.

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Campfire.app
```

For the benchmark controls, quit the app and launch it with:

```sh
open build/Build/Products/Debug/Campfire.app --args -uvsBenchmark YES
```

The room uses the unchanged local `CampfireKit` package for all history, live messages, presentation grouping, pages, and structured attachments. Its seeded names and messages differ from the screenshot copy. Production never reads the fixture JSON or screenshots. The reference colours, typography, spacing, and geometry are encoded in the SwiftUI views.

`RoomScroll` records each row in content coordinates and restores an id plus its offset after a layout change. It waits for scroll geometry to confirm the restored position before updating the benchmark timing. The live feed is the package's real-time `AsyncStream`; the debug boost burst reuses the five matching seeded package boosts, since `Boost` has no public initializer.

Run the offscreen rendering and behavior checks with:

```sh
Scripts/check.sh
```

The checks render all ten reference row types in both appearances and verify their heights against the fixtures within 2 pt. They also check boost wrapping at 393 and 1,200 pt, all text sizes, page loading, scroll anchor calculations, boost-burst contents, and the complete 30-second, 600-message stream. Images and the check log are in `runs/`. Reference messages are constructed only in the developer renderer using `@testable import`; the app uses the package's generated messages.

Native UI tests are included in the Campfire scheme:

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire -derivedDataPath build test
```

They cover window dimensions, jump and page anchoring, text changes, resize anchoring, the stream, and native text/context-menu interaction. An unlocked desktop is needed. During this build the Mac's screen was locked, so native interaction and on-screen launch timing could not be verified. The application and UI tests compile, and the offscreen checks pass.

The checked-in Xcode project can be regenerated from `project.yml` with XcodeGen.
