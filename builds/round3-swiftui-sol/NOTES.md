# Campfire performance results

All nine performance measures beat the supplied scorecard. The retained build
passes 12 of 13 checks. The remaining failure is native arbitrary-range text
selection on iOS 26.4; this requirement is not complete.

## Before and after

Final validation completed at 00:37 local time, before the 00:46 deadline.
These after values come from one complete `./bench` run,
`sim-20261021-003312`, rather than combining the best values from separate runs.

| Measure | Supplied before | Retained build |
| --- | ---: | ---: |
| First 40 rows, cold | 370 ms | 290 ms |
| First 40 rows, repeated | 883 ms | 762 ms |
| Stream CPU | 19.8 s | 12.4 s |
| Jump to message 2,500 | 174 ms | 76 ms |
| Load older | 114 ms | 71 ms |
| Text size, at the bottom | 89 ms | 55 ms |
| Text size, mid-list | 111 ms | 75 ms |
| Peak memory | 95.3 MB | 75.4 MB |
| App size | 2.28 MB | 0.89 MB |

## Retained changes

- Use a `LazyVStack` with stable message IDs and scroll targets. Unrealized
  jump targets are first reached by ID, then corrected using measured geometry.
  Row appearances while dragging no longer trigger automatic restoration.
- Separate the timeline from the view that observes scroll geometry. Scroll
  position updates do not rebuild the timeline's collection.
- Keep immutable message content separate from each observable row's boosts.
  A boost changes that row's boost property. Cache emoji classification and
  format a day label only for rows that show a day separator.
- Use the generated dataset's contiguous IDs for history indexing, with bounds
  and ID checks. Use a dictionary for loaded-row lookup. Feed bounded slices
  into the unchanged CampfireKit Windowing APIs instead of scanning 50,000
  messages for a page or jump.
- Trim the live window in pages of 40, retaining about 80–120 rows, rather
  than deleting a leading row for every incoming message. This amortizes lazy
  layout rebasing and keeps update costs bounded as history grows.
- Build Release with `-Osize` and strip installed symbols. Match settings in
  both the Xcode project and project.yml.
- Remove the explicit UIKit clipboard import. Copy still uses the clipboard
  service; all views remain SwiftUI.

Row dimensions, colors, rendering, Copy/Reply, and the debug clock's start/stop
code retain their original implementation.

## Validation and remaining limitation

The complete run passed stack compliance, newest-40 startup, all 600 streamed
messages, stream pinning, paging, jump positioning, Dynamic Type, rotation,
boost growth, and Copy/Reply. Measured jump drift was at most 0.1 pt; older-page
drift was 0 pt; mid-list Dynamic Type drift was at most 0.2 pt; rotation drift
was 0 pt. Protected-file checks passed.

The native range-selection check still fails. Apple's
[textSelection documentation](https://developer.apple.com/documentation/swiftui/view/textselection(_:))
states that Text operations on iOS 26 and earlier act on the whole Text value;
range handles arrive in iOS 27. The final Text views keep
`.textSelection(.enabled)`, but that does not satisfy arbitrary-range selection
on the measured OS.

I tested SwiftUI TextField and TextEditor alternatives, including constant and
local bindings, overlays and sibling layout, conditional activation after the
Copy/Reply menu, native-only rows, keyboard/focus handling, and delayed automatic
focus after the custom menu closed. These did not
produce the recognized system range-selection menu in the simulator. Some also
regressed Copy/Reply, startup, or scrolling. They were removed rather than
retained as an unverified fix. This is evidence that the attempted approaches
failed, not proof that every possible SwiftUI implementation is impossible.

## Measurement notes

Individual metric runs were used during the early experiments, followed by
complete runs to catch interactions between lazy layout and anchoring.
A complete intermediate build (`sim-20261020-230506`) measured 289/747 ms
startup, 12.8 s CPU, 76 ms jump, 63 ms older, 55/77 ms text size, 77.3 MB
memory, and 0.96 MB size, with 12/13 checks.

Rejected experiments included permanent input controls (583/1186 ms startup,
28.6 s CPU, 108.4 MB memory in the initial attempt), restoration gating that
broke jump/rotation anchoring, and always-active native editors that still
failed selection and lost Copy/Reply. The simpler retained build is faster
and preserves all originally passing checks.

Guidance used: the installed swiftui-specialist skill, Apple's
[Demystify SwiftUI performance](https://developer.apple.com/videos/play/wwdc2023/10160/),
and the text-selection documentation linked above.
