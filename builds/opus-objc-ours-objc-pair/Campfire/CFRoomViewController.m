#import "CFRoomViewController.h"
#import "CFRoomStore.h"
#import "CFRowLayout.h"
#import "CFMessageCell.h"
#import "CFChrome.h"
#import "CFDebugBar.h"
#import "CFLaunch.h"
#import "CFIcons.h"

static NSString *const kMessageCell = @"message";
static NSString *const kWelcomeCell = @"welcome";
static const CGFloat kPinDistance = 100;      // "within 100 pt of the bottom" stays pinned
static const CGFloat kLoadMoreDistance = 400;  // start loading a page this far from the end
static const CGFloat kListBottomGap = 24;      // list ends this far above the composer
static const CGFloat kComposerBottom = 24;
static const CGFloat kContentBottomPad = 0.8;
static const CGFloat kRowBottomMargin = 1.6;
static const CGFloat kFadeStart = 11.67;       // header fade: content hidden above, fully shown below 57.67
static const CGFloat kFadeEnd = 57.67;

/// A row to keep in place: its id and its top relative to the bottom edge of the header.
typedef struct {
    NSInteger itemID;
    CGFloat offset;
    BOOL valid;
} CFAnchor;

#pragma mark - Layout

@protocol CFRoomLayoutSource <NSObject>
- (NSInteger)layoutRowCount;
- (CGRect)layoutFrameForRow:(NSInteger)row;
- (CGSize)layoutContentSize;
@end

@interface CFRoomLayout : UICollectionViewLayout
@property (nonatomic, weak) id<CFRoomLayoutSource> source;
@end

@implementation CFRoomLayout {
    NSInteger _count;
    CGSize _contentSize;
}

- (void)prepareLayout {
    [super prepareLayout];
    _count = [self.source layoutRowCount];
    _contentSize = [self.source layoutContentSize];
}

- (CGSize)collectionViewContentSize { return _contentSize; }

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray *out = [NSMutableArray array];
    // Rows are sorted by y: binary search for the first row that reaches the rect, then walk.
    NSInteger lo = 0, hi = _count;
    while (lo < hi) {
        NSInteger mid = (lo + hi) / 2;
        if (CGRectGetMaxY([self.source layoutFrameForRow:mid]) < CGRectGetMinY(rect)) { lo = mid + 1; } else { hi = mid; }
    }
    for (NSInteger i = MAX(0, lo - 1); i < _count; i++) {
        CGRect f = [self.source layoutFrameForRow:i];
        if (CGRectGetMinY(f) > CGRectGetMaxY(rect)) { break; }
        if (CGRectIntersectsRect(f, rect)) {
            [out addObject:[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]]];
        }
    }
    return out;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= _count) { return nil; }
    UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    a.frame = [self.source layoutFrameForRow:indexPath.item];
    return a;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return newBounds.size.width != self.collectionView.bounds.size.width;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self layoutAttributesForItemAtIndexPath:indexPath];
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

@end

#pragma mark - View controller

@interface CFRoomViewController () <UICollectionViewDataSource, UICollectionViewDelegate, CFRoomLayoutSource>
@end

