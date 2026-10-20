@import UIKit;
#import "CFRowLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFMessageCell : UICollectionViewCell
- (void)configureWithLayout:(CFRowLayout *)layout item:(CFMessageItem *)item store:(CFRoomStore *)store;
@property (nonatomic, readonly) NSInteger itemID;
@end

/// Solid-colour placeholder images from CampfireKit's `CFKPlaceholder` PNGs, decoded off the main thread and cached.
@interface CFImageLoader : NSObject
+ (instancetype)shared;
- (nullable UIImage *)cachedImageForAttachment:(CFKAttachment *)attachment;
- (void)loadImageForAttachment:(CFKAttachment *)attachment completion:(void (^)(UIImage *image))completion;
@end

NS_ASSUME_NONNULL_END
