#import "CFRowLayout.h"
#import "CFAvatar.h"

// Campfire's measured geometry (Fixtures/constants.json and the reference screenshots), in points.
static const CGFloat kAvatarX = 14.01;
static const CGFloat kAvatarSize = 35.27;
static const CGFloat kBubbleLeft = 40.8;
static const CGFloat kBubbleRightInset = 14.0;
static const CGFloat kBubblePadX = 15.12;
static const CGFloat kRowTopInset = 1.59;
static const CGFloat kRowBottomMargin = 1.6;
static const CGFloat kRowGap = 21.28;
static const CGFloat kThreadedGap = -1.2;
static const CGFloat kHeaderTop = 12.45;      // bubble top to the name/time line box
static const CGFloat kHeaderGap = 0.35;       // name/time line to the first body line
static const CGFloat kBottomPad = 11.08;      // last body line to the bubble bottom
static const CGFloat kDotsGap = 12.7;
static const CGFloat kDotsWidth = 17.0;
static const CGFloat kDotsHeight = 4.6;
static const CGFloat kSeparatorTop = 17.02;
static const CGFloat kSeparatorBottom = 16.87;
static const CGFloat kSeparatorPadX = 23.5;
static const CGFloat kSeparatorPadY = 8.5;
static const CGFloat kImageMaxWidth = 300;
static const CGFloat kImageInset = 1.0;
static const CGFloat kImageTopGap = 12.0;     // first body line top to the image
static const CGFloat kCodeInsetX = 16.2;
static const CGFloat kCodePad = 12.8;
static const CGFloat kCodeTopGap = 2.4;
static const CGFloat kBlockGap = 8.0;
static const CGFloat kFileRowHeight = 34.0;
static const CGFloat kBoostGapText = 4.4;
static const CGFloat kBoostGapImage = 5.2;
static const CGFloat kBoostBottomText = 10.0;
static const CGFloat kBoostBottomImage = 8.2;
static const CGFloat kBoostStripInsetImage = 10.2;
static const CGFloat kPillHeight = 28.64;
static const CGFloat kPillAvatar = 23.4;
static const CGFloat kPillGap = 4.0;
static const CGFloat kPillRowGap = 4.0;
static const CGFloat kMentionAvatar = 18.0;

#pragma mark - Text helpers

@implementation CFText

+ (NSLayoutManager *)layoutManager {
    static NSLayoutManager *lm;
    static NSTextContainer *tc;
    static NSTextStorage *ts;
    if (!lm) {
        ts = [[NSTextStorage alloc] init];
        lm = [[NSLayoutManager alloc] init];
        tc = [[NSTextContainer alloc] initWithSize:CGSizeMake(100, CGFLOAT_MAX)];
        tc.lineFragmentPadding = 0;
        [lm addTextContainer:tc];
        [ts addLayoutManager:lm];
    }
    return lm;
}

+ (CGSize)sizeOfAttributedString:(NSAttributedString *)string width:(CGFloat)width {
    NSLayoutManager *lm = [self layoutManager];
    NSTextContainer *tc = lm.textContainers.firstObject;
    tc.size = CGSizeMake(width, CGFLOAT_MAX);
    [lm.textStorage setAttributedString:string];
    [lm ensureLayoutForTextContainer:tc];
    CGRect used = [lm usedRectForTextContainer:tc];
    return CGSizeMake(ceil(used.size.width * 3) / 3, used.size.height);
}

+ (CGFloat)widthOfString:(NSString *)string font:(UIFont *)font {
    CGRect r = [string boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin
                                 attributes:@{NSFontAttributeName: font} context:nil];
    return ceil(r.size.width * 3) / 3;
}

+ (NSDictionary<NSAttributedStringKey, id> *)attributesWithFont:(UIFont *)font color:(UIColor *)color lineHeight:(CGFloat)lineHeight {
    NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
    p.minimumLineHeight = lineHeight;
    p.maximumLineHeight = lineHeight;
    p.lineBreakMode = NSLineBreakByWordWrapping;
    // TextKit puts the extra line height above the glyphs; CSS splits it. Lift the baseline by half.
    CGFloat offset = (lineHeight - font.lineHeight) / 2;
    return @{NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: p,
             NSBaselineOffsetAttributeName: @(offset)};
}