@implementation CFRoomViewController {
    CFRoomStore *_store;
    CFMetrics *_metrics;

    UICollectionView *_collectionView;
    CFRoomLayout *_layout;
    CFHeaderView *_header;
    UIView *_fade;
    CAGradientLayer *_fadeGradient;
    UIView *_statusCover;
    CFComposerView *_composer;
    UIButton *_jumpToBottom;
    CFDebugBar *_debugBar;

    NSMutableArray<CFMessageItem *> *_rows;
    BOOL _showsWelcome;
    NSMutableDictionary<NSNumber *, CFRowLayout *> *_layoutCache;
    CGRect *_frames;
    NSInteger _frameCapacity;
    NSInteger _frameCount;
    CGSize _contentSize;
    CGFloat _rowWidth;
    CGFloat _rowX;

    BOOL _updating;
    BOOL _freezeAnchor;
    CFAnchor _lastAnchor;
    BOOL _lastPinned;
    BOOL _loadScheduled;
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
    _layoutCache = [NSMutableDictionary dictionary];
    _pendingAppends = [NSMutableArray array];
    _pendingChanged = [NSMutableSet set];
    _lastMs = -1;

    _layout = [[CFRoomLayout alloc] init];
    _layout.source = self;
    _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:_layout];
    _collectionView.backgroundColor = CFTheme.background;
    _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.alwaysBounceVertical = YES;
    _collectionView.prefetchingEnabled = NO;
    _collectionView.accessibilityIdentifier = @"room";
    [_collectionView registerClass:[CFMessageCell class] forCellWithReuseIdentifier:kMessageCell];
    [_collectionView registerClass:[CFWelcomeCell class] forCellWithReuseIdentifier:kWelcomeCell];
    [self.view addSubview:_collectionView];

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

    __weak typeof(self) weakSelf = self;
    [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class] withHandler:^(id<UITraitEnvironment> env, UITraitCollection *previous) {
        [weakSelf textSizeDidChange];
    }];
    [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withHandler:^(id<UITraitEnvironment> env, UITraitCollection *previous) {
        [weakSelf updateFadeColors];
    }];

    _metrics = [CFMetrics metricsForTraitCollection:self.traitCollection];
    _store = [[CFRoomStore alloc] initWithDataset:CFLaunchDataset()];
    NSInteger devStart = [NSUserDefaults.standardUserDefaults integerForKey:@"uvsDevStartID"];
    if (devStart > 0) {
        [_rows addObjectsFromArray:[_store itemsFrom:devStart to:devStart + CFKDataset.pageSize - 1]];
    } else {
        [_rows addObjectsFromArray:[_store newestItems:CFKDataset.pageSize]];
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
    CGRect cvFrame = CGRectMake(0, 0, W, listBottom);
    UIEdgeInsets inset = UIEdgeInsetsMake(headerTop + headerH, 0, 0, 0);
    _jumpToBottom.frame = CGRectMake(W - safe.right - 14 - 42, listBottom - 42 - 8, 42, 42);

    BOOL geometryChanged = !CGRectEqualToRect(cvFrame, _collectionView.frame) || !UIEdgeInsetsEqualToEdgeInsets(inset, _collectionView.contentInset);
    CGFloat newRowWidth = W - safe.left - safe.right;
    BOOL widthChanged = newRowWidth != _rowWidth || safe.left != _rowX;

    if (!_didInitialLoad) {
        _collectionView.frame = cvFrame;
        _collectionView.contentInset = inset;
        _collectionView.verticalScrollIndicatorInsets = inset;
        [self rebuildFrames];
        [_collectionView reloadData];
        [_collectionView layoutIfNeeded];
        [self scrollToBottom];
        _didInitialLoad = YES;
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
            [self setOffsetY:-_collectionView.contentInset.top];
            [self recordAnchor];
            [self updateState];
        } else if (devJump > 0) {
            NSInteger row = [self rowIndexOfItemID:devJump];
            if (row != NSNotFound) {
                [self setOffsetY:_frames[row].origin.y - _collectionView.contentInset.top - [NSUserDefaults.standardUserDefaults doubleForKey:@"uvsDevOffset"]];
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
    _collectionView.frame = cvFrame;
    _collectionView.contentInset = inset;
    _collectionView.verticalScrollIndicatorInsets = inset;
    if (widthChanged) {
        [self relayoutAllRowsPinned:pinned anchor:anchor];
    } else {
        [_collectionView layoutIfNeeded];
        [self restorePinned:pinned anchor:anchor];
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
    CFRowLayout *L = _layoutCache[@(item.itemID)];
    if (L && L.width == _rowWidth && L.scale == _metrics.scale && L.revision == item.revision) { return L; }
    L = [CFRowLayout layoutForItem:item store:_store width:_rowWidth metrics:_metrics];
    _layoutCache[@(item.itemID)] = L;
    return L;
}

/// Lays out every loaded row top to bottom, Campfire style: 21.28 between rows, threaded rows overlap by 1.2.
- (void)rebuildFrames {
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat W = self.view.bounds.size.width;
    _rowWidth = W - safe.left - safe.right;
    _rowX = safe.left;
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
    UIEdgeInsets inset = _collectionView.contentInset;
    CGFloat visible = _collectionView.bounds.size.height - inset.top - inset.bottom;
    if (y < visible) {
        CGFloat shift = visible - y;
        for (NSInteger k = 0; k < _frameCount; k++) { _frames[k].origin.y += shift; }
        y = visible;
    }
    _contentSize = CGSizeMake(W, y);
}

- (NSInteger)layoutRowCount { return _frameCount; }
- (CGRect)layoutFrameForRow:(NSInteger)row { return _frames[row]; }
- (CGSize)layoutContentSize { return _contentSize; }

- (NSInteger)rowIndexForItemIndex:(NSInteger)index { return index + (_showsWelcome ? 1 : 0); }

- (NSInteger)rowIndexOfItemID:(NSInteger)itemID {
    if (_rows.count == 0) { return NSNotFound; }
    NSInteger first = _rows.firstObject.itemID;
    NSInteger k = itemID - first;
    if (k < 0 || k >= (NSInteger)_rows.count || _rows[(NSUInteger)k].itemID != itemID) { return NSNotFound; }
    return [self rowIndexForItemIndex:k];
}

#pragma mark Position

- (CGFloat)visibleTop { return _collectionView.contentOffset.y + _collectionView.contentInset.top; }

- (CGFloat)maxOffsetY {
    return MAX(_contentSize.height + _collectionView.contentInset.bottom - _collectionView.bounds.size.height,
               -_collectionView.contentInset.top);
}

/// True when the loaded rows (plus live messages queued to be appended) end at the newest message.
- (BOOL)isNewestLoaded {
    return _rows.count == 0 || _rows.lastObject.itemID + (NSInteger)_pendingAppends.count >= _store.newestID;
}

- (BOOL)isPinned {
    if (_frameCount == 0) { return YES; }
    if (!self.isNewestLoaded) { return NO; }
    CGFloat lastBottom = CGRectGetMaxY(_frames[_frameCount - 1]);
    CGFloat visibleBottom = _collectionView.contentOffset.y + _collectionView.bounds.size.height - _collectionView.contentInset.bottom;
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
    _collectionView.contentOffset = CGPointMake(0, y);
}

- (void)scrollToBottom {
    [self setOffsetY:[self maxOffsetY]];
}

- (void)restoreAnchor:(CFAnchor)a {
    if (!a.valid) { return; }
    NSInteger row = [self rowIndexOfItemID:a.itemID];
    if (row == NSNotFound) { return; }
    CGFloat y = _frames[row].origin.y - a.offset - _collectionView.contentInset.top;
    [self setOffsetY:y];
}

- (void)restorePinned:(BOOL)pinned anchor:(CFAnchor)anchor {
    if (pinned && self.isNewestLoaded) { [self scrollToBottom]; } else { [self restoreAnchor:anchor]; }
}

/// Re-lays out every row (new width or text size) and puts the room back where it was.
/// The offset is set from our own frames before the collection view lays out, so it never sees an
/// offset past the end of the shorter content (UIKit would animate that back into range).
- (void)relayoutAllRowsPinned:(BOOL)pinned anchor:(CFAnchor)anchor {
    _updating = YES;
    [self rebuildFrames];
    [_collectionView reloadData];
    [self restorePinned:pinned anchor:anchor];
    [_collectionView layoutIfNeeded];
    [self restorePinned:pinned anchor:anchor];
    _updating = NO;
}

/// Runs a change to the rows, then puts the room back: pinned stays at the bottom, otherwise the top row stays put.
- (void)performKeepingPosition:(void (^)(void))change {
    BOOL pinned = [self isPinned];
    CFAnchor anchor = [self currentAnchor];
    if (_lastAnchor.valid && anchor.valid && _lastAnchor.itemID == anchor.itemID && fabs(_lastAnchor.offset - anchor.offset) < 1) {
        anchor = _lastAnchor;
    }
    _updating = YES;
    change();
    [self restorePinned:pinned anchor:anchor];
    [_collectionView layoutIfNeeded];
    [self restorePinned:pinned anchor:anchor];
    [_collectionView layoutIfNeeded];
    _updating = NO;
    [self recordAnchorPreferring:anchor];
    [self updateState];
}

#pragma mark Data source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _frameCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_showsWelcome && indexPath.item == 0) {
        CFWelcomeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kWelcomeCell forIndexPath:indexPath];
        [cell configureWithMetrics:_metrics];
        return cell;
    }
    CFMessageCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kMessageCell forIndexPath:indexPath];
    CFMessageItem *item = _rows[(NSUInteger)(indexPath.item - (_showsWelcome ? 1 : 0))];
    [cell configureWithLayout:[self rowLayoutForItem:item] item:item store:_store];
    return cell;
}

