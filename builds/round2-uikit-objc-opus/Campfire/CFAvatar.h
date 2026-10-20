@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// Round avatar images: palette colour with a white bold initial. Cached; the palette is the same in light and dark.
@interface CFAvatar : NSObject
+ (UIImage *)imageForUserID:(NSInteger)userID initial:(NSString *)initial diameter:(CGFloat)diameter;
/// The avatar with transparent padding on the left and right (for inline mentions).
+ (UIImage *)imageForUserID:(NSInteger)userID initial:(NSString *)initial diameter:(CGFloat)diameter
                leftPadding:(CGFloat)left rightPadding:(CGFloat)right;
+ (NSString *)initialForName:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
