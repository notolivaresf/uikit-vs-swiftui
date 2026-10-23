#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

// Benchmark bar (only with -uvsBenchmark YES): standard buttons and labels, so accessibility tools see their text.
@interface CFDebugBar : NSView

- (instancetype)initWithTarget:(id)target;

@property (nonatomic, readonly) NSTextField *stateLabel;
@property (nonatomic, readonly) NSTextField *streamDoneLabel;

// Height needed for the bar at a given width (buttons wrap on narrow windows).
- (CGFloat)heightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
