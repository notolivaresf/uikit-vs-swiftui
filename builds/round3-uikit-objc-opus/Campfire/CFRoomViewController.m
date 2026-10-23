#import "CFRoomViewController.h"
#import "CFRoomStore.h"
#import "CFRowLayout.h"
#import "CFMessageCell.h"
#import "CFChrome.h"
#import "CFDebugBar.h"
#import "CFLaunch.h"
#import "CFIcons.h"

static const CGFloat kPinDistance = 100;      // "within 100 pt of the bottom" stays pinned
static const CGFloat kLoadMoreDistance = 400;  // start loading a page this far from the end
static const CGFloat kListBottomGap = 24;      // list ends this far above the composer
static const CGFloat kComposerBottom = 24;
static const CGFloat kContentBottomPad = 0.8;
static const CGFloat kRowBottomMargin = 1.6;
static const NSInteger kJumpRowsAbove = 10;     // a jump loads one page: this many rows above the target
static const CGFloat kFadeStart = 11.67;       // header fade: content hidden above, fully shown below 57.67
static const CGFloat kFadeEnd = 57.67;

/// A row to keep in place: its id and its top relative to the bottom edge of the header.
typedef struct {
    NSInteger itemID;
    CGFloat offset;
    BOOL valid;
} CFAnchor;

#pragma mark - List

/// The room's list: a plain scroll view whose owner places the row views. UIScrollView lays out on every scroll
/// step, so `tile` runs whenever the visible area moves.
@interface CFRoomScrollView : UIScrollView
@property (nonatomic, copy) void (^tile)(void);
@end

@implementation CFRoomScrollView
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.tile) { self.tile(); }
}
@end

#pragma mark - View controller

@interface CFRoomViewController () <UIScrollViewDelegate>
@end

@implementation CFRoomViewController {
    CFRoomStore *_store;
    CFMetrics *_metrics;

    CFRoomScrollView *_list;
    NSMutableDictionary<NSNumber *, UIView *> *_visibleViews;  // by item id; the welcome card under 0
    NSMutableArray<CFMessageCell *> *_reusableCells;
    CFWelcomeCell *_welcomeCell;
    CFHeaderView *_header;
    UIView *_fade;
    CAGradientLayer *_fadeGradient;
    UIView *_statusCover;
    CFComposerView *_composer;
    UIButton *_jumpToBottom;
    CFDebugBar *_debugBar;

    NSMutableArray<CFMessageItem *> *_rows;
    BOOL _showsWelcome;
    CGRect *_frames;
    NSInteger _frameCapacity;
    NSInteger _frameCount;
    CGSize _contentSize;
    CGFloat _bottomShift;   // > 0 when a short room was pushed down to sit at the bottom
    CGFloat _rowWidth;
    CGFloat _rowX;

    BOOL _updating;
    BOOL _freezeAnchor;
    CFAnchor _lastAnchor;
    BOOL _lastPinned;
    BOOL _loadScheduled;
    BOOL _prefetching;
    BOOL _didInitialLoad;

    CFKLiveFeed *_feed;
    CFKFeedHandle *_feedHandle;
    BOOL _streaming;
    NSMutableArray<CFMessageItem *> *_pendingAppends;
    NSMutableSet<NSNumber *> *_pendingChanged;
    BOOL _flushScheduled;

    NSTimer *_burstTimer;
    NSInteger _burstIndex;
    NSInteger _burstTarget;

    NSInteger _lastMs;
    NSTimeInterval _lastStateUpdate;
    BOOL _stateUpdateScheduled;
    NSTimeInterval _measureStart;
    CADisplayLink *_measureLink;
}

- (void)dealloc {
    free(_frames);
    [_feedHandle cancel];
    [_burstTimer invalidate];
    [_measureLink invalidate];
}

