# Campfire

An iOS 18+ UIKit chat-room benchmark. Open **Campfire.xcodeproj** and run the **Campfire** scheme. The application identifier is `campfire.bench`. The local `CampfireKit` package is linked without modifications; the app performs no fixture-file loading.

Add `-uvsBenchmark YES` to the scheme's launch arguments to show Reset, Jump to 2500, Load older, Start stream, Text size +, Boost burst, and the live state/timing label. Reset restores the original dataset and default system text size. The stream runs once per reset. The composer, room controls, attachment actions, Reply, and Add boost are intentionally inert.

The room uses one section in a collection view, stable message identifiers, a diffable data source, and cached message layouts. A prefix-height index supports point height changes and visible-range queries. New messages and boosts measure only the affected rows; text-size and width changes rebuild the loaded layouts. Every mutation restores a message anchor or the bottom after UIKit completes its update. Incoming events are coalesced over 80 ms. Native selectable text views retain the system selection actions plus Reply; metadata also has a Copy/Reply context menu.

## Build and test

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`project.yml` is included for regenerating the project with XcodeGen. XcodeGen is not needed to open or build the checked-in project.

The unit tests check all ten reference bubble rectangles against the supplied measurements with a 2 pt tolerance, along with image aspect ratios, boost wrapping, theme colors, Dynamic Type growth, and selectable-text sizing. They attach light and dark reference-row renders to the test results. UI tests check launch timing, page anchoring, the jump target, Dynamic Type, rotation, pinned and unpinned streaming, boost updates, and text-selection menus.

For a device hitch check, use a Release build and Instruments' Animation Hitches template while streaming and scrolling in both directions. The app emits `campfire.bench / Room / Layout update` signpost intervals. Simulator launch timings do not establish physical-device performance.

## Reference assets

Measurements and colors are transcribed from `Fixtures/constants.json`. The supplied screenshots show a different conversation, names, and dates from the package's fixed dataset; the running app displays the package's data as requested. The screenshots also have no iPhone cutout or home indicator. Pixel-identical full-screen captures therefore depend on matching content and capture geometry; a 2 pt screenshot match is not claimed by the automated checks.
