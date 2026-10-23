#import "ChatUI.h"
@interface CFRoomController : NSWindowController <NSWindowDelegate>
- (void)textLarger:(id)sender;
- (void)resetTextSize:(id)sender;
- (instancetype)initWithStartTime:(CFTimeInterval)start;
@end