#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CFTheme.background;
    _rows = [NSMutableArray array];
    _pendingAppends = [NSMutableArray array];
    _pendingChanged = [NSMutableSet set];
    _lastMs = -1;

    _visibleViews = [NSMutableDictionary dictionary];
    _reusableCells = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    _list = [[CFRoomScrollView alloc] initWithFrame:self.view.bounds];
    _list.backgroundColor = CFTheme.background;
    _list.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _list.delegate = self;
    _list.alwaysBounceVertical = YES;
    _list.accessibilityIdentifier = @"room";
    _list.tile = ^{ [weakSelf tileRows]; };
    [self.view addSubview:_list];

    _fade = [[UIView alloc] init];
    _fade.userInteractionEnabled = NO;
    _fadeGradient = [CAGradientLayer layer];
    [_fade.layer addSublayer:_fadeGradient];
    [self.view addSubview:_fade];
    _statusCover = [[UIView alloc] init];
    _statusCover.backgroundColor = CFTheme.background;
    _statusCover.userInteractionEnabled = NO;
    [self.view addSubview:_statusCover];

    _header = [[CFHeaderView alloc] init];
    [self.view addSubview:_header];
    _composer = [[CFComposerView alloc] init];
    [self.view addSubview:_composer];

    _jumpToBottom = [[CFCircleButton alloc] initWithImage:[CFIcons symbol:@"arrow.down" size:CGSizeMake(16, 18) weight:UIImageSymbolWeightBold] diameter:42];
    _jumpToBottom.accessibilityLabel = @"Jump to bottom";
    _jumpToBottom.accessibilityIdentifier = @"jumpToBottom";
    _jumpToBottom.hidden = YES;
    [_jumpToBottom addTarget:self action:@selector(jumpToBottomTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_jumpToBottom];

    if ([NSUserDefaults.standardUserDefaults boolForKey:@"uvsBenchmark"]) {
        _debugBar = [[CFDebugBar alloc] init];
        [_debugBar.resetButton addTarget:self action:@selector(resetTapped:event:) forControlEvents:UIControlEventTouchUpInside];
        [_debugBar.jumpButton addTarget:self action:@selector(jumpTapped:event:) forControlEvents:UIControlEventTouchUpInside];
        [_debugBar.loadOlderButton addTarget:self action:@selector(loadOlderTapped:event:) forControlEvents:UIControlEventTouchUpInside];
        [_debugBar.streamButton addTarget:self action:@selector(streamTapped:event:) forControlEvents:UIControlEventTouchUpInside];
        [_debugBar.textSizeButton addTarget:self action:@selector(textSizeTapped:event:) forControlEvents:UIControlEventTouchUpInside];
        [_debugBar.boostBurstButton addTarget:self action:@selector(boostBurstTapped:event:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_debugBar];
    }

    [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class] withHandler:^(id<UITraitEnvironment> env, UITraitCollection *previous) {
        [weakSelf textSizeDidChange];
    }];
    [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withHandler:^(id<UITraitEnvironment> env, UITraitCollection *previous) {
        [weakSelf updateFadeColors];
    }];

    _store = CFLaunchStore();
    _metrics = [CFMetrics metricsForTraitCollection:self.traitCollection];
    NSInteger devStart = [NSUserDefaults.standardUserDefaults integerForKey:@"uvsDevStartID"];
    if (devStart > 0) {
        [_rows addObjectsFromArray:[_store itemsFrom:devStart to:devStart + CFKDataset.pageSize - 1]];
    } else {
        [_rows addObjectsFromArray:CFLaunchInitialItems()];
    }
    _showsWelcome = _rows.firstObject.itemID == _store.firstID;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGRect b = self.view.bounds;
    CGFloat W = b.size.width;

    CGFloat bottom = b.size.height - kComposerBottom;
    if (_debugBar) {
        CGFloat h = [CFDebugBar heightForWidth:W];
        _debugBar.frame = CGRectMake(0, b.size.height - safe.bottom - h, W, h + safe.bottom);
        bottom = CGRectGetMinY(_debugBar.frame) - 8;
    }
    CGFloat composerH = [CFComposerView height];
    _composer.frame = CGRectMake(safe.left, bottom - composerH, W - safe.left - safe.right, composerH);
    CGFloat headerTop = safe.top;
    CGFloat headerH = [CFHeaderView height];
    _header.frame = CGRectMake(safe.left, headerTop, W - safe.left - safe.right, headerH);
    _statusCover.frame = CGRectMake(0, 0, W, headerTop);
    _fade.frame = CGRectMake(0, headerTop, W, kFadeEnd);
    _fadeGradient.frame = _fade.bounds;
    _fadeGradient.locations = @[@(kFadeStart / kFadeEnd), @1];
    [self updateFadeColors];

    CGFloat listBottom = CGRectGetMinY(_composer.frame) - kListBottomGap;
    CGRect listFrame = CGRectMake(0, 0, W, listBottom);
    UIEdgeInsets inset = UIEdgeInsetsMake(headerTop + headerH, 0, 0, 0);
    _jumpToBottom.frame = CGRectMake(W - safe.right - 14 - 42, listBottom - 42 - 8, 42, 42);

    BOOL geometryChanged = !CGRectEqualToRect(listFrame, _list.frame) || !UIEdgeInsetsEqualToEdgeInsets(inset, _list.contentInset);
    CGFloat newRowWidth = W - safe.left - safe.right;
    BOOL widthChanged = newRowWidth != _rowWidth || safe.left != _rowX;

    if (!_didInitialLoad) {
        _list.frame = listFrame;
        _list.contentInset = inset;
        _list.verticalScrollIndicatorInsets = inset;
        [self rebuildFrames];
        [self scrollToBottom];
        [self tileRows];
        _didInitialLoad = YES;
        CFLaunchRememberGeometry(_rowWidth, _metrics.category, self.traitCollection.displayScale);
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf prefetchOlderPage];
        });
        NSInteger devStart = [NSUserDefaults.standardUserDefaults integerForKey:@"uvsDevStartID"];
        [self recordAnchor];
        [self updateState];
        [self beginMeasuringFrom:CFLaunchStart];
        if ([NSUserDefaults.standardUserDefaults boolForKey:@"uvsDevStream"]) { [self startStream]; }
        if ([NSUserDefaults.standardUserDefaults boolForKey:@"uvsDevBurst"]) { [self boostBurstTapped:nil event:nil]; }
        NSInteger devSteps = [NSUserDefaults.standardUserDefaults integerForKey:@"uvsDevTextSteps"];
        for (NSInteger k = 0; k < devSteps; k++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((k + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self textSizeTapped:nil event:nil];
            });
        }
        NSInteger devJump = [NSUserDefaults.standardUserDefaults integerForKey:@"uvsDevTopID"];
        if (devStart > 0) {
            [self setOffsetY:-_list.contentInset.top];
            [self recordAnchor];
            [self updateState];
        } else if (devJump > 0) {
            NSInteger row = [self rowIndexOfItemID:devJump];
            if (row != NSNotFound) {
                [self setOffsetY:_frames[row].origin.y - _list.contentInset.top - [NSUserDefaults.standardUserDefaults doubleForKey:@"uvsDevOffset"]];
                [self recordAnchor];
                [self updateState];
            }
        }
        return;
    }
    if (!geometryChanged && !widthChanged) { return; }

    CFAnchor anchor = _lastAnchor;
    BOOL pinned = _lastPinned;
    _updating = YES;
    _list.frame = listFrame;
    _list.contentInset = inset;
    _list.verticalScrollIndicatorInsets = inset;
    if (widthChanged) {
        [self relayoutAllRowsPinned:pinned anchor:anchor];
    } else {
        [self restorePinned:pinned anchor:anchor];
        [self tileRows];
    }
    _updating = NO;
    [self recordAnchorPreferring:anchor];
    [self updateState];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self recordAnchor];
    _freezeAnchor = YES;
    CFAnchor anchor = _lastAnchor;
    BOOL pinned = _lastPinned;
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        strongSelf->_freezeAnchor = NO;
        [strongSelf.view layoutIfNeeded];
        strongSelf->_updating = YES;
        [strongSelf restorePinned:pinned anchor:anchor];
        strongSelf->_updating = NO;
        [strongSelf recordAnchorPreferring:anchor];
        [strongSelf updateState];
    }];
}

