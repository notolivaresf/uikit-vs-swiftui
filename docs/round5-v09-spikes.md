# Round 5: what the E9 build's three misses come from, and what changes in skill v0.9

## In plain words

- **Text size, mid-list: the top row is lost to a 0.12 pt sliver.** Message 2,500 is threaded under 2,499 with no gap. The E9 layout stacks rows with fractional heights, so row edges fall between device pixels, while the scroll offset is rounded to the pixel grid. On the first step row 2,500's top lands at 1299.119 and the offset rounds to 1299.000, so 0.12 pt of row 2,499 is still under the header and counts as the top row; every later step anchors on 2,499. Snapping each row's top and bottom to the pixel grid in the layout (rounding the running position, as the control does) fixes it: top row 2,500 at y 0.0 after every step, 3 of 3 passes, also with the TextKit 1 changes below. Confidence: high.
- **Stream CPU: the text views run on TextKit 2.** The E9 build makes its message text view with `UITextView(frame:textContainer: nil)`, which gives a TextKit 2 view; the control builds its own TextKit 1 stack. A main-thread sample of the unpolled stream shows the E9 build spending its extra time in TextKit 2 viewport layout (`NSTextLayoutManager` fragment enumeration, about 1,370 more samples than the control, which has none), selection rects and selection display updates (about 1,000 more) and the text view's frame setting. Switching the text views to TextKit 1 alone cuts stream CPU from 4.73 s to 3.53 s (-25 %), below the control's 3.92 s in the same sitting. Skipping unchanged text and frames in cell setup, the v0.8 lead, gains nothing (4.88 s against 4.87 s): that lead is ruled out. Confidence: high.
- **Peak memory: TextKit 2 per-cell objects plus cell prefetching.** Peak footprint is a transient during the stream (the end-of-stream footprint differs by only 3 MB). Each TextKit 2 text view carries an `NSTextLayoutManager`, a content storage, layout fragments and fragment views; and the E9 build leaves cell prefetching on (the control turns it off), so more of those heavier cells are alive at once. Prefetching off alone lowers the peak from 49.2 to 47.0 MB (-4 %) with no CPU change; TextKit 1 alone to 48.3 MB; all three changes together from 51.4 to 46.0 MB (-10 %), against the control's 45.5 MB in the same sitting. What is left (about 1.5 to 2 MB at the end of the stream) is Core Animation memory from more layers per cell (433 layers against 323), a drawing choice, not a list fault. Confidence: high on the fix (three passes, each within 2 MB), medium on the split between the two causes.
- **All fixes together** (TextKit 1 views and measurer, pixel-snapped rows, prefetching off): stream CPU 3.38 s against the shipped 4.92 s (-31 %) and the control's 3.95 s; peak 46.0 MB against 51.4 MB and 45.5 MB; the text size check passes in every pass. A patched copy of the E9 build with the same changes passes all 13 checks on the full harness, with stream CPU 5.8 s against 7.4 s shipped and 6.5 s control, and peak memory 57.1 MB against 62.1 MB and 53.5 MB (one pass each, same sitting): the CPU miss is gone, the memory miss shrinks from 16 % to 7 % (below).

## What v0.9 changes

1. Selectable text: message text views are TextKit 1 (`UITextView(usingTextLayoutManager: false)`), measured with an `NSLayoutManager`; a default TextKit 2 view redoes viewport layout and selection rects on every cell setup. `references/measuring-text.md` now gives the TextKit 1 pairing as the one to use (the `boundingRect` measurer stays as the fallback for a TextKit 2 view), and says skipping unchanged text does not recover the cost. Checklist item 6 and the reviewer check for it.
2. Text size and rotation: snap each row's top and bottom to the pixel grid in the layout, rounding the running position, not each height; otherwise the rounded offset leaves a sliver of the row above that the next anchor picks. The reviewer's item 4 checks it.
3. The layout class: `isPrefetchingEnabled = false` for a list pinned at the bottom. The reviewer's item 5 checks it.
4. Not changed: skipping unchanged text and frames in cell setup (measured, no gain); the "a row showing less than 1 pt is not the top" rule (it passes, but it hides the sliver instead of removing it).
5. SKILL.md is 1,915 words (v0.8: 1,915); the words came from shortening lines that repeated a core rule or another section.

