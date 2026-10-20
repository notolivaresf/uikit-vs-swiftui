# Objective-C bridge (CampfireKitObjC)

V2 adds a UIKit app written in Objective-C. CampfireKit is pure Swift (structs, enums with associated values, `AsyncStream`), which Objective-C cannot see, so `CampfireKit/Sources/CampfireKitObjC` wraps it in `@objc` classes. The `CampfireKit` target and its public API are unchanged; the four Round 1 builds do not use the new target.

## Rules for the Objective-C build

- No `.swift` files in the app.
- No changes to `CampfireKit` or `CampfireKitObjC`.
- Add the package, link the `CampfireKitObjC` product, and use `@import CampfireKitObjC;`.

## What it gives Objective-C

All classes use the prefix `CFK`, are immutable, and use only Foundation types (colours are plain 0 to 255 `NSInteger` red/green/blue, so the bridge stays UIKit-free).

| Swift | Objective-C |
|---|---|
| `FakeData.generate(count:)` | `[[CFKDataset alloc] init]` (50,000) or `initWithMessageCount:`; `users`, `userWithID:`, `messageWithID:` |
| `Windowing` (pages of 40) | `lastPage`, `pageBeforeMessageID:`, `pageAfterMessageID:`, `pageAroundMessageID:` returning a `CFKPage` |
| `Grouping` | `CFKPage.presentations` (same index as `messages`), `presentationForMessageID:`, `presentationOf:after:` for live messages: `isThreaded`, `isFirstOfDay`, `isMine`, `mentionsMe` |
| `Message`, `Boost`, `User` | `CFKMessage`, `CFKBoost`, `CFKUser` |
| `Block` | `CFKBlock` with `kind` (`CFKBlockKindText`, `Mention`, `Code`), `text`, `mentionedUserID`, `language` |
| `Attachment` | `CFKAttachment` with `kind` (`CFKAttachmentKindImage`, `File`), size, colour, name, bytes |
| `FakeLiveFeed` | `CFKLiveFeed`: `startOnEvent:completion:` returns a `CFKFeedHandle` (`cancel`); both blocks run on the main queue; events are `CFKFeedEvent` (`kind` message, boost, typingStarted, typingStopped) |
| `Placeholder.pngData` | `CFKPlaceholder pngDataWithWidth:height:red:green:blue:` and `CFKAttachment.placeholderPNGData` (PNG `NSData`; draw with `+[UIImage imageWithData:]`) |

Wrapping is lazy: the 50,000 Swift messages stay as Swift values, and `CFKMessage` objects are made only for the page (40) or the id requested. A `CFKMessage` copies every field when it is created, so repeated property reads in a cell cost nothing extra.

## Checks

- `CampfireKit/Tests/CampfireKitObjCTests`: for message ids 1, 50,000, 2,500 and 200 random ids from the seed, every bridged field equals the Swift value (blocks, attachments and placeholder PNG bytes, boosts, mentions); pages equal `Windowing`; grouping equals `Grouping` (single messages and whole pages); the scripted feed matches event for event; a short real feed delivers the same sequence on the main thread with one completion; cancel stops callbacks.
- `CampfireKit/ObjCProbe`: a small Objective-C command-line package that does `@import CampfireKitObjC;`, generates the dataset, reads the newest page with its grouping, and plays a short feed. SwiftPM builds it directly, no Xcode project needed: `swift run --package-path CampfireKit/ObjCProbe`.

## Measured wrapping cost

One page of 40 messages, median of 1,000 runs, release build on the Mac (`swift test -c release -Xswiftc -enable-testing --filter wrapOnePageOf40`):

- wrapping 40 `Message` values into `CFKMessage`: about 0.017 ms
- the full `pageBeforeMessageID:` call (id lookup, slice, grouping, wrapping): about 0.066 ms

So the bridge adds under a tenth of a millisecond per page; it is not a meaningful cost next to layout.
