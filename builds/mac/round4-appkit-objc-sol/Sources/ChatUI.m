#import "ChatUI.h"

static BOOL CFDark(void) { return [[NSAppearance.currentDrawingAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua]; }
static NSColor *CFHex(NSString *s) { unsigned rgb=0; [[NSScanner scannerWithString:s] scanHexInt:&rgb]; return [NSColor colorWithSRGBRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1]; }
NSColor *CFColor(NSString *light, NSString *dark) { return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *a) { return CFHex([[a bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua] ? dark : light); }]; }
NSColor *CFBackground(void) { return CFColor(@"FFFFFF",@"000000"); }
NSColor *CFText(void) { return CFColor(@"000000",@"FFFFFF"); }
NSColor *CFBubble(void) { return CFColor(@"F3F2EE",@"222222"); }
NSFont *CFFont(CGFloat size, BOOL bold) { return [NSFont systemFontOfSize:size weight:bold?NSFontWeightBold:NSFontWeightRegular]; }
void CFDraw(NSString *text, NSRect rect, CGFloat size, BOOL bold, NSColor *color) { [text drawInRect:rect withAttributes:@{NSFontAttributeName:CFFont(size,bold), NSForegroundColorAttributeName:color}]; }
void CFRound(NSRect rect, CGFloat radius, NSColor *fill, NSColor *stroke, CGFloat line) { NSBezierPath *p=[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius]; if(fill){[fill setFill];[p fill];} if(stroke){[stroke setStroke];p.lineWidth=line;[p stroke];} }
void CFIcon(NSString *name, NSRect rect, NSColor *color) {
    if([name isEqual:@"line.3.horizontal"]){
        NSBezierPath *p=[NSBezierPath bezierPath];for(int i=0;i<3;i++){CGFloat y=rect.origin.y+1+i*(rect.size.height-2)/2;[p moveToPoint:NSMakePoint(rect.origin.x,y)];[p lineToPoint:NSMakePoint(NSMaxX(rect),y)];}p.lineWidth=2.5;p.lineCapStyle=NSLineCapStyleRound;[color setStroke];[p stroke];return;
    }
    if([name isEqual:@"bubble"]){
        NSBezierPath *p=[NSBezierPath bezierPath];CGFloat x=rect.origin.x,y=rect.origin.y,w=rect.size.width,h=rect.size.height;
        [p moveToPoint:NSMakePoint(x+3,y+h-1)];[p lineToPoint:NSMakePoint(x+5,y+h-7)];
        [p curveToPoint:NSMakePoint(x+1,y+h*.45) controlPoint1:NSMakePoint(x+1,y+h*.7) controlPoint2:NSMakePoint(x+1,y+h*.6)];
        [p curveToPoint:NSMakePoint(x+w/2,y+1) controlPoint1:NSMakePoint(x+1,y+2) controlPoint2:NSMakePoint(x+w*.3,y+1)];
        [p curveToPoint:NSMakePoint(x+w-1,y+h*.45) controlPoint1:NSMakePoint(x+w*.85,y+1) controlPoint2:NSMakePoint(x+w-1,y+3)];
        [p curveToPoint:NSMakePoint(x+10,y+h-5) controlPoint1:NSMakePoint(x+w-1,y+h*.8) controlPoint2:NSMakePoint(x+w*.7,y+h-3)];
        [p closePath];p.lineWidth=2;p.lineJoinStyle=NSLineJoinStyleRound;[color setStroke];[p stroke];return;
    }
    NSImage *symbol=[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    symbol=[symbol imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:rect.size.height weight:NSFontWeightSemibold]];
    NSImage *tinted=[NSImage imageWithSize:rect.size flipped:YES drawingHandler:^BOOL(NSRect dst){
        CGFloat fit=MIN(dst.size.width/MAX(1,symbol.size.width),dst.size.height/MAX(1,symbol.size.height));
        NSRect fitted=NSMakeRect(NSMidX(dst)-symbol.size.width*fit/2,NSMidY(dst)-symbol.size.height*fit/2,symbol.size.width*fit,symbol.size.height*fit);
        [symbol drawInRect:fitted fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        [color setFill];NSRectFillUsingOperation(dst,NSCompositingOperationSourceIn);return YES;
    }];
    [tinted drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}
static void CFAvatar(CFKUser *u, NSRect frame) {
    static NSArray<NSString *> *palette;static dispatch_once_t once;
    dispatch_once(&once,^{palette=@[@"AF2E1B",@"CC6324",@"3B4B59",@"BFA07A",@"ED8008",@"ED3F1C",@"BF1B1B",@"736B1E",@"D07B53",@"736356",@"AD1D1D",@"BF7C2A",@"C09C6F",@"698F9C",@"7C956B",@"5D618F",@"3B3633",@"67695E"];});
    NSData *identifier=[[NSString stringWithFormat:@"%ld",u.userID] dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t crc=0xffffffff;for(NSUInteger i=0;i<identifier.length;i++){crc^=((const uint8_t *)identifier.bytes)[i];for(int bit=0;bit<8;bit++)crc=(crc>>1)^((crc&1)?0xedb88320:0);}crc^=0xffffffff;
    CFRound(frame,frame.size.width/2,CFHex(palette[crc%palette.count]),CFBackground(),2);
    NSString *initial=u.name.length?[u.name substringToIndex:1]:@"?";CGFloat fs=frame.size.width*.47;
    NSSize sz=[initial sizeWithAttributes:@{NSFontAttributeName:CFFont(fs,YES)}];
    CFDraw(initial,NSMakeRect(NSMidX(frame)-sz.width/2,NSMidY(frame)-sz.height/2,sz.width,sz.height),fs,YES,NSColor.whiteColor);
}
@implementation CFFlippedView
- (BOOL)isFlipped { return YES; }
@end
@implementation CFDocument
- (void)drawRect:(NSRect)dirty { [CFBackground() setFill];NSRectFill(dirty); }
@end
@implementation CFChrome
- (void)drawRect:(NSRect)dirty {
    CGFloat w=self.bounds.size.width; [CFBackground() setFill];NSRectFill(self.bounds);
    NSColor *border=CFColor(@"AFAEAA",@"555555");
    if(self.composer){
        CGFloat y=24; CFRound(NSMakeRect(14.0,y,41.6,41.6),21,CFBackground(),border,1);
        CFIcon(@"magnifyingglass",NSMakeRect(24,y+10,22,22),CFText());
        CFRound(NSMakeRect(66.1,y,w-80.1,41.6),21,CFBackground(),border,1);
        CFIcon(@"bubble",NSMakeRect(80,y+10,22,22),CFText());
        CFIcon(@"paperclip",NSMakeRect(w-91,y+11,20,20),CFText());
        CFRound(NSMakeRect(w-53,y+3.8,34,34),17,CFText(),nil,0);
        CFIcon(@"arrow.up",NSMakeRect(w-44,y+12,16,18),CFBackground());
    } else {
        CFRound(NSMakeRect(10,8,97,42),8,CFText(),nil,0);
        CFDraw(self.roomName?:@"General",NSMakeRect(10,18.5,97,27),16,YES,CFBackground());
        // Centre the room label precisely in its tab.
        NSRect tab=NSMakeRect(10,8,97,42); CFRound(tab,8,CFText(),nil,0);
        NSString *title=self.roomName?:@"General";CGFloat tw=[title sizeWithAttributes:@{NSFontAttributeName:CFFont(16,YES)}].width;
        CFDraw(title,NSMakeRect(58.5-tw/2,19,tw,23),16,YES,CFBackground());
        CFRound(NSMakeRect(113,8,41.6,41.6),21,CFBackground(),border,1);
        CFIcon(@"ellipsis",NSMakeRect(123,18,22,22),CFText());
        CFRound(NSMakeRect(158.8,6.5,45,45),23,nil,CFColor(@"FF7800",@"FF7800"),3);
        CFRound(NSMakeRect(160.5,8,41.6,41.6),21,CFBackground(),border,1);
        CFIcon(@"bell.fill",NSMakeRect(171,19,18,20),CFText());
        CFIcon(@"exclamationmark.triangle.fill",NSMakeRect(176,25,16,16),CFText());
        CFRound(NSMakeRect(w-52.5,8,41.6,41.6),21,CFBackground(),border,1);
        CFIcon(@"line.3.horizontal",NSMakeRect(w-41,20,19,18),CFText());
    }
}
@end
@implementation CFWelcome
- (void)drawRect:(NSRect)dirty {
    CGFloat w=self.bounds.size.width;
    CFRound(NSMakeRect(14,109,w-28,269),10.56,CFBubble(),nil,0);
    NSRect logo=NSMakeRect(w/2-34.5,85,69,69);
    [NSGraphicsContext saveGraphicsState];[[NSBezierPath bezierPathWithRoundedRect:logo xRadius:12 yRadius:12] addClip];
    NSGradient *gradient=[[NSGradient alloc] initWithStartingColor:CFHex(@"651B77") endingColor:CFHex(@"19051D")];[gradient drawInRect:logo angle:65];
    NSArray *rainbow=@[@"DB168F",@"EF175A",@"FF5428",@"FF9C00",@"FFE43D",@"58CBEC",@"A8E6FA"];
    for(NSInteger i=0;i<12;i++){
        CGFloat x=NSMidX(logo)-13+i*1.8,y=logo.origin.y+17+fabs(i-5.5)*1.7;
        NSBezierPath *line=[NSBezierPath bezierPath];[line moveToPoint:NSMakePoint(x,y)];
        [line curveToPoint:NSMakePoint(x+13,logo.origin.y+51-fabs(i-6.0)*1.4) controlPoint1:NSMakePoint(x+4,y+8) controlPoint2:NSMakePoint(x+20,logo.origin.y+59-fabs(i-6.0)*1.6)];
        line.lineWidth=2.1;line.lineCapStyle=NSLineCapStyleRound;[CFHex(rainbow[MIN(6,i/2)]) setStroke];[line stroke];
    }[NSGraphicsContext restoreGraphicsState];
    CFRound(NSMakeRect(30,125,41.6,41.6),21,CFBackground(),CFColor(@"AFAEAA",@"555555"),1);
    CFDraw(@"🌎",NSMakeRect(42,136,22,24),16,NO,CFText());
    NSString *title=@"Welcome to Campfire";CGFloat tw=[title sizeWithAttributes:@{NSFontAttributeName:CFFont(16,YES)}].width;
    CFDraw(title,NSMakeRect(w/2-tw/2,188,tw,24),16,YES,CFText());
    NSMutableParagraphStyle *p=[NSMutableParagraphStyle new];p.alignment=NSTextAlignmentCenter;p.minimumLineHeight=22.4;p.maximumLineHeight=22.4;
    [@"To invite people to chat, share the join link\nbelow." drawInRect:NSMakeRect(30,211,w-60,48) withAttributes:@{NSFontAttributeName:CFFont(16,NO),NSForegroundColorAttributeName:CFText(),NSParagraphStyleAttributeName:p}];
    CFRound(NSMakeRect(30,270,w-60,39.5),8,CFBackground(),CFColor(@"AFAEAA",@"555555"),1);
    CFIcon(@"person.badge.plus.fill",NSMakeRect(44,280,18,19),CFText());
    CFDraw(@"http://127.0.0.1:3055/join/GwHG-HbZN",NSMakeRect(72,281,w-108,23),15.4,NO,CFText());
    NSArray *icons=@[@"qrcode.viewfinder",@"doc.on.clipboard",@"square.and.arrow.up"];
    for(NSInteger i=0;i<3;i++){CGFloat x=w/2-78+i*52;CFRound(NSMakeRect(x,326,41.6,41.6),21,CFBackground(),CFColor(@"AFAEAA",@"555555"),1);CFIcon(icons[i],NSMakeRect(x+11,337,20,21),CFText());}
}
@end

static NSMutableAttributedString *CFAttributed(NSString *string, CGFloat size, CGFloat line, BOOL mono) {
    NSMutableParagraphStyle *p=[NSMutableParagraphStyle new];p.minimumLineHeight=line;p.maximumLineHeight=line;p.lineBreakMode=NSLineBreakByWordWrapping;
    NSFont *f=mono?[NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular]:CFFont(size,NO);
    return [[NSMutableAttributedString alloc] initWithString:string?:@"" attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:CFText(), NSParagraphStyleAttributeName:p}];
}
static NSSize CFMeasure(NSAttributedString *s, CGFloat width) {
    if(!s.length) return NSZeroSize;
    NSTextStorage *storage=[[NSTextStorage alloc] initWithAttributedString:s];NSLayoutManager *lm=[NSLayoutManager new];NSTextContainer *tc=[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width,CGFLOAT_MAX)];tc.lineFragmentPadding=0;[lm addTextContainer:tc];[storage addLayoutManager:lm];[lm ensureLayoutForTextContainer:tc];NSRect r=[lm usedRectForTextContainer:tc];return NSMakeSize(ceil(r.size.width),ceil(r.size.height));
}
@implementation CFRowLayout
+ (instancetype)layoutMessage:(CFKMessage *)m presentation:(CFKPresentation *)pr dataset:(CFKDataset *)d width:(CGFloat)width scale:(CGFloat)s extraBoosts:(NSArray *)extras {
    CFRowLayout *l=[CFRowLayout new];l.message=m;l.presentation=pr;l.user=[d userWithID:m.creatorID];l.scale=s;
    static NSDateFormatter *tf,*df;static dispatch_once_t once;dispatch_once(&once,^{tf=[NSDateFormatter new];tf.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];tf.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];tf.dateFormat=@"h:mm a";df=[NSDateFormatter new];df.locale=tf.locale;df.timeZone=tf.timeZone;df.dateFormat=@"MMMM d, yyyy";});
    l.time=[tf stringFromDate:m.createdAt];l.day=[[df stringFromDate:m.createdAt] uppercaseString];
    CGFloat px=15.12*s, py=10.56*s, meta=19.2*s, bodyTop=py+meta+2.76*s;
    CGFloat maxW=MAX(100,width-54.8-(pr.isMine?50.23:0));
    NSMutableAttributedString *body=CFAttributed(@"",16*s,22.4*s,NO);NSMutableAttributedString *code=nil;
    for(CFKBlock *b in m.blocks){
        if(b.kind==CFKBlockKindCode){code=CFAttributed(b.text,12.8*s,17.92*s,YES);}
        else if(b.kind==CFKBlockKindMention){NSString *name=[d userWithID:b.mentionedUserID].name?:@"Someone";NSMutableAttributedString *a=CFAttributed(name,16*s,22.4*s,NO);[a addAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:16*s weight:NSFontWeightSemibold],NSBackgroundColorAttributeName:[CFColor(@"BE1600",@"FF7563") colorWithAlphaComponent:.14]} range:NSMakeRange(0,a.length)];[body appendAttributedString:a];}
        else { [body appendAttributedString:CFAttributed(b.text, m.isEmojiOnly?38.4*s:16*s,m.isEmojiOnly?53.76*s:22.4*s,NO)]; }
    }
    if(code){
        // Highlight token categories without interpreting the message body as markup.
        NSArray *patterns=@[@"\\b(def|end|func|let|return|if|else|import|class|const|var)\\b",@"\\b(greet|print|console|puts)\\b",@"\"[^\"]*\"",@"#[^\\n]*"];
        NSArray *colors=@[CFColor(@"D73A49",@"FF7B72"),CFColor(@"6F42C1",@"D2A8FF"),CFColor(@"032F62",@"79C0FF"),CFColor(@"6A737D",@"8B949E")];
        for(NSUInteger i=0;i<patterns.count;i++){NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:patterns[i] options:0 error:nil];for(NSTextCheckingResult *match in [re matchesInString:code.string options:0 range:NSMakeRange(0,code.length)]){[code addAttribute:NSForegroundColorAttributeName value:colors[i] range:match.range];}}
    }
    l.body=body;l.code=code;
    NSSize textSize=CFMeasure(body,maxW-2*px);NSSize codeSize=CFMeasure(code,maxW-2*px-25.6*s);
    CGFloat headW=([l.time sizeWithAttributes:@{NSFontAttributeName:CFFont(12.8*s,NO)}].width+26*s)+(pr.isThreaded?0:[l.user.name sizeWithAttributes:@{NSFontAttributeName:CFFont(12.8*s,YES)}].width+4*s);
    CGFloat bw=MIN(maxW,MAX(headW+2*px,textSize.width+2*px));
    if(code)bw=MIN(maxW,MAX(bw,codeSize.width+2*px+25.6*s));
    if(m.attachment && m.attachment.kind==CFKAttachmentKindImage)bw=MIN(300,maxW);
    if(m.attachment && m.attachment.kind==CFKAttachmentKindFile)bw=MIN(maxW,MAX(bw,283.11*s));
    CGFloat by=pr.isFirstOfDay?70.4:1.59;
    CGFloat bx=pr.isMine?width-40.8-bw:40.8;
    CGFloat cursor=bodyTop;
    if(body.length){l.textFrame=NSMakeRect(bx+px,by+cursor,bw-2*px,textSize.height);cursor+=textSize.height;}
    if(code){if(body.length)cursor+=8*s;else cursor+=1.97*s;l.codeFrame=NSMakeRect(bx+px,by+cursor,bw-2*px,codeSize.height+25.6*s);cursor+=l.codeFrame.size.height;}
    if(m.attachment){
        if(m.attachment.kind==CFKAttachmentKindImage){if(body.length)cursor+=8*s;else cursor=43.97*s;CGFloat ih=(bw-2)*m.attachment.height/MAX(1.0,(CGFloat)m.attachment.width);l.attachmentFrame=NSMakeRect(bx+1,by+cursor,bw-2,ih);cursor+=ih;}
        else {l.attachmentFrame=NSMakeRect(bx+px,by+bodyTop,bw-2*px,24*s);cursor=66.44*s;}
    }
    NSMutableArray *boosts=[NSMutableArray new];for(CFKBoost *b in m.boosts){[boosts addObject:@{@"user":@(b.boosterID),@"content":b.content}];}[boosts addObjectsFromArray:extras?:@[]];l.boosts=boosts;
    NSMutableArray *frames=[NSMutableArray new];
    if(boosts.count){CGFloat x=0,y=cursor+4*s;CGFloat available=bw-2*px;
        for(NSDictionary *b in boosts){CGFloat pw=MIN(available,28*s+[b[@"content"] sizeWithAttributes:@{NSFontAttributeName:CFFont(17.6*s,NO)}].width+7*s);if(x>0 && x+pw>available){x=0;y+=32.64*s;}[frames addObject:[NSValue valueWithRect:NSMakeRect(bx+px+x,by+y,pw,28.64*s)]];x+=pw+6*s;}
        if(x+28.64*s>available){x=0;y+=32.64*s;}l.addBoostFrame=NSMakeRect(bx+px+x,by+y,28.64*s,28.64*s);cursor=y+28.64*s;
    }l.boostFrames=frames;
    l.bubble=NSMakeRect(bx,by,bw,cursor+((m.attachment && m.attachment.kind==CFKAttachmentKindImage)?8.453*s:py));l.height=NSMaxY(l.bubble)+1.6;
    return l;
}
@end