- (void)updateFadeColors {
    UIColor *bg = [CFTheme.background resolvedColorWithTraitCollection:self.traitCollection];
    _fadeGradient.colors = @[(id)bg.CGColor, (id)[bg colorWithAlphaComponent:0].CGColor];
}

#pragma mark Frames

- (CFRowLayout *)rowLayoutForItem:(CFMessageItem *)item {
    CFRowLayout *L = item.layout;
    if (L && L.width == _rowWidth && L.scale == _metrics.scale && L.revision == item.revision) { return L; }
    L = [CFRowLayout layoutForItem:item store:_store width:_rowWidth metrics:_metrics];
    item.layout = L;
    return L;
}

/// Lays out, in parallel, every item whose cached layout is missing or stale (row layout is thread-safe:
/// each thread measures with its own layout manager). Stragglers are left to -rowLayoutForItem:.
- (void)prepareLayoutsForItems:(NSArray<CFMessageItem *> *)items {
    CGFloat width = _rowWidth;
    CFMetrics *m = _metrics;
    CFRoomStore *store = _store;
    NSMutableArray<CFMessageItem *> *todo = [NSMutableArray array];
    for (CFMessageItem *item in items) {
        CFRowLayout *L = item.layout;
        if (!L || L.width != width || L.scale != m.scale || L.revision != item.revision) { [todo addObject:item]; }
    }
    if (todo.count < 4) { return; }
    dispatch_apply(todo.count, DISPATCH_APPLY_AUTO, ^(size_t i) {
        CFMessageItem *item = todo[i];
        item.layout = [CFRowLayout layoutForItem:item store:store width:width metrics:m];
    });
}

/// Lays out every loaded row top to bottom, Campfire style: 21.28 between rows, threaded rows overlap by 1.2.
- (void)rebuildFrames {
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat W = self.view.bounds.size.width;
    _rowWidth = W - safe.left - safe.right;
    _rowX = safe.left;
    [self prepareLayoutsForItems:_rows];
    NSInteger count = (NSInteger)_rows.count + (_showsWelcome ? 1 : 0);
    if (count > _frameCapacity) {
        _frameCapacity = MAX(count * 2, 128);
        _frames = realloc(_frames, sizeof(CGRect) * (size_t)_frameCapacity);
    }
    _frameCount = count;
    CGFloat y = 0;
    NSInteger i = 0;
    if (_showsWelcome) {
        CGFloat h = [CFWelcomeCell heightForWidth:_rowWidth metrics:_metrics];
        _frames[i++] = CGRectMake(_rowX, 0, _rowWidth, h);
        y = h;
    }
    for (NSUInteger r = 0; r < _rows.count; r++) {
        CFRowLayout *L = [self rowLayoutForItem:_rows[r]];
        if (i > 0) { y += L.spacingBefore; }
        _frames[i++] = CGRectMake(_rowX, y, _rowWidth, L.height);
        y += L.height;
    }
    y += kContentBottomPad;
    // Short rooms sit at the bottom, like a chat.
    UIEdgeInsets inset = _list.contentInset;
    CGFloat visible = _list.bounds.size.height - inset.top - inset.bottom;
    _bottomShift = 0;
    if (y < visible) {
        CGFloat shift = visible - y;
        for (NSInteger k = 0; k < _frameCount; k++) { _frames[k].origin.y += shift; }
        y = visible;
        _bottomShift = shift;
    }
    _contentSize = CGSizeMake(W, y);
    _list.contentSize = _contentSize;
}

