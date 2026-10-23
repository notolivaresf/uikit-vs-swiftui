# Campfire room (SwiftUI, macOS)

One window showing a single ONCE Campfire chat room, built with SwiftUI only. Data comes from the
`CampfireKit` package (added as a local package, unchanged).

## Build and run

```sh
xcodebuild -project Campfire.xcodeproj -scheme Campfire build
open build/Build/Products/Debug/Campfire.app --args -uvsBenchmark YES   # path depends on -derivedDataPath
```

Signed ad hoc to run locally; no team needed. `project.yml` regenerates the project with XcodeGen.

`-uvsBenchmark YES` shows the debug bar above the header.

## Layout of the code

- `ChatStore` – the dataset in memory, the loaded slice (pages of 40), the live stream and boosts.
- `ScrollEngine` – keeps the room pinned or holds the top row in place across every change (paging,
  stream, boosts, text size, window size), keeps only rows near the viewport as real views (spacers of
  measured or estimated height stand in for the rest), and keeps the debug label and timings.
- `HeightEstimator` – Core Text estimates for rows not yet shown.
- `MessageRow`, `Bubble`, `Chrome` – the room as drawn; sizes and colours in `Theme` (from
  `Fixtures/constants.json`).
- `Selection` – document-like text selection across messages (drag, double/triple click, ⌘C, ⌘A) and
  the Copy / Reply menu.
