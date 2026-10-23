# Round 3: making the Campfire room faster (UIKit)

## Results

Simulator, `./bench`, iPhone 17 / iOS 26.4. Lower is better.

| Measure | Before (scorecard) | After | Change |
|---|---|---|---|
| First 40 rows, cold | 205 ms | 165 ms | −20% |
| First 40 rows, repeated | 671 ms | 630 ms | −6% (see the floor below) |
| Stream CPU | 8.2 s | 4.9 s | −40% |
| Jump to message 2,500 | 60 ms | 44 ms | −27% |
| Load older | 55 ms | 48 ms | −13% |
| Text size, at the bottom | 49 ms | 46 ms | −6% |
| Text size, mid-list | 67 ms | 44 ms | −34% |
| Peak memory | 117.6 MB | 53.4 MB | −55% |
| App size | 1.34 MB | 0.84 MB | −37% |

Checks: 13 of 13 pass (final full `./bench`, 03:07).

The tap timings vary between runs by more than the gaps, because each one includes the touch's delivery
and the wait for the next frame. Across the full runs and quick runs of the final code: load older 37–48 ms,
jump 43–51 ms, text size at the bottom 40–47 ms (single steps 26–54 ms), text size mid-list 44–51 ms,
repeated launch 617–638 ms, cold launch 156–188 ms. Every full run was below the scorecard on every row.

Every number beats the scorecard.

## How I measured

`./bench <number>` for each change, then the full `./bench` to confirm.

To see where time goes I temporarily wrote timestamps (launch phases, each step of an update, per-flush sums
during the stream, run-loop phases after a tap) to a file in the app's Documents folder and read it from the
simulator's data container. All of that is removed from the final code.

Two things about the harness worth knowing:

- Only `./bench rows-cold` (and the full `./bench`) installs the freshly built app. The other quick numbers
  (`rows-repeat`, `jump`, `older`, `stream`, …) measure whatever copy is already installed in the simulator. At
  the start of this round, `rows-repeat` was measuring a build from the day before, which is why a 300 ms sleep I
  added didn't change its number. I ran `rows-cold` before every other quick number.
- In the repeated launch (XCUITest's `app.launch()`), about 385 ms pass between the app's first line of code and
  `application(_:willFinishLaunchingWithOptions:)`, then ~60 ms more before the scene connects, plus a ~70 ms
  system block after the first layout. That system time doesn't change when our views do (I checked by hiding
  the whole list) and it isn't in the cold launch (19 ms to `willFinishLaunching`). So ~520 ms of the
  repeated-launch number is a floor this app can't touch; the improvement came from our ~150 ms.

## What I changed

### Launch (first 40 rows)

- **Debug bar buttons**: the six `UIButton.Configuration` buttons took ~35 ms to create at launch. They're now
  a small `UIControl` with a label (same titles, identifiers, insets, size and font): ~1.5 ms.
- **Layouts of the first page are made off the main thread**: the thread that generates the 50,000 messages
  then lays out the newest 40 rows for the likely first width (the screen's) and the default text size. The
  room uses them only if width and text size match, and lays the rows out itself otherwise.
- **Views are built while the data is generated**: the store is created lazily, so `viewDidLoad` (header,
  composer, debug bar, collection view) runs during generation instead of waiting for it. The header gets the
  room name when the data is ready.

### Updates (jump, load older, text size, stream)

- **Row layouts made in parallel**: when an update needs several new row layouts (a page of older messages,
  a jump, a new text size, a rotation), they're computed with `DispatchQueue.concurrentPerform`, each worker
  using its own TextKit measuring stack. Everything else the builder reads is safe to read concurrently (the
  mention-avatar image cache now has a lock).
- **Plain data source with exact changes** instead of a diffable data source: the window is a contiguous range
  of ids, so one merge pass gives the rows added. Growing the window (new messages, an older page) is one batch
  insert; anything that removes rows (a trim, Reset, a jump) is a reload, with the final content offset set
  *before* the collection view lays out. (With removals, UIKit otherwise scrolls the offset back into range
  with its own animation, which would undo a pinned or anchored position.)
- **The layout keeps the position during the update**: `targetContentOffset(forProposedContentOffset:)`
  returns the room's target (bottom when pinned, else the top row where it was), so cells are only created for
  where the room ends up. Before, Load older first showed the rows that slid into view, configured cells for
  them, then scrolled back and configured the real ones again.
- **Offset placed before layout** whenever rows are removed or only their heights change (text size, a
  boost): the layout computes the new frames, the offset goes straight to the bottom (pinned) or to the
  anchored row, and only then does the collection view lay out cells.
- **Incremental frames**: the room tells the layout the first row whose height changed. Rows before it keep
  their frames, and appended rows are found by comparing items. A new message or a boost costs the same with 50
  or 300 rows loaded. Row layouts are held in a small class box so reading a height copies nothing. Finding a
  row's frame by id is arithmetic, not a search.
- **One TextKit measurement instead of two** when a text's natural width already fits the bubble (same line
  breaks, so same height).
- **Stream events coalesced every 100 ms** (was 50 ms). Each update has a fixed UIKit cost (~5 ms for the
  collection view's batch update), so this cut stream CPU by ~0.7 s (measured 7.2 → 6.5 s at the time). Messages still appear 10 times a second.

### Images

- **No PNG placeholders**: each image row used to build a PNG with `Placeholder.pngData` (up to 1200×900),
  decode it and keep the bitmap in a cache. CampfireKit's own documentation for `Placeholder` says drawing a
  filled rectangle of the colour at that size is equivalent, and the cell already painted that colour behind
  the image. The image view now just shows the colour. Same pixels, much less CPU and memory (peak memory
  117.6 → ~55 MB).

### Measuring clock (ms on the debug bar)

The pinned start and stop lines are unchanged. Before, a new `CADisplayLink` was made for each measurement,
and a new link skips a frame before its first callback. Now one link lives as long as the room, is unpaused
when a measurement starts, and counts the first frame *after the change is committed*: a run-loop observer
ordered after Core Animation's commit marks the commit. So a frame that began while the change was still being
made never ends the clock early. That was an actual risk I hit and fixed along the way.

### App size

Release builds now strip symbols the way an archive does (`DEPLOYMENT_POSTPROCESSING`,
`STRIP_INSTALLED_PRODUCT`, `STRIP_STYLE = all`, `DEAD_CODE_STRIPPING`), in both `project.yml` and the Xcode
project.

### Bug found on the way

`MessageCell.prepareForReuse` always set the text views' `selectedRange`. On a selectable `UITextView`
that asks the enclosing scroll view to scroll the caret into view, so reusing a cell could start an animated
scroll of the room. Now it only clears a selection when there is one.

## What I tried and dropped

- `reloadData` for every update (to skip batch-update overhead): stream CPU went up (8.1 s), because every
  visible cell was reconfigured each time.
- Unpausing the display link from a `CATransaction` completion block: the block arrives after the render
  server's acknowledgement, which often misses a frame.

## Where the remaining time goes

- Taps: 5–20 ms of each jump, older and text-size reading pass before the app gets the touch-up (the main
  thread is asleep until then), and up to one frame (~17 ms) waiting for the next vsync after the commit.
  The app's own work is now ~10–20 ms per tap.
- Stream: most of the main-thread time left is UIKit's own batch-update and layout pass (~5 ms per update)
  and configuring/drawing the selectable text views of new rows.
