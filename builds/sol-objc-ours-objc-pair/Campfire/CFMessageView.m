#import "CFMessageView.h"

static UIColor *CFHex(unsigned value) { return [UIColor colorWithRed:((value>>16)&255)/255.0 green:((value>>8)&255)/255.0 blue:(value&255)/255.0 alpha:1]; }
static UIColor *CFAdaptive(unsigned light, unsigned dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) { return CFHex(traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light); }];
}
UIColor *CFBackground(void) { return CFAdaptive(0xFFFFFF, 0x000000); }
UIColor *CFText(void) { return CFAdaptive(0x000000, 0xFFFFFF); }
UIColor *CFBubble(void) { return CFAdaptive(0xF3F2EE, 0x222222); }
UIColor *CFBorder(void) { return CFAdaptive(0xAFAEAA, 0x555555); }
UIColor *CFAvatarColor(NSInteger userID) {
    static const unsigned palette[] = {0xAF2E1B,0xCC6324,0x3B4B59,0xBFA07A,0xED8008,0xED3F1C,0xBF1B1B,0x736B1E,0xD07B53,0x736356,0xAD1D1D,0xBF7C2A,0xC09C6F,0x698F9C,0x7C956B,0x5D618F,0x3B3633,0x67695E};
    NSData *bytes = [[@(userID) stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t crc = 0xFFFFFFFF; const uint8_t *p = bytes.bytes;
    for (NSUInteger i=0;i<bytes.length;i++) { crc ^= p[i]; for(int j=0;j<8;j++) crc = (crc&1) ? (crc>>1)^0xEDB88320 : crc>>1; }
    return CFHex(palette[(crc^0xFFFFFFFF)%18]);
}
UIFont *CFFont(CGFloat size, UIFontWeight weight, CGFloat scale) { return [UIFont systemFontOfSize:size*scale weight:weight]; }
UILabel *CFLabel(NSString *text, UIFont *font) { UILabel *label=[UILabel new]; label.text=text; label.font=font; label.textColor=CFText(); return label; }
UIButton *CFIconButton(NSString *symbol, NSString *label) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    NSDictionary *assets=@{@"magnifyingglass":@"search",@"ellipsis":@"menu-dots-horizontal",@"line.3.horizontal":@"menu",@"bell.badge.fill":@"notification-bell-alert",@"bubble.left":@"messages-outlined",@"paperclip":@"attachment",@"arrow.up":@"arrow-up",@"face.smiling.badge.plus":@"boost",@"arrow.down.to.line":@"download",@"square.and.arrow.up":@"share",@"qrcode.viewfinder":@"qr-code",@"doc.on.clipboard":@"copy-paste"};
    UIImage *art=[UIImage imageNamed:assets[symbol] ?: @""];
    if(art) art=[art imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    else art=[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightSemibold]];
    [b setImage:art forState:UIControlStateNormal]; b.imageView.contentMode=UIViewContentModeScaleAspectFit;
    b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;
    if(assets[symbol]) { UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(22,22)]; UIImage *sized=[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) { [art drawInRect:CGRectMake(0,0,22,22)]; }]; [b setImage:[sized imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal]; }
    b.tintColor=CFText(); b.accessibilityLabel=label; return b;
}
static UIImage *CFInitial(CFKUser *user, CGFloat size) {
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size,size)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [CFAvatarColor(user.userID) setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,size,size)] fill];
        NSString *initial=[user.name substringToIndex:1];
        NSDictionary *attrs=@{NSFontAttributeName:CFFont(size*.48,UIFontWeightBold,1),NSForegroundColorAttributeName:UIColor.whiteColor};
        CGSize measured=[initial sizeWithAttributes:attrs];
        [initial drawAtPoint:CGPointMake((size-measured.width)/2,(size-measured.height)/2) withAttributes:attrs];
    }];
}
static NSDictionary *CFAttributes(UIFont *font, CGFloat lineHeight) {
    NSMutableParagraphStyle *paragraph=[NSMutableParagraphStyle new];
    paragraph.minimumLineHeight=lineHeight; paragraph.maximumLineHeight=lineHeight;
    return @{NSFontAttributeName:font,NSForegroundColorAttributeName:CFText(),NSParagraphStyleAttributeName:paragraph};
}
static CGSize CFMeasure(NSAttributedString *text, CGFloat width) {
    if (!text.length) return CGSizeZero;
    CGRect r=[text boundingRectWithSize:CGSizeMake(MAX(1,width),CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading context:nil];
    return CGSizeMake(ceil(r.size.width*3)/3,ceil(r.size.height*3)/3);
}
@implementation CFRow
- (void)measureWidth:(CGFloat)width scale:(CGFloat)scale {
    _scale=scale; self.viewportWidth=width; CFKMessage *m=self.message; CFKPresentation *pr=self.presentation;
    CGFloat maxWidth=pr.isMine ? width-105.03 : width-54.8;
    maxWidth=MAX(120,maxWidth); CGFloat inner=maxWidth-30.24;
    NSMutableAttributedString *text=[NSMutableAttributedString new];
    NSMutableAttributedString *code=[NSMutableAttributedString new];
    NSDictionary *attrs=CFAttributes(CFFont(m.isEmojiOnly ? 38.4 : 16,UIFontWeightRegular,scale),(m.isEmojiOnly ? 53.76 : 22.4)*scale);
    for (CFKBlock *block in m.blocks) {
        if (block.kind==CFKBlockKindMention) {
            CFKUser *user=self.users[@(block.mentionedUserID)];
            NSTextAttachment *avatar=[NSTextAttachment new]; avatar.image=CFInitial(user,18*scale); avatar.bounds=CGRectMake(0,-3*scale,18*scale,18*scale);
            [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:avatar]];
            [text appendAttributedString:[[NSAttributedString alloc] initWithString:[@" " stringByAppendingString:user.name] attributes:CFAttributes(CFFont(16,UIFontWeightSemibold,scale),22.4*scale)]];
        } else if (block.kind==CFKBlockKindCode) {
            if(code.length) [code appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            UIFont *mono=[UIFont monospacedSystemFontOfSize:12.8*scale weight:UIFontWeightRegular];
            [code appendAttributedString:[[NSAttributedString alloc] initWithString:block.text ?: @"" attributes:CFAttributes(mono,17.92*scale)]];
        } else {
            [text appendAttributedString:[[NSAttributedString alloc] initWithString:block.text ?: @"" attributes:attrs]];
        }
    }
    if(code.length) {
        NSArray<NSString *> *patterns=@[@"\\b(def|end|class|return|func|let|var|if|else|import|from|const|for|in)\\b", @"(?<=def )[A-Za-z_][A-Za-z_0-9]*", @"\"[^\"]*\"|'[^']*'", @"(?m)^\\s*#.*$"];
        NSArray<UIColor *> *colors=@[CFAdaptive(0xD73A49,0xFF7B72),CFAdaptive(0x6F42C1,0xD2A8FF),CFAdaptive(0x032F62,0x79C0FF),CFAdaptive(0x6A737D,0x8B949E)];
        for(NSUInteger i=0;i<patterns.count;i++) {
            NSRegularExpression *expression=[NSRegularExpression regularExpressionWithPattern:patterns[i] options:0 error:nil];
            for(NSTextCheckingResult *match in [expression matchesInString:code.string options:0 range:NSMakeRange(0,code.length)]) [code addAttribute:NSForegroundColorAttributeName value:colors[i] range:match.range];
        }
    }
    self.body=text; self.code=code;
    CGFloat headerWidth=([(pr.isThreaded ? @"" : self.users[@(m.creatorID)].name) sizeWithAttributes:@{NSFontAttributeName:CFFont(12.8,UIFontWeightBold,scale)}].width + [self.time sizeWithAttributes:@{NSFontAttributeName:CFFont(12.8,UIFontWeightRegular,scale)}].width + 40*scale);
    CGSize bodySize=CFMeasure(text,inner);
    CGFloat codeWidth=code.length ? MIN(inner,CFMeasure(code,CGFLOAT_MAX).width+25.6) : 0;
    CGFloat bubbleWidth=MIN(maxWidth,MAX(headerWidth+30.24,MAX(bodySize.width+30.24,codeWidth+30.24)));
    CFKAttachment *attachment=m.attachment;
    if (attachment) bubbleWidth=attachment.kind==CFKAttachmentKindImage ? MIN(300,maxWidth) : MIN(maxWidth,MAX(headerWidth+30.24,283.11*MIN(scale,1.4)));
    CGFloat bubbleTop=1.6;
    if(pr.isFirstOfDay) bubbleTop+=33.8+35*scale;
    self.headerY=10.56; self.headerStacked=!pr.isThreaded && headerWidth>bubbleWidth-30.24; CGFloat y=10.56+20.36*scale*(self.headerStacked ? 2 : 1)+1.6;
    self.bodyFrame=CGRectZero; self.codeFrame=CGRectZero; self.attachmentFrame=CGRectZero;
    inner=bubbleWidth-30.24; self.contentWidth=inner;
    if(text.length) { bodySize=CFMeasure(text,inner); self.bodyFrame=CGRectMake(15.12,y,inner,MAX(bodySize.height,(m.isEmojiOnly ? 53.76 : 22.4)*scale)); y=CGRectGetMaxY(self.bodyFrame); }
    if(code.length) {
        if(text.length) y+=8;
        CGSize cs=CFMeasure(code,MAX(1,inner-25.6));
        self.codeFrame=CGRectMake(15.12,y,inner,cs.height+25.6); y=CGRectGetMaxY(self.codeFrame)+2;
    }
    if(attachment) {
        if(attachment.kind==CFKAttachmentKindImage) {
            y=MAX(y+12.94,44.5*scale);
            self.attachmentFrame=CGRectMake(1.1,y,bubbleWidth-2.2,(bubbleWidth-2.2)*attachment.height/MAX(1.0,attachment.width));
        } else { self.attachmentFrame=CGRectMake(15.12,y,inner,33.92*scale); }
        y=CGRectGetMaxY(self.attachmentFrame);
    }
    NSMutableArray *boosts=[NSMutableArray new];
    for(CFKBoost *boost in m.boosts) [boosts addObject:@{@"user":@(boost.boosterID),@"text":boost.content}];
    [boosts addObjectsFromArray:self.extraBoosts ?: @[]];
    NSMutableArray *pills=[NSMutableArray new];
    if(boosts.count) {
        y+=4;
        CGFloat x=15.12, lineY=y, height=28.64*scale;
        [boosts addObject:@{@"add":@YES}];
        for(NSDictionary *boost in boosts) {
            NSString *s=boost[@"text"]; BOOL emoji=s.length && [s rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location==NSNotFound;
            CGFloat w=boost[@"add"] ? height : MIN(inner,32*scale+[s sizeWithAttributes:@{NSFontAttributeName:CFFont(emoji ? 17.6 : 12.8,UIFontWeightRegular,scale)}].width);
            if(x+w>15.12+inner+.1 && x>15.12) { x=15.12; lineY+=height+4; }
            NSMutableDictionary *pill=[boost mutableCopy]; pill[@"frame"]=[NSValue valueWithCGRect:CGRectMake(x,lineY,w,height)]; pill[@"emoji"]=@(emoji); [pills addObject:pill]; x+=w+4.8;
        }
        y=lineY+height;
    }
    self.pills=pills;
    CGFloat bubbleHeight=y+(attachment && attachment.kind==CFKAttachmentKindImage && boosts.count ? 9.26 : 10.56);
    CGFloat bubbleX=pr.isMine ? width-40.8-bubbleWidth : 40.8;
    self.bubbleFrame=CGRectMake(bubbleX,bubbleTop,bubbleWidth,bubbleHeight);
    self.height=ceil(CGRectGetMaxY(self.bubbleFrame)+1.6);
}
@end

@implementation CFMessageConfiguration
- (id)copyWithZone:(NSZone *)zone { CFMessageConfiguration *copy=[CFMessageConfiguration new]; copy.row=self.row; return copy; }
- (id<UIContentView>)makeContentView { CFMessageView *v=[[CFMessageView alloc] initWithFrame:CGRectZero]; v.configuration=self; return v; }
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state { return self; }
@end
@interface CFMessageView () <UITextViewDelegate, UIContextMenuInteractionDelegate>
@property (nonatomic, strong) UIView *bubble;
@property (nonatomic) CGFloat renderedWidth;
@property (nonatomic) CGFloat renderedScale;
@end
@implementation CFMessageView
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withHandler:^(__kindof id<UITraitEnvironment> environment, UITraitCollection *previous) {
            CFMessageView *view=(CFMessageView *)environment;
            if(view.configuration) [view setConfiguration:view.configuration];
        }];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CFRow *row=((CFMessageConfiguration *)self.configuration).row;
    if(row && (fabs(self.renderedWidth-row.viewportWidth)>.1 || fabs(self.renderedScale-row.scale)>.001)) [self setConfiguration:self.configuration];
}
- (void)setConfiguration:(id<UIContentConfiguration>)configuration {
    _configuration=[configuration copyWithZone:nil];
    for(UIView *view in self.subviews) [view removeFromSuperview];
    CFRow *row=((CFMessageConfiguration *)configuration).row;
    self.renderedWidth=row.viewportWidth; self.renderedScale=row.scale;
    CFKMessage *m=row.message; CFKPresentation *pr=row.presentation; CGFloat scale=row.scale;
    self.accessibilityIdentifier=[NSString stringWithFormat:@"message-%ld",(long)m.messageID];
    if(pr.isFirstOfDay) {
        CGFloat top=17.02;
        UIView *line=[UIView new]; line.backgroundColor=CFBubble(); line.frame=CGRectMake(14,top+17.5*scale,row.viewportWidth-28,2); line.autoresizingMask=UIViewAutoresizingFlexibleWidth; [self addSubview:line];
        UILabel *day=CFLabel(row.day,CFFont(12.8,UIFontWeightSemibold,scale)); day.textAlignment=NSTextAlignmentCenter; day.backgroundColor=CFBubble();
        CGFloat w=MIN(row.viewportWidth-28,[day sizeThatFits:CGSizeMake(CGFLOAT_MAX,40)].width+47);
        if(w<47) w=200;
        day.frame=CGRectMake((row.viewportWidth-w)/2,top,w,35*scale); day.layer.cornerRadius=17.5*scale; day.clipsToBounds=YES; [self addSubview:day];
    }
    UIView *bubble=[UIView new]; bubble.frame=row.bubbleFrame; bubble.layer.cornerRadius=10.56; bubble.clipsToBounds=YES;
    bubble.backgroundColor=m.isEmojiOnly ? UIColor.clearColor : pr.mentionsMe ? [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return [CFHex(t.userInterfaceStyle==UIUserInterfaceStyleDark ? 0xFF7563 : 0xBE1600) colorWithAlphaComponent:t.userInterfaceStyle==UIUserInterfaceStyleDark ? .2 : .1]; }] : CFBubble();
    [self addSubview:bubble]; self.bubble=bubble;
    [bubble addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];
    CFKUser *author=row.users[@(m.creatorID)];
    if(!pr.isThreaded) {
        UIImageView *avatar=[[UIImageView alloc] initWithImage:CFInitial(author,35.27)];
        CGFloat fullWidth=row.viewportWidth;
        avatar.frame=CGRectMake(pr.isMine ? fullWidth-49.27 :14,row.bubbleFrame.origin.y,35.27,35.27);
        UIView *ring=[UIView new]; ring.frame=CGRectInset(avatar.frame,-2.5,-2.5); ring.backgroundColor=CFBackground(); ring.layer.cornerRadius=20.135; [self addSubview:ring];
        avatar.layer.cornerRadius=17.635; avatar.clipsToBounds=YES; [self addSubview:avatar];
    }
    CGFloat headerHeight=20.36*scale;
    UILabel *name=CFLabel(pr.isThreaded ? @"" : author.name,CFFont(12.8,UIFontWeightBold,scale));
    UILabel *time=CFLabel(row.time,CFFont(12.8,UIFontWeightRegular,scale)); time.alpha=.5;
    UILabel *dots=CFLabel(@"•••",CFFont(16,UIFontWeightBold,scale)); dots.alpha=.5;
    CGFloat nw=[name sizeThatFits:CGSizeMake(CGFLOAT_MAX,headerHeight)].width;
    CGFloat tw=[time sizeThatFits:CGSizeMake(CGFLOAT_MAX,headerHeight)].width;
    CGFloat x=15.12;
    if(row.headerStacked) {
        name.frame=CGRectMake(15.12,row.headerY,row.contentWidth,headerHeight);
        name.textAlignment=pr.isMine ? NSTextAlignmentRight : NSTextAlignmentLeft;
        CGFloat timeX=pr.isMine ? bubble.bounds.size.width-15.12-MIN(tw,row.contentWidth-30*scale) : 15.12;
        time.frame=CGRectMake(timeX,row.headerY+headerHeight,MIN(tw,row.contentWidth-30*scale),headerHeight);
        CGFloat dotsX=pr.isMine ? timeX-26*scale : CGRectGetMaxX(time.frame)+6*scale;
        dots.frame=CGRectMake(dotsX,row.headerY+headerHeight,20*scale,headerHeight);
    } else if(pr.isMine) {
        x=bubble.bounds.size.width-15.12;
        name.frame=CGRectMake(x-nw,row.headerY,nw,headerHeight); x-=nw+(nw?4:0);
        time.frame=CGRectMake(x-tw,row.headerY,tw,headerHeight); x-=tw+12;
        dots.frame=CGRectMake(x-20*scale,row.headerY,20*scale,headerHeight);
    } else {
        name.frame=CGRectMake(x,row.headerY,nw,headerHeight); x+=nw+(nw?4:0);
        time.frame=CGRectMake(x,row.headerY,tw,headerHeight); x+=tw+12;
        dots.frame=CGRectMake(x,row.headerY,20*scale,headerHeight);
    }
    [bubble addSubview:name]; [bubble addSubview:time]; [bubble addSubview:dots];
    if(row.body.length) [self addText:row.body frame:row.bodyFrame to:bubble inset:0];
    if(row.code.length) {
        UIView *box=[UIView new]; box.frame=row.codeFrame; box.backgroundColor=CFBackground(); box.layer.cornerRadius=6.4; box.clipsToBounds=YES; [bubble addSubview:box];
        [self addText:row.code frame:box.bounds to:box inset:12.8];
    }
    CFKAttachment *attachment=m.attachment;
    if(attachment) {
        if(attachment.kind==CFKAttachmentKindImage) {
            // CampfireKit documents a solid fill of the supplied RGB as equivalent to its Placeholder PNG.
            UIView *image=[UIView new]; image.frame=row.attachmentFrame;
            image.backgroundColor=[UIColor colorWithRed:attachment.red/255.0 green:attachment.green/255.0 blue:attachment.blue/255.0 alpha:1];
            image.isAccessibilityElement=YES; image.accessibilityLabel=[NSString stringWithFormat:@"Image, %ld by %ld",(long)attachment.width,(long)attachment.height]; [bubble addSubview:image];
        } else {
            UIView *file=[UIView new]; file.frame=row.attachmentFrame; [bubble addSubview:file];
            UIImageView *icon=[[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"common-file-text"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]]; icon.tintColor=CFText(); icon.frame=CGRectMake(0,5*scale,21*scale,25*scale); [file addSubview:icon];
            UILabel *filename=CFLabel(attachment.name,CFFont(16,UIFontWeightRegular,scale)); filename.frame=CGRectMake(27*scale,0,MAX(1,file.bounds.size.width-85*scale),file.bounds.size.height); filename.adjustsFontSizeToFitWidth=YES; filename.minimumScaleFactor=.7; [file addSubview:filename];
            UIButton *download=CFIconButton(@"arrow.down.to.line",@"Download file"); download.frame=CGRectMake(file.bounds.size.width-54*scale,0,26*scale,file.bounds.size.height); [file addSubview:download];
            UIButton *share=CFIconButton(@"square.and.arrow.up",@"Share file"); share.frame=CGRectMake(file.bounds.size.width-17*scale,0,17*scale,file.bounds.size.height); [file addSubview:share];
            file.accessibilityLabel=[NSString stringWithFormat:@"%@, %ld KB",attachment.name,(long)(attachment.bytes/1024)];
        }
    }
    for(NSDictionary *pill in row.pills) {
        UIView *p=[UIView new]; p.frame=[pill[@"frame"] CGRectValue]; p.backgroundColor=CFBackground(); p.layer.cornerRadius=p.bounds.size.height/2; p.layer.borderWidth=1; p.layer.borderColor=[CFAdaptive(0xE5E4E1,0x2E2E2E) resolvedColorWithTraitCollection:self.traitCollection].CGColor;
        [bubble addSubview:p];
        if(pill[@"add"]) { UIButton *add=CFIconButton(@"face.smiling.badge.plus",@"Add boost"); add.frame=p.bounds; [p addSubview:add]; }
        else {
            CFKUser *user=row.users[pill[@"user"]]; UIImageView *av=[[UIImageView alloc] initWithImage:CFInitial(user,22.4*scale)]; av.frame=CGRectMake(1.6*scale,3.12*scale,22.4*scale,22.4*scale); [p addSubview:av];
            UILabel *content=CFLabel(pill[@"text"],CFFont([pill[@"emoji"] boolValue] ? 17.6 : 12.8,UIFontWeightRegular,scale)); content.frame=CGRectMake(28*scale,0,p.bounds.size.width-29*scale,p.bounds.size.height); [p addSubview:content];
            p.isAccessibilityElement=YES; p.accessibilityLabel=[NSString stringWithFormat:@"%@ boosted %@",user.name,pill[@"text"]];
        }
    }
}
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    UIView *hit=[self.bubble hitTest:location withEvent:nil];
    for(UIView *view=hit;view && view!=self.bubble;view=view.superview) if([view isKindOfClass:UITextView.class]) return nil;
    CFRow *row=((CFMessageConfiguration *)self.configuration).row;
    NSMutableString *text=[NSMutableString new];
    for(CFKBlock *block in row.message.blocks) {
        if(block.kind==CFKBlockKindMention) [text appendString:row.users[@(block.mentionedUserID)].name ?: @""];
        else { if(block.kind==CFKBlockKindCode && text.length) [text appendString:@"\n"]; [text appendString:block.text ?: @""]; }
    }
    if(!text.length && row.message.attachment.name) [text appendString:row.message.attachment.name];
    return [UIContextMenuConfiguration configurationWithIdentifier:@(row.message.messageID) previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *copy=[UIAction actionWithTitle:@"Copy" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction *action) { UIPasteboard.generalPasteboard.string=text; }];
        UIAction *reply=[UIAction actionWithTitle:@"Reply" image:[UIImage systemImageNamed:@"arrowshape.turn.up.left"] identifier:nil handler:^(__kindof UIAction *action) {}];
        return [UIMenu menuWithChildren:@[copy,reply]];
    }];
}
- (UIMenu *)textView:(UITextView *)textView editMenuForTextInRange:(NSRange)range suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    __weak UITextView *weakTextView=textView;
    UIAction *copy=[UIAction actionWithTitle:@"Copy" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction *action) { [weakTextView copy:nil]; }];
    UIAction *reply=[UIAction actionWithTitle:@"Reply" image:[UIImage systemImageNamed:@"arrowshape.turn.up.left"] identifier:nil handler:^(__kindof UIAction *action) {}];
    return [UIMenu menuWithChildren:@[copy,reply]];
}
- (void)addText:(NSAttributedString *)text frame:(CGRect)frame to:(UIView *)parent inset:(CGFloat)inset {
    UITextView *view=[[UITextView alloc] initWithFrame:frame]; view.backgroundColor=UIColor.clearColor; view.editable=NO; view.selectable=YES; view.scrollEnabled=NO;
    view.textContainerInset=UIEdgeInsetsMake(inset,inset,inset,inset); view.textContainer.lineFragmentPadding=0;
    view.delegate=self; view.attributedText=text; view.accessibilityIdentifier=@"messageText"; [parent addSubview:view];
}
@end