- (void)ensureFrameCapacity:(NSInteger)count {
    if (count > _frameCapacity) {
        _frameCapacity = MAX(count * 2, 128);
        _frames = realloc(_frames, sizeof(CGRect) * (size_t)_frameCapacity);
    }
}

- (BOOL)contentFillsView {
    UIEdgeInsets inset = _list.contentInset;
    return _contentSize.height > _list.bounds.size.height - inset.top - inset.bottom;
}

/// Rows were added at the end of `_rows`: lays out only those, so a new message costs the same however many are loaded.
- (void)appendFrames {
    NSInteger count = (NSInteger)_rows.count + (_showsWelcome ? 1 : 0);
    if (_bottomShift > 0 || _frameCount == 0 || count < _frameCount) { [self rebuildFrames]; return; }
    [self ensureFrameCapacity:count];
    NSInteger offset = _showsWelcome ? 1 : 0;
    [self prepareLayoutsForItems:[_rows subarrayWithRange:NSMakeRange((NSUInteger)(_frameCount - offset), (NSUInteger)(count - _frameCount))]];
    CGFloat y = CGRectGetMaxY(_frames[_frameCount - 1]);
    for (NSInteger i = _frameCount; i < count; i++) {
        CFRowLayout *L = [self rowLayoutForItem:_rows[(NSUInteger)(i - offset)]];
        y += L.spacingBefore;
        _frames[i] = CGRectMake(_rowX, y, _rowWidth, L.height);
        y += L.height;
    }
    _frameCount = count;
    _contentSize.height = y + kContentBottomPad;
    if (![self contentFillsView]) { [self rebuildFrames]; }
    _list.contentSize = _contentSize;
}

/// `added` rows were inserted at the front of `_rows` (the welcome card unchanged): lays out only those and
/// moves the rest down by the height they take.
- (void)prependFrames:(NSInteger)added {
    NSInteger count = (NSInteger)_rows.count + (_showsWelcome ? 1 : 0);
    if (_bottomShift > 0 || _showsWelcome || _frameCount == 0 || count != _frameCount + added) { [self rebuildFrames]; return; }
    [self ensureFrameCapacity:count];
    memmove(_frames + added, _frames, sizeof(CGRect) * (size_t)_frameCount);
    [self prepareLayoutsForItems:[_rows subarrayWithRange:NSMakeRange(0, (NSUInteger)added)]];
    CGFloat y = 0;
    for (NSInteger i = 0; i < added; i++) {
        CFRowLayout *L = [self rowLayoutForItem:_rows[(NSUInteger)i]];
        if (i > 0) { y += L.spacingBefore; }
        _frames[i] = CGRectMake(_rowX, y, _rowWidth, L.height);
        y += L.height;
    }
    y += [self rowLayoutForItem:_rows[(NSUInteger)added]].spacingBefore;
    CGFloat delta = y - _frames[added].origin.y;
    for (NSInteger i = added; i < count; i++) { _frames[i].origin.y += delta; }
    _frameCount = count;
    _contentSize.height += delta;
    _list.contentSize = _contentSize;
}

/// One row changed height (new boosts): resizes it and moves the rows below.
- (void)updateFrameForRow:(NSInteger)row {
    if (row < 0 || row >= _frameCount) { return; }
    if (_bottomShift > 0) { [self rebuildFrames]; return; }
    CFRowLayout *L = [self rowLayoutForItem:_rows[(NSUInteger)(row - (_showsWelcome ? 1 : 0))]];
    CGFloat delta = L.height - _frames[row].size.height;
    if (delta == 0) { return; }
    _frames[row].size.height = L.height;
    for (NSInteger i = row + 1; i < _frameCount; i++) { _frames[i].origin.y += delta; }
    _contentSize.height += delta;
    if (![self contentFillsView]) { [self rebuildFrames]; }
    _list.contentSize = _contentSize;
}


- (NSInteger)rowIndexForItemIndex:(NSInteger)index { return index + (_showsWelcome ? 1 : 0); }

- (NSInteger)rowIndexOfItemID:(NSInteger)itemID {
    if (_rows.count == 0) { return NSNotFound; }
    NSInteger first = _rows.firstObject.itemID;
    NSInteger k = itemID - first;
    if (k < 0 || k >= (NSInteger)_rows.count || _rows[(NSUInteger)k].itemID != itemID) { return NSNotFound; }
    return [self rowIndexForItemIndex:k];
}

#pragma mark Position

- (CGFloat)visibleTop { return _list.contentOffset.y + _list.contentInset.top; }

- (CGFloat)maxOffsetY {
    return MAX(_contentSize.height + _list.contentInset.bottom - _list.bounds.size.height,
               -_list.contentInset.top);
}

/// True when the loaded rows (plus live messages queued to be appended) end at the newest message.
- (BOOL)isNewestLoaded {
    return _rows.count == 0 || _rows.lastObject.itemID + (NSInteger)_pendingAppends.count >= _store.newestID;
}

