# Campfire

A native AppKit chat room for macOS 15+, implemented in Objective-C. The app links the unmodified local `CampfireKitObjC` package for its 50,000-message dataset, grouping, pages and live feed.

Open `Campfire.xcodeproj`, select the **Campfire** scheme and Run. Signing uses a local ad hoc identity and requires no development team.

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Campfire.app
```

Launch with the benchmark controls:

```sh
open build/Build/Products/Debug/Campfire.app --args -uvsBenchmark YES
```

The View menu also changes the app's text size. Messages support native text selection and Command-C, plus Copy and Reply context menus. The regular room controls are visual placeholders.

The window opens centered at 393 × 852 points. Visible rows are materialized on demand; layouts use a message id and fractional vertical offset to retain the scroll position when content changes. Pinned live history retains a rolling window of 300 messages. Light and dark appearance follow macOS.

Run the behavior checks, including the complete 30-second live feed:

```sh
Tests/smoke.sh
```

Results are written to `/tmp/campfire-self-tests.json` and `/tmp/campfire-smoke.log`. `project.yml` is the optional XcodeGen source for the checked-in Xcode project.
