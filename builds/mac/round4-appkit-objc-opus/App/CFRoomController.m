#import "CFRoomController.h"
#import "CFRoomView.h"
#import "CFChromeViews.h"
#import "CFDebugBar.h"
#import "CFTheme.h"
#import <QuartzCore/QuartzCore.h>
@import CampfireKitObjC;

static const CGFloat kPinDistance = 100;      // "within 100 pt of the bottom" counts as pinned
static const CGFloat kLoadMoreDistance = 300; // load another page when this close to an end
static const CGFloat kJumpSize = 42;

typedef struct {
    BOOL pinned;
    NSInteger messageID;   // top row (first row at least partly visible below the header)
    CGFloat offset;        // its top relative to the header's bottom edge
} CFAnchor;

#pragma mark - Content view

@class CFRoomContentView;
@protocol CFRoomContentLayout <NSObject>
- (void)layoutRoomContent:(CFRoomContentView *)view;
@end

// Window content: debug bar (optional), header over the room, room scroll view, composer.
@interface CFRoomContentView : NSView
@property (nonatomic, weak) id<CFRoomContentLayout> layoutDelegate;
@end

@implementation CFRoomContentView
- (BOOL)isFlipped { return YES; }
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [self.layoutDelegate layoutRoomContent:self];
}
- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];
    [self.layoutDelegate layoutRoomContent:self];
}
@end

#pragma mark - Controller

@interface CFRoomController () <CFRoomContentLayout, NSMenuItemValidation>
@end

@implementation CFRoomController {
    BOOL _benchmark;
    CFTimeInterval _launchStart;
    NSWindow *_window;
    CFRoomContentView *_content;
    CFDebugBar *_bar;
    CFHeaderView *_header;
    NSScrollView *_scroll;
    CFRoomView *_room;
    CFComposerView *_composer;
    CFJumpButton *_jump;

    CFKDataset *_dataset;
    NSDictionary<NSNumber *, NSString *> *_names;
    NSMutableArray<CFMessage *> *_live;          // messages from the live stream, oldest first
    CFKMessage *_lastKitMessage;                 // newest message known (for live presentations)
    NSMutableDictionary<NSNumber *, NSMutableArray<CFBoostItem *> *> *_extraBoosts;   // live boosts on history

    NSMutableArray<CFMessage *> *_loaded;
    NSMutableArray<CFRowLayout *> *_layouts;
    NSInteger _textStep;
    CGFloat _layoutWidth;

    CFKFeedHandle *_feed;
    BOOL _streaming;
    NSInteger _nextBoostID;

    CFAnchor _anchor;
    BOOL _adjusting;
    BOOL _resizing;
    BOOL _loadScheduled;
    BOOL _stateUpdateScheduled;
    BOOL _hasUnseenMessages;
    NSInteger _ms;
    CFTimeInterval _clickTime;
}

static dispatch_group_t sDatasetGroup;
static CFKDataset *sDataset;

+ (void)preloadDataset {
    sDatasetGroup = dispatch_group_create();
    dispatch_group_async(sDatasetGroup, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        sDataset = [[CFKDataset alloc] init];
    });
}

- (instancetype)initWithBenchmarkBar:(BOOL)benchmark launchStart:(CFTimeInterval)launchStart {
    if ((self = [super init])) {
        _benchmark = benchmark;
        _launchStart = launchStart;
        _live = [NSMutableArray array];
        _extraBoosts = [NSMutableDictionary dictionary];
        _loaded = [NSMutableArray array];
        _layouts = [NSMutableArray array];
        _nextBoostID = 2000000;
        _anchor.pinned = YES;
    }
    return self;
}

#pragma mark Window