- (BOOL)isPinned {
    if (_frameCount == 0) { return YES; }
    if (!self.isNewestLoaded) { return NO; }
    CGFloat lastBottom = CGRectGetMaxY(_frames[_frameCount - 1]);
    CGFloat visibleBottom = _list.contentOffset.y + _list.bounds.size.height - _list.contentInset.bottom;
    return lastBottom - visibleBottom <= kPinDistance;
}

/// The topmost message row at least partly visible below the header.
- (NSInteger)topRowIndex {
    CGFloat top = [self visibleTop];
    NSInteger start = _showsWelcome ? 1 : 0;
    NSInteger lo = start, hi = _frameCount;
    while (lo < hi) {
        NSInteger mid = (lo + hi) / 2;
        // A row's last 1.6 pt is its empty bottom margin, which the next (threaded) row overlaps.
        // Sub-pixel slivers (offsets snap to device pixels) do not count as visible.
        if (CGRectGetMaxY(_frames[mid]) - kRowBottomMargin <= top + 0.5) { lo = mid + 1; } else { hi = mid; }
    }
    return lo < _frameCount ? lo : NSNotFound;
}

- (CFAnchor)currentAnchor {
    CFAnchor a = {0, 0, NO};
    NSInteger row = [self topRowIndex];
    if (row == NSNotFound) { return a; }
    CFMessageItem *item = _rows[(NSUInteger)(row - (_showsWelcome ? 1 : 0))];
    a.itemID = item.itemID;
    a.offset = _frames[row].origin.y - [self visibleTop];
    a.valid = YES;
    return a;
}

- (void)recordAnchor {
    if (_freezeAnchor || !_didInitialLoad) { return; }
    _lastAnchor = [self currentAnchor];
    _lastPinned = [self isPinned];
}

/// After a programmatic restore, remember the intended anchor rather than the pixel-snapped result,
/// so repeated relayouts (text size steps, rotations) do not drift.
- (void)recordAnchorPreferring:(CFAnchor)intended {
    [self recordAnchor];
    if (_freezeAnchor || !intended.valid || _lastPinned) { return; }
    if (_lastAnchor.valid && _lastAnchor.itemID == intended.itemID && fabs(_lastAnchor.offset - intended.offset) < 1) {
        _lastAnchor = intended;
    }
}

- (void)setOffsetY:(CGFloat)y {
    _list.contentOffset = CGPointMake(0, y);
}

- (void)scrollToBottom {
    [self setOffsetY:[self maxOffsetY]];
}

- (void)restoreAnchor:(CFAnchor)a {
    if (!a.valid) { return; }
    NSInteger row = [self rowIndexOfItemID:a.itemID];
    if (row == NSNotFound) { return; }
    CGFloat y = _frames[row].origin.y - a.offset - _list.contentInset.top;
    [self setOffsetY:y];
}

- (void)restorePinned:(BOOL)pinned anchor:(CFAnchor)anchor {
    if (pinned && self.isNewestLoaded) { [self scrollToBottom]; } else { [self restoreAnchor:anchor]; }
}

/// Re-lays out every row (new width or text size) and puts the room back where it was.
- (void)relayoutAllRowsPinned:(BOOL)pinned anchor:(CFAnchor)anchor {
    _updating = YES;
    [self rebuildFrames];
    [self restorePinned:pinned anchor:anchor];
    [self tileRows];
    _updating = NO;
}

/// Runs a change to the rows, then puts the room back: pinned stays at the bottom, otherwise the top row stays put.
- (void)performKeepingPosition:(void (^)(void))change {
    [self performKeepingPosition:change throttleState:NO];
}

- (void)performKeepingPosition:(void (^)(void))change throttleState:(BOOL)throttle {
    BOOL pinned = [self isPinned];
    CFAnchor anchor = [self currentAnchor];
    if (_lastAnchor.valid && anchor.valid && _lastAnchor.itemID == anchor.itemID && fabs(_lastAnchor.offset - anchor.offset) < 1) {
        anchor = _lastAnchor;
    }
    _updating = YES;
    change();
    [self restorePinned:pinned anchor:anchor];
    [self tileRows];
    _updating = NO;
    [self recordAnchorPreferring:anchor];
    if (throttle) { [self setNeedsStateUpdate]; } else { [self updateState]; }
}

#pragma mark Row views

- (NSInteger)firstRowIntersectingY:(CGFloat)y {
    NSInteger lo = 0, hi = _frameCount;
    while (lo < hi) {
        NSInteger mid = (lo + hi) / 2;
        if (CGRectGetMaxY(_frames[mid]) <= y) { lo = mid + 1; } else { hi = mid; }
    }
    return lo;
}

