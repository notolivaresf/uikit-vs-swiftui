@import UIKit;
@class CFRow;
NS_ASSUME_NONNULL_BEGIN

// A height index for the ordered room. Inserts and a single height change touch
// only a tree path; asking for a viewport visits only intersecting rows.
@interface CFChatLayout : UICollectionViewLayout
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, copy, nullable) NSDictionary<NSString *,id> *anchor;
- (void)removeAllRows;
- (void)appendRows:(NSArray<CFRow *> *)rows;
- (void)prependRows:(NSArray<CFRow *> *)rows;
- (void)updateRow:(CFRow *)row;
- (void)refreshHeights;
- (nullable NSNumber *)identifierAtIndexPath:(NSIndexPath *)path;
- (nullable NSIndexPath *)indexPathForIdentifier:(NSNumber *)identifier;
@end
NS_ASSUME_NONNULL_END