## Text size, mid-list: why the top row slips from 2,500 to 2,499

After the jump the list shows message 2,500 at the top. Message 2,500 is a threaded reply under 2,499, so there is no gap between them: 2,499's bottom edge is 2,500's top edge. The layout stacks rows with unrounded heights (rows are separated by 21.28 pt, and each height is a fraction), so row edges fall between device pixels, while the scroll offset is rounded to the pixel grid (1/3 pt).

Probe trace, E9 build as shipped (unpolled, 3 passes, identical each time):

| Moment | Offset | Visible top | Row 2,499 bottom | Row 2,500 top | Top row reported |
|---|---|---|---|---|---|
| after jump | 1082.000 | 1204.000 | 1203.980 | 1203.980 | 2,500 (y -0.02) |
| after step 1 | 1177.000 | 1299.000 | 1299.119 | 1299.119 | **2,499 (y -96.9)** |

On the first step the text grows, the anchor puts row 2,500's top at 1299.119, and the offset is rounded down to the pixel at 1299.000. That leaves 0.12 pt of row 2,499 (its last sliver) under the header, and the "top row" lookup (first row whose bottom is below the visible top) returns 2,499. The later steps anchor on 2,499 and keep it, so the check fails on every step after the first, in every pass.

Two fixes, each measured 3 passes unpolled (top row after steps 1, 2, 3):

| Arm | Change | Step 1 | Step 2 | Step 3 |
|---|---|---|---|---|
| E9Shipped | none | 2,499 (-96.9) | 2,499 | 2,499 |
| E9TopFix | a row showing less than 1 pt under the header does not count as the top | 2,500 (0.1) | 2,500 (0.2) | 2,500 (0.1) |
| E9PixelTops | row tops and bottoms snapped to device pixels in the layout | 2,500 (0.0) | 2,500 (0.0) | 2,500 (0.0) |

Snapping row edges to pixels (what the control does) removes the cause: every edge and every offset are on the same grid, so no sliver can be left. The 1 pt rule only stops the sliver from counting.

With the TextKit 1 changes as well (E9TK1Pair, E9Fix) the result is the same: top row 2,500 at y 0.0 after every step, 3 of 3 passes each. TextKit 1 views alone (E9TK1, earlier sitting) still fail (2,499), so the text engine is not the text size cause.

## Stream CPU and peak memory: the numbers

Unpolled 30 s stream, CPU from stream start to end (`getrusage`, all threads), peak = lifetime `phys_footprint` peak. Arms run in turn (A B C, A B C), three passes each; the medians are of the three. Each sitting has its own shipped and control arms, so compare within a sitting.