- (void)showWindow {
    if (!sDatasetGroup) [CFRoomController preloadDataset];
    dispatch_group_wait(sDatasetGroup, DISPATCH_TIME_FOREVER);
    _dataset = sDataset;
    NSMutableDictionary *names = [NSMutableDictionary dictionary];
    for (CFKUser *u in _dataset.users) names[@(u.userID)] = u.name;
    _names = names;
    _lastKitMessage = [_dataset messageWithID:_dataset.lastMessageID];

    NSRect contentRect = NSMakeRect(0, 0, 393, 852);
    _window = [[NSWindow alloc] initWithContentRect:contentRect
                                          styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                    NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = _dataset.roomName;
    _window.restorable = NO;
    _window.releasedWhenClosed = NO;
    _window.delegate = self;
    _window.contentMinSize = NSMakeSize(393, 600);
    _window.backgroundColor = CFTheme.background;

    _content = [[CFRoomContentView alloc] initWithFrame:contentRect];
    _content.layoutDelegate = self;
    _window.contentView = _content;

    _scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _scroll.hasVerticalScroller = YES;
    _scroll.hasHorizontalScroller = NO;
    _scroll.drawsBackground = YES;
    _scroll.backgroundColor = CFTheme.background;
    _scroll.automaticallyAdjustsContentInsets = NO;
    _scroll.contentInsets = NSEdgeInsetsMake(CFHeaderHeight, 0, 0, 0);
    _scroll.scrollerInsets = NSEdgeInsetsMake(0, 0, 0, 0);
    _scroll.verticalScrollElasticity = NSScrollElasticityAllowed;
    _scroll.horizontalScrollElasticity = NSScrollElasticityNone;
    _scroll.contentView.postsBoundsChangedNotifications = YES;
    _room = [[CFRoomView alloc] initWithFrame:NSMakeRect(0, 0, 393, 100)];
    _scroll.documentView = _room;
    [_content addSubview:_scroll];

    _header = [[CFHeaderView alloc] initWithFrame:NSZeroRect];
    _header.scrollView = _scroll;
    [_content addSubview:_header];

    _composer = [[CFComposerView alloc] initWithFrame:NSZeroRect];
    [_content addSubview:_composer];

    _jump = [[CFJumpButton alloc] initWithFrame:NSMakeRect(0, 0, kJumpSize, kJumpSize)];
    _jump.target = self;
    _jump.action = @selector(jumpToBottom:);
    _jump.hidden = YES;
    [_content addSubview:_jump];

    if (_benchmark) {
        _bar = [[CFDebugBar alloc] initWithTarget:self];
        [_content addSubview:_bar];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clipBoundsChanged:)
                                                 name:NSViewBoundsDidChangeNotification object:_scroll.contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scrollEnded:)
                                                 name:NSScrollViewDidEndLiveScrollNotification object:_scroll];

    [self layoutRoomContent:_content];
    [self loadNewestPage];

    // Centre the window on the screen (no restored frame).
    NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSRect vis = screen.visibleFrame;
    NSRect frame = _window.frame;
    frame.origin.x = round(NSMidX(vis) - frame.size.width / 2);
    frame.origin.y = round(NSMidY(vis) - frame.size.height / 2);
    if (NSMaxY(frame) > NSMaxY(vis)) frame.origin.y = NSMaxY(vis) - frame.size.height;
    [_window setFrame:frame display:NO];
    [_window makeKeyAndOrderFront:nil];
    [_window makeFirstResponder:_room];
    [self scrollToBottom];
    [_window displayIfNeeded];
    _ms = (NSInteger)llround((CACurrentMediaTime() - _launchStart) * 1000);
    [self updateState];
}

- (void)layoutRoomContent:(CFRoomContentView *)view {
    if (!_scroll) return;
    NSSize size = view.bounds.size;
    CGFloat W = size.width, y = 0;
    if (_bar) {
        CGFloat h = [_bar heightForWidth:W];
        _bar.frame = NSMakeRect(0, 0, W, h);
        [_bar resizeSubviewsWithOldSize:NSZeroSize];
        y = h;
    }
    _resizing = YES;
    _composer.frame = NSMakeRect(0, size.height - CFComposerHeight, W, CFComposerHeight);
    NSRect scrollFrame = NSMakeRect(0, y, W, MAX(size.height - CFComposerHeight - y, 50));
    _scroll.frame = scrollFrame;
    _header.frame = NSMakeRect(0, y, W, CFHeaderHeight);
    _jump.frame = NSMakeRect(W - CFScreenPadX - kJumpSize, NSMaxY(scrollFrame) - kJumpSize - 12, kJumpSize, kJumpSize);
    CGFloat width = _scroll.contentView.bounds.size.width;
    if (width > 0 && fabs(width - _layoutWidth) > 0.01) {
        _layoutWidth = width;
        [self relayoutAll];
    } else {
        [_room setFrameSize:NSMakeSize(width, _room.frame.size.height)];
    }
    if (_loaded.count) {
        // The anchor from before the resize (kept for the whole live resize) decides the position.
        CFAnchor a = _anchor;
        [self restoreAnchor:a];
        _resizing = NO;
        if (!view.inLiveResize) {
            _anchor = [self currentAnchor];
            if (a.pinned) _anchor.pinned = YES;
        }
        [self updateState];
    }
    _resizing = NO;
}