@implementation CFWelcomeView
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) { self.contentView.backgroundColor=CFBackground(); } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; for(UIView *v in self.contentView.subviews) [v removeFromSuperview];
    CGFloat width=self.bounds.size.width;
    UIView *card=[UIView new]; card.frame=CGRectMake(14,109,width-28,269); card.backgroundColor=CFBubble(); card.layer.cornerRadius=10.56; [self.contentView addSubview:card];
    UILabel *globe=CFLabel(@"🌎",CFFont(16,UIFontWeightRegular,1)); globe.textAlignment=NSTextAlignmentCenter; globe.frame=CGRectMake(16,16,42,42); globe.backgroundColor=CFBackground(); globe.layer.cornerRadius=21; globe.clipsToBounds=YES; globe.layer.borderWidth=1; globe.layer.borderColor=[CFBorder() resolvedColorWithTraitCollection:self.traitCollection].CGColor; [card addSubview:globe];
    UILabel *title=CFLabel(@"Welcome to Campfire",CFFont(16,UIFontWeightBold,1)); title.textAlignment=NSTextAlignmentCenter; title.frame=CGRectMake(10,77,card.bounds.size.width-20,22.4); [card addSubview:title];
    UILabel *detail=CFLabel(@"To invite people to chat, share the join link\nbelow.",CFFont(16,UIFontWeightRegular,1)); detail.numberOfLines=0; detail.textAlignment=NSTextAlignmentCenter; detail.frame=CGRectMake(10,100,card.bounds.size.width-20,44.8); [card addSubview:detail];
    UIView *link=[UIView new]; link.backgroundColor=CFBackground(); link.layer.cornerRadius=8; link.clipsToBounds=YES; link.layer.borderWidth=1; link.layer.borderColor=[CFBorder() resolvedColorWithTraitCollection:self.traitCollection].CGColor; link.frame=CGRectMake(16,160,card.bounds.size.width-32,40); [card addSubview:link];
    UIImageView *person=[[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"person-add"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]]; person.tintColor=CFText(); person.frame=CGRectMake(12,9,22,22); [link addSubview:person];
    UILabel *url=CFLabel(@"http://127.0.0.1:3055/join/GwHG-HbZN",CFFont(16,UIFontWeightRegular,1)); url.adjustsFontSizeToFitWidth=YES; url.frame=CGRectMake(41,0,link.bounds.size.width-45,40); [link addSubview:url];
    NSArray *symbols=@[@"qrcode.viewfinder",@"doc.on.clipboard",@"square.and.arrow.up"];
    for(NSInteger i=0;i<3;i++) { UIButton *b=CFIconButton(symbols[i],@"Invite"); b.frame=CGRectMake(card.bounds.size.width/2-78+i*52,216,42,42); b.layer.cornerRadius=21; b.backgroundColor=CFBackground(); b.layer.borderWidth=1; b.layer.borderColor=[CFBorder() resolvedColorWithTraitCollection:self.traitCollection].CGColor; [card addSubview:b]; }
    UIImageView *logo=[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"campfire-icon"]]; logo.contentMode=UIViewContentModeScaleAspectFit; logo.frame=CGRectMake(width/2-34.5,85,69,69); logo.backgroundColor=CFHex(0x400D49); logo.layer.cornerRadius=12; logo.clipsToBounds=YES; [self.contentView addSubview:logo];
}
@end
