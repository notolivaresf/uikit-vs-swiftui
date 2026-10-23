# Campfire

A native AppKit chat-room benchmark for macOS 15 or later. Open `Campfire.xcodeproj`, select the **Campfire** scheme, and Run. Signing uses a local ad-hoc identity; no development team is required.

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire \
  -configuration Release -derivedDataPath build build
open -n build/Build/Products/Release/Campfire.app
```

The View menu changes the room’s text size without the benchmark bar.

Show the benchmark controls:

```sh
open -n build/Build/Products/Release/Campfire.app --args -uvsBenchmark YES
```

The Xcode project includes the unchanged local `CampfireKit` package. `project.yml` is the optional XcodeGen source for regenerating the checked-in project.

The room uses a native `NSScrollView`, visible-row virtualization, cached TextKit measurements, and selectable `NSTextView` message bodies. Scroll anchors use message IDs and fractional point offsets. History paging, text resizing, window resizing, live messages, and boost changes all use the same anchor restoration path. Light and dark colors follow the system appearance. The composer and room toolbar are decorative controls.

Run the app's behavioral checks:

```sh
./Harness/smoke.sh
./Harness/smoke.sh --dark
./Harness/smoke.sh --timed-stream
```

Checks cover paging, a partially hidden scroll anchor, all text-size steps, 1200 × 1200 resizing, pinned and unpinned updates, 600 stream messages, boost wrapping, native selection and copying, and accessibility roles and labels. The timed option also runs the actual 30-second live stream. Reports and rendered window captures are written to `/tmp/campfire-smoke.txt` and `/tmp/campfire-*.png`.