#pragma mark Data

- (CFMessage *)modelFromKit:(CFKMessage *)k presentation:(CFKPresentation *)p {
    CFMessage *m = [CFMessage new];
    m.messageID = k.messageID;
    m.creatorID = k.creatorID;
    m.authorName = _names[@(k.creatorID)] ?: @"Unknown";
    m.createdAt = k.createdAt;
    NSMutableArray *blocks = [NSMutableArray arrayWithCapacity:k.blocks.count];
    for (CFKBlock *b in k.blocks) {
        CFBlockItem *item = [CFBlockItem new];
        switch (b.kind) {
            case CFKBlockKindText: item.type = CFBlockTypeText; item.text = b.text; break;
            case CFKBlockKindMention:
                item.type = CFBlockTypeMention;
                item.mentionedUserID = b.mentionedUserID;
                item.mentionName = _names[@(b.mentionedUserID)] ?: @"someone";
                break;
            case CFKBlockKindCode: item.type = CFBlockTypeCode; item.text = b.text; item.language = b.language; break;
        }
        [blocks addObject:item];
    }
    m.blocks = blocks;
    CFKAttachment *a = k.attachment;
    if (a && a.kind == CFKAttachmentKindImage) {
        m.hasImage = YES;
        m.imageWidth = a.width;
        m.imageHeight = a.height;
        m.imageColor = [NSColor colorWithSRGBRed:a.red / 255.0 green:a.green / 255.0 blue:a.blue / 255.0 alpha:1];
    } else if (a && a.kind == CFKAttachmentKindFile) {
        m.fileName = a.name;
        m.fileBytes = a.bytes;
    }
    for (CFKBoost *b in k.boosts) [m.boosts addObject:[self boostItem:b]];
    for (CFBoostItem *b in _extraBoosts[@(k.messageID)]) [m.boosts addObject:b];
    m.isEmojiOnly = k.isEmojiOnly;
    m.isThreaded = p.isThreaded;
    m.isFirstOfDay = p.isFirstOfDay;
    m.isMine = p.isMine;
    m.mentionsMe = p.mentionsMe;
    return m;
}

- (CFBoostItem *)boostItem:(CFKBoost *)b {
    CFBoostItem *item = [CFBoostItem new];
    item.boostID = b.boostID;
    item.boosterID = b.boosterID;
    item.boosterName = _names[@(b.boosterID)] ?: @"?";
    item.content = b.content;
    return item;
}

- (NSArray<CFMessage *> *)modelsFromPage:(CFKPage *)page {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:page.messages.count];
    for (NSUInteger i = 0; i < page.messages.count; i++) {
        [out addObject:[self modelFromKit:page.messages[i] presentation:page.presentations[i]]];
    }
    return out;
}

- (NSInteger)newestID {
    return _live.count ? _live.lastObject.messageID : _dataset.lastMessageID;
}