- (void)reconfigureVisibleCells {
    for (NSIndexPath *ip in _collectionView.indexPathsForVisibleItems) {
        UICollectionViewCell *cell = [_collectionView cellForItemAtIndexPath:ip];
        if ([cell isKindOfClass:[CFMessageCell class]]) {
            CFMessageItem *item = _rows[(NSUInteger)(ip.item - (_showsWelcome ? 1 : 0))];
            [(CFMessageCell *)cell configureWithLayout:[self rowLayoutForItem:item] item:item store:_store];
        } else if ([cell isKindOfClass:[CFWelcomeCell class]]) {
            [(CFWelcomeCell *)cell configureWithMetrics:_metrics];
        }
    }
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
    CGFloat visibleBottom = _collectionView.contentOffset.y + _collectionView.bounds.size.height;
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

- (void)loadOlder {
    if (_rows.count == 0 || _rows.firstObject.itemID <= _store.firstID) { return; }
    NSInteger first = _rows.firstObject.itemID;
    NSArray<CFMessageItem *> *older = [_store itemsFrom:first - CFKDataset.pageSize to:first - 1];
    if (older.count == 0) { return; }
    [self performKeepingPosition:^{
        BOOL hadWelcome = self->_showsWelcome;
        [self->_rows insertObjects:older atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, older.count)]];
        self->_showsWelcome = self->_rows.firstObject.itemID == self->_store.firstID;
        [self rebuildFrames];
        NSInteger inserted = (NSInteger)older.count + (self->_showsWelcome && !hadWelcome ? 1 : 0);
        NSMutableArray *paths = [NSMutableArray array];
        for (NSInteger i = 0; i < inserted; i++) { [paths addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
        [self insertItemsAtIndexPaths:paths];
    }];
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
        NSInteger start = self->_frameCount;
        [self->_rows addObjectsFromArray:items];
        [self rebuildFrames];
        NSMutableArray *paths = [NSMutableArray array];
        for (NSInteger i = start; i < self->_frameCount; i++) { [paths addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
        [self insertItemsAtIndexPaths:paths];
    }];
}

- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)paths {
    [UIView performWithoutAnimation:^{
        [self->_collectionView performBatchUpdates:^{
            [self->_collectionView insertItemsAtIndexPaths:paths];
        } completion:nil];
    }];
}