/// Puts a view on every row in the visible area (configured only when its layout changed); views of rows that
/// left it are hidden and reused. Costs the same however many rows are loaded.
- (void)tileRows {
    if (!_didInitialLoad && _frameCount == 0) { return; }
    CGRect visible = _list.bounds;
    NSMutableDictionary<NSNumber *, UIView *> *shown = [NSMutableDictionary dictionaryWithCapacity:_visibleViews.count + 2];
    NSInteger offset = _showsWelcome ? 1 : 0;
    for (NSInteger i = [self firstRowIntersectingY:CGRectGetMinY(visible)]; i < _frameCount; i++) {
        CGRect f = _frames[i];
        if (CGRectGetMinY(f) >= CGRectGetMaxY(visible)) { break; }
        UIView *view;
        if (_showsWelcome && i == 0) {
            if (!_welcomeCell) {
                _welcomeCell = [[CFWelcomeCell alloc] initWithFrame:f];
                [_list addSubview:_welcomeCell];
            }
            if (_welcomeCell.metrics != _metrics) { [_welcomeCell configureWithMetrics:_metrics]; }
            [_visibleViews removeObjectForKey:@0];
            shown[@0] = _welcomeCell;
            view = _welcomeCell;
        } else {
            CFMessageItem *item = _rows[(NSUInteger)(i - offset)];
            NSNumber *key = @(item.itemID);
            CFMessageCell *cell = (CFMessageCell *)_visibleViews[key];
            if (cell) {
                [_visibleViews removeObjectForKey:key];
            } else {
                cell = _reusableCells.lastObject;
                if (cell) {
                    [_reusableCells removeLastObject];
                } else {
                    cell = [[CFMessageCell alloc] initWithFrame:f];
                    [_list addSubview:cell];
                }
            }
            CFRowLayout *L = [self rowLayoutForItem:item];
            if (cell.layout != L) { [cell configureWithLayout:L item:item store:_store]; }
            shown[key] = cell;
            view = cell;
        }
        if (!CGRectEqualToRect(view.frame, f)) { view.frame = f; }
        view.hidden = NO;
    }
    for (UIView *view in _visibleViews.objectEnumerator) {
        view.hidden = YES;
        if ([view isKindOfClass:[CFMessageCell class]]) { [_reusableCells addObject:(CFMessageCell *)view]; }
    }
    _visibleViews = shown;
}

#pragma mark Scrolling

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_updating || !_didInitialLoad) { return; }
    [self recordAnchor];
    [self updateState];
    [self loadMoreIfNeeded];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { [self updateState]; }
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate { if (!decelerate) { [self updateState]; } }

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView { [self loadMoreIfNeeded]; }

- (void)loadMoreIfNeeded {
    if (_loadScheduled || _frameCount == 0) { return; }
    BOOL nearTop = [self visibleTop] - _frames[0].origin.y < kLoadMoreDistance && _rows.firstObject.itemID > _store.firstID;
    CGFloat visibleBottom = _list.contentOffset.y + _list.bounds.size.height;
    BOOL nearBottom = _contentSize.height - visibleBottom < kLoadMoreDistance && !self.isNewestLoaded;
    if (!nearTop && !nearBottom) { return; }
    _loadScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        strongSelf->_loadScheduled = NO;
        if (nearTop) { [strongSelf loadOlder]; }
        if (nearBottom) { [strongSelf loadNewer]; }
    });
}

/// Wraps and lays out the page above the first loaded row on a background queue, so reaching the top (or
/// "Load older") only has to insert rows that are ready.
- (void)prefetchOlderPage {
    NSInteger first = _rows.firstObject.itemID;
    if (_prefetching || _rows.count == 0 || first <= _store.firstID || first > _store.dataset.lastMessageID) { return; }
    if ([_store hasItemsFrom:first - CFKDataset.pageSize to:first - 1]) { return; }
    _prefetching = YES;
    CFRoomStore *store = _store;
    CFMetrics *m = _metrics;
    CGFloat width = _rowWidth;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray<CFMessageItem *> *items = [store detachedItemsBefore:first];
        dispatch_apply(items.count, DISPATCH_APPLY_AUTO, ^(size_t i) {
            items[i].layout = [CFRowLayout layoutForItem:items[i] store:store width:width metrics:m];
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            [store adoptItems:items];
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) { strongSelf->_prefetching = NO; }
        });
    });
}

- (void)loadOlder {
    if (_rows.count == 0 || _rows.firstObject.itemID <= _store.firstID) { return; }
    NSInteger first = _rows.firstObject.itemID;
    NSArray<CFMessageItem *> *older = [_store itemsFrom:first - CFKDataset.pageSize to:first - 1];
    if (older.count == 0) { return; }
    [self performKeepingPosition:^{
        BOOL hadWelcome = self->_showsWelcome;
        [self->_rows insertObjects:older atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, older.count)]];
        self->_showsWelcome = self->_rows.firstObject.itemID == self->_store.firstID;
        if (self->_showsWelcome != hadWelcome) { [self rebuildFrames]; } else { [self prependFrames:(NSInteger)older.count]; }
    }];
    [self prefetchOlderPage];
}

- (void)loadNewer {
    if (self.isNewestLoaded) { return; }
    NSInteger last = _rows.lastObject.itemID;
    NSArray<CFMessageItem *> *newer = [_store itemsFrom:last + 1 to:last + CFKDataset.pageSize];
    [self appendItems:newer];
}

- (void)appendItems:(NSArray<CFMessageItem *> *)items {
    if (items.count == 0) { return; }
    [self performKeepingPosition:^{
        [self->_rows addObjectsFromArray:items];
        [self appendFrames];
    }];
}