// Up to `count` messages before `messageID`, across the history and the live messages.
- (NSArray<CFMessage *> *)modelsBeforeID:(NSInteger)messageID count:(NSInteger)count {
    NSInteger last = _dataset.lastMessageID;
    NSMutableArray<CFMessage *> *out = [NSMutableArray array];
    NSInteger liveBefore = MIN(MAX(messageID - last - 1, 0), (NSInteger)_live.count);
    if (liveBefore > 0) {
        NSInteger from = MAX(liveBefore - count, 0);
        [out addObjectsFromArray:[_live subarrayWithRange:NSMakeRange((NSUInteger)from, (NSUInteger)(liveBefore - from))]];
    }
    NSInteger remaining = count - (NSInteger)out.count;
    NSInteger before = MIN(messageID, last + 1);
    if (remaining > 0 && before > _dataset.firstMessageID) {
        CFKPage *page = before == last + 1 ? [_dataset lastPage] : [_dataset pageBeforeMessageID:before];
        NSArray<CFMessage *> *models = [self modelsFromPage:page];
        NSInteger take = MIN(remaining, (NSInteger)models.count);
        NSArray *tail = [models subarrayWithRange:NSMakeRange(models.count - (NSUInteger)take, (NSUInteger)take)];
        [out insertObjects:tail atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, tail.count)]];
    }
    return out;
}

// Up to `count` messages after `messageID`.
- (NSArray<CFMessage *> *)modelsAfterID:(NSInteger)messageID count:(NSInteger)count {
    NSInteger last = _dataset.lastMessageID;
    NSMutableArray<CFMessage *> *out = [NSMutableArray array];
    if (messageID < last) {
        NSArray *models = [self modelsFromPage:[_dataset pageAfterMessageID:messageID]];
        [out addObjectsFromArray:[models subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)count, models.count))]];
    }
    NSInteger remaining = count - (NSInteger)out.count;
    if (remaining > 0 && _live.count) {
        NSInteger startID = out.count ? out.lastObject.messageID + 1 : messageID + 1;
        NSInteger from = startID - last - 1;
        if (from >= 0 && from < (NSInteger)_live.count) {
            NSInteger n = MIN(remaining, (NSInteger)_live.count - from);
            [out addObjectsFromArray:[_live subarrayWithRange:NSMakeRange((NSUInteger)from, (NSUInteger)n)]];
        }
    }
    return out;
}

#pragma mark Layout

- (CGFloat)textScale { return CFTextScaleAt(_textStep); }

- (CFRowLayout *)layoutFor:(CFMessage *)m {
    return [CFRowLayout layoutForMessage:m width:_layoutWidth scale:self.textScale];
}

// Lays out many rows on all cores (CoreText typesetting is thread-safe); order is kept.
- (NSArray<CFRowLayout *> *)layoutsFor:(NSArray<CFMessage *> *)messages {
    NSUInteger n = messages.count;
    if (n < 8) {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
        for (CFMessage *m in messages) [out addObject:[self layoutFor:m]];
        return out;
    }
    __strong CFRowLayout **results = (__strong CFRowLayout **)calloc(n, sizeof(CFRowLayout *));
    CGFloat width = _layoutWidth, scale = self.textScale;
    dispatch_apply(n, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t i) {
        results[i] = [CFRowLayout layoutForMessage:messages[i] width:width scale:scale];
    });
    NSArray *out = [NSArray arrayWithObjects:results count:n];
    for (NSUInteger i = 0; i < n; i++) results[i] = nil;
    free(results);
    return out;
}

- (void)relayoutAll {
    [_layouts setArray:[self layoutsFor:_loaded]];
    [self applyRows];
}

- (void)applyRows {
    BOOL welcome = _loaded.count && _loaded.firstObject.messageID == _dataset.firstMessageID;
    [_room setFrameSize:NSMakeSize(_layoutWidth, _room.frame.size.height)];
    [_room setRows:_layouts welcome:welcome];
}

- (void)setLoaded:(NSArray<CFMessage *> *)models {
    [_room clearSelection];
    [_loaded setArray:models];
    [_layouts setArray:[self layoutsFor:_loaded]];
    [self applyRows];
}

#pragma mark Scrolling and anchoring

- (NSClipView *)clip { return _scroll.contentView; }

- (CGFloat)visibleTop { return self.clip.bounds.origin.y + CFHeaderHeight; }
- (CGFloat)visibleBottom { return NSMaxY(self.clip.bounds); }
- (CGFloat)minScrollY { return -CFHeaderHeight; }
- (CGFloat)maxScrollY { return MAX(self.minScrollY, _room.frame.size.height - self.clip.bounds.size.height); }

