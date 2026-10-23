# Campfire room (SwiftUI)

One iPhone chat room, drawn after 37signals' ONCE Campfire, in SwiftUI only (no UIKit views or
representables). iOS 18+, bundle id `campfire.bench`. Data comes from the `CampfireKit` package, used as is.

## Build and run

```sh
open Campfire.xcodeproj          # scheme "Campfire"; Run and Test use the Release configuration
```

The project is generated from `project.yml` with XcodeGen (`xcodegen generate`); the generated
`Campfire.xcodeproj` is checked in. Launch with `-uvsBenchmark YES` for the debug bar.

## Layout

- `Campfire/Room/RoomModel.swift`: the loaded window of messages (newest 40, pages of 40, at most 300 + 20),
  the live stream, boosts, text size, the reading position and the debug label.
- `Campfire/Room/RoomView.swift`: header, message list (`ScrollView` + `LazyVStack`), composer, debug bar.
- `Campfire/Room/MessageRow.swift`: a row: day separator, bubble, avatar, meta line, body, code, image,
  file, boosts, long-press menu.
- `Campfire/Support/`: colours and metrics from `Fixtures/constants.json`, fit-content and flow layouts,
  the code highlighter, formatting.

## How the scrolling works

- Every row reports its frame in the scroll view's coordinate space. The top row and its `y` (from the
  header's bottom edge) come from those frames, using only rows whose frames chain edge to edge.
- Changes above the reader (older page, a boost on a row above) move the offset by the content-height delta
  inside the same layout pass, so nothing jumps. Text size changes and rotation re-place the remembered top
  row once the new layout has settled; "settled" means the geometry callbacks have gone quiet.
- Pinned (last row within 100 pt of the bottom): every change scrolls to the bottom edge.
- After a drag or fling, the reader's position is converted from SwiftUI's "positioned by user" to the same
  position anchored to the top row. Left as it was, the lazy stack could spin forever re-placing rows as
  messages arrived below.
- While pinned, the window is trimmed in steps of 20 (Campfire's "20+ over") rather than one row per
  message. Trimming one row per message, 20 times a second, eventually left the lazy stack with nothing
  realized on screen.

## Notes

- Images are drawn as filled rectangles of the placeholder colour and pixel aspect. The `Placeholder` docs
  say this is the same as decoding its PNG, and it avoids building megabyte PNGs on the main thread.
- Long-press shows Copy and Reply. SwiftUI `Text` on iOS can only copy its whole text, so the menu also has
  **Select Text**, which opens the message in a read-only text view where any range can be selected and
  copied.
- `CampfireKit.Boost` has no public initializer, so boosts that arrive after load are stored in the app.
- Development aids, all behind launch arguments: `-uvsGallery <row-name|room-top|room-bottom>` renders the
  reference rows from the constants file for pixel comparison with `screenshots/`, `-uvsAutorun "jump:2500,…"`
  replays debug-bar actions, and `-uvsVerbose` logs scroll geometry. `CampfireUITests` drives the debug bar
  and checks the label (launch, jump, paging, stream pinned and scrolled up, boosts, text size, rotation,
  long-press).
