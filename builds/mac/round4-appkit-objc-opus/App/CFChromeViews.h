#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

// Height of the welcome block at the very start of the room (logo, card and the gap to the first row).
extern const CGFloat CFWelcomeHeight;

// The room header: "General" pill and round buttons over a fade of the page background. Drawn only.
@interface CFHeaderView : NSView
@property (nonatomic, weak, nullable) NSScrollView *scrollView;   // receives scroll-wheel events over the header
@end

// The composer under the room: search, message field, attach and send. Drawn only.
@interface CFComposerView : NSView
@end

// Welcome card shown above the first message of the room.
@interface CFWelcomeView : NSView
@end

// Round "jump to bottom" button shown when the room is not pinned to the newest message.
@interface CFJumpButton : NSButton
@end

NS_ASSUME_NONNULL_END