- (void)scrollToY:(CGFloat)y {
    y = MIN(MAX(y, self.minScrollY), self.maxScrollY);
    BOOL was = _adjusting;
    _adjusting = YES;
    [self.clip scrollToPoint:NSMakePoint(0, y)];
    [_scroll reflectScrolledClipView:self.clip];
    [_room tile];
    _adjusting = was;
}

- (void)scrollToBottom {
    [self scrollToY:self.maxScrollY];
}

- (BOOL)isPinned {
    if (_loaded.count == 0) return YES;
    if (_loaded.lastObject.messageID != self.newestID) return NO;
    return _room.contentHeight - self.visibleBottom <= kPinDistance;
}

- (CFAnchor)currentAnchor {
    CFAnchor a = {0};
    a.pinned = self.isPinned;
    NSUInteger i = [_room indexOfRowAtOrBelowY:self.visibleTop];
    if (i != NSNotFound) {
        a.messageID = _room.rows[i].message.messageID;
        a.offset = [_room topOfRowAtIndex:i] - self.visibleTop;
    }
    return a;
}

- (void)restoreAnchor:(CFAnchor)a {
    if (a.pinned) {
        [self scrollToBottom];
    } else {
        NSUInteger i = [_room indexOfMessageID:a.messageID];
        if (i != NSNotFound) [self scrollToY:[_room topOfRowAtIndex:i] - a.offset - CFHeaderHeight];
    }
    if (!_resizing && !_content.inLiveResize) {
        _anchor = [self currentAnchor];
        if (a.pinned) _anchor.pinned = YES;
    }
    [self updateJumpButton];
}

- (void)clipBoundsChanged:(NSNotification *)n {
    [_room tile];
    if (_adjusting || _resizing || _content.inLiveResize) return;
    _anchor = [self currentAnchor];
    [self updateJumpButton];
    [self scheduleStateUpdate];
    [self scheduleLoadMoreIfNeeded];
}

- (void)scrollEnded:(NSNotification *)n {
    [self updateState];
}

- (void)scheduleLoadMoreIfNeeded {
    if (_loadScheduled || _loaded.count == 0) return;
    BOOL older = self.visibleTop - [_room topOfRowAtIndex:0] < kLoadMoreDistance &&
                 _loaded.firstObject.messageID > _dataset.firstMessageID;
    BOOL newer = _room.contentHeight - self.visibleBottom < kLoadMoreDistance && _loaded.lastObject.messageID < self.newestID;
    if (!older && !newer) return;
    _loadScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_loadScheduled = NO;
        if (older) [self loadOlder];
        else [self loadNewer];
        [self updateState];
    });
}

- (void)loadOlder {
    if (_loaded.count == 0 || _loaded.firstObject.messageID <= _dataset.firstMessageID) return;
    NSArray<CFMessage *> *older = [self modelsBeforeID:_loaded.firstObject.messageID count:CFKDataset.pageSize];
    if (older.count == 0) return;
    CFAnchor a = [self currentAnchor];
    a.pinned = NO;
    NSArray *layouts = [self layoutsFor:older];
    [_loaded insertObjects:older atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, older.count)]];
    [_layouts insertObjects:layouts atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, layouts.count)]];
    [self applyRows];
    [self restoreAnchor:a];
}

- (void)loadNewer {
    if (_loaded.count == 0 || _loaded.lastObject.messageID >= self.newestID) return;
    NSArray<CFMessage *> *newer = [self modelsAfterID:_loaded.lastObject.messageID count:CFKDataset.pageSize];
    if (newer.count == 0) return;
    CFAnchor a = [self currentAnchor];
    a.pinned = NO;
    [_loaded addObjectsFromArray:newer];
    [_layouts addObjectsFromArray:[self layoutsFor:newer]];
    [self applyRows];
    [self restoreAnchor:a];
}

- (void)loadNewestPage {
    [self setLoaded:[self modelsBeforeID:self.newestID + 1 count:CFKDataset.pageSize]];
    [self scrollToBottom];
    _anchor = [self currentAnchor];
    _anchor.pinned = YES;
    [self updateJumpButton];
}

