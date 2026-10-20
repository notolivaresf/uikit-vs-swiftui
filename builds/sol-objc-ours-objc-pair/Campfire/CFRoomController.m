#import "CFRoomController.h"
#import "CFMessageView.h"
extern CFTimeInterval CFLaunchTime;

@interface CFRoomController () <UICollectionViewDelegate>
@property (nonatomic, strong) CFKDataset *dataset;
@property (nonatomic, copy) NSDictionary<NSNumber *,CFKUser *> *users;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *identifiers;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *,CFRow *> *rows;
@property (nonatomic, strong) UICollectionView *collection;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *,NSNumber *> *source;
@property (nonatomic, strong) UICollectionViewCellRegistration *registration;
@property (nonatomic, strong) UICollectionViewCellRegistration *welcomeRegistration;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIView *composer;
@property (nonatomic, strong) UIView *debug;
@property (nonatomic, strong) UILabel *state;
@property (nonatomic, strong) UILabel *streamState;
@property (nonatomic, strong) UIButton *jumpButton;
@property (nonatomic, strong) CFKFeedHandle *feedHandle;
@property (nonatomic, strong) CFKLiveFeed *feed;
@property (nonatomic, copy) NSDictionary *pendingAnchor;
@property (nonatomic, copy) NSDictionary *rotationAnchor;
@property (nonatomic, copy) UIContentSizeCategory textCategory;
@property (nonatomic) BOOL benchmark;
@property (nonatomic) BOOL ready;
@property (nonatomic) BOOL applying;
@property (nonatomic) BOOL loadingOlder;
@property (nonatomic) CGFloat measuredWidth;
@property (nonatomic) CGFloat textScale;
@property (nonatomic) CFTimeInterval tapStart;
@property (nonatomic) NSInteger elapsedMS;
@property (nonatomic) NSInteger burstGeneration;
@property (nonatomic) BOOL didInitialPosition;
@end
@implementation CFRoomController
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=CFBackground(); self.textScale=1; self.tapStart=CFLaunchTime;
    self.textCategory=self.traitCollection.preferredContentSizeCategory;
    self.benchmark=[NSUserDefaults.standardUserDefaults boolForKey:@"uvsBenchmark"];
    self.rows=[NSMutableDictionary new]; self.identifiers=[NSMutableArray new];
    self.header=[UIView new]; self.header.backgroundColor=CFBackground(); [self.view addSubview:self.header];
    UIButton *room=[UIButton buttonWithType:UIButtonTypeSystem]; [room setTitle:@"General" forState:UIControlStateNormal]; room.titleLabel.font=CFFont(16,UIFontWeightBold,1); room.backgroundColor=CFText(); [room setTitleColor:CFBackground() forState:UIControlStateNormal]; room.layer.cornerRadius=8; room.accessibilityLabel=@"General room"; [self.header addSubview:room];
    NSArray *icons=@[@"ellipsis",@"bell.badge.fill",@"line.3.horizontal"];
    NSArray *labels=@[@"Room options",@"Notifications",@"Menu"];
    for(NSUInteger i=0;i<3;i++) { UIButton *button=CFIconButton(icons[i],labels[i]); button.layer.cornerRadius=21; button.layer.borderWidth=1; [self.header addSubview:button]; }
    __weak typeof(self) weakSelf=self;
    UICollectionViewCompositionalLayout *layout=[[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
        CFRoomController *self=weakSelf; NSNumber *identifier=[self.source sectionIdentifierForIndex:index];
        CGFloat height=identifier.integerValue==0 ? 380 : self.rows[identifier].height;
        NSCollectionLayoutSize *size=[NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:[NSCollectionLayoutDimension absoluteDimension:MAX(1,height)]];
        NSCollectionLayoutItem *item=[NSCollectionLayoutItem itemWithLayoutSize:size];
        NSCollectionLayoutGroup *group=[NSCollectionLayoutGroup verticalGroupWithLayoutSize:size subitems:@[item]];
        NSCollectionLayoutSection *section=[NSCollectionLayoutSection sectionWithGroup:group];
        if(identifier.integerValue && !self.rows[identifier].presentation.isThreaded) section.contentInsets=NSDirectionalEdgeInsetsMake(21.28,0,0,0);
        return section;
    }];
    [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withHandler:^(__kindof id<UITraitEnvironment> environment, UITraitCollection *previous) {
        [weakSelf.view setNeedsLayout]; [weakSelf reconfigureVisible];
    }];
    self.collection=[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout]; self.collection.delegate=self;
    self.collection.backgroundColor=CFBackground(); self.collection.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
    self.collection.alwaysBounceVertical=YES; self.collection.accessibilityIdentifier=@"messages";
    [self.view insertSubview:self.collection belowSubview:self.header];
    self.registration=[UICollectionViewCellRegistration registrationWithCellClass:UICollectionViewCell.class configurationHandler:^(UICollectionViewCell *cell, NSIndexPath *indexPath, NSNumber *identifier) {
        CFMessageConfiguration *configuration=[CFMessageConfiguration new]; configuration.row=weakSelf.rows[identifier]; cell.contentConfiguration=configuration;
        cell.accessibilityIdentifier=[NSString stringWithFormat:@"row-%@",identifier];
    }];
    self.welcomeRegistration=[UICollectionViewCellRegistration registrationWithCellClass:CFWelcomeView.class configurationHandler:^(UICollectionViewCell *cell,NSIndexPath *indexPath,NSNumber *identifier) {}];
    self.source=[[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collection cellProvider:^UICollectionViewCell *(UICollectionView *collection,NSIndexPath *path,NSNumber *identifier) {
        CFRoomController *self=weakSelf; return [collection dequeueConfiguredReusableCellWithRegistration:identifier.integerValue==0 ? self.welcomeRegistration : self.registration forIndexPath:path item:identifier];
    }];
    self.composer=[UIView new]; self.composer.backgroundColor=CFBackground(); [self.view addSubview:self.composer];
    UIButton *search=CFIconButton(@"magnifyingglass",@"Search"); search.layer.cornerRadius=21; search.layer.borderWidth=1; [self.composer addSubview:search];
    UIView *input=[UIView new]; input.layer.cornerRadius=21; input.layer.borderWidth=1; [self.composer addSubview:input];
    UIButton *chat=CFIconButton(@"bubble.left",@"Message composer"); [input addSubview:chat];
    UIButton *clip=CFIconButton(@"paperclip",@"Attach file"); [input addSubview:clip];
    UIButton *send=CFIconButton(@"arrow.up",@"Send message"); send.backgroundColor=CFText(); send.tintColor=CFBackground(); send.layer.cornerRadius=17; [input addSubview:send];
    self.jumpButton=[UIButton buttonWithType:UIButtonTypeSystem]; [self.jumpButton setTitle:@"↓  Jump to bottom" forState:UIControlStateNormal]; self.jumpButton.titleLabel.font=CFFont(13,UIFontWeightSemibold,1); self.jumpButton.backgroundColor=CFText(); [self.jumpButton setTitleColor:CFBackground() forState:UIControlStateNormal]; self.jumpButton.layer.cornerRadius=18; self.jumpButton.hidden=YES; [self.jumpButton addTarget:self action:@selector(jumpBottom) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.jumpButton];
    if(self.benchmark) [self buildDebug];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(systemTextChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        CFKDataset *dataset=[CFKDataset new]; CFKPage *page=[dataset lastPage];
        NSMutableDictionary *users=[NSMutableDictionary new]; for(CFKUser *user in dataset.users) users[@(user.userID)]=user;
        dispatch_async(dispatch_get_main_queue(), ^{
            CFRoomController *self=weakSelf; if(!self) return;
            self.dataset=dataset; self.users=users; self.ready=YES;
            [self addPage:page prepend:NO]; [self remeasure];
            [self applyWithAnchor:@{@"pinned":@YES} changed:@[] timed:YES];
        });
    });
}
- (void)buildDebug {
    self.debug=[UIView new]; self.debug.backgroundColor=CFBubble(); [self.view addSubview:self.debug];
    NSArray *names=@[@"Reset",@"Jump to 2500",@"Load older",@"Start stream",@"Text size +",@"Boost burst"];
    NSArray *actions=@[NSStringFromSelector(@selector(reset)),NSStringFromSelector(@selector(jump2500)),NSStringFromSelector(@selector(loadOlderTap)),NSStringFromSelector(@selector(startStream)),NSStringFromSelector(@selector(increaseText)),NSStringFromSelector(@selector(boostBurst))];
    for(NSUInteger i=0;i<names.count;i++) {
        UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setTitle:names[i] forState:UIControlStateNormal]; b.titleLabel.font=CFFont(11,UIFontWeightSemibold,1); b.tintColor=CFText(); b.accessibilityIdentifier=names[i]; [b addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside]; [self.debug addSubview:b];
    }
    self.state=CFLabel(@"Loading…",[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular]); self.state.numberOfLines=2; self.state.accessibilityIdentifier=@"benchmarkState"; [self.debug addSubview:self.state];
    self.streamState=CFLabel(@"",CFFont(10,UIFontWeightSemibold,1)); self.streamState.accessibilityIdentifier=@"streamState"; [self.debug addSubview:self.streamState];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w=self.view.bounds.size.width, h=self.view.bounds.size.height;
    CGFloat left=self.view.safeAreaInsets.left, right=self.view.safeAreaInsets.right;
    CGFloat contentWidth=w-left-right;
    NSDictionary *anchor=self.rotationAnchor ?: self.pendingAnchor ?: (self.didInitialPosition ? [self captureAnchor] : @{@"pinned":@YES});
    BOOL widthChanged=fabs(contentWidth-self.measuredWidth)>.1;
    CGFloat headerHeight=58+(self.benchmark ? 90 :0);
    self.header.frame=CGRectMake(left,0,contentWidth,58);
    NSArray<UIView *> *hv=self.header.subviews;
    hv[0].frame=CGRectMake(10,8,97,42); hv[1].frame=CGRectMake(113.5,8,42,42); hv[2].frame=CGRectMake(160,8,42,42); hv[3].frame=CGRectMake(contentWidth-53,8,42,42);
    for(NSUInteger i=1;i<4;i++) { hv[i].layer.borderColor=[CFBorder() resolvedColorWithTraitCollection:self.traitCollection].CGColor; hv[i].backgroundColor=CFBackground(); }
    hv[2].layer.shadowColor=[UIColor colorWithRed:1 green:.43 blue:0 alpha:1].CGColor; hv[2].layer.shadowOpacity=1; hv[2].layer.shadowRadius=0; hv[2].layer.shadowOffset=CGSizeZero; hv[2].layer.shadowPath=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(hv[2].bounds,-3,-3)].CGPath;
    if(self.benchmark) {
        self.debug.frame=CGRectMake(left,58,contentWidth,90);
        for(NSInteger i=0;i<6;i++) self.debug.subviews[i].frame=CGRectMake((i%3)*contentWidth/3,(i/3)*26,contentWidth/3,26);
        self.state.frame=CGRectMake(8,54,contentWidth-16,28); self.streamState.frame=CGRectMake(contentWidth-85,78,80,12);
    }
    self.collection.frame=CGRectMake(left,headerHeight,contentWidth,MAX(1,h-headerHeight-90));
    self.composer.frame=CGRectMake(left,h-90,contentWidth,90);
    UIView *search=self.composer.subviews[0], *input=self.composer.subviews[1];
    search.frame=CGRectMake(14,24,42,42); input.frame=CGRectMake(66,24,contentWidth-80,42);
    search.layer.borderColor=[CFBorder() resolvedColorWithTraitCollection:self.traitCollection].CGColor; input.layer.borderColor=search.layer.borderColor;
    input.subviews[0].frame=CGRectMake(7,0,34,42); input.subviews[1].frame=CGRectMake(input.bounds.size.width-82,0,34,42); input.subviews[2].frame=CGRectMake(input.bounds.size.width-39,4,34,34);
    self.jumpButton.frame=CGRectMake(w/2-78,h-133,156,36);
    if(self.ready && widthChanged) { [self remeasure]; [self.collection.collectionViewLayout invalidateLayout]; [self.collection layoutIfNeeded]; [self restoreAnchor:anchor]; [self reconfigureVisible]; }
    else if(self.pendingAnchor || self.rotationAnchor) [self restoreAnchor:anchor];
    self.pendingAnchor=nil;
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    self.rotationAnchor=[self captureAnchor]; self.pendingAnchor=self.rotationAnchor; [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    __weak typeof(self) weakSelf=self;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        CFRoomController *self=weakSelf; if(!self) return;
        [self.collection layoutIfNeeded]; [self restoreAnchor:self.rotationAnchor]; self.rotationAnchor=nil; [self updateState];
    }];
}
- (void)addPage:(CFKPage *)page prepend:(BOOL)prepend {
    NSMutableArray *newIDs=[NSMutableArray new];
    static NSDateFormatter *timeFormatter, *dayFormatter;
    static dispatch_once_t once; dispatch_once(&once, ^{
        timeFormatter=[NSDateFormatter new]; timeFormatter.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; timeFormatter.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0]; timeFormatter.dateFormat=@"h:mm a";
        dayFormatter=[NSDateFormatter new]; dayFormatter.locale=timeFormatter.locale; dayFormatter.timeZone=timeFormatter.timeZone; dayFormatter.dateFormat=@"MMMM d, yyyy";
    });
    for(NSUInteger i=0;i<page.messages.count;i++) {
        CFKMessage *m=page.messages[i]; NSNumber *identifier=@(m.messageID); if(self.rows[identifier]) continue;
        CFRow *row=[CFRow new]; row.message=m; row.presentation=page.presentations[i]; row.users=self.users; row.time=[timeFormatter stringFromDate:m.createdAt]; row.day=[[dayFormatter stringFromDate:m.createdAt] uppercaseString];
        self.rows[identifier]=row; [newIDs addObject:identifier];
    }
    if(prepend) [self.identifiers insertObjects:newIDs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,newIDs.count)]]; else [self.identifiers addObjectsFromArray:newIDs];
}
- (void)remeasure {
    self.measuredWidth=MAX(1,self.collection.bounds.size.width);
    UITraitCollection *traits=[UITraitCollection traitCollectionWithPreferredContentSizeCategory:self.textCategory];
    self.textScale=[[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledValueForValue:16 compatibleWithTraitCollection:traits]/16;
    for(NSNumber *identifier in self.identifiers) [self.rows[identifier] measureWidth:self.measuredWidth scale:self.textScale];
}
- (NSArray<NSNumber *> *)snapshotIDs {
    if(self.identifiers.firstObject.integerValue==1) { NSMutableArray *ids=[self.identifiers mutableCopy]; [ids insertObject:@0 atIndex:0]; return ids; } return self.identifiers;
}
- (void)applyWithAnchor:(NSDictionary *)anchor changed:(NSArray<NSNumber *> *)changed timed:(BOOL)timed {
    self.applying=YES;
    NSDiffableDataSourceSnapshot *snapshot=[NSDiffableDataSourceSnapshot new];
    for(NSNumber *identifier in [self snapshotIDs]) { [snapshot appendSectionsWithIdentifiers:@[identifier]]; [snapshot appendItemsWithIdentifiers:@[identifier] intoSectionWithIdentifier:identifier]; }
    NSArray *existing=self.source.snapshot.itemIdentifiers;
    NSMutableArray *valid=[NSMutableArray new]; for(NSNumber *identifier in changed) if([existing containsObject:identifier] && [snapshot.itemIdentifiers containsObject:identifier]) [valid addObject:identifier];
    if(valid.count) [snapshot reconfigureItemsWithIdentifiers:valid];
    __weak typeof(self) weakSelf=self;
    [self.source applySnapshot:snapshot animatingDifferences:NO completion:^{
        CFRoomController *self=weakSelf; if(!self) return;
        [self.collection.collectionViewLayout invalidateLayout]; [self.collection layoutIfNeeded];
        [self restoreAnchor:anchor]; [self.collection layoutIfNeeded];
        self.didInitialPosition=YES; self.applying=NO;
        if(timed) self.elapsedMS=lround((CACurrentMediaTime()-self.tapStart)*1000);
        [self updateState];
    }];
}
- (BOOL)isPinned { return self.collection.contentSize.height-self.collection.contentOffset.y-self.collection.bounds.size.height<=100.0; }
- (NSDictionary *)captureAnchor {
    if([self isPinned]) return @{@"pinned":@YES};
    CGFloat offset=self.collection.contentOffset.y;
    NSArray *visible=[[self.collection indexPathsForVisibleItems] sortedArrayUsingSelector:@selector(compare:)];
    for(NSIndexPath *path in visible) {
        NSNumber *identifier=[self.source itemIdentifierForIndexPath:path]; if(!identifier.integerValue) continue;
        CGRect frame=[self.collection layoutAttributesForItemAtIndexPath:path].frame;
        if(CGRectGetMaxY(frame)>offset+.01) return @{@"id":identifier,@"y":@(frame.origin.y-offset),@"pinned":@NO};
    }
    return @{@"pinned":@NO,@"offset":@(offset)};
}
- (void)restoreAnchor:(NSDictionary *)anchor {
    CGFloat offset=self.collection.contentOffset.y;
    if([anchor[@"pinned"] boolValue]) offset=MAX(0,self.collection.contentSize.height-self.collection.bounds.size.height);
    else if(anchor[@"id"]) {
        NSIndexPath *path=[self.source indexPathForItemIdentifier:anchor[@"id"]];
        if(path) offset=[self.collection layoutAttributesForItemAtIndexPath:path].frame.origin.y-[anchor[@"y"] doubleValue];
    } else if(anchor[@"offset"]) offset=[anchor[@"offset"] doubleValue];
    self.collection.contentOffset=CGPointMake(0,MAX(0,MIN(offset,MAX(0,self.collection.contentSize.height-self.collection.bounds.size.height))));
}
- (void)updateState {
    if(!self.ready) return;
    CGFloat offset=self.collection.contentOffset.y; NSInteger top=0; CGFloat y=0;
    NSArray *visible=[[self.collection indexPathsForVisibleItems] sortedArrayUsingSelector:@selector(compare:)];
    for(NSIndexPath *path in visible) {
        NSNumber *identifier=[self.source itemIdentifierForIndexPath:path]; if(!identifier.integerValue) continue;
        CGRect frame=[self.collection layoutAttributesForItemAtIndexPath:path].frame;
        if(CGRectGetMaxY(frame)>offset+.01) { top=identifier.integerValue; y=frame.origin.y-offset; if(fabs(y)<.05) y=0; break; }
    }
    BOOL pinned=[self isPinned];
    self.state.text=[NSString stringWithFormat:@"first %@ last %@ loaded %lu pinned %@ top %ld y %.1f ms %ld",self.identifiers.firstObject ?: @0,self.identifiers.lastObject ?: @0,(unsigned long)self.identifiers.count,pinned ? @"yes" : @"no",(long)top,y,(long)self.elapsedMS];
    self.jumpButton.hidden=pinned;
}
- (void)reconfigureVisible {
    NSDiffableDataSourceSnapshot *snapshot=self.source.snapshot;
    NSMutableArray<NSNumber *> *ids=[NSMutableArray new];
    // Mark every loaded identity, including cells about to enter the resized viewport.
    for(NSNumber *identifier in snapshot.itemIdentifiers) if(identifier.integerValue && self.rows[identifier]) [ids addObject:identifier];
    if(ids.count) {
        [snapshot reconfigureItemsWithIdentifiers:ids];
        [self.source applySnapshot:snapshot animatingDifferences:NO];
    }
}
- (void)reset {
    if(!self.ready) return; self.tapStart=CACurrentMediaTime(); [self.feedHandle cancel]; self.feedHandle=nil; self.streamState.text=@""; self.burstGeneration++;
    [self.rows removeAllObjects]; [self.identifiers removeAllObjects]; self.textCategory=UIContentSizeCategoryLarge;
    [self addPage:[self.dataset lastPage] prepend:NO]; [self remeasure]; [self applyWithAnchor:@{@"pinned":@YES} changed:@[] timed:YES];
}
- (void)jump2500 {
    if(!self.ready) return; self.tapStart=CACurrentMediaTime();
    [self.rows removeAllObjects]; [self.identifiers removeAllObjects]; [self addPage:[self.dataset pageAroundMessageID:2500] prepend:NO]; [self remeasure];
    [self applyWithAnchor:@{@"id":@2500,@"y":@0,@"pinned":@NO} changed:@[] timed:YES];
}
- (void)loadOlderTap { if(!self.ready) return; self.tapStart=CACurrentMediaTime(); [self loadOlder:YES]; }
- (void)loadOlder:(BOOL)timed {
    if(self.loadingOlder || self.applying || self.identifiers.firstObject.integerValue<=1) { if(timed) { self.elapsedMS=lround((CACurrentMediaTime()-self.tapStart)*1000); [self updateState]; } return; }
    self.loadingOlder=YES; NSDictionary *anchor=[self captureAnchor];
    [self addPage:[self.dataset pageBeforeMessageID:self.identifiers.firstObject.integerValue] prepend:YES];
    // Bound historical windows by trimming the distant tail, only if it cannot remove the anchor.
    while(self.identifiers.count>300 && ![anchor[@"pinned"] boolValue] && [self.identifiers indexOfObject:anchor[@"id"]]<260) { NSNumber *last=self.identifiers.lastObject; [self.rows removeObjectForKey:last]; [self.identifiers removeLastObject]; }
    [self remeasure]; [self applyWithAnchor:anchor changed:@[] timed:timed]; self.loadingOlder=NO;
}
- (void)jumpBottom {
    [self.collection layoutIfNeeded]; [self restoreAnchor:@{@"pinned":@YES}]; [self updateState];
}
- (void)increaseText {
    if(!self.ready) return; self.tapStart=CACurrentMediaTime(); NSDictionary *anchor=[self captureAnchor];
    NSArray *categories=@[UIContentSizeCategoryLarge,UIContentSizeCategoryExtraLarge,UIContentSizeCategoryExtraExtraLarge,UIContentSizeCategoryExtraExtraExtraLarge,UIContentSizeCategoryAccessibilityMedium,UIContentSizeCategoryAccessibilityLarge,UIContentSizeCategoryAccessibilityExtraLarge,UIContentSizeCategoryAccessibilityExtraExtraLarge,UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    NSUInteger index=[categories indexOfObject:self.textCategory]; self.textCategory=categories[index==NSNotFound ? 0 : (index+1)%categories.count];
    [self remeasure]; [self applyWithAnchor:anchor changed:self.identifiers timed:YES];
}
- (void)systemTextChanged:(NSNotification *)notification {
    NSDictionary *anchor=[self captureAnchor]; self.textCategory=notification.userInfo[UIContentSizeCategoryNewValueKey] ?: self.traitCollection.preferredContentSizeCategory;
    [self remeasure]; [self applyWithAnchor:anchor changed:self.identifiers timed:NO];
}
- (void)startStream {
    if(!self.ready || self.feedHandle) return;
    self.streamState.text=@""; self.feed=[[CFKLiveFeed alloc] initWithDataset:self.dataset]; __weak typeof(self) weakSelf=self;
    self.feedHandle=[self.feed startOnEvent:^(CFKFeedEvent *event) { [weakSelf receiveEvent:event]; } completion:^{ weakSelf.streamState.text=@"Stream done"; [weakSelf updateState]; }];
}
- (void)receiveEvent:(CFKFeedEvent *)event {
    if(event.kind==CFKFeedEventKindMessage) {
        CFKMessage *m=event.message; if(self.rows[@(m.messageID)]) return;
        NSDictionary *anchor=[self captureAnchor]; CFKMessage *previous=self.rows[self.identifiers.lastObject].message;
        if(previous.messageID+1!=m.messageID) previous=[self.dataset messageWithID:m.messageID-1];
        CFRow *row=[CFRow new]; row.message=m; row.presentation=[self.dataset presentationOf:m after:previous]; row.users=self.users;
        // Reuse the UTC date strings from the fixed formatters in addPage through a lightweight formatter cache.
        static NSDateFormatter *time, *day; static dispatch_once_t once; dispatch_once(&once, ^{ time=[NSDateFormatter new]; time.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; time.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0]; time.dateFormat=@"h:mm a"; day=[NSDateFormatter new]; day.locale=time.locale; day.timeZone=time.timeZone; day.dateFormat=@"MMMM d, yyyy"; });
        row.time=[time stringFromDate:m.createdAt]; row.day=[[day stringFromDate:m.createdAt] uppercaseString];
        NSNumber *identifier=@(m.messageID); self.rows[identifier]=row; [self.identifiers addObject:identifier]; [row measureWidth:self.measuredWidth scale:self.textScale];
        while(self.identifiers.count>300 && [anchor[@"pinned"] boolValue]) { NSNumber *first=self.identifiers.firstObject; [self.rows removeObjectForKey:first]; [self.identifiers removeObjectAtIndex:0]; }
        [self applyWithAnchor:anchor changed:@[] timed:NO];
    } else if(event.kind==CFKFeedEventKindBoost && event.boost) [self addBoostTo:@(event.messageID) user:event.boost.boosterID content:event.boost.content];
}
- (void)addBoostTo:(NSNumber *)identifier user:(NSInteger)userID content:(NSString *)content {
    CFRow *row=self.rows[identifier]; if(!row) return;
    NSDictionary *anchor=[self captureAnchor]; NSMutableArray *boosts=[row.extraBoosts mutableCopy] ?: [NSMutableArray new]; [boosts addObject:@{@"user":@(userID),@"text":content}]; row.extraBoosts=boosts;
    [row measureWidth:self.measuredWidth scale:self.textScale]; [self applyWithAnchor:anchor changed:@[identifier] timed:NO];
}
- (void)boostBurst {
    if(!self.ready) return; NSNumber *identifier=self.identifiers.lastObject; NSInteger generation=++self.burstGeneration; __weak typeof(self) weakSelf=self;
    NSArray *emojis=@[@"👍",@"🎉",@"🔥",@"❤️",@"😂"];
    for(NSInteger i=0;i<5;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((i+1)*.2*NSEC_PER_SEC)),dispatch_get_main_queue(), ^{ if(weakSelf.burstGeneration==generation) [weakSelf addBoostTo:identifier user:i+2 content:emojis[i]]; });
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(!self.ready || self.applying) return;
    [self updateState];
    if((scrollView.dragging || scrollView.decelerating) && scrollView.contentOffset.y<60) [self loadOlder:NO];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { [self updateState]; }
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate { if(!decelerate) [self updateState]; }
- (void)dealloc { [self.feedHandle cancel]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