/// Replaces every loaded row (reset, jump), then positions the room with `position` (run before and after
/// the collection view lays out, so it never sees an out-of-range offset).
- (void)replaceRows:(NSArray<CFMessageItem *> *)rows position:(void (^)(void))position {
    _updating = YES;
    [_rows setArray:rows];
    _showsWelcome = _rows.firstObject.itemID == _store.firstID;
    [self rebuildFrames];
    [_collectionView reloadData];
    position();
    [_collectionView layoutIfNeeded];
    position();
    _updating = NO;
}

- (void)jumpToBottomTapped {
    if (self.isNewestLoaded) {
        _updating = YES;
        [self scrollToBottom];
        [_collectionView layoutIfNeeded];
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
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf flushPending]; });
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
        NSInteger start = self->_frameCount;
        // Only append when the rows still end at the message before these (no gap after a jump).
        BOOL contiguous = appends.count > 0 && self->_rows.lastObject.itemID + 1 == appends.firstObject.itemID;
        if (contiguous) { [self->_rows addObjectsFromArray:appends]; }
        [self rebuildFrames];
        if (contiguous) {
            NSMutableArray *paths = [NSMutableArray array];
            for (NSInteger i = start; i < self->_frameCount; i++) { [paths addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
            [self insertItemsAtIndexPaths:paths];
        }
        if (changed.count) {
            for (NSNumber *n in changed) {
                NSInteger row = [self rowIndexOfItemID:n.integerValue];
                if (row == NSNotFound) { continue; }
                CFMessageCell *cell = (CFMessageCell *)[self->_collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:row inSection:0]];
                if ([cell isKindOfClass:[CFMessageCell class]]) {
                    CFMessageItem *item = self->_rows[(NSUInteger)(row - (self->_showsWelcome ? 1 : 0))];
                    [cell configureWithLayout:[self rowLayoutForItem:item] item:item store:self->_store];
                }
            }
            [self->_layout invalidateLayout];
        }
    }];
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
    [self replaceRows:[_store itemsFrom:target - CFKDataset.pageSize to:target + CFKDataset.pageSize] position:^{
        NSInteger row = [self rowIndexOfItemID:target];
        if (row != NSNotFound) { [self setOffsetY:self->_frames[row].origin.y - self->_collectionView.contentInset.top]; }
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

- (void)updateState {
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
        _debugBar.stateLabel.text = text;
        _debugBar.stateLabel.accessibilityLabel = text;
        _debugBar.stateLabel.accessibilityValue = text;
    }
}

@end
