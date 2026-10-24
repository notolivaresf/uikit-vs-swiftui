# Campfire

An iPhone chat-room benchmark built entirely with SwiftUI, targeting iOS 18 and using the unchanged local `CampfireKit` package. Bundle identifier: `campfire.bench`.

Open `Campfire.xcodeproj`, select the **Campfire** scheme, and run on an iPhone simulator or device. The shared scheme enables `-uvsBenchmark YES`; remove those launch arguments to hide the debug controls. No network service or credentials are needed.

The app opens at the newest 40 messages from the deterministic 50,000-message dataset. History loads in pages of 40. The live stream supplies 600 messages over 30 seconds. A measured row anchor restores the reading position after paging, Dynamic Type changes, rotation, and boost updates. The stream retains a 300-row window. Long-press message text, choose **Select text**, and drag the selection handles to copy a range; **Copy** and **Reply** are also in the context menu.

`Fixtures/constants.json` is transcribed into the design constants; the app does not read fixture files or screenshots. The supplied screenshots contain different names, dates, and message bodies from `FakeData.generate(size: .k50)`, so the running room preserves the package data. The reference geometry tests reconstruct the ten illustrated row bodies in the test target and compare their bubble sizes against the measured constants, in both light and dark appearance, with a 2-point tolerance.

Build and run tests with Xcode, or:

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The test suite covers reference geometry, initial paging, grouping, boost order, Unicode selection boundaries, scroll anchoring, rotation, resizing, automatic history loading, both live-stream reading modes, and selecting/copying a text range. UI tests retain screenshots in the test result bundle.

`project.yml` is the optional XcodeGen source for the checked-in Xcode project. Regenerate it with `xcodegen generate` after changing project configuration.