| Arm | What differs from the E9 build | CPU s (3 passes) | Median | Peak MB (3 passes) | Median |
|---|---|---|---|---|---|
| **Sitting 1** | | | | | |
| E9Shipped | nothing | 4.727 / 4.992 / 4.865 | 4.865 | 50.4 / 51.2 / 52.3 | 51.2 |
| E9CellSkip | cell setup skips unchanged text and frame | 4.356 / 4.992 / 4.880 | 4.880 | 50.3 / 50.7 / 49.1 | 50.3 |
| E9Ctrl | the control | 3.941 / 4.055 / 3.764 | 3.941 | 45.5 / 44.3 / 44.7 | 44.7 |
| **Sitting 2** | | | | | |
| E9Shipped | nothing | 4.714 / 4.853 / 4.734 | 4.734 | 51.1 / 48.4 / 49.2 | 49.2 |
| E9TK1 | text views on TextKit 1, measurer unchanged | 3.452 / 3.525 / 3.615 | 3.525 | 47.5 / 48.3 / 48.9 | 48.3 |
| E9TK1PixelTops | TextKit 1 views, pixel-snapped rows | 3.389 / 3.458 / 3.555 | 3.458 | 47.6 / 49.9 / 48.3 | 48.3 |
| E9NoPrefetch | cell prefetching off | 4.741 / 4.751 / 4.735 | 4.741 | 47.0 / 46.5 / 47.3 | 47.0 |
| E9Ctrl | the control | 3.921 / 3.801 / 4.009 | 3.921 | 46.1 / 45.0 / 44.5 | 45.0 |
| **Sitting 3** | | | | | |
| E9Shipped | nothing | 4.947 / 4.902 / 4.924 | 4.924 | 51.4 / 51.7 / 49.7 | 51.4 |
| E9TK1Pair | TextKit 1 views and `NSLayoutManager` measurer, pixel-snapped rows | 3.494 / 3.605 / 3.599 | 3.599 | 50.3 / 47.4 / 47.5 | 47.5 |
| E9Fix | E9TK1Pair plus prefetching off | 3.365 / 3.384 / 3.451 | 3.384 | 46.3 / 46.0 / 45.3 | 46.0 |
| E9Ctrl | the control | 3.849 / 3.952 / 4.009 | 3.952 | 45.5 / 45.1 / 46.2 | 45.5 |

All arms make about 225 list updates per stream; the E9 arms provide about 690 cells, the control about 660.

Main-thread sample, 15 s in the middle of the stream (`sample.sh`; the sampler costs CPU, so the totals, 6.73 s shipped against 5.28 s control, are higher than above). Inclusive samples, E9 shipped minus control:

| Frame | Extra samples in E9 |
|---|---|
| `NSTextLayoutManager` enumerate text layout fragments (control: 0) | +1,368 |
| `UITextSelectionDisplayInteraction` selection updates | +615 |
| `selectionRectsForRange:` | +400 |
| `UITextView setFrame:` | +371 |
| `_UITextLayoutCanvasView` viewport layout | present only in E9 |

UIKit's own header for `UITextView(usingTextLayoutManager:)` says the TextKit 1 initializer "avoids inefficiencies associated with the needless creation of a NSTextLayoutManager"; with it the `NSTextLayoutManager` frames are gone.

Heap and footprint 35 s after launch (`heapdump.sh`, end of stream; `heap` crashed on the E9Fix process, so its object counts are missing):

| | E9Shipped | E9Fix | E9NoPrefetch | E9Ctrl |
|---|---|---|---|---|
| Footprint at end of stream | 44 MB | 43 MB | 43 MB | 41 MB |
| Peak in that run | 48.6 MB | 44.7 MB | 46.8 MB | 44.8 MB |
| Core Animation (dirty) | 6.2 MB | 6.4 MB | 6.3 MB | 4.3 MB |
| `CALayer` objects | 433 | n/a | n/a | 323 |
| TextKit 2 objects per text view | `NSTextLayoutManager`, `NSTextContentStorage`, `UITextLayoutCanvasView`, layout fragment views (16 text views live) | n/a (TextKit 1 by construction) | as shipped | none (`NSLayoutManager`, 20) |

The extra peak is a transient while cells are built (peak minus end-of-stream footprint: about 4 to 5 MB shipped, 1.5 to 3 MB fixed and control). The steady difference that is left, about 2 MB of Core Animation from more layers per cell, comes from how the E9 build draws its rows and is not a list rule.

Confidence: high that TextKit 2 is the stream CPU gap (one change, -25 %, three passes within 5 %, and the sample shows where it goes) and that cell-setup skipping is not; high that the three changes bring peak memory to the control's level; medium on how the peak splits between TextKit 2 objects and prefetching (each alone moves the peak by 1 to 2 MB, within pass-to-pass spread).

