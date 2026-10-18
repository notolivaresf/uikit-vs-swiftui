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

## Data and debug bar

- All data comes from the Swift package in `CampfireKit/`; add it to the app as is and don't load or parse any file yourself. `FakeData.generate(size:)` builds the 50 people (user 1 is me) and 50,000 messages in memory from a fixed seed. `Windowing` gives pages of 40, `Grouping` says when a row is threaded, `FakeLiveFeed` plays the live stream (20 messages a second for 30 s), `Placeholder` draws the images.
- Bodies are structured fields, never parsed text: paragraphs, mention (user id), emoji-only flag, code block, image, file (name, size), boosts (booster id, emoji).
- Launched with `-uvsBenchmark YES`, show a debug bar with buttons "Reset", "Jump to 2500", "Load older", "Start stream", a "Stream done" label when the trace ends, and a state label: first id, last id, loaded count, pinned.
