#import "RoomController.h"
#import <QuartzCore/QuartzCore.h>

@interface CFRoot : CFFlippedView
@property(copy) void (^resized)(void);
@end
@implementation CFRoot
- (void)setFrameSize:(NSSize)size { [super setFrameSize:size];if(self.resized)self.resized(); }
- (void)drawRect:(NSRect)dirty { [CFBackground() setFill];NSRectFill(dirty); }
@end

@interface CFRoomController ()
@property CFKDataset *dataset;
@property CFKLiveFeed *feed;
@property CFKFeedHandle *feedHandle;
@property NSMutableArray<CFKMessage *> *messages;
@property NSMutableArray<CFKPresentation *> *presentations;
@property NSMutableArray<CFKMessage *> *liveMessages;
@property NSMutableArray<CFRowLayout *> *layouts;
@property NSMutableDictionary<NSNumber *,CFRowView *> *visibleRows;
@property NSMutableDictionary<NSNumber *,NSMutableArray *> *extraBoosts;
@property NSScrollView *scroll;
@property CFDocument *chatDocument;
@property CFRoot *root;
@property CFChrome *header, *composer;
@property CFWelcome *welcome;
@property NSView *debugBar;
@property NSArray<NSButton *> *debugButtons;
@property NSTextField *stateLabel,*streamLabel;
@property NSButton *jumpButton;
@property BOOL benchmark, changing, loadingOlder, unread, streamRunning;
@property NSInteger textStep, boostGeneration, pageGeneration;
@property CGFloat contentHeight;
@property CFTimeInterval actionStart;
@property NSInteger elapsedMS;
@end
@implementation CFRoomController
- (instancetype)initWithStartTime:(CFTimeInterval)start {
    NSWindow *w=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,393,852) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    if((self=[super initWithWindow:w])){
        _actionStart=start;_benchmark=[[NSUserDefaults standardUserDefaults] boolForKey:@"uvsBenchmark"];
        w.title=@"Campfire";w.contentMinSize=NSMakeSize(393,600);w.contentMaxSize=NSMakeSize(2400,2400);w.delegate=self;w.releasedWhenClosed=NO;w.tabbingMode=NSWindowTabbingModeDisallowed;w.restorable=NO;w.backgroundColor=CFBackground();
        _messages=[NSMutableArray new];_presentations=[NSMutableArray new];_liveMessages=[NSMutableArray new];_layouts=[NSMutableArray new];_visibleRows=[NSMutableDictionary new];_extraBoosts=[NSMutableDictionary new];
        _root=[[CFRoot alloc] initWithFrame:NSMakeRect(0,0,393,852)];w.contentView=_root;
        _scroll=[[NSScrollView alloc] initWithFrame:NSZeroRect];_scroll.borderType=NSNoBorder;_scroll.hasVerticalScroller=YES;_scroll.hasHorizontalScroller=NO;_scroll.autohidesScrollers=YES;_scroll.scrollerStyle=NSScrollerStyleOverlay;_scroll.drawsBackground=NO;_scroll.verticalScrollElasticity=NSScrollElasticityNone;_scroll.horizontalScrollElasticity=NSScrollElasticityNone;_scroll.automaticallyAdjustsContentInsets=NO;[_scroll setAccessibilityLabel:@"Room messages"];
        _chatDocument=[[CFDocument alloc] initWithFrame:NSZeroRect];_scroll.documentView=_chatDocument;_scroll.contentView.postsBoundsChangedNotifications=YES;[_root addSubview:_scroll];
        _header=[[CFChrome alloc] initWithFrame:NSZeroRect];[_root addSubview:_header];
        _composer=[[CFChrome alloc] initWithFrame:NSZeroRect];_composer.composer=YES;[_root addSubview:_composer];
        _welcome=[[CFWelcome alloc] initWithFrame:NSZeroRect];
        _jumpButton=[NSButton buttonWithTitle:@"Jump to bottom" target:self action:@selector(jumpToBottom:)];_jumpButton.bezelStyle=NSBezelStyleRounded;_jumpButton.hidden=YES;[_root addSubview:_jumpButton];
        if(_benchmark)[self makeDebugBar];
        __weak typeof(self) weak=self;_root.resized=^{[weak resizeRoom];};
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scrolled:) name:NSViewBoundsDidChangeNotification object:_scroll.contentView];
        [self arrangeChrome];[w center];
        _dataset=[CFKDataset new];_header.roomName=_dataset.roomName;
        [self installPage:[_dataset lastPage]];[self rebuildPreserving:nil pinned:YES force:YES];
        [w makeKeyAndOrderFront:nil];[self finishAction];
        NSString *snapshot=[[NSUserDefaults standardUserDefaults] stringForKey:@"uvsSnapshot"];
        if(snapshot){NSString *look=[[NSUserDefaults standardUserDefaults] stringForKey:@"uvsSnapshotAppearance"];if(look)w.appearance=[NSAppearance appearanceNamed:[look isEqual:@"light"]?NSAppearanceNameAqua:NSAppearanceNameDarkAqua];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            NSBitmapImageRep *bitmap=[self.root bitmapImageRepForCachingDisplayInRect:self.root.bounds];
            [self.root cacheDisplayInRect:self.root.bounds toBitmapImageRep:bitmap];
            [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:snapshot atomically:YES];
        });}
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"uvsSelfTest"]){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[weak runSelfTests];});}
    }return self;
}
- (void)makeDebugBar {
    self.debugBar=[[CFFlippedView alloc] initWithFrame:NSZeroRect];[self.root addSubview:self.debugBar];
    NSArray *titles=@[@"Reset",@"Jump to 2500",@"Load older",@"Start stream",@"Text size +",@"Boost burst"];
    NSArray *actions=@[NSStringFromSelector(@selector(reset:)),NSStringFromSelector(@selector(jumpTo2500:)),NSStringFromSelector(@selector(loadOlder:)),NSStringFromSelector(@selector(startStream:)),NSStringFromSelector(@selector(textLarger:)),NSStringFromSelector(@selector(boostBurst:))];
    NSMutableArray *buttons=[NSMutableArray new];
    for(NSUInteger i=0;i<titles.count;i++){NSButton *b=[NSButton buttonWithTitle:titles[i] target:self action:NSSelectorFromString(actions[i])];b.bezelStyle=NSBezelStyleRounded;b.font=CFFont(11,NO);[b setAccessibilityElement:YES];[b setAccessibilityRole:NSAccessibilityButtonRole];[b setAccessibilityLabel:titles[i]];[self.debugBar addSubview:b];[buttons addObject:b];}self.debugButtons=buttons;
    self.stateLabel=[NSTextField labelWithString:@""];self.stateLabel.font=[NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightRegular];self.stateLabel.textColor=NSColor.labelColor;self.stateLabel.lineBreakMode=NSLineBreakByClipping;self.stateLabel.accessibilityElement=YES;self.stateLabel.accessibilityRole=NSAccessibilityStaticTextRole;[self.debugBar addSubview:self.stateLabel];
    self.streamLabel=[NSTextField labelWithString:@""];self.streamLabel.font=CFFont(11,NO);self.streamLabel.accessibilityElement=YES;self.streamLabel.accessibilityRole=NSAccessibilityStaticTextRole;[self.debugBar addSubview:self.streamLabel];
}
- (CGFloat)debugHeight { return self.benchmark?98:0; }
- (void)arrangeChrome {
    CGFloat w=self.root.bounds.size.width,h=self.root.bounds.size.height,debug=[self debugHeight];
    self.header.frame=NSMakeRect(0,debug,w,58);self.composer.frame=NSMakeRect(0,h-90,w,90);self.scroll.frame=NSMakeRect(0,debug+58,w,MAX(1,h-debug-148));
    self.jumpButton.frame=NSMakeRect(w-145,h-125,130,28);
    if(self.benchmark){self.debugBar.frame=NSMakeRect(0,0,w,debug);CGFloat x=8,y=3;for(NSButton *b in self.debugButtons){CGFloat bw=MAX(60,[b.title sizeWithAttributes:@{NSFontAttributeName:b.font}].width+20);if(x+bw>w-8){x=8;y+=27;}b.frame=NSMakeRect(x,y,bw,24);x+=bw+4;}self.streamLabel.frame=NSMakeRect(x,y+5,84,18);self.stateLabel.frame=NSMakeRect(8,75,w-16,16);}
    self.header.needsDisplay=YES;self.composer.needsDisplay=YES;
}
- (void)installPage:(CFKPage *)page {
    self.pageGeneration++;self.loadingOlder=NO;
    [self.messages setArray:page.messages];[self.presentations setArray:page.presentations];[self.layouts removeAllObjects];
    for(CFRowView *v in self.visibleRows.allValues)[v removeFromSuperview];[self.visibleRows removeAllObjects];
}
- (BOOL)isPinned { return self.contentHeight-NSMaxY(self.scroll.contentView.bounds)<=100.0; }
- (NSDictionary *)anchor {
    CGFloat y=self.scroll.contentView.bounds.origin.y;
    for(CFRowLayout *l in self.layouts){if(l.y+l.height-1.6>y+.01)return @{@"id":@(l.message.messageID),@"offset":@(l.y-y)};}
    return nil;
}
- (CFRowLayout *)layoutForID:(NSInteger)messageID { for(CFRowLayout *l in self.layouts)if(l.message.messageID==messageID)return l;return nil; }
- (void)rebuildPreserving:(NSDictionary *)anchor pinned:(BOOL)pinned force:(BOOL)force {
    self.changing=YES;CGFloat width=self.scroll.contentView.bounds.size.width;CGFloat scale=1+self.textStep*.125;
    NSMutableDictionary *cache=[NSMutableDictionary new];if(!force){for(CFRowLayout *l in self.layouts)cache[@(l.message.messageID)]=l;}
    NSMutableArray *newLayouts=[NSMutableArray new];CGFloat y=0;
    // The invitation belongs at the beginning of the complete room history.
    if(self.messages.firstObject.messageID==self.dataset.firstMessageID){self.welcome.frame=NSMakeRect(0,0,width,401);[self.chatDocument addSubview:self.welcome];y=401;}else [self.welcome removeFromSuperview];
    CFRowLayout *previous=nil;
    for(NSUInteger i=0;i<self.messages.count;i++){
        CFKMessage *m=self.messages[i];CFKPresentation *p=self.presentations[i];NSArray *extras=self.extraBoosts[@(m.messageID)];CFRowLayout *l=cache[@(m.messageID)];
        if(!l || l.boosts.count!=m.boosts.count+extras.count)l=[CFRowLayout layoutMessage:m presentation:p dataset:self.dataset width:width scale:scale extraBoosts:extras];
        if(previous)y+=p.isThreaded?-1.2:21.28;l.y=y;[newLayouts addObject:l];y+=l.height;previous=l;
    }
    self.layouts=newLayouts;self.contentHeight=MAX(y+2,self.scroll.contentView.bounds.size.height);self.chatDocument.frame=NSMakeRect(0,0,width,self.contentHeight);
    CGFloat origin=self.scroll.contentView.bounds.origin.y;
    if(pinned)origin=self.contentHeight-self.scroll.contentView.bounds.size.height;
    else if(anchor){CFRowLayout *l=[self layoutForID:[anchor[@"id"] integerValue]];if(l)origin=l.y-[anchor[@"offset"] doubleValue];}
    origin=MAX(0,MIN(origin,self.contentHeight-self.scroll.contentView.bounds.size.height));[self.scroll.contentView scrollToPoint:NSMakePoint(0,origin)];[self.scroll reflectScrolledClipView:self.scroll.contentView];
    [self materializeRows];self.changing=NO;[self updateState];
}
- (void)materializeRows {
    NSRect visible=NSInsetRect(self.scroll.contentView.bounds,0,-250);NSMutableSet *needed=[NSMutableSet new];
    for(CFRowLayout *l in self.layouts){NSRect frame=NSMakeRect(0,l.y,self.chatDocument.bounds.size.width,l.height);if(!NSIntersectsRect(visible,frame))continue;NSNumber *key=@(l.message.messageID);[needed addObject:key];CFRowView *v=self.visibleRows[key];if(!v){v=[[CFRowView alloc] initWithFrame:frame];v.dataset=self.dataset;self.visibleRows[key]=v;[self.chatDocument addSubview:v];}v.frame=frame;if(v.row!=l)v.row=l;}
    for(NSNumber *key in self.visibleRows.allKeys.copy){if(![needed containsObject:key]){[self.visibleRows[key] removeFromSuperview];[self.visibleRows removeObjectForKey:key];}}
}
- (void)resizeRoom {
    if(!self.scroll || !self.dataset){[self arrangeChrome];return;}NSDictionary *a=[self anchor];BOOL pinned=[self isPinned];self.changing=YES;[self arrangeChrome];[self rebuildPreserving:a pinned:pinned force:YES];
}
- (void)windowDidEndLiveResize:(NSNotification *)notification { [self updateState]; }
- (void)scrolled:(NSNotification *)notification {
    if(self.changing)return;[self materializeRows];
    if([self isPinned] && self.messages.lastObject.messageID==self.dataset.lastMessageID+self.liveMessages.count)self.unread=NO;
    [self updateState];
    if(self.scroll.contentView.bounds.origin.y<=1 && self.messages.firstObject.messageID>1 && !self.loadingOlder){self.loadingOlder=YES;NSInteger generation=self.pageGeneration;dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.pageGeneration)return;[self prependPage];self.loadingOlder=NO;});}
}
- (void)updateState {
    NSDictionary *a=[self anchor];CFKMessage *first=self.messages.firstObject,*last=self.messages.lastObject;
    NSString *state=[NSString stringWithFormat:@"first %ld last %ld loaded %lu pinned %@ top %ld y %.1f ms %ld",first.messageID,last.messageID,(unsigned long)self.messages.count,[self isPinned]?@"yes":@"no",[a[@"id"] integerValue],[a[@"offset"] doubleValue],self.elapsedMS];
    CGFloat naturalWidth=[state sizeWithAttributes:@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightRegular]}].width;
    self.stateLabel.font=[NSFont monospacedSystemFontOfSize:9*MIN(1,(self.stateLabel.bounds.size.width-1)/MAX(1,naturalWidth)) weight:NSFontWeightRegular];
    self.stateLabel.stringValue=state;[self.stateLabel setAccessibilityLabel:state];self.jumpButton.hidden=!self.unread;
}
- (void)beginAction { self.actionStart=CACurrentMediaTime(); }
- (void)finishAction {
    [self.root layoutSubtreeIfNeeded];[self.window displayIfNeeded];self.elapsedMS=llround((CACurrentMediaTime()-self.actionStart)*1000);[self updateState];[self.stateLabel displayIfNeeded];
}
- (void)reset:(id)sender {
    [self beginAction];self.boostGeneration++;[self.feedHandle cancel];self.feedHandle=nil;self.feed=nil;self.streamRunning=NO;self.streamLabel.stringValue=@"";[self.liveMessages removeAllObjects];[self.extraBoosts removeAllObjects];self.textStep=0;self.unread=NO;[self installPage:[self.dataset lastPage]];[self rebuildPreserving:nil pinned:YES force:YES];[self finishAction];
}
- (void)jumpTo2500:(id)sender {
    [self beginAction];[self installPage:[self.dataset pageAroundMessageID:2500]];[self rebuildPreserving:@{@"id":@2500,@"offset":@0} pinned:NO force:YES];[self finishAction];
}
- (void)prependPage {
    CFKPage *page=[self.dataset pageBeforeMessageID:self.messages.firstObject.messageID];if(!page.messages.count)return;
    NSDictionary *a=[self anchor];NSIndexSet *indexes=[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,page.messages.count)];[self.messages insertObjects:page.messages atIndexes:indexes];[self.presentations insertObjects:page.presentations atIndexes:indexes];
    [self rebuildPreserving:a pinned:NO force:NO];
}
- (void)loadOlder:(id)sender { [self beginAction];[self prependPage];[self finishAction]; }
- (void)textLarger:(id)sender {
    [self beginAction];NSDictionary *a=[self anchor];BOOL pin=[self isPinned];self.textStep=(self.textStep+1)%5;[self rebuildPreserving:a pinned:pin force:YES];[self finishAction];
}
- (void)resetTextSize:(id)sender {
    [self beginAction];NSDictionary *a=[self anchor];BOOL pinned=[self isPinned];self.textStep=0;[self rebuildPreserving:a pinned:pinned force:YES];[self finishAction];
}
- (void)jumpToBottom:(id)sender {
    BOOL latest=self.messages.lastObject.messageID==self.dataset.lastMessageID+self.liveMessages.count;
    if(!latest){[self installPage:[self.dataset lastPage]];for(CFKMessage *m in self.liveMessages){CFKMessage *previous=self.messages.lastObject;[self.messages addObject:m];[self.presentations addObject:[self.dataset presentationOf:m after:previous]];}}
    self.unread=NO;[self rebuildPreserving:nil pinned:YES force:NO];
}
- (void)startStream:(id)sender {
    if(self.streamRunning)return;self.streamRunning=YES;self.streamLabel.stringValue=@"";
    // Restarting a completed script would replay ids, so reset the stream state first.
    if(self.liveMessages.count){[self.liveMessages removeAllObjects];[self installPage:[self.dataset lastPage]];[self rebuildPreserving:nil pinned:YES force:YES];}
    self.feed=[[CFKLiveFeed alloc] initWithDataset:self.dataset];__weak typeof(self) weak=self;
    self.feedHandle=[self.feed startOnEvent:^(CFKFeedEvent *e){[weak receiveEvent:e];} completion:^{weak.streamRunning=NO;weak.streamLabel.stringValue=@"Stream done";[weak.streamLabel setAccessibilityLabel:@"Stream done"];[weak updateState];}];
}
- (void)receiveEvent:(CFKFeedEvent *)event {
    if(event.kind==CFKFeedEventKindMessage){
        [self.liveMessages addObject:event.message];BOOL pin=[self isPinned];NSDictionary *a=[self anchor];
        if(self.messages.lastObject.messageID==event.message.messageID-1){CFKMessage *previous=self.messages.lastObject;[self.messages addObject:event.message];[self.presentations addObject:[self.dataset presentationOf:event.message after:previous]];
            if(pin && self.messages.count>300){NSUInteger count=self.messages.count-300;[self.messages removeObjectsInRange:NSMakeRange(0,count)];[self.presentations removeObjectsInRange:NSMakeRange(0,count)];}
            [self rebuildPreserving:a pinned:pin force:NO];if(!pin)self.unread=YES;
        }else self.unread=YES;
        [self updateState];
    }else if(event.kind==CFKFeedEventKindBoost && event.boost){[self addBoostTo:event.messageID user:event.boost.boosterID content:event.boost.content];}
}
- (void)addBoostTo:(NSInteger)messageID user:(NSInteger)user content:(NSString *)content {
    NSNumber *key=@(messageID);if(!self.extraBoosts[key])self.extraBoosts[key]=[NSMutableArray new];[self.extraBoosts[key] addObject:@{@"user":@(user),@"content":content}];
    if([self layoutForID:messageID]){NSDictionary *a=[self anchor];BOOL pin=[self isPinned];[self rebuildPreserving:a pinned:pin force:NO];}
}
- (void)boostBurst:(id)sender {
    NSInteger generation=self.boostGeneration;NSInteger messageID=self.liveMessages.lastObject?self.liveMessages.lastObject.messageID:self.dataset.lastMessageID;NSArray *emoji=@[@"👍",@"🎉",@"🔥",@"❤️",@"😂"];
    for(NSInteger i=0;i<5;i++){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(i+1)*200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(generation==self.boostGeneration)[self addBoostTo:messageID user:i+2 content:emoji[i]];});}
}
- (void)runSelfTests {
    NSMutableArray *results=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[results addObject:@{@"test":name,@"passed":@(ok)}];NSLog(@"%@: %@",ok?@"PASS":@"FAIL",name);};
    check(self.messages.count==40 && self.messages.firstObject.messageID==49961 && [self isPinned],@"launch newest 40 pinned");
    check(self.elapsedMS<1000,@"first content under one second");
    NSLog(@"Startup: %ld ms",self.elapsedMS);
    BOOL accessible=self.debugButtons.count==6;for(NSButton *button in self.debugButtons)accessible=accessible && [button.accessibilityRole isEqual:NSAccessibilityButtonRole] && [button.accessibilityLabel isEqual:button.title];
    check(accessible && [self.stateLabel.accessibilityRole isEqual:NSAccessibilityStaticTextRole],@"benchmark controls expose standard accessibility roles and labels");
    check(fabs(self.root.bounds.size.width-393)<.1 && fabs(self.root.bounds.size.height-852)<.1,@"initial content is 393 by 852 points");
    [self jumpTo2500:nil];check([self.anchor[@"id"] integerValue]==2500 && fabs([self.anchor[@"offset"] doubleValue])<2,@"jump 2500 aligned below header");
    NSDictionary *before=[self anchor];[self loadOlder:nil];NSDictionary *after=[self anchor];check([before[@"id"] isEqual:after[@"id"]] && fabs([before[@"offset"] doubleValue]-[after[@"offset"] doubleValue])<2,@"prepend preserves visible message");
    for(NSInteger i=0;i<5;i++){before=[self anchor];[self textLarger:nil];after=[self anchor];check([before[@"id"] isEqual:after[@"id"]] && fabs([before[@"offset"] doubleValue]-[after[@"offset"] doubleValue])<2,[NSString stringWithFormat:@"text step %ld preserves anchor",i+1]);}
    before=[self anchor];[self.window setContentSize:NSMakeSize(1200,1200)];after=[self anchor];check([before[@"id"] isEqual:after[@"id"]] && fabs([before[@"offset"] doubleValue]-[after[@"offset"] doubleValue])<2,@"resize to 1200 preserves anchor");
    [self.window setContentSize:NSMakeSize(393,852)];
    // Exercise fractional anchoring and the actual AppKit text and scroll responders.
    [self jumpTo2500:nil];self.changing=YES;
    [self.scroll.contentView scrollToPoint:NSMakePoint(0,[self layoutForID:2500].y+12.5)];self.changing=NO;[self materializeRows];
    before=[self anchor];[self textLarger:nil];after=[self anchor];
    check([before[@"id"] isEqual:after[@"id"]] && fabs([before[@"offset"] doubleValue]-[after[@"offset"] doubleValue])<2,@"fractional anchor survives reflow");
    CFRowView *selectable=nil;NSTextView *textView=nil;
    for(CFRowView *v in self.visibleRows.allValues){for(NSView *child in v.subviews){if([child isKindOfClass:NSTextView.class] && ((NSTextView *)child).string.length>=4){selectable=v;textView=(NSTextView *)child;break;}}if(textView)break;}
    check(textView.selectable && !textView.editable,@"message uses native selectable text");
    [textView setSelectedRange:NSMakeRange(0,4)];[textView copy:nil];
    check([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqual:[textView.string substringToIndex:4]],@"native selected-range copy");
    NSEvent *rightClick=[NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:self.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:0];
    NSMenu *context=[selectable menuForEvent:rightClick];
    check(context.itemArray.count==2 && [context.itemArray[0].title isEqual:@"Copy"] && [context.itemArray[1].title isEqual:@"Reply"],@"context menu contains Copy and Reply");
    [NSApp sendAction:context.itemArray[0].action to:context.itemArray[0].target from:context.itemArray[0]];
    check([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqual:selectable.row.message.plainText],@"context Copy copies whole message");
    CGFloat wheelBefore=self.scroll.contentView.bounds.origin.y;
    CGEventRef wheel=CGEventCreateScrollWheelEvent(NULL,kCGScrollEventUnitPixel,1,-90);NSEvent *wheelEvent=[NSEvent eventWithCGEvent:wheel];[textView scrollWheel:wheelEvent];CFRelease(wheel);
    check(fabs(self.scroll.contentView.bounds.origin.y-wheelBefore)>1,@"wheel scroll works over message text");
    NSUInteger loadedBefore=self.messages.count;self.changing=YES;[self.scroll.contentView scrollToPoint:NSZeroPoint];self.changing=NO;[self scrolled:nil];
    dispatch_async(dispatch_get_main_queue(),^{
    check(self.messages.count==loadedBefore+40,@"reaching top automatically loads 40 older");
    [self reset:nil];CGFloat h=self.contentHeight;NSInteger last=self.messages.lastObject.messageID;
    for(NSInteger i=0;i<5;i++)[self addBoostTo:last user:i+2 content:@[@"👍",@"🎉",@"🔥",@"❤️",@"😂"][i]];
    check([self isPinned] && self.contentHeight>h,@"boost growth remains pinned");
    [self jumpTo2500:nil];NSDictionary *boostBefore=[self anchor];[self addBoostTo:2500 user:2 content:@"👍"];NSDictionary *boostAfter=[self anchor];check([boostBefore[@"id"] isEqual:boostAfter[@"id"]] && fabs([boostBefore[@"offset"] doubleValue]-[boostAfter[@"offset"] doubleValue])<2,@"boost growth preserves anchor");
    [self reset:nil];[self startStream:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        check(self.liveMessages.count>=20 && [self isPinned],@"live stream appends and pins");
        self.changing=YES;[self.scroll.contentView scrollToPoint:NSMakePoint(0,MAX(1,self.contentHeight-self.scroll.contentView.bounds.size.height-600))];self.changing=NO;[self materializeRows];NSDictionary *a=[self anchor];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            NSDictionary *b=[self anchor];check([a[@"id"] isEqual:b[@"id"]] && fabs([a[@"offset"] doubleValue]-[b[@"offset"] doubleValue])<2 && !self.jumpButton.hidden,@"unpinned stream preserves anchor and shows jump");
            [self jumpToBottom:nil];check([self isPinned] && self.jumpButton.hidden,@"jump to bottom resumes pinning");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,29*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                check([self.streamLabel.stringValue isEqual:@"Stream done"] && self.liveMessages.count==600,@"stream completes with 600 messages");
                check(self.messages.count<=300 && [self isPinned],@"stream retains bounded pinned window");
                NSData *data=[NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:nil];[data writeToFile:@"/tmp/campfire-self-tests.json" atomically:YES];[NSApp terminate:nil];
            });
        });
    });
    });
}
@end
