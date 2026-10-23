@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// Template icons drawn at the exact size Campfire shows them (tint with `tintColor`).
@interface CFIcons : NSObject
+ (UIImage *)symbol:(NSString *)name size:(CGSize)size weight:(UIImageSymbolWeight)weight;
+ (UIImage *)fileIcon;
+ (UIImage *)downloadIcon;
+ (UIImage *)shareIcon;
+ (UIImage *)addBoostIcon;
+ (UIImage *)campfireLogo;
@end

NS_ASSUME_NONNULL_END
