@import UIKit;
@import CampfireKitObjC;
@class CFRoomStore, CFMessageItem;

NS_ASSUME_NONNULL_BEGIN

/// System uptime at the first line of `main`, for the launch time in the debug bar.
extern NSTimeInterval CFLaunchStart;
/// Starts generating the 50,000-message dataset on a background queue, in parallel with UIKit's launch, and
/// lays out the newest page at the row width and text size of the last launch, so the first frame only has to
/// apply it (the room re-measures any row whose width or text size turns out different).
void CFLaunchBegin(void);
/// Remembers the room's row width, text size and screen scale for the next launch's layouts.
void CFLaunchRememberGeometry(CGFloat width, UIContentSizeCategory category, CGFloat scale);
/// The room store; waits for the background work to finish if needed.
CFRoomStore *CFLaunchStore(void);
/// The newest page, laid out (layouts cached on the items) when the guessed width and text size were right.
NSArray<CFMessageItem *> *CFLaunchInitialItems(void);
/// Screen scale of the last launch (0 if unknown), for images drawn off the main thread.
extern CGFloat CFLaunchScreenScale;

NS_ASSUME_NONNULL_END
