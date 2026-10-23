@import UIKit;
#import "CFTheme.h"

NS_ASSUME_NONNULL_BEGIN

/// The room's welcome card, shown above the first message of the room.
@interface CFWelcomeCell : UIView
+ (CGFloat)heightForWidth:(CGFloat)width metrics:(CFMetrics *)metrics;
- (void)configureWithMetrics:(CFMetrics *)metrics;
@property (nonatomic, readonly, nullable) CFMetrics *metrics;
@end

/// Room name, actions and the menu button. Drawn only; the buttons do nothing.
@interface CFHeaderView : UIView
+ (CGFloat)height;
@end

/// Search button and composer field. Drawn only.
@interface CFComposerView : UIView
+ (CGFloat)height;
@end

/// A circular button with a 1 pt border, the look of every round Campfire button.
@interface CFCircleButton : UIButton
- (instancetype)initWithImage:(UIImage *)image diameter:(CGFloat)diameter;
@end

NS_ASSUME_NONNULL_END
