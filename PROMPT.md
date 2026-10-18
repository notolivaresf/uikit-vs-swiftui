# Build a Campfire chat room

Stack: {UIKit only, no SwiftUI | SwiftUI only: no UIKit views, no UIViewRepresentable or UIViewControllerRepresentable, no UIHostingController, no reaching into UIKit views underneath}

Build one iPhone app, from this empty folder, that shows a single chat room copied 1:1 from 37signals' ONCE Campfire. It's a UI test, not a product: buttons, the composer and add-boost are drawn but do nothing. Xcode project, iOS 18, app id `campfire.bench`.

## Look

- Match every screenshot in `screenshots/`, light and dark, within 2 pt. Each has a `-dark` twin.
- Use the numbers in `Fixtures/constants.json`: sizes, fonts, paddings, radii, colours, and 10 reference rows you must match within 2 pt. The screenshots and constants win over this text.
- Row: round avatar (palette colour, white initial), bold name, time like "10:12 AM" (UTC) at 50% opacity. Same author within 5 minutes and same UTC day: hide avatar and name, keep the time.
- Mine (user 1): same grey bubble, right-aligned, avatar on the right, header reversed.
- Mentions me: Campfire's red tint, 10% light, 20% dark.
- Day separator above the first message of each UTC day: uppercase pill with a line.
- Image fills the bubble edge to edge, 300 pt wide, aspect kept.
- Boost pill: booster's initial avatar plus the emoji; the strip ends with the add-boost button. Pills wrap.

Screenshots:

- `room-top.png`: whole room from the top: header, welcome card, first rows, composer
- `room-bottom.png`: whole room at the bottom: mixed rows, composer
- `row-day-separator.png`: day separator pill
- `row-threaded.png`: same author within 5 min: no avatar or name
- `row-long-text.png`: long text wrapping
- `row-mine.png`: my message: right-aligned, avatar right
- `row-mention.png`: mentions me: red tint
- `row-image-boosts.png`: image edge to edge, boost pills
- `row-code.png`: code block
- `row-file.png`: file row
- `row-emoji-only.png`: emoji-only, no bubble
- `row-long-boosts.png`: text boost pill, add-boost button

## Behaviours

- Open on the newest 40 of the 50,000 messages, at the bottom; first content within 1 s.
- Reaching the top loads 40 older messages; the message you were looking at stays put (within 2 pt).
- New messages come only from the live stream. If the last row is within 100 pt of the bottom, stay pinned; otherwise stay put and show a jump-to-bottom button.
- "Jump to 2500" puts message 2,500's top just under the header, within 2 pt.
- Text size follows Dynamic Type. Changing it re-lays out the room and keeps the row at the top in place (within 2 pt), or keeps the room pinned if it was.
- Portrait and landscape. Rotating keeps the row at the top in place (within 2 pt), or keeps the room pinned if it was.
- A row can change after it shows: new boosts make it grow and its pills wrap, and the room stays pinned or in place.
- Long-press a message: select any range of its text and copy it; also show a context menu with Copy and Reply (Reply does nothing). Scrolling still works around it.

## Data and debug bar

- All data comes from the Swift package in `CampfireKit/`; add it to the app as is and don't load or parse any file yourself. `FakeData.generate(size:)` builds the 50 people (user 1 is me) and 50,000 messages in memory from a fixed seed. `Windowing` gives pages of 40, `Grouping` says when a row is threaded, `FakeLiveFeed` plays the live stream (20 messages a second for 30 s), `Placeholder` draws the images.
- Bodies are structured fields, never parsed text: paragraphs, mention (user id), emoji-only flag, code block, image, file (name, size), boosts (booster id, emoji).
- Launched with `-uvsBenchmark YES`, show a debug bar with buttons "Reset" (back to the newest 40 at the bottom, default text size), "Jump to 2500", "Load older", "Start stream", "Text size +" (one Dynamic Type step larger, back to the default after the largest), "Boost burst" (adds 5 boosts to the newest message, one every 200 ms, from users 2 to 6 with 👍 🎉 🔥 ❤️ 😂), a "Stream done" label when the stream ends, and one state label in exactly this form: `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`.
  - first, last, loaded: ids of the first and last loaded messages, and how many are loaded. pinned: yes or no.
  - top: id of the topmost message row on screen (the first one at least partly visible below the header); y: where that row's top is, in points, measured from the bottom edge of the header (0 = just under it, negative = partly hidden under it).
  - ms: whole milliseconds from the last debug-bar tap (touch up) until the label shows that tap's result, once the rows are laid out on screen (for Text size +: until the room has re-laid out); at launch, from the first line of the app's own code until the first 40 rows are on screen. Boost burst and Start stream don't change it.
  - Keep the label current; while a scroll is moving it may wait until the scroll stops.
