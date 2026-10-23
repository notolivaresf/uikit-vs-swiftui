#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CFBlockType) {
    CFBlockTypeText = 0,
    CFBlockTypeMention,
    CFBlockTypeCode,
};

@interface CFBlockItem : NSObject
@property (nonatomic) CFBlockType type;
@property (nonatomic, copy, nullable) NSString *text;       // text, or code source
@property (nonatomic) NSInteger mentionedUserID;
@property (nonatomic, copy, nullable) NSString *mentionName;
@property (nonatomic, copy, nullable) NSString *language;
@end

@interface CFBoostItem : NSObject
@property (nonatomic) NSInteger boostID;
@property (nonatomic) NSInteger boosterID;
@property (nonatomic, copy) NSString *boosterName;
@property (nonatomic, copy) NSString *content;
@end

// One row's data, already resolved (names, presentation) so layout never goes back to the dataset.
@interface CFMessage : NSObject
@property (nonatomic) NSInteger messageID;
@property (nonatomic) NSInteger creatorID;
@property (nonatomic, copy) NSString *authorName;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, copy) NSArray<CFBlockItem *> *blocks;

@property (nonatomic) BOOL hasImage;
@property (nonatomic) NSInteger imageWidth, imageHeight;
@property (nonatomic, strong, nullable) NSColor *imageColor;

@property (nonatomic, copy, nullable) NSString *fileName;
@property (nonatomic) NSInteger fileBytes;

@property (nonatomic, strong) NSMutableArray<CFBoostItem *> *boosts;
@property (nonatomic) BOOL isEmojiOnly;

// Presentation (from CampfireKit's Grouping).
@property (nonatomic) BOOL isThreaded;
@property (nonatomic) BOOL isFirstOfDay;
@property (nonatomic) BOOL isMine;
@property (nonatomic) BOOL mentionsMe;

// Shaped text kept between layouts (keyed by fragment and text size); only touched by the row layout.
@property (nonatomic, readonly) NSMutableDictionary<NSString *, id> *layoutCache;

// The message's text as shown (mentions as names), for Copy.
@property (nonatomic, readonly) NSString *displayText;
@end

NS_ASSUME_NONNULL_END