- (void)updateJumpButton {
    // Shown only when new messages came in while the room was not pinned to the bottom.
    BOOL pinned = self.isPinned;
    if (pinned) _hasUnseenMessages = NO;
    _jump.hidden = pinned || !_hasUnseenMessages;
}

- (void)jumpToBottom:(id)sender {
    if (_loaded.count && _loaded.lastObject.messageID == self.newestID) {
        [self scrollToBottom];
    } else {
        [self loadNewestPage];
    }
    _anchor = [self currentAnchor];
    _anchor.pinned = YES;
    [self updateJumpButton];
    [self updateState];
}

#pragma mark Live updates

- (void)appendLiveMessage:(CFKMessage *)k {
    if (k.messageID <= self.newestID) return;   // replayed stream: already have it
    CFKPresentation *p = [_dataset presentationOf:k after:_lastKitMessage];
    _lastKitMessage = k;
    CFMessage *m = [self modelFromKit:k presentation:p];
    BOOL showing = _loaded.count && _loaded.lastObject.messageID == self.newestID;
    CFAnchor a = [self currentAnchor];   // before the new message counts as the newest
    [_live addObject:m];
    if (!a.pinned) _hasUnseenMessages = YES;
    if (!showing) {
        [self updateJumpButton];
        return;
    }
    [_loaded addObject:m];
    [_layouts addObject:[self layoutFor:m]];
    [self applyRows];
    [self restoreAnchor:a];
}

- (void)addBoost:(CFBoostItem *)boost toMessageID:(NSInteger)messageID {
    NSInteger last = _dataset.lastMessageID;
    CFMessage *liveModel = nil;
    if (messageID > last) {
        NSInteger i = messageID - last - 1;
        if (i >= 0 && i < (NSInteger)_live.count) liveModel = _live[(NSUInteger)i];
    }
    NSUInteger row = [_room indexOfMessageID:messageID];
    if (liveModel) {
        [liveModel.boosts addObject:boost];
    } else {
        NSMutableArray *extra = _extraBoosts[@(messageID)];
        if (!extra) _extraBoosts[@(messageID)] = extra = [NSMutableArray array];
        [extra addObject:boost];
        if (row != NSNotFound) [_loaded[row].boosts addObject:boost];
    }
    if (row == NSNotFound) return;
    CFAnchor a = [self currentAnchor];
    _layouts[row] = [self layoutFor:_loaded[row]];
    [self applyRows];
    [self restoreAnchor:a];
}

#pragma mark State label

- (void)scheduleStateUpdate {
    if (_stateUpdateScheduled || !_bar) return;
    _stateUpdateScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_stateUpdateScheduled = NO;
        [self updateState];
    });
}

- (void)updateState {
    if (!_bar) return;
    NSInteger first = _loaded.firstObject.messageID, last = _loaded.lastObject.messageID;
    NSInteger top = 0;
    CGFloat y = 0;
    NSUInteger i = [_room indexOfRowAtOrBelowY:self.visibleTop];
    if (i != NSNotFound) {
        top = _room.rows[i].message.messageID;
        y = [_room topOfRowAtIndex:i] - self.visibleTop;
    }
    if (fabs(y) < 0.05) y = 0;
    NSString *s = [NSString stringWithFormat:@"first %ld last %ld loaded %lu pinned %@ top %ld y %.1f ms %ld",
                   (long)first, (long)last, (unsigned long)_loaded.count, self.isPinned ? @"yes" : @"no",
                   (long)top, y, (long)_ms];
    if (![_bar.stateLabel.stringValue isEqualToString:s]) _bar.stateLabel.stringValue = s;
}

#pragma mark Debug bar

// Start of a debug-bar measurement: the mouse-up of the click on `sender` (event timestamps share
// CACurrentMediaTime's clock), or now when the button was pressed some other way.
- (void)beginTimingForSender:(id)sender {
    NSEvent *e = NSApp.currentEvent;
    CFTimeInterval now = CACurrentMediaTime();
    _clickTime = now;
    if (e.type == NSEventTypeLeftMouseUp && [sender isKindOfClass:NSView.class] && e.window == [sender window]) {
        NSView *v = sender;
        NSPoint p = [v convertPoint:e.locationInWindow fromView:nil];
        CFTimeInterval t = e.timestamp;
        if (NSPointInRect(p, v.bounds) && t <= now && now - t < 2) _clickTime = t;
    }
}

