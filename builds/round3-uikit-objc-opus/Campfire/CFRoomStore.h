@import Foundation;
@import CampfireKitObjC;

NS_ASSUME_NONNULL_BEGIN

@interface CFBoostItem : NSObject
- (instancetype)initWithBoosterID:(NSInteger)boosterID content:(NSString *)content;
@property (nonatomic, readonly) NSInteger boosterID;
@property (nonatomic, readonly, copy) NSString *content;
@end

/// One message row: the immutable CampfireKit message plus the boosts it has gained since.
@interface CFMessageItem : NSObject
@property (nonatomic, readonly) NSInteger itemID;
@property (nonatomic, readonly) CFKMessage *message;
@property (nonatomic, readonly) CFKPresentation *presentation;
@property (nonatomic, readonly, copy) NSArray<CFBoostItem *> *boosts;
/// Bumped whenever the row's content changes, so cached layouts know to re-measure.
@property (nonatomic, readonly) NSUInteger revision;
/// The last layout computed for this row (a CFRowLayout); checked against width, text size and revision before use.
@property (nonatomic, strong, nullable) id layout;
@end

/// All messages of the room: the 50,000 generated ones plus what the live stream adds after them.
/// Ids are contiguous: 1...dataset.lastMessageID, then live messages.
@interface CFRoomStore : NSObject
- (instancetype)initWithDataset:(CFKDataset *)dataset;
@property (nonatomic, readonly) CFKDataset *dataset;
@property (nonatomic, readonly) NSInteger currentUserID;
@property (nonatomic, readonly) NSInteger firstID;
@property (nonatomic, readonly) NSInteger newestID;
- (nullable CFKUser *)userWithID:(NSInteger)userID;

- (NSArray<CFMessageItem *> *)newestItems:(NSInteger)count;
/// Items with ids in [from, to], clamped to what exists.
- (NSArray<CFMessageItem *> *)itemsFrom:(NSInteger)from to:(NSInteger)to;
- (nullable CFMessageItem *)itemWithID:(NSInteger)itemID;
/// True when every dataset message in [from, to] is already wrapped (main thread).
- (BOOL)hasItemsFrom:(NSInteger)from to:(NSInteger)to;
/// Wraps the page of messages before `itemID` without touching the store: safe on any thread. Hand the result
/// to -adoptItems: on the main thread.
- (NSArray<CFMessageItem *> *)detachedItemsBefore:(NSInteger)itemID;
/// Keeps prefetched items, unless the store already wrapped those messages (main thread).
- (void)adoptItems:(NSArray<CFMessageItem *> *)items;

/// Starts a live session: ids the feed hands out (dataset last + 1...) are mapped after the newest message.
- (void)beginLiveSession;
- (CFMessageItem *)appendLiveMessage:(CFKMessage *)message;
/// Maps a message id from the live feed to a room id.
- (NSInteger)roomIDForFeedMessageID:(NSInteger)feedID;
- (nullable CFMessageItem *)addBoost:(CFBoostItem *)boost toItemID:(NSInteger)itemID;
@end

NS_ASSUME_NONNULL_END