@interface CFMessageText : NSTextView
@property NSString *messageText;
@end
@implementation CFMessageText
- (NSMenu *)menuForEvent:(NSEvent *)event { NSMenu *m=[NSMenu new];NSMenuItem *c=[[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copyMessage:) keyEquivalent:@""];c.target=self;[m addItem:c];NSMenuItem *r=[[NSMenuItem alloc] initWithTitle:@"Reply" action:@selector(reply:) keyEquivalent:@""];r.target=self;[m addItem:r];return m; }
- (void)copyMessage:(id)sender { [NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:self.messageText forType:NSPasteboardTypeString]; }
- (void)reply:(id)sender {}
@end
@implementation CFRowView
- (void)setRow:(CFRowLayout *)row {
    _row=row;for(NSView *v in self.subviews.copy)[v removeFromSuperview];
    NSArray *texts=@[row.body?:[[NSAttributedString alloc] initWithString:@""],row.code?:[[NSAttributedString alloc] initWithString:@""]];
    for(NSUInteger i=0;i<texts.count;i++){NSAttributedString *text=texts[i];if(!text.length)continue;NSRect frame=i?NSInsetRect(row.codeFrame,12.8*row.scale,12.8*row.scale):row.textFrame;
        CFMessageText *v=[[CFMessageText alloc] initWithFrame:frame];v.editable=NO;v.selectable=YES;v.drawsBackground=NO;v.textContainerInset=NSZeroSize;v.textContainer.lineFragmentPadding=0;v.textContainer.containerSize=NSMakeSize(frame.size.width,CGFLOAT_MAX);v.horizontallyResizable=NO;v.verticallyResizable=NO;v.richText=YES;v.importsGraphics=NO;v.messageText=row.message.plainText;v.automaticLinkDetectionEnabled=NO;[v.textStorage setAttributedString:text];[v setAccessibilityLabel:[NSString stringWithFormat:@"Message %ld",row.message.messageID]];[self addSubview:v];
    }self.needsDisplay=YES;
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu=[NSMenu new];
    NSMenuItem *copy=[[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copyMessage:) keyEquivalent:@""];copy.target=self;[menu addItem:copy];
    NSMenuItem *reply=[[NSMenuItem alloc] initWithTitle:@"Reply" action:@selector(reply:) keyEquivalent:@""];reply.target=self;[menu addItem:reply];return menu;
}
- (void)copyMessage:(id)sender { [NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:self.row.message.plainText forType:NSPasteboardTypeString]; }
- (void)reply:(id)sender {}
- (void)drawRect:(NSRect)dirty {
    CFRowLayout *l=self.row;if(!l)return;CGFloat s=l.scale;CFKPresentation *p=l.presentation;
    if(p.isFirstOfDay){CGFloat cy=17.02;CGFloat textw=[l.day sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12.8 weight:NSFontWeightSemibold]}].width;CGFloat pw=textw+47;CGFloat w=self.bounds.size.width;[CFBubble() setFill];NSRectFill(NSMakeRect(14,cy+17, w-28,2));CFRound(NSMakeRect((w-pw)/2,cy,pw,35),18,CFBubble(),nil,0);CFDraw(l.day,NSMakeRect((w-textw)/2,cy+8.5,textw,19),12.8,YES,CFText());}
    NSColor *bg=p.mentionsMe?[CFColor(@"BE1600",@"FF7563") colorWithAlphaComponent:CFDark()?.20:.10]:CFBubble();
    if(!l.message.isEmojiOnly)CFRound(l.bubble,10.56,bg,nil,0);
    if(!p.isThreaded){CGFloat ax=p.isMine?self.bounds.size.width-49.27:14;CFAvatar(l.user,NSMakeRect(ax,l.bubble.origin.y,35.27,35.27));}
    CGFloat px=15.12*s;CGFloat yy=l.bubble.origin.y+10.56*s;CGFloat x=l.bubble.origin.x+px;
    CGFloat namew=[l.user.name sizeWithAttributes:@{NSFontAttributeName:CFFont(12.8*s,YES)}].width;
    CGFloat timew=[l.time sizeWithAttributes:@{NSFontAttributeName:CFFont(12.8*s,NO)}].width;
    NSColor *muted=[CFText() colorWithAlphaComponent:.5];
    if(p.isMine){x=NSMaxX(l.bubble)-px;if(!p.isThreaded){x-=namew;CFDraw(l.user.name,NSMakeRect(x,yy,namew,20*s),12.8*s,YES,CFText());x-=4*s;}x-=timew;CFDraw(l.time,NSMakeRect(x,yy,timew,20*s),12.8*s,NO,muted);CFDraw(@"•••",NSMakeRect(x-29*s,yy-1*s,23*s,20*s),12.8*s,YES,muted);}
    else{if(!p.isThreaded){CFDraw(l.user.name,NSMakeRect(x,yy,namew,20*s),12.8*s,YES,CFText());x+=namew+4*s;}CFDraw(l.time,NSMakeRect(x,yy,timew,20*s),12.8*s,NO,muted);CFDraw(@"•••",NSMakeRect(x+timew+11*s,yy-1*s,23*s,20*s),12.8*s,YES,muted);}
    if(l.code.length)CFRound(l.codeFrame,6.4,CFBackground(),nil,0);
    CFKAttachment *a=l.message.attachment;
    if(a && a.kind==CFKAttachmentKindImage){NSColor *c=[NSColor colorWithSRGBRed:a.red/255.0 green:a.green/255.0 blue:a.blue/255.0 alpha:1];[NSGraphicsContext saveGraphicsState];[[NSBezierPath bezierPathWithRoundedRect:l.bubble xRadius:10.56 yRadius:10.56] addClip];[c setFill];NSRectFill(l.attachmentFrame);[NSGraphicsContext restoreGraphicsState];}
    if(a && a.kind==CFKAttachmentKindFile){NSRect f=l.attachmentFrame;CFIcon(@"doc.text.fill",NSMakeRect(f.origin.x,f.origin.y+1*s,18*s,22*s),CFText());CFDraw(a.name,NSMakeRect(f.origin.x+26*s,f.origin.y+2*s,MAX(0,f.size.width-72*s),24*s),16*s,NO,CFText());CFIcon(@"arrow.down.to.line",NSMakeRect(NSMaxX(f)-49*s,f.origin.y+3*s,18*s,19*s),CFText());CFIcon(@"square.and.arrow.up",NSMakeRect(NSMaxX(f)-13*s,f.origin.y+3*s,14*s,19*s),CFText());}
    for(NSUInteger i=0;i<l.boosts.count;i++){NSRect f=[l.boostFrames[i] rectValue];CFRound(f,14.32*s,CFBackground(),CFColor(@"E5E4E1",@"2E2E2E"),1);NSDictionary *b=l.boosts[i];CFAvatar([self.dataset userWithID:[b[@"user"] integerValue]],NSMakeRect(f.origin.x+1.6*s,f.origin.y+2.8*s,23*s,23*s));CFDraw(b[@"content"],NSMakeRect(f.origin.x+28*s,f.origin.y+4*s,f.size.width-29*s,24*s),17.6*s,NO,CFText());}
    if(l.boosts.count){CFRound(l.addBoostFrame,14.32*s,CFBackground(),CFColor(@"E5E4E1",@"2E2E2E"),1);CFIcon(@"face.smiling",NSInsetRect(l.addBoostFrame,6*s,6*s),CFText());CFDraw(@"+",NSMakeRect(NSMaxX(l.addBoostFrame)-12*s,NSMaxY(l.addBoostFrame)-16*s,10*s,13*s),10*s,YES,CFText());}
}
@end
