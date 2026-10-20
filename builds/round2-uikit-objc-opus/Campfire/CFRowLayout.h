@import UIKit;
#import "CFRoomStore.h"
#import "CFTheme.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CFBubbleStyle) {
    CFBubbleStyleNormal,
    CFBubbleStyleMention,
    CFBubbleStyleNone,      // emoji-only: no bubble
};

/// Geometry of one message row, in row coordinates (x from the row's leading edge, y from its top).
/// Computed once per (width, text size, revision) and shared by the collection layout and the cell.
@interface CFRowLayout : NSObject
+ (CFRowLayout *)layoutForItem:(CFMessageItem *)item store:(CFRoomStore *)store width:(CGFloat)width metrics:(CFMetrics *)metrics;

@property (nonatomic, readonly) NSInteger itemID;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) NSUInteger revision;

@property (nonatomic, readonly) CGFloat height;
/// Gap to the previous row: 21.28, or -1.2 for a threaded row (Campfire's negative margin).
@property (nonatomic, readonly) CGFloat spacingBefore;

@property (nonatomic, readonly) BOOL hasSeparator;
@property (nonatomic, readonly) CGRect separatorPillFrame;
@property (nonatomic, readonly) CGRect separatorLineFrame;
@property (nonatomic, readonly, copy, nullable) NSAttributedString *separatorText;

@property (nonatomic, readonly) BOOL showsAvatar;
@property (nonatomic, readonly) CGRect avatarFrame;
@property (nonatomic, readonly) NSInteger avatarUserID;
@property (nonatomic, readonly, copy) NSString *avatarInitial;

@property (nonatomic, readonly) CGRect bubbleFrame;
@property (nonatomic, readonly) CFBubbleStyle bubbleStyle;
@property (nonatomic, readonly) BOOL isMine;

@property (nonatomic, readonly) CGRect headerFrame;
@property (nonatomic, readonly, copy) NSAttributedString *headerText;
@property (nonatomic, readonly) CGRect dotsFrame;

@property (nonatomic, readonly) CGRect textFrame;
@property (nonatomic, readonly, copy, nullable) NSAttributedString *bodyText;

@property (nonatomic, readonly) CGRect codeBoxFrame;
@property (nonatomic, readonly) CGRect codeTextFrame;
@property (nonatomic, readonly, copy, nullable) NSAttributedString *codeText;

@property (nonatomic, readonly) CGRect imageFrame;   // zero when no image
@property (nonatomic, readonly) CGRect fileIconFrame; // zero when no file
@property (nonatomic, readonly) CGRect fileNameFrame;
@property (nonatomic, readonly) CGRect fileDownloadFrame;
@property (nonatomic, readonly) CGRect fileShareFrame;
@property (nonatomic, readonly, copy, nullable) NSAttributedString *fileNameText;

@property (nonatomic, readonly, copy) NSArray<NSValue *> *boostFrames;
@property (nonatomic, readonly, copy) NSArray<NSAttributedString *> *boostTexts;
@property (nonatomic, readonly, copy) NSArray<CFBoostItem *> *boosts;
@property (nonatomic, readonly) CGRect addBoostFrame; // zero when no boosts
@property (nonatomic, readonly) CGFloat boostAvatarSize;

/// Text for Copy and accessibility.
@property (nonatomic, readonly, copy) NSString *plainText;
@property (nonatomic, readonly, copy) NSString *accessibilityText;
@end

/// Shared measuring helpers (main thread only).
@interface CFText : NSObject
+ (CGSize)sizeOfAttributedString:(NSAttributedString *)string width:(CGFloat)width;
+ (CGFloat)widthOfString:(NSString *)string font:(UIFont *)font;
+ (NSDictionary<NSAttributedStringKey, id> *)attributesWithFont:(UIFont *)font color:(UIColor *)color lineHeight:(CGFloat)lineHeight;
+ (NSString *)timeStringForDate:(NSDate *)date;
+ (NSString *)dayStringForDate:(NSDate *)date;
@end

NS_ASSUME_NONNULL_END