/// Replaces every loaded row (reset, jump), then positions the room with `position` and places the row views.
- (void)replaceRows:(NSArray<CFMessageItem *> *)rows position:(void (^)(void))position {
    _updating = YES;
    [_rows setArray:rows];
    _showsWelcome = _rows.firstObject.itemID == _store.firstID;
    [self rebuildFrames];
    position();
    [self tileRows];
    _updating = NO;
    [self prefetchOlderPage];
}

- (void)jumpToBottomTapped {
    if (self.isNewestLoaded) {
        _updating = YES;
        [self scrollToBottom];
        [self tileRows];
        _updating = NO;
    } else {
        [self replaceRows:[_store newestItems:CFKDataset.pageSize] position:^{ [self scrollToBottom]; }];
    }
    [self recordAnchor];
    [self updateState];
}

#pragma mark Text size

- (void)textSizeDidChange {
    CFMetrics *m = [CFMetrics metricsForTraitCollection:self.traitCollection];
    if (m == _metrics || !_didInitialLoad) { _metrics = m; return; }
    CFAnchor anchor = _lastAnchor;
    BOOL pinned = _lastPinned;
    _metrics = m;
    [self relayoutAllRowsPinned:pinned anchor:anchor];
    [self recordAnchorPreferring:anchor];
    [self updateState];
}

#pragma mark Live stream

- (void)startStream {
    if (_streaming) { return; }
    _streaming = YES;
    _debugBar.streamDoneLabel.hidden = YES;
    [_store beginLiveSession];
    _feed = [[CFKLiveFeed alloc] initWithDataset:_store.dataset];
    __weak typeof(self) weakSelf = self;
    _feedHandle = [_feed startOnEvent:^(CFKFeedEvent *event) {
        [weakSelf handleFeedEvent:event];
    } completion:^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [strongSelf flushPending];
        strongSelf->_streaming = NO;
        strongSelf->_debugBar.streamDoneLabel.hidden = NO;
        [strongSelf updateState];
    }];
}

- (void)handleFeedEvent:(CFKFeedEvent *)event {
    switch (event.kind) {
        case CFKFeedEventKindMessage: {
            if (!event.message) { return; }
            // Follow the stream only while the loaded rows end at the newest message.
            BOOL follow = _pendingAppends.count > 0 || self.isNewestLoaded;
            CFMessageItem *item = [_store appendLiveMessage:event.message];
            if (follow) { [_pendingAppends addObject:item]; }
            break;
        }
        case CFKFeedEventKindBoost: {
            if (!event.boost) { return; }
            NSInteger target = [_store roomIDForFeedMessageID:event.messageID];
            [self addBoost:[[CFBoostItem alloc] initWithBoosterID:event.boost.boosterID content:event.boost.content] toItemID:target];
            return;
        }
        default:
            return;
    }
    [self scheduleFlush];
}

- (void)addBoost:(CFBoostItem *)boost toItemID:(NSInteger)itemID {
    CFMessageItem *item = [_store addBoost:boost toItemID:itemID];
    if (item && [self rowIndexOfItemID:itemID] != NSNotFound) {
        [_pendingChanged addObject:@(itemID)];
        [self scheduleFlush];
    }
}

- (void)scheduleFlush {
    if (_flushScheduled) { return; }
    _flushScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf flushPending]; });
}

/// Applies queued live changes in one pass: new rows at the bottom and rows that gained boosts.
- (void)flushPending {
    _flushScheduled = NO;
    if (_pendingAppends.count == 0 && _pendingChanged.count == 0) { return; }
    [self performKeepingPosition:^{
        NSArray<CFMessageItem *> *appends = [self->_pendingAppends copy];
        NSSet<NSNumber *> *changed = [self->_pendingChanged copy];
        [self->_pendingAppends removeAllObjects];
        [self->_pendingChanged removeAllObjects];
        // Only append when the rows still end at the message before these (no gap after a jump).
        BOOL contiguous = appends.count > 0 && self->_rows.lastObject.itemID + 1 == appends.firstObject.itemID;
        if (contiguous) {
            [self->_rows addObjectsFromArray:appends];
            [self appendFrames];
        }
        // Rows that gained boosts get a new layout; tiling re-configures their views.
        for (NSNumber *n in changed) {
            [self updateFrameForRow:[self rowIndexOfItemID:n.integerValue]];
        }
    } throttleState:YES];
}

#pragma mark Debug bar actions

- (NSTimeInterval)touchUpTimeForEvent:(UIEvent *)event {
    UITouch *touch = event.allTouches.anyObject;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (touch && touch.timestamp > 0 && touch.timestamp <= now) { return touch.timestamp; }
    return now;
}

- (void)resetTapped:(UIButton *)sender event:(UIEvent *)event {
    NSTimeInterval start = [self touchUpTimeForEvent:event];
    [_burstTimer invalidate];
    _burstTimer = nil;
    [self flushPending];
    [self.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self updateTraitsIfNeeded];
    _metrics = [CFMetrics metricsForTraitCollection:self.traitCollection];
    [self replaceRows:[_store newestItems:CFKDataset.pageSize] position:^{ [self scrollToBottom]; }];
    [self recordAnchor];
    [self updateState];
    [self beginMeasuringFrom:start];
}