- (void)endTiming {
    [_room tile];
    [_window displayIfNeeded];
    _ms = (NSInteger)llround((CACurrentMediaTime() - _clickTime) * 1000);
    [self updateState];
    [_bar.stateLabel displayIfNeeded];
}

- (void)debugReset:(id)sender {
    [self beginTimingForSender:sender];
    _textStep = 0;
    [self loadNewestPage];
    [self endTiming];
}

- (void)debugJump:(id)sender {
    [self beginTimingForSender:sender];
    NSInteger target = 2500;
    [self setLoaded:[self modelsFromPage:[_dataset pageAroundMessageID:target]]];
    NSUInteger i = [_room indexOfMessageID:target];
    if (i != NSNotFound) [self scrollToY:[_room topOfRowAtIndex:i] - CFHeaderHeight];
    _anchor = [self currentAnchor];
    [self updateJumpButton];
    [self endTiming];
}

- (void)debugLoadOlder:(id)sender {
    [self beginTimingForSender:sender];
    [self loadOlder];
    [self endTiming];
}

- (void)debugStartStream:(id)sender {
    if (_streaming) return;
    _streaming = YES;
    _bar.streamDoneLabel.hidden = YES;
    CFKLiveFeed *feed = [[CFKLiveFeed alloc] initWithDataset:_dataset];
    __weak typeof(self) weakSelf = self;
    _feed = [feed startOnEvent:^(CFKFeedEvent *event) {
        [weakSelf handleFeedEvent:event];
    } completion:^{
        [weakSelf streamFinished];
    }];
}

- (void)handleFeedEvent:(CFKFeedEvent *)event {
    switch (event.kind) {
        case CFKFeedEventKindMessage:
            if (event.message) [self appendLiveMessage:event.message];
            break;
        case CFKFeedEventKindBoost:
            if (event.boost) [self addBoost:[self boostItem:event.boost] toMessageID:event.messageID];
            break;
        default:
            break;
    }
    [self scheduleStateUpdate];
}

- (void)streamFinished {
    _streaming = NO;
    _feed = nil;
    _bar.streamDoneLabel.hidden = NO;
    [self updateState];
}

- (void)debugTextSize:(id)sender {
    [self beginTimingForSender:sender];
    [self setTextStep:(_textStep + 1) % CFTextScaleCount];
    [self endTiming];
}

- (void)debugBoostBurst:(id)sender {
    NSInteger target = self.newestID;
    NSArray *emoji = @[@"👍", @"🎉", @"🔥", @"❤️", @"😂"];
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            CFBoostItem *b = [CFBoostItem new];
            b.boostID = self->_nextBoostID++;
            b.boosterID = 2 + i;
            b.boosterName = self->_names[@(2 + i)] ?: @"?";
            b.content = emoji[(NSUInteger)i];
            [self addBoost:b toMessageID:target];
            [self updateState];
        });
    }
}

#pragma mark Text size

- (void)setTextStep:(NSInteger)step {
    step = MAX(0, MIN(step, CFTextScaleCount - 1));
    CFAnchor a = [self currentAnchor];
    _textStep = step;
    [self relayoutAll];
    [self restoreAnchor:a];
    [self updateState];
}

- (IBAction)makeTextBigger:(id)sender { [self setTextStep:_textStep + 1]; }
- (IBAction)makeTextSmaller:(id)sender { [self setTextStep:_textStep - 1]; }
- (IBAction)makeTextStandardSize:(id)sender { [self setTextStep:0]; }

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(makeTextBigger:)) return _textStep < CFTextScaleCount - 1;
    if (item.action == @selector(makeTextSmaller:)) return _textStep > 0;
    if (item.action == @selector(makeTextStandardSize:)) return _textStep != 0;
    return YES;
}

@end
