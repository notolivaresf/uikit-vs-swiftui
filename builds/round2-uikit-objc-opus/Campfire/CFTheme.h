@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// Colours from Fixtures/constants.json (Campfire light and dark), as dynamic colours.
@interface CFTheme : NSObject
+ (UIColor *)background;
+ (UIColor *)text;
+ (UIColor *)secondaryText;          // text at 50% opacity
+ (UIColor *)bubble;
+ (UIColor *)borderDark;
+ (UIColor *)borderDarker;
+ (UIColor *)mentionBubble;
+ (UIColor *)pillBackground;         // boost pill and code box
+ (UIColor *)codeKeyword;
+ (UIColor *)codeEntity;
+ (UIColor *)codeConstant;
+ (UIColor *)codeString;
+ (UIColor *)codeComment;
+ (UIColor *)orange;
/// Campfire's avatar colour: palette[crc32(user id as text) % 18].
+ (UIColor *)avatarColorForUserID:(NSInteger)userID;
+ (UIColor *)colorWithHex:(uint32_t)hex;
@end

/// Text metrics for one Dynamic Type size. Campfire's sizes are at a 16 pt body; `scale` follows the body style.
@interface CFMetrics : NSObject
+ (CFMetrics *)metricsForTraitCollection:(UITraitCollection *)traits;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) UIContentSizeCategory category;
@property (nonatomic, readonly) UIFont *bodyFont;
@property (nonatomic, readonly) UIFont *mentionFont;
@property (nonatomic, readonly) UIFont *nameFont;
@property (nonatomic, readonly) UIFont *timeFont;
@property (nonatomic, readonly) UIFont *separatorFont;
@property (nonatomic, readonly) UIFont *codeFont;
@property (nonatomic, readonly) UIFont *emojiOnlyFont;
@property (nonatomic, readonly) UIFont *boostEmojiFont;
@property (nonatomic, readonly) UIFont *boostTextFont;
@property (nonatomic, readonly) UIFont *titleFont;
@property (nonatomic, readonly) CGFloat bodyLineHeight;     // 22.4
@property (nonatomic, readonly) CGFloat metaLineHeight;     // 19.2
@property (nonatomic, readonly) CGFloat separatorLineHeight; // 17.92
@property (nonatomic, readonly) CGFloat codeLineHeight;     // 17.92
@property (nonatomic, readonly) CGFloat emojiLineHeight;    // 53.76
@end

NS_ASSUME_NONNULL_END
