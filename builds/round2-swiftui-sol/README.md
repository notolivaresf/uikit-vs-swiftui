# Campfire

A single-room iPhone UI benchmark, implemented with SwiftUI and the unchanged local `CampfireKit` package. Open `Campfire.xcodeproj`, select the **Campfire** scheme, and run on an iPhone simulator. Deployment target: iOS 18. Bundle identifier: `campfire.bench`.

Add `-uvsBenchmark YES` to the scheme's launch arguments to expose the benchmark controls and live layout measurements. Without that argument, only the room is displayed. The composer, room controls, Reply, and add-boost button are visual controls with no product actions.

The room opens on the last 40 seeded messages. It loads history in pages of 40, restores a measured row and its pixel offset after layout changes, and follows the bottom while pinned. During a live stream the pinned window retains the newest 80 rows; history navigation can retain up to 320 before trimming to CampfireKit's 300-row limit. All 50,000 original messages and subsequent live events remain available in the in-memory history. The stream may be started once per reset.

All displayed chat data comes from `CampfireKit`. Its seed's names, dates, and newest-page text differ from the reference screenshots. The app does not substitute screenshot messages or read fixture files at runtime. `Fixtures/constants.json` measurements are represented in the SwiftUI layout. The reference examples live only in the geometry tests.

`UIPasteboard` is used only as the system clipboard service for Copy. All views, text selection, menus, layout, scrolling, and rendering use SwiftUI; there are no view wrappers or UIKit view access.

## Verification

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
```

The tests exercise history windows, boost contents, reference row heights, jump alignment, preservation across paging, Dynamic Type and rotation, and the complete 600-message live stream. `project.yml` is the XcodeGen source for the checked-in Xcode project.
