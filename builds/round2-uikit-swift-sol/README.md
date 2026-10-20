# Campfire

An iOS 18+ UIKit chat-room benchmark. Open **Campfire.xcodeproj** and run the **Campfire** scheme. The application identifier is `campfire.bench`. The local `CampfireKit` package is linked without modifications; the app performs no fixture-file loading.

Add `-uvsBenchmark YES` to the scheme's launch arguments to show Reset, Jump to 2500, Load older, Start stream, Text size +, Boost burst, and the live state/timing label. Reset restores the original dataset and default system text size. The stream runs once per reset. The composer, room controls, attachment actions, Reply, and Add boost are intentionally inert.

The room uses a collection view with a compositional layout, stable message identifiers, a diffable data source, and cached attributed-text measurements. Every layout mutation captures a message identifier and its vertical position before updating, then restores that anchor or the bottom. Incoming events are coalesced over 80 ms. Visible messages use selectable text views; long-press text to select a range and copy it, or long-press metadata for the message's Copy/Reply menu.

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