+ (NSDateFormatter *)formatterWithFormat:(NSString *)format {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    f.dateFormat = format;
    return f;
}

+ (NSString *)timeStringForDate:(NSDate *)date {
    static NSDateFormatter *f;
    if (!f) { f = [self formatterWithFormat:@"h:mm a"]; }
    return [f stringFromDate:date];
}

+ (NSString *)dayStringForDate:(NSDate *)date {
    static NSDateFormatter *f;
    if (!f) { f = [self formatterWithFormat:@"MMMM d, yyyy"]; }
    return [[f stringFromDate:date] uppercaseString];
}

@end

#pragma mark - Code highlighting

static NSAttributedString *CFHighlightCode(NSString *source, NSString *language, CFMetrics *m) {
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:source
                                                                         attributes:[CFText attributesWithFont:m.codeFont color:CFTheme.text lineHeight:m.codeLineHeight]];
    NSString *lang = language.lowercaseString ?: @"";
    NSArray<NSString *> *keywords;
    if ([lang isEqualToString:@"ruby"]) {
        keywords = @[@"def", @"end", @"do", @"if", @"else", @"elsif", @"class", @"module", @"return", @"unless", @"while", @"yield", @"self", @"nil", @"true", @"false"];
    } else if ([lang isEqualToString:@"swift"]) {
        keywords = @[@"let", @"var", @"func", @"return", @"if", @"else", @"guard", @"for", @"in", @"struct", @"class", @"import", @"self", @"nil", @"true", @"false"];
    } else if ([lang isEqualToString:@"sh"]) {
        keywords = @[@"if", @"then", @"fi", @"for", @"do", @"done", @"export"];
    } else {
        keywords = @[@"SELECT", @"FROM", @"WHERE", @"ORDER", @"BY", @"DESC", @"ASC", @"LIMIT", @"AND", @"OR", @"JOIN", @"ON", @"AS", @"GROUP", @"INSERT", @"UPDATE"];
    }
    void (^paint)(NSString *, UIColor *, NSUInteger) = ^(NSString *pattern, UIColor *color, NSUInteger group) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        [re enumerateMatchesInString:source options:0 range:NSMakeRange(0, source.length)
                          usingBlock:^(NSTextCheckingResult *r, NSMatchingFlags f, BOOL *stop) {
            NSRange range = [r rangeAtIndex:group];
            if (range.location != NSNotFound) { [s addAttribute:NSForegroundColorAttributeName value:color range:range]; }
        }];
    };
    paint([NSString stringWithFormat:@"\\b(%@)\\b", [keywords componentsJoinedByString:@"|"]], CFTheme.codeKeyword, 1);
    paint(@"\\b(?:def|func)\\s+([A-Za-z_][A-Za-z0-9_]*)", CFTheme.codeEntity, 1);
    paint(@"(?<![A-Za-z_])(-{1,2}[A-Za-z]+|\\b\\d+\\b)", CFTheme.codeConstant, 1);
    paint(@"(\"[^\"\\n]*\"|'[^'\\n]*')", CFTheme.codeString, 1);
    paint(@"(?m)(?<![:\\w\"])((?://|#(?!\\{))[^\\n]*)$", CFTheme.codeComment, 1);
    return s;
}

#pragma mark - Row layout

