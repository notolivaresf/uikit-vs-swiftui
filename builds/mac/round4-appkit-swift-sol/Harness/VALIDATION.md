# Validation

Verified on this Mac with Xcode 26.4.1:

- Debug and universal Release builds succeed for macOS 15+.
- Release app passes strict code-signature verification with an ad-hoc signature and no team.
- All 23 CampfireKit tests pass, in both Debug and Release.
- Native app behavioral checks pass in light and dark appearances.
- The newest 40 rows are ready in approximately 0.36 seconds in Debug.
- Jump to 2500 places the row at y = 0.0. Paging, four larger text sizes, and 1200 × 1200 resizing preserve a partly hidden row at y = −12.5 to within 0.1 point.
- The 600-message replay stays pinned and caps the loaded window at 300 messages. An unpinned history window remains in place and exposes the jump control.
- The actual 30-second feed delivers through message 50600 and shows “Stream done”.
- Boost growth wraps pills and preserves the viewport, both pinned and unpinned.
- Native text selection copies the selected range; context Copy copies the complete message. The context menu contains Copy and Reply.
- Debug control labels match the specified text and expose button/static-text accessibility roles.

`smoke.sh` reproduces the app checks and writes its report and AppKit-rendered captures under `/tmp`. System screen capture is unavailable in this session; visual inspection used AppKit-rendered captures alongside the supplied references.
