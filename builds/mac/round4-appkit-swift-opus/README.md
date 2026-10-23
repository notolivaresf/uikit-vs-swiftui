# Campfire room (AppKit, Swift)

One Mac window showing a single ONCE Campfire chat room, drawn with AppKit only (no SwiftUI).
Data comes from the `CampfireKit` package in this folder, added to the app unchanged.

## Build and run

    xcodebuild -project Campfire.xcodeproj -scheme Campfire -configuration Release build
    open build/…/Campfire.app        # or run from Xcode

The app is ad-hoc signed (`CODE_SIGN_IDENTITY = -`), so no signing team is needed. Bundle id
`campfire.bench`, macOS 15. `Campfire.xcodeproj` is generated from `project.yml` with XcodeGen.

Launch with `-uvsBenchmark YES` to show the debug bar (the scheme has this argument, unchecked).

## Layout of the code

- `RoomController.swift`: loaded window of messages, anchoring (pinned / row at offset), paging,
  live stream, boosts, text size, debug bar.
- `RowLayout.swift`: per-row geometry from `Fixtures/constants.json`; TextKit 1 measuring.
- `RowView.swift`: row drawing; message text in selectable `NSTextView`s with Copy / Reply menu.
- `RoomViews.swift`: root view, scroll view (keeps the reading position across resizes), virtualized
  document view.
- `Chrome.swift`: header, composer, welcome card, jump-to-bottom button, debug bar.
- `DevSnapshot.swift`, `DevScript.swift`: development aids driven by environment variables
  (`CF_SNAPSHOT`, `CF_SCRIPT`); inactive otherwise.
