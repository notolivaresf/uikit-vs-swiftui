# Round 3 notes: making the Campfire room faster (SwiftUI)

All 13 checks pass and every number beats the Round 2 scorecard. Final full `./bench` run (iPhone 17 simulator, iOS 26.4):

| Measure | Before (Round 2) | After | Change |
|---|---|---|---|
| First 40 rows, cold | 583 ms | 170 ms | −71% |
| First 40 rows, repeated | 785 ms | 678 ms | −14% |
| Stream CPU | 30.7 s | 9.9 s | −68% |
| Jump to message 2,500 | 133 ms | 19 ms | −86% |
| Load older | 61 ms | 28 ms | −54% |
| Text size, at the bottom | 56 ms | 9 ms | −84% |
| Text size, mid-list | 80 ms | 19 ms | −76% |
| Peak memory | 200.5 MB | 127.4 MB | −36% |
| App size | 2.88 MB | 2.86 MB | −1% |

Checks: 11 of 13 → 13 of 13.

## The two failed checks

**Stack rule.** `RowParts.swift` had `import UIKit` for `UIPasteboard`. The rule matches the text `UIKit` anywhere in a Swift file, so I removed the import. On iOS, `import SwiftUI` already makes `UIPasteboard` visible; no UIKit views are used.

**System text selection.** Round 2 drew its own highlight and handles over `Text.Layout`, so the system's selection menu never appeared. On iOS 26, SwiftUI `Text` can only select its whole contents (range selection on `Text` arrives in iOS 27), so now:
- Message text (paragraphs and code) has `.textSelection(.enabled)`. A long press shows the system menu (Copy, Share…), which is what the harness looks for.
- The long press also selects the message (now a simultaneous gesture, so it doesn't block the text's own long press). That shows the Copy / Reply menu as before. The message's text blocks also get a read-only `TextEditor` laid over them, with the same characters. Mention names are bold; code keeps its highlighting. In that editor the system selection picks any range (handles, loupe, Look Up / Translate / Select All). Edits are put back straight away. The menu's Copy copies the picked range, or the whole message when nothing is picked.
- The original `Text` stays in place (faded out) under the editor, so the layout doesn't move and a menu it is showing isn't torn down.
- A tap away from the selected message ends the selection; taps on it go to the editor.
- One known rough edge: on a phone without a hardware keyboard, the keyboard appears when you tap into that editor, because SwiftUI has no read-only `TextEditor`.
- The old hand-made selection code (`SelectionGeometry`, `SelectionHandles`) is gone.

## The performance change: `LazyVStack`

Round 2 drew the room in a plain `VStack`, so every loaded row (up to 320) was laid out, rendered and kept in memory. Switching to `LazyVStack` is what moved every number. Making it keep the exact positioning behaviours (2 pt tolerances) took most of the work:

- **Visible rows only.** Rows report their frames (`onGeometryChange`) and whether they are on screen (`onScrollVisibilityChange`). The row at the top, the `top`/`y` label, and anchoring all use visible rows only. Frames of rows the stack has let go may be stale.
- **Frames are never dropped.** `onGeometryChange` reports only when a frame differs from its last report. If the model forgets a frame and the row stays (or comes back) where it was, nothing reports it again. That is why every time I cleared frames, Reset ended with "top 0".
- **Rotation.** Frames reported at an old width are ignored (every row spans the list).
- **Jump, Reset and rotation scroll by id.** They use `ScrollPosition.scrollTo(id:anchor:)` to reach a row the stack hasn't realized, then fine-tune to the exact y from its frame, as before. Reset is a "jump" to the newest message (its top can't reach the header, so the scroll stops at the bottom), then pins. Scrolling to the bottom edge was unreliable right after rows above were dropped: the stack's estimate for them moves the edge.
- **Load older while pinned** holds the top row still, rather than the estimated bottom edge, then pins again once settled.
- **`ScrollPosition` is a value.** Asking for the one it already holds (the same row again, the bottom edge again) does nothing, even if the content moved underneath. Requests alternate between two equivalent values: a 0.001 pt y nudge, and an anchor x of 0.5 vs 0.5001. A scroll by id that doesn't land is retried once.
- **Scroll phase.** Only finger-driven phases (`tracking`, `interacting`, `decelerating`) re-capture the reader's anchor. `.animating` (rotation, our own animated scrolls) no longer overwrites it.
- **Smaller change.** A single-run paragraph builds `Text(verbatim:)` directly instead of interpolating.

A change to one message costs the same however many messages are loaded. Only the realized rows (about a screenful) lay out, report or redraw. The window is still capped at 300 (+20 slack) rows, as Campfire does.

## How I measured (and a harness quirk worth knowing)

The single-number runs (`./bench stream`, `jump`, `older`, …) measure the app already installed in the simulator. Only `rows-cold` and the full run install the new build. My first stream "measurements" were of an old copy; I confirmed this by making the stream do nothing and still seeing "600 added". After that, every quick measurement was `./bench rows-cold` (installs) followed by the number. Positions were checked from the per-run `record.log` (`top`, `y`, `drift_pt`). Twice I temporarily encoded diagnostic values in the label's `top` field, because the app's logs can't be read from the sandbox.

Things tried and dropped:
- Hiding rows from accessibility: no change in stream CPU.
- Rebuilding the whole list (`.id`) on Reset: the fresh lazy stack ended up with no row on screen reported.
- Tracking realized rows with `onAppear`/`onDisappear`: `onAppear` doesn't fire for rows reached by the initial jump to the bottom.
- An epoch passed to rows to force them to report again: unreliable frames, load-older drift of up to about 120 pt.

"First 40 rows, repeated" improved least. Both launch numbers include generating the 50,000 messages (which must finish before the newest 40 exist), and the repeated launches run under XCUITest, which adds its own accessibility and launch overhead to the app's main thread.
