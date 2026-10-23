# Round 4 Mac: real app screenshots

These are real renders of the six built Round 4 Mac apps (Release builds), made on 22 Oct 2026 on macOS 27.0.1. They are not the files in `builds/*/screenshots`, which are the reference images given to the models in the prompt.

How: screen capture was not available, so a small Objective-C library loaded into each app at launch rendered its window (title bar included) with `cacheDisplayInRect:` a few seconds after the room opened. The apps ran with no arguments: no debug bar, default text size, the fixture conversation.

- `<build>/room-bottom.png`: the room as it opens.
- `<build>/room-top.png`: after scrolling the room's scroll view to its top (loaded rows only, 40 of them).
- `contact-bottom.png`: the six room-bottom shots side by side.
- Window sizes (points): AppKit and SwiftUI Opus 393 x 884; SwiftUI Sol 393 x 852 (its title bar is not part of the render).
- No dark-mode shots: all six apps draw the same dark theme whatever the system appearance (the dark launches came out identical to the default), so they are not kept.

Known limit for SwiftUI Sol: its renders were identical for bottom and top and show the top of the room, so they are not a trustworthy bottom view (the in-app render may not reflect its scroll position).
