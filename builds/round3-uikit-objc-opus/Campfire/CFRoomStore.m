#import "CFRoomStore.h"

@implementation CFBoostItem
- (instancetype)initWithBoosterID:(NSInteger)boosterID content:(NSString *)content {
    if ((self = [super init])) { _boosterID = boosterID; _content = [content copy]; }
    return self;
}
@end

@interface CFMessageItem ()
@property (nonatomic, readwrite, copy) NSArray<CFBoostItem *> *boosts;
@property (nonatomic, readwrite) NSUInteger revision;
@end

@implementation CFMessageItem
- (instancetype)initWithID:(NSInteger)itemID message:(CFKMessage *)message presentation:(CFKPresentation *)presentation {
    if ((self = [super init])) {
        _itemID = itemID;
        _message = message;
        _presentation = presentation;
        NSMutableArray *boosts = [NSMutableArray arrayWithCapacity:message.boosts.count];
        for (CFKBoost *b in message.boosts) {
            [boosts addObject:[[CFBoostItem alloc] initWithBoosterID:b.boosterID content:b.content]];
        }
        _boosts = boosts;
    }
    return self;
}
@end

@implementation CFRoomStore {
    NSMutableDictionary<NSNumber *, CFMessageItem *> *_items;
    NSMutableArray<CFMessageItem *> *_live;
    NSDictionary<NSNumber *, CFKUser *> *_users;
    NSInteger _datasetLast;
    NSInteger _feedOffset;
}

- (instancetype)initWithDataset:(CFKDataset *)dataset {
    if ((self = [super init])) {
        _dataset = dataset;
        _currentUserID = dataset.currentUserID;
        _datasetLast = dataset.lastMessageID;
        _items = [NSMutableDictionary dictionary];
        _live = [NSMutableArray array];
        NSMutableDictionary *users = [NSMutableDictionary dictionary];
        for (CFKUser *u in dataset.users) { users[@(u.userID)] = u; }
        _users = users;
    }
    return self;
}

- (NSInteger)firstID { return _dataset.firstMessageID; }
- (NSInteger)newestID { return _datasetLast + (NSInteger)_live.count; }
- (CFKUser *)userWithID:(NSInteger)userID { return _users[@(userID)]; }

- (CFMessageItem *)itemForMessage:(CFKMessage *)m presentation:(CFKPresentation *)p {
    CFMessageItem *item = _items[@(m.messageID)];
    if (!item) {
        item = [[CFMessageItem alloc] initWithID:m.messageID message:m presentation:p];
        _items[@(m.messageID)] = item;
    }
    return item;
}

- (NSArray<CFMessageItem *> *)datasetItemsFrom:(NSInteger)from to:(NSInteger)to {
    NSMutableArray<CFMessageItem *> *out = [NSMutableArray array];
    if (from > to) { return out; }
    // Fast path: everything already wrapped.
    BOOL cached = YES;
    for (NSInteger i = from; i <= to; i++) { if (!_items[@(i)]) { cached = NO; break; } }
    if (cached) {
        for (NSInteger i = from; i <= to; i++) { [out addObject:_items[@(i)]]; }
        return out;
    }
    NSInteger cursor = to;
    NSMutableArray<NSArray<CFMessageItem *> *> *chunks = [NSMutableArray array];
    while (cursor >= from) {
        CFKPage *page = cursor >= _datasetLast ? [_dataset lastPage] : [_dataset pageBeforeMessageID:cursor + 1];
        if (page.messages.count == 0) { break; }
        NSMutableArray *chunk = [NSMutableArray array];
        for (NSUInteger i = 0; i < page.messages.count; i++) {
            CFKMessage *m = page.messages[i];
            if (m.messageID < from || m.messageID > cursor) { continue; }
            [chunk addObject:[self itemForMessage:m presentation:page.presentations[i]]];
        }
        [chunks insertObject:chunk atIndex:0];
        cursor = page.messages.firstObject.messageID - 1;
    }
    for (NSArray *c in chunks) { [out addObjectsFromArray:c]; }
    return out;
}

- (NSArray<CFMessageItem *> *)itemsFrom:(NSInteger)from to:(NSInteger)to {
    from = MAX(from, self.firstID);
    to = MIN(to, self.newestID);
    NSMutableArray *out = [NSMutableArray array];
    if (from > to) { return out; }
    if (from <= _datasetLast) {
        [out addObjectsFromArray:[self datasetItemsFrom:from to:MIN(to, _datasetLast)]];
    }
    for (NSInteger i = MAX(from, _datasetLast + 1); i <= to; i++) {
        [out addObject:_live[(NSUInteger)(i - _datasetLast - 1)]];
    }
    return out;
}

- (NSArray<CFMessageItem *> *)newestItems:(NSInteger)count {
    NSInteger newest = self.newestID;
    return [self itemsFrom:newest - count + 1 to:newest];
}

- (CFMessageItem *)itemWithID:(NSInteger)itemID {
    if (itemID < self.firstID || itemID > self.newestID) { return nil; }
    if (itemID > _datasetLast) { return _live[(NSUInteger)(itemID - _datasetLast - 1)]; }
    CFMessageItem *item = _items[@(itemID)];
    if (item) { return item; }
    CFKMessage *m = [_dataset messageWithID:itemID];
    CFKPresentation *p = [_dataset presentationForMessageID:itemID];
    if (!m || !p) { return nil; }
    return [self itemForMessage:m presentation:p];
}

- (BOOL)hasItemsFrom:(NSInteger)from to:(NSInteger)to {
    for (NSInteger i = MAX(from, self.firstID); i <= MIN(to, _datasetLast); i++) { if (!_items[@(i)]) { return NO; } }
    return YES;
}

- (NSArray<CFMessageItem *> *)detachedItemsBefore:(NSInteger)itemID {
    CFKPage *page = [_dataset pageBeforeMessageID:itemID];
    NSMutableArray<CFMessageItem *> *out = [NSMutableArray arrayWithCapacity:page.messages.count];
    for (NSUInteger i = 0; i < page.messages.count; i++) {
        CFKMessage *m = page.messages[i];
        [out addObject:[[CFMessageItem alloc] initWithID:m.messageID message:m presentation:page.presentations[i]]];
    }
    return out;
}

- (void)adoptItems:(NSArray<CFMessageItem *> *)items {
    for (CFMessageItem *item in items) {
        if (!_items[@(item.itemID)]) { _items[@(item.itemID)] = item; }
    }
}

- (void)beginLiveSession {
    _feedOffset = (NSInteger)_live.count;
}

- (NSInteger)roomIDForFeedMessageID:(NSInteger)feedID {
    return feedID > _datasetLast ? feedID + _feedOffset : feedID;
}

- (CFMessageItem *)appendLiveMessage:(CFKMessage *)message {
    CFMessageItem *last = [self itemWithID:self.newestID];
    CFKPresentation *p = [_dataset presentationOf:message after:last.message];
    CFMessageItem *item = [[CFMessageItem alloc] initWithID:self.newestID + 1 message:message presentation:p];
    [_live addObject:item];
    return item;
}

- (CFMessageItem *)addBoost:(CFBoostItem *)boost toItemID:(NSInteger)itemID {
    CFMessageItem *item = [self itemWithID:itemID];
    if (!item) { return nil; }
    item.boosts = [item.boosts arrayByAddingObject:boost];
    item.revision += 1;
    return item;
}

@end
