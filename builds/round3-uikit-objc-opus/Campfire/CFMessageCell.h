@import UIKit;
#import "CFRowLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFMessageCell : UIView
- (void)configureWithLayout:(CFRowLayout *)layout item:(CFMessageItem *)item store:(CFRoomStore *)store;
@property (nonatomic, readonly) NSInteger itemID;
/// The layout the cell shows (nil before the first configure).
@property (nonatomic, readonly, nullable) CFRowLayout *layout;
@end

NS_ASSUME_NONNULL_END