## Confirmation on the full harness

A copy of the E9 build (copied to a scratch folder, the original untouched) with the four changes (TextKit 1 text views, `NSLayoutManager` measurer, pixel-snapped row edges, prefetching off), built Release, then one full `Harness/record.sh` pass each for the patched copy, the E9 build as shipped and the control, in one sitting on uvs-r3-b. Polled numbers (the UI test queries the app throughout):

| | E9 as shipped | E9 patched | Control |
|---|---|---|---|
| Checks passed | 12 of 13 (text size, mid-list fails) | **13 of 13** | 13 of 13 |
| Stream CPU | 7.4 s | **5.8 s** | 6.5 s |
| Peak memory | 62.1 MB | **57.1 MB** | 53.5 MB |
| Jump to message 2,500 | 53 ms | 46 ms | |
| Text size, mid-list | 44 ms | 50 ms | 44 ms |

One pass each, so read these as direction, not medians. Stream CPU moves from 14 % over the control to 11 % under it. Peak memory moves from 16 % over to 7 % over: under constant accessibility queries the remaining difference in views per cell (the E9 avatar is a disc view with a label inside, plus separate name, time and menu views in the bubble; 433 layers against the control's 323 at the end of the stream) costs more than it does unpolled. That is a lead about drawing rows with fewer views, not measured here, and v0.9 makes no rule from it. Confidence: medium.

## How it was measured

Spike: `spikes/round5/E9/`. `App/` is the E9 Opus build's `App/` (skill v0.8.0) and `Control/` the Opus control from the E8 spike, each with the small probe in `Shared/` and compile flags for the arms; `project.yml` (xcodegen) makes one target per arm, all Release with the benchmark's strip settings and the same bundle id. The E9 build folder itself was not touched.

- `measure.sh stream` installs and launches each arm in turn (A B C, A B C, ...) with a launch argument that starts the 30 s stream by itself: no UI test attached, nothing polls the accessibility tree. The probe prints the process's own CPU time (`getrusage`, all threads) from stream start to stream end, the number of list updates and cells provided, and the memory footprint (`TASK_VM_INFO`: `phys_footprint` now, and the lifetime peak `ledger_phys_footprint_peak`).
- `textsize.sh` launches with `-uvsAutoTextSize`: jump to message 2,500, then three text size steps the way the app's own text size button makes them, printing the top row and its offset after each step, plus a trace of the offset and the neighbouring rows' edges.
- `sample.sh` runs `sample` on the app for 15 s in the middle of the unpolled stream; `build/out-sample/` holds the two call graphs (not committed; `build/` is ignored).
- One simulator (uvs-r3-b, iOS 26.4 iPhone, otherwise idle), Release builds, one arm at a time.

Unpolled numbers are lower than the scorecard's (the UI test's queries cost the app CPU and memory too); the ratios are what carry over.

Arms (one target each in `project.yml`, all the E9 build plus the probe):

| Target | Flags | What differs |
|---|---|---|
| E9Shipped | none | nothing |
| E9TopFix | `TOP_FIX` | a row showing less than 1 pt under the header is not the top row |
| E9PixelTops | `PIXEL_TOPS` | row tops and bottoms snapped to device pixels in the layout |
| E9CellSkip | `CELL_SKIP` | cell setup skips unchanged text and frame |
| E9NoPrefetch | `NO_PREFETCH` | `isPrefetchingEnabled = false` |
| E9TK1 | `TK1` | text views built on their own TextKit 1 stack |
| E9TK1PixelTops | `TK1 PIXEL_TOPS` | both |
| E9TK1Pair | `TK1 TK1_MEASURE PIXEL_TOPS` | plus an `NSLayoutManager` measurer |
| E9Fix | `TK1 TK1_MEASURE PIXEL_TOPS NO_PREFETCH` | all four |
| E9Ctrl | | the control |