@interface CFRowLayout ()
@property (nonatomic, readwrite) NSInteger itemID;
@property (nonatomic, readwrite) CGFloat width;
@property (nonatomic, readwrite) CGFloat scale;
@property (nonatomic, readwrite) NSUInteger revision;
@property (nonatomic, readwrite) CGFloat height;
@property (nonatomic, readwrite) CGFloat spacingBefore;
@property (nonatomic, readwrite) BOOL hasSeparator;
@property (nonatomic, readwrite) CGRect separatorPillFrame;
@property (nonatomic, readwrite) CGRect separatorLineFrame;
@property (nonatomic, readwrite, copy) NSAttributedString *separatorText;
@property (nonatomic, readwrite) BOOL showsAvatar;
@property (nonatomic, readwrite) CGRect avatarFrame;
@property (nonatomic, readwrite) NSInteger avatarUserID;
@property (nonatomic, readwrite, copy) NSString *avatarInitial;
@property (nonatomic, readwrite) CGRect bubbleFrame;
@property (nonatomic, readwrite) CFBubbleStyle bubbleStyle;
@property (nonatomic, readwrite) BOOL isMine;
@property (nonatomic, readwrite) CGRect headerFrame;
@property (nonatomic, readwrite, copy) NSAttributedString *headerText;
@property (nonatomic, readwrite) CGRect dotsFrame;
@property (nonatomic, readwrite) CGRect textFrame;
@property (nonatomic, readwrite, copy) NSAttributedString *bodyText;
@property (nonatomic, readwrite) CGRect codeBoxFrame;
@property (nonatomic, readwrite) CGRect codeTextFrame;
@property (nonatomic, readwrite, copy) NSAttributedString *codeText;
@property (nonatomic, readwrite) CGRect imageFrame;
@property (nonatomic, readwrite) CGRect fileIconFrame;
@property (nonatomic, readwrite) CGRect fileNameFrame;
@property (nonatomic, readwrite) CGRect fileDownloadFrame;
@property (nonatomic, readwrite) CGRect fileShareFrame;
@property (nonatomic, readwrite, copy) NSAttributedString *fileNameText;
@property (nonatomic, readwrite, copy) NSArray<NSValue *> *boostFrames;
@property (nonatomic, readwrite, copy) NSArray<NSAttributedString *> *boostTexts;
@property (nonatomic, readwrite, copy) NSArray<CFBoostItem *> *boosts;
@property (nonatomic, readwrite) CGRect addBoostFrame;
@property (nonatomic, readwrite) CGFloat boostAvatarSize;
@property (nonatomic, readwrite, copy) NSString *plainText;
@property (nonatomic, readwrite, copy) NSString *accessibilityText;
@end

static BOOL CFIsEmojiText(NSString *s) {
    __block BOOL emoji = s.length > 0;
    [s enumerateSubstringsInRange:NSMakeRange(0, s.length) options:NSStringEnumerationByComposedCharacterSequences
                       usingBlock:^(NSString *sub, NSRange r, NSRange er, BOOL *stop) {
        unichar c = [sub characterAtIndex:0];
        if (c < 0x2000 && sub.length == 1) { emoji = NO; *stop = YES; }
    }];
    return emoji;
}

@implementation CFRowLayout

+ (NSAttributedString *)bodyStringForBlocks:(NSArray<CFKBlock *> *)blocks store:(CFRoomStore *)store metrics:(CFMetrics *)m
                                      plain:(NSMutableString *)plain {
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] init];
    NSDictionary *body = [CFText attributesWithFont:m.bodyFont color:CFTheme.text lineHeight:m.bodyLineHeight];
    for (CFKBlock *b in blocks) {
        if (b.kind == CFKBlockKindText && b.text) {
            [s appendAttributedString:[[NSAttributedString alloc] initWithString:b.text attributes:body]];
            [plain appendString:b.text];
        } else if (b.kind == CFKBlockKindMention) {
            CFKUser *u = [store userWithID:b.mentionedUserID];
            NSString *name = u.name ?: @"Someone";
            CGFloat d = round(kMentionAvatar * m.scale * 3) / 3;
            UIImage *avatar = [CFAvatar imageForUserID:b.mentionedUserID initial:[CFAvatar initialForName:name] diameter:d
                                           leftPadding:1.1 rightPadding:2.0];
            NSTextAttachment *a = [[NSTextAttachment alloc] init];
            a.image = avatar;
            // Circle centre about 4.7 pt above the baseline, as in Campfire.
            a.bounds = CGRectMake(0, 4.7 * m.scale - d / 2, avatar.size.width, d);
            NSMutableAttributedString *att = [[NSAttributedString attributedStringWithAttachment:a] mutableCopy];
            [att addAttributes:body range:NSMakeRange(0, att.length)];
            [s appendAttributedString:att];
            NSMutableDictionary *mention = [[CFText attributesWithFont:m.mentionFont color:CFTheme.text lineHeight:m.bodyLineHeight] mutableCopy];
            [s appendAttributedString:[[NSAttributedString alloc] initWithString:name attributes:mention]];
            [plain appendFormat:@"@%@", name];
        }
    }
    return s;
}

