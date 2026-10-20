# Campfire

UIKit iPhone app, iOS 18+, bundle identifier `campfire.bench`.

Open `Campfire.xcodeproj` and run the **Campfire** scheme. No dependencies need downloading: the project uses the unchanged local `CampfireKit` Swift package.

For the benchmark controls, add the two launch arguments `-uvsBenchmark YES` in the scheme's Run settings, or launch an installed simulator build with:

```sh
xcrun simctl launch booted campfire.bench -uvsBenchmark YES
```

Build and test with an available iPhone simulator:

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
swift test -c release --package-path CampfireKit
```

`project.yml` is the optional XcodeGen source for the checked-in project. Regenerate it with `xcodegen generate` if adding targets or changing project settings.

The collection view uses premeasured TextKit geometry and reusable UIKit cells. Viewport restoration stores a message id and its offset below the header; inserts, boost updates, Dynamic Type, and rotation restore that anchor or the bottom. History is paged through `Windowing`, grouping uses `Grouping`, and the only incoming messages are from `FakeLiveFeed`. The visible window is capped at 300 messages while the full generated history remains available for navigation.

Tests cover all ten reference row geometries in both appearances, all 600 live messages with pinned and unpinned readers, window trimming, jumps, pagination, Dynamic Type, rotation, and native text selection with Copy and Reply. Reference rendering attachments are retained in Xcode's test results.
