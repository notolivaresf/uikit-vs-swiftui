# Campfire room (SwiftUI)

One iPhone chat room drawn 1:1 after 37signals' ONCE Campfire, in SwiftUI only (iOS 18, app id `campfire.bench`).
All data comes from `CampfireKit/` unchanged.

- Open `Campfire.xcodeproj` (generated from `project.yml` with `xcodegen generate`) and run the `Campfire` scheme.
- Launch with `-uvsBenchmark YES` for the debug bar and the state label.
- `CampfireUITests` drives the debug bar (launch, jump, load older, stream, text size, rotation, boosts, long-press selection).

## Layout of the code

- `RoomStore` holds the loaded window (pages of 40, at most 300 + 20), the live stream and the debug-bar actions.
- `ScrollCoordinator` keeps the room pinned to the bottom or anchored to the top row under the header across every
  layout change (older pages, new messages, boosts, text size, rotation) and produces the debug label.
- `MessageRow` and friends draw the rows with the sizes in `Fixtures/constants.json`.
- `Selection` adds long-press range selection on top of SwiftUI's `TextRenderer`, with a Copy / Reply menu.
- `LineBreaker` forces Chrome's greedy line breaking where SwiftUI would pull a word down to avoid a one-word last line.

Debug builds also accept `-uvsFixture YES` (and `-uvsFixtureTop YES`) or `-uvsFixtureRow YES -uvsRow N` to draw the
reference rows from `Fixtures/constants.json` for pixel comparison with `screenshots/`.