+ (CFRowLayout *)layoutForItem:(CFMessageItem *)item store:(CFRoomStore *)store width:(CGFloat)W metrics:(CFMetrics *)m {
    CFRowLayout *L = [[CFRowLayout alloc] init];
    CGFloat s = m.scale;
    CFKMessage *msg = item.message;
    CFKPresentation *pres = item.presentation;
    L.itemID = item.itemID;
    L.width = W;
    L.scale = s;
    L.revision = item.revision;
    L.isMine = pres.isMine;
    L.boosts = item.boosts;

    CFKUser *author = [store userWithID:msg.creatorID];
    NSString *authorName = author.name ?: @"Unknown";
    BOOL threaded = pres.isThreaded;

    // Day separator.
    CGFloat y = 0;
    if (pres.isFirstOfDay) {
        L.hasSeparator = YES;
        NSString *day = [CFText dayStringForDate:msg.createdAt];
        L.separatorText = [[NSAttributedString alloc] initWithString:day attributes:@{
            NSFontAttributeName: m.separatorFont, NSForegroundColorAttributeName: CFTheme.text}];
        CGFloat tw = [CFText widthOfString:day font:m.separatorFont];
        CGFloat ph = m.separatorLineHeight + 2 * kSeparatorPadY;
        CGFloat pw = tw + 2 * kSeparatorPadX;
        L.separatorPillFrame = CGRectMake(round((W - pw) / 2 * 3) / 3, kSeparatorTop, pw, ph);
        L.separatorLineFrame = CGRectMake(kAvatarX, kSeparatorTop + ph / 2 - 1, W - kAvatarX - kBubbleRightInset, 2);
        y = kSeparatorTop + ph + kSeparatorBottom;
    }
    CGFloat bubbleTop = y + kRowTopInset;

    // Header: name and time (reversed for my messages), then the actions dots.
    NSMutableAttributedString *header = [[NSMutableAttributedString alloc] init];
    NSMutableDictionary *nameAttrs = [[CFText attributesWithFont:m.nameFont color:CFTheme.text lineHeight:m.metaLineHeight] mutableCopy];
    NSMutableDictionary *timeAttrs = [[CFText attributesWithFont:m.timeFont color:CFTheme.secondaryText lineHeight:m.metaLineHeight] mutableCopy];
    if (pres.isMine) {
        for (NSMutableDictionary *d in @[nameAttrs, timeAttrs]) {
            NSMutableParagraphStyle *p = [d[NSParagraphStyleAttributeName] mutableCopy];
            p.alignment = NSTextAlignmentRight;
            d[NSParagraphStyleAttributeName] = p;
        }
    }
    NSString *time = [CFText timeStringForDate:msg.createdAt];
    if (threaded) {
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:time attributes:timeAttrs]];
    } else if (pres.isMine) {
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:[time stringByAppendingString:@" "] attributes:timeAttrs]];
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:authorName attributes:nameAttrs]];
    } else {
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:authorName attributes:nameAttrs]];
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:[@" " stringByAppendingString:time] attributes:timeAttrs]];
    }
    L.headerText = header;
    CGFloat maxBubbleW = pres.isMine ? W - 2 * kBubbleLeft : W - kBubbleLeft - kBubbleRightInset;
    CGFloat maxContentW = maxBubbleW - 2 * kBubblePadX;
    // Name and time on one line, wrapping only when large text no longer fits beside the dots.
    CGSize headerSize = [CFText sizeOfAttributedString:header width:maxContentW - kDotsGap - kDotsWidth];
    CGFloat headerW = headerSize.width;
    CGFloat headerH = MAX(m.metaLineHeight, headerSize.height);
    CGFloat headerExtent = headerW + kDotsGap + kDotsWidth;
    CGFloat contentTop = kHeaderTop + headerH + kHeaderGap; // relative to bubble top

    // Body pieces.
    NSMutableArray<CFKBlock *> *inlineBlocks = [NSMutableArray array];
    CFKBlock *codeBlock = nil;
    for (CFKBlock *b in msg.blocks) {
        if (b.kind == CFKBlockKindCode) { codeBlock = b; } else { [inlineBlocks addObject:b]; }
    }
    NSMutableString *plain = [NSMutableString string];
    CFKAttachment *attachment = msg.attachment;
    BOOL emojiOnly = msg.isEmojiOnly;
    BOOL isImage = attachment && attachment.kind == CFKAttachmentKindImage;
    BOOL isFile = attachment && attachment.kind == CFKAttachmentKindFile;

    CGFloat contentW = 0;          // widest content line, for fit-to-content bubbles
    CGFloat cursor = contentTop;   // relative to bubble top
    CGFloat bottomPad = kBottomPad;
    CGFloat boostGap = kBoostGapText, boostBottom = kBoostBottomText;
    CGFloat bubbleW = 0;
    CGRect textRel = CGRectZero, codeBoxRel = CGRectZero, imageRel = CGRectZero, fileRel = CGRectZero;
    NSAttributedString *bodyString = nil;

    if (emojiOnly) {
        NSString *t = [inlineBlocks.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] ?: @"";
        bodyString = [[NSAttributedString alloc] initWithString:t attributes:[CFText attributesWithFont:m.emojiOnlyFont color:CFTheme.text lineHeight:m.emojiLineHeight]];
        [plain appendString:t];
        CGSize size = [CFText sizeOfAttributedString:bodyString width:maxContentW];
        textRel = CGRectMake(0, cursor, size.width, size.height);
        contentW = size.width;
        cursor += size.height;
    } else {
        if (isImage) {
            CGFloat iw = MIN(kImageMaxWidth, maxBubbleW) - 2 * kImageInset;
            CGFloat ih = attachment.width > 0 ? iw * attachment.height / attachment.width : iw;
            cursor += kImageTopGap;
            imageRel = CGRectMake(kImageInset, cursor, iw, ih);
            cursor += ih;
            bubbleW = iw + 2 * kImageInset;
            maxContentW = bubbleW - 2 * kBubblePadX;
            bottomPad = kImageInset;
            boostGap = kBoostGapImage; boostBottom = kBoostBottomImage;
        }
        if (inlineBlocks.count > 0) {
            bodyString = [self bodyStringForBlocks:inlineBlocks store:store metrics:m plain:plain];
            if (bodyString.length > 0) {
                if (isImage) { cursor += kBlockGap; }
                CGSize size = [CFText sizeOfAttributedString:bodyString width:maxContentW];
                textRel = CGRectMake(0, cursor, size.width, size.height);
                contentW = MAX(contentW, size.width);
                cursor += size.height;
                bottomPad = kBottomPad;
                boostGap = kBoostGapText; boostBottom = kBoostBottomText;
            } else {
                bodyString = nil;
            }
        }
        if (codeBlock) {
            NSAttributedString *code = CFHighlightCode(codeBlock.text ?: @"", codeBlock.language, m);
            L.codeText = code;
            if (plain.length) { [plain appendString:@"\n"]; }
            [plain appendString:codeBlock.text ?: @""];
            CGFloat maxCodeW = maxBubbleW - 2 * kCodeInsetX - 2 * kCodePad;
            CGSize cs = [CFText sizeOfAttributedString:code width:maxCodeW];
            cursor += bodyString ? kBlockGap : kCodeTopGap;
            codeBoxRel = CGRectMake(0, cursor, cs.width + 2 * kCodePad, cs.height + 2 * kCodePad);
            cursor += codeBoxRel.size.height;
            bottomPad = kBottomPad;
            boostGap = kBoostGapText; boostBottom = kBoostBottomText;
        }
        if (isFile) {
            NSString *name = attachment.name ?: @"file";
            L.fileNameText = [[NSAttributedString alloc] initWithString:name attributes:@{
                NSFontAttributeName: m.bodyFont, NSForegroundColorAttributeName: CFTheme.text}];
            if (plain.length) { [plain appendString:@"\n"]; }
            [plain appendString:name];
            if (bodyString || codeBlock) { cursor += kBlockGap; }
            CGFloat nameW = [CFText widthOfString:name font:m.bodyFont];
            CGFloat rowH = MAX(kFileRowHeight, m.bodyLineHeight + 11.6);
            fileRel = CGRectMake(0, cursor, nameW, rowH);
            cursor += rowH;
            bottomPad = kBottomPad;
            boostGap = kBoostGapText; boostBottom = kBoostBottomText;
        }
    }

    // Boosts: pills that wrap, then the add-boost button.
    NSMutableArray<NSValue *> *pillRel = [NSMutableArray array];
    NSMutableArray<NSAttributedString *> *pillTexts = [NSMutableArray array];
    CGRect addRel = CGRectZero;
    CGFloat stripW = 0;
    CGFloat ph = kPillHeight * s;
    if (item.boosts.count > 0) {
        CGFloat stripMaxW = isImage ? bubbleW - 2 * kBoostStripInsetImage : maxContentW;
        CGFloat x = 0, rowY = 0;
        for (CFBoostItem *b in item.boosts) {
            BOOL emoji = CFIsEmojiText(b.content);
            UIFont *font = emoji ? m.boostEmojiFont : m.boostTextFont;
            NSAttributedString *t = [[NSAttributedString alloc] initWithString:b.content attributes:@{
                NSFontAttributeName: font, NSForegroundColorAttributeName: CFTheme.text}];
            [pillTexts addObject:t];
            CGFloat tw = [CFText widthOfString:b.content font:font];
            CGFloat pw = 2 + (1.6 + kPillAvatar + 4.5) * s + tw + (emoji ? 2.7 : 6.75) * s;
            if (x > 0 && x + pw > stripMaxW) { x = 0; rowY += ph + kPillRowGap; }
            [pillRel addObject:[NSValue valueWithCGRect:CGRectMake(x, rowY, pw, ph)]];
            stripW = MAX(stripW, x + pw);
            x += pw + kPillGap;
        }
        if (x > 0 && x + ph > stripMaxW) { x = 0; rowY += ph + kPillRowGap; }
        addRel = CGRectMake(x, rowY, ph, ph);
        stripW = MAX(stripW, x + ph);
        cursor += boostGap;
        CGFloat stripTop = cursor;
        for (NSUInteger i = 0; i < pillRel.count; i++) {
            CGRect r = pillRel[i].CGRectValue;
            r.origin.y += stripTop;
            pillRel[i] = [NSValue valueWithCGRect:r];
        }
        addRel.origin.y += stripTop;
        cursor += rowY + ph;
        bottomPad = boostBottom;
    }
    cursor += bottomPad;
    CGFloat bubbleH = cursor;

    // Bubble width: fit to content, up to the row.
    if (bubbleW == 0) {
        CGFloat inner = MAX(headerExtent, contentW);
        if (!CGRectIsEmpty(codeBoxRel)) { inner = MAX(inner, codeBoxRel.size.width + 2 * (kCodeInsetX - kBubblePadX)); }
        if (!CGRectIsEmpty(fileRel)) { inner = MAX(inner, fileRel.size.width + 136.0 - 2 * kBubblePadX); }
        inner = MAX(inner, stripW);
        bubbleW = MIN(maxBubbleW, inner + 2 * kBubblePadX);
    }
    CGFloat bubbleX = pres.isMine ? W - kBubbleLeft - bubbleW : kBubbleLeft;
    L.bubbleFrame = CGRectMake(bubbleX, bubbleTop, bubbleW, bubbleH);
    L.bubbleStyle = emojiOnly ? CFBubbleStyleNone : (pres.mentionsMe ? CFBubbleStyleMention : CFBubbleStyleNormal);

    CGFloat contentX = bubbleX + kBubblePadX;
    CGFloat headerY = bubbleTop + kHeaderTop;
    if (pres.isMine) {
        CGFloat right = bubbleX + bubbleW - kBubblePadX;
        L.headerFrame = CGRectMake(right - headerW - 1, headerY, headerW + 1, headerH);
        L.dotsFrame = CGRectMake(right - headerW - kDotsGap - kDotsWidth, headerY + (m.metaLineHeight - kDotsHeight) / 2, kDotsWidth, kDotsHeight);
    } else {
        L.headerFrame = CGRectMake(contentX, headerY, headerW + 1, headerH);
        L.dotsFrame = CGRectMake(contentX + headerW + kDotsGap, headerY + (m.metaLineHeight - kDotsHeight) / 2, kDotsWidth, kDotsHeight);
    }

    if (bodyString) {
        L.bodyText = bodyString;
        L.textFrame = CGRectMake(contentX, bubbleTop + textRel.origin.y, MIN(textRel.size.width + 1, maxContentW), textRel.size.height);
    }
    if (!CGRectIsEmpty(codeBoxRel)) {
        CGRect box = CGRectMake(bubbleX + kCodeInsetX, bubbleTop + codeBoxRel.origin.y, codeBoxRel.size.width, codeBoxRel.size.height);
        L.codeBoxFrame = box;
        L.codeTextFrame = CGRectMake(kCodePad, kCodePad, box.size.width - 2 * kCodePad + 1, box.size.height - 2 * kCodePad);
    }
    if (!CGRectIsEmpty(imageRel)) {
        L.imageFrame = CGRectOffset(imageRel, bubbleX, bubbleTop);
    }
    if (!CGRectIsEmpty(fileRel)) {
        CGFloat midY = bubbleTop + fileRel.origin.y + fileRel.size.height / 2;
        CGFloat x = bubbleX + 16.9;
        L.fileIconFrame = CGRectMake(x, midY - 11, 18.7, 22);
        x += 18.7 + 7.3;
        L.fileNameFrame = CGRectMake(x, midY - m.bodyLineHeight / 2, fileRel.size.width, m.bodyLineHeight);
        x += fileRel.size.width + 14.3;
        L.fileDownloadFrame = CGRectMake(x, midY - 8.35, 16, 16.7);
        x += 16 + 25.3;
        L.fileShareFrame = CGRectMake(x, midY - 8.35, 11.3, 16.7);
    }
    if (pillRel.count > 0) {
        CGFloat stripX = isImage ? bubbleX + kBoostStripInsetImage : contentX;
        NSMutableArray *frames = [NSMutableArray array];
        for (NSValue *v in pillRel) { [frames addObject:[NSValue valueWithCGRect:CGRectOffset(v.CGRectValue, stripX, bubbleTop)]]; }
        L.boostFrames = frames;
        L.boostTexts = pillTexts;
        L.addBoostFrame = CGRectOffset(addRel, stripX, bubbleTop);
        L.boostAvatarSize = kPillAvatar * s;
    } else {
        L.boostFrames = @[];
        L.boostTexts = @[];
    }

    if (!threaded) {
        L.showsAvatar = YES;
        L.avatarUserID = msg.creatorID;
        L.avatarInitial = [CFAvatar initialForName:authorName];
        CGFloat ax = pres.isMine ? W - kBubbleRightInset - kAvatarSize : kAvatarX;
        L.avatarFrame = CGRectMake(ax, bubbleTop, kAvatarSize, kAvatarSize);
    }
    L.avatarInitial = L.avatarInitial ?: @"";

    L.height = bubbleTop + bubbleH + kRowBottomMargin;
    L.spacingBefore = threaded ? kThreadedGap : kRowGap;
    L.plainText = plain;
    NSString *what = plain.length ? plain : (isImage ? @"Image" : @"");
    L.accessibilityText = [NSString stringWithFormat:@"%@, %@, %@", authorName, time, what];
    return L;
}

@end