- (void)jumpTapped:(UIButton *)sender event:(UIEvent *)event {
    NSTimeInterval start = [self touchUpTimeForEvent:event];
    NSInteger target = 2500;
    [self flushPending];
    // One page around the target: a few rows above it, the rest below to fill the room. Scrolling loads more
    // either way, so the jump only lays out what it shows.
    NSInteger above = kJumpRowsAbove;
    [self replaceRows:[_store itemsFrom:target - above to:target - above + CFKDataset.pageSize - 1] position:^{
        NSInteger row = [self rowIndexOfItemID:target];
        if (row != NSNotFound) { [self setOffsetY:self->_frames[row].origin.y - self->_list.contentInset.top]; }
    }];
    CFAnchor intended = {target, 0, YES};
    [self recordAnchorPreferring:intended];
    [self updateState];
    [self beginMeasuringFrom:start];
}

- (void)loadOlderTapped:(UIButton *)sender event:(UIEvent *)event {
    NSTimeInterval start = [self touchUpTimeForEvent:event];
    [self loadOlder];
    [self updateState];
    [self beginMeasuringFrom:start];
}

- (void)streamTapped:(UIButton *)sender event:(UIEvent *)event {
    [self startStream];
}

- (void)textSizeTapped:(UIButton *)sender event:(UIEvent *)event {
    NSTimeInterval start = [self touchUpTimeForEvent:event];
    NSArray<UIContentSizeCategory> *steps = @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium,
                                              UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge,
                                              UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium,
                                              UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
                                              UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    NSUInteger index = [steps indexOfObject:_metrics.category];
    if (index == NSNotFound || index + 1 >= steps.count) {
        [self.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    } else {
        self.traitOverrides.preferredContentSizeCategory = steps[index + 1];
    }
    [self updateTraitsIfNeeded];
    [self textSizeDidChange];
    [self beginMeasuringFrom:start];
}

- (void)boostBurstTapped:(UIButton *)sender event:(UIEvent *)event {
    [_burstTimer invalidate];
    _burstIndex = 0;
    _burstTarget = _store.newestID;
    __weak typeof(self) weakSelf = self;
    _burstTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
        [weakSelf burstTick];
    }];
}

- (void)burstTick {
    NSArray<NSString *> *emoji = @[@"👍", @"🎉", @"🔥", @"❤️", @"😂"];
    if (_burstIndex >= (NSInteger)emoji.count) {
        [_burstTimer invalidate];
        _burstTimer = nil;
        return;
    }
    CFBoostItem *boost = [[CFBoostItem alloc] initWithBoosterID:2 + _burstIndex content:emoji[(NSUInteger)_burstIndex]];
    _burstIndex += 1;
    [self addBoost:boost toItemID:_burstTarget];
    [self flushPending];
    if (_burstIndex >= (NSInteger)emoji.count) {
        [_burstTimer invalidate];
        _burstTimer = nil;
    }
}

#pragma mark State label

/// Waits for the frame that shows the result, then records the time since the tap (or since launch).
- (void)beginMeasuringFrom:(NSTimeInterval)start {
    _measureStart = start;
    [_measureLink invalidate];
    _measureLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(measureFrame:)];
    [_measureLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)measureFrame:(CADisplayLink *)link {
    [link invalidate];
    if (link == _measureLink) { _measureLink = nil; }
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    _lastMs = (NSInteger)floor(MAX(0, now - _measureStart) * 1000);
    [self updateState];
}

/// Live changes arrive up to 20 times a second: the label follows them at most every 100 ms (and always
/// catches up with the last one), so the stream does not spend its time re-rendering the label.
- (void)setNeedsStateUpdate {
    NSTimeInterval wait = 0.1 - (CACurrentMediaTime() - _lastStateUpdate);
    if (wait <= 0) { [self updateState]; return; }
    if (_stateUpdateScheduled) { return; }
    _stateUpdateScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_stateUpdateScheduled) { [strongSelf updateState]; }
    });
}

- (void)updateState {
    _stateUpdateScheduled = NO;
    _lastStateUpdate = CACurrentMediaTime();
    BOOL pinned = [self isPinned];
    _jumpToBottom.hidden = pinned || _frameCount == 0;
    if (!_debugBar) { return; }
    NSInteger topID = 0;
    CGFloat y = 0;
    NSInteger row = [self topRowIndex];
    if (row != NSNotFound) {
        topID = _rows[(NSUInteger)(row - (_showsWelcome ? 1 : 0))].itemID;
        y = round((_frames[row].origin.y - [self visibleTop]) * 10) / 10;
        if (y == 0) { y = 0; }
    }
    NSString *text = [NSString stringWithFormat:@"first %ld last %ld loaded %lu pinned %@ top %ld y %.1f ms %ld",
                      (long)_rows.firstObject.itemID, (long)_rows.lastObject.itemID, (unsigned long)_rows.count,
                      pinned ? @"yes" : @"no", (long)topID, y, (long)MAX(_lastMs, 0)];
    if (![_debugBar.stateLabel.text isEqualToString:text]) {
        _debugBar.stateLabel.text = text;  // its accessibility label is its text
    }
}

@end
