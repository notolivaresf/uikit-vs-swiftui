Campfire is an Objective-C UIKit iPhone app targeting iOS 18+, with bundle identifier `campfire.bench`.

Open `Campfire.xcodeproj`, select the Campfire scheme, and run. Add `-uvsBenchmark YES` to the scheme's launch arguments to show the benchmark controls. The checked-in Xcode project is ready to use; `project.yml` regenerates it with XcodeGen.

All message data, UTC grouping, history pages, and live events come from the unchanged local `CampfireKitObjC` package. The app target contains only Objective-C source. Images use the package's documented equivalent solid RGB placeholder. The supplied screenshots contain different sample names and messages than the fixed package dataset; the app uses the package's content with the supplied visual measurements.

Rows use registered collection cells, content configurations, a compositional layout, and stable message IDs in a diffable data source. Height measurements are cached by viewport width and text size. Updates capture the visible message ID and its offset from the header, then restore that position after layout. Each measured row height is rounded up to a whole point so adjacent items cannot overlap through independent pixel rounding. Inter-row spacing uses section insets.

Run UI checks with:

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -destination 'platform=iOS Simulator,name=CF iPhone 16' test
```

The tests cover launch latency, paging, jump alignment, text-size and rotation anchoring, boost growth, live stream completion, and long-press interactions. Test results include screenshots. For a manual hitch check, start the stream, scroll away from the bottom, load older messages, change text size, and rotate; use Instruments Animation Hitches to inspect frame pacing.

The original Campfire icons and welcome artwork are from [basecamp/once-campfire](https://github.com/basecamp/once-campfire/tree/main/app/assets/images). Their MIT license is included in `Campfire/Assets-LICENSE.txt`.
