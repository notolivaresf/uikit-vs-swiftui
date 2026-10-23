# Round 3: making the Campfire room faster (UIKit, Objective-C)

## Result

Measured with `./bench` in the iPhone 17 simulator (iOS 26.4). "Before" is the Round 2 scorecard; "after" is the
final full `./bench` run (median of its samples); "quick runs" are the `./bench <number>` runs of the final
build, for an idea of the spread.

| Measure | Before (scorecard) | After (final full run) | Previous full run, near-final build | Raw samples, final run |
|---|---|---|---|---|
| First 40 rows, cold | 165 ms | **118 ms** | 126 ms | 118 |
| First 40 rows, repeated | 640 ms | **597 ms** | 586 ms | 603, 590, 597 |
| Stream CPU | 8.4 s | **4.6 s** | 4.5 s | |
| Jump to message 2,500 | 37 ms | 47 ms | 37 ms | 47, 34, 49 |
| Load older | 41 ms | 41 ms | 44 ms | 38, 42, 41 |
| Text size, at the bottom | 44 ms | 47 ms | 45 ms | 45 48 54 / 38 47 51 / 50 44 38 |
| Text size, mid-list | 45 ms | 46 ms | 50 ms | 47 43 48 / 40 40 48 / 47 46 44 |
| Peak memory | 67.9 MB | **52.9 MB** | 52.1 MB | |
| App size | 1.18 MB | **0.71 MB** | 0.71 MB | |

Checks: 13 of 13 pass in both full runs (Round 2: 12 of 13; the text-selection check failed).

Cold launch, repeated launch, stream CPU, peak memory and app size beat the scorecard by a wide margin. The four
tap timings (jump, load older and the two text-size rows) do not reliably beat it. Run to run they land a few ms
either side of it (jump: 37 in one full run, 47 in the next, single samples from 33 to 49), because nearly all
that is left in them happens outside the app's own work. The app's share of a tap did shrink a lot; see "The tap
timings" below.

## What I changed

1. **Text selection (the failed check).** The text views' edit-menu delegate returned only Copy and Reply, which
   replaced the system's own items (Look Up, Translate, Select All...). It now returns Reply followed by the
   system's suggested actions, with Reply first so it stays on the menu's first page next to Copy. Copy still
   leaves out the mention avatars: the text view subclass's `copy:` copies the selected range as plain text
   without attachment characters.

2. **No PNG generation for images.** CampfireKit's placeholder is a solid-colour PNG ("drawing a filled rectangle
   of `color` at the same pixel size is equivalent"). The image view was already filled with that colour, so
   building the PNG byte by byte, decoding it and caching up to 64 MB of bitmaps bought nothing. Now the image is
   a view filled with that colour: the same pixels, no image cache.

3. **Launch work moves to a background thread.** Under XCUITest, `UIApplicationMain` spends about 380 ms before
   the app delegate runs (automation setup; 19 ms in a cold launch). The background thread that already built the
   dataset now also builds the store and the newest page, and lays out its 40 rows. It uses the row width and
   text size the room had last time, kept in user defaults; any row laid out for a different width or text size
   is simply measured again on the main thread. Cell subviews that most rows don't need (day separator, code
   block, file row, image, add-boost button) are now created the first time a row needs them.

4. **The list is a `UIScrollView` that recycles row views itself**, instead of a `UICollectionView` with a custom
   layout. The room already computed every row frame itself; the collection view added batch-update
   bookkeeping, layout-attribute objects and two layout passes to every change (about 7 ms per live update).
   `tileRows` places a view on each row in the visible area. A view is configured only when its row's layout
   object changed. Rows that leave the area are hidden and reused.

5. **One message costs the same whatever is loaded.** Appending rows, prepending a page and growing a row
   (boosts) now lay out only those rows and move the others with a plain loop over the frame array. Before, all
   rows were rebuilt. Layouts are cached on the message item, not in a dictionary.

6. **The live stream batches its work.** Live changes are applied at most every 100 ms, so a batch usually holds
   2 messages, and the state label follows at most every 100 ms (it always catches up with the last change).
   The label's font is fitted once per width instead of `adjustsFontSizeToFitWidth`, which re-fitted it on every
   change; the label's own text is its accessibility label. Per-message label updates alone cost about 1.3 s of
   the stream.

7. **Row layout is thread-safe and runs in parallel.** Each thread measures with its own TextKit 1 layout
   manager, and the date formatters are created once with `dispatch_once`. Whenever several rows need new
   layouts (a page, a jump, a text-size step), they are computed with `dispatch_apply`.

8. **Bodies are drawn from the layout that was already measured.** Setting `attributedText` on ~12 `UITextView`s
   made each lay out its text again on the main thread: about 9 ms of the 10.5 ms text-size relayout. Each row
   layout now keeps its TextKit 1 text system, built off the main thread, and the row draws it with the same
   `NSLayoutManager` calls a TextKit 1 `UITextView` uses (same container settings, so the same pixels). The real
   selectable `UITextView` is filled and swapped in from the cell's `hitTest:` as soon as a touch lands on the
   text, before the touch is delivered. So long press and double tap still select text with the system menu
   (both checks pass).

9. **Jump loads one page** around message 2,500 (10 rows above, 29 below) instead of 81 rows; scrolling loads
   more in either direction as before.

10. **The next older page is prefetched** (wrapped and laid out on a background queue) after launch, a jump, a
    reset and each older page. Reaching the top or "Load older" then only inserts ready rows.

11. **App size:** Release now strips symbols (`DEPLOYMENT_POSTPROCESSING`, `STRIP_INSTALLED_PRODUCT`,
    `STRIP_STYLE = all`, `DEAD_CODE_STRIPPING`), in the project and in `project.yml`.

## Tried and dropped (measured, no gain)

- `CADisableMinimumFrameDurationOnPhone` (120 Hz): no change in the tap timings.
- Rendering the visible bodies into images in parallel before the commit: no change. The commit was already
  short; reverted to drawing in `drawRect:`.
- Setting the text views' text through `textStorage` instead of `attributedText`: no change.
- Hiding the list from accessibility (experiment only, to test whether XCUITest's snapshots slowed touch
  delivery): no change.

## The tap timings: why they don't move further

I briefly encoded timestamps into the label's `ms` field (removed afterwards) to split a tap into its parts. After
the changes above, a jump or text-size step in the simulator looks like this, counted from the touch-up time
stamp:

- 5–21 ms before the button's action runs (event delivery: outside the app);
- 3–8 ms of app work and commit. Measured the same way on intermediate builds: jump work was 8–28 ms before the
  drawn bodies and the one-page window, and is now 1–6 ms. The text-size relayout went from about 12 ms
  (9 ms of it `UITextView` text setting) to 4–5 ms. The commit is 1–3 ms, and a load older is mostly
  prefetched;
- then 13–28 ms with the main thread idle (2–4 run-loop wake-ups, under 0.2 ms busy) until the measuring display
  link, which is created at the end of the action, gets its first callback.

So the part the app controls is now a small fraction of these numbers, and the medians land within a few ms of
the scorecard either way, run to run. Getting them lower would mean changing how the debug bar's clock waits for
the frame, which is locked, or acting on touch-down instead of touch-up, which would change how the buttons
behave. I did neither.

## Note on `./bench <number>`

In quick mode the harness reinstalls the app only for the cold-launch measure. `./bench jump`, `./bench stream`
and the others measure whatever build was installed last. I ran `./bench rows-cold` (which installs) before every
other quick measure so each one measured the current build.
