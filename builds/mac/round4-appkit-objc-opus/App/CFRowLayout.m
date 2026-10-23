#import "CFRowLayout.h"
#import "CFTheme.h"
#import <CoreText/CoreText.h>

// ---- Measured constants (points at text scale 1) ----
static const CGFloat kBodySize = 16, kBodyLine = 22.4;
static const CGFloat kMetaSize = 12.8, kMetaLine = 19.2;
static const CGFloat kHeaderBlock = 21.96;     // header line box incl. its gap to the body
static const CGFloat kHeaderTextDY = 1.8;      // meta line box offset inside the header block
static const CGFloat kDotsGap = 12.4, kDotD = 4.3, kDotPitch = 5.83;
static const CGFloat kEmojiSize = 38.4, kEmojiLine = 53.76, kEmojiBaselineAdjust = -1.1, kBodyBaselineAdjust = 0;
static const CGFloat kCodeSize = 12.8, kCodeLine = 17.92, kCodePad = 12.8, kCodeRadius = 6.4;
static const CGFloat kCodeMarginX = 1.4, kCodeMarginTop = 0.5, kCodeMarginBottom = 1.45, kCodeAfterText = 4;
static const CGFloat kSepMarginY = 17.02, kSepPadY = 8.5, kSepPadX = 23.5, kSepSize = 12.8, kSepLine = 17.92;
static const CGFloat kImageTopExtra = 11.48, kImageInset = 1.0, kCaptionGap = 8;
static const CGFloat kStripGapText = 4, kStripGapImage = 5, kStripBottomImage = 8, kImageStripPadX = 10.2;
static const CGFloat kPillGap = 4, kPillRowGap = 4, kPillBorder = 1, kPillPadL = 1.5, kPillAvatar = 23.5;
static const CGFloat kPillInnerGap = 4.6, kPillPadR = 7.7, kPillEmojiPadR = 8.8, kPillEmojiH = 29, kPillTextH = 26, kAddSize = 28;
static const CGFloat kPillEmojiSize = 17.6, kPillTextSize = 12.8;
static const CGFloat kFileContentH = 33.92, kFileIconW = 19.4, kFileIconH = 22, kFileIconLead = 1.4, kFileNameGap = 6.6;
static const CGFloat kFileDownloadOffset = 22.3, kFileShareOffset = 39.2, kFileTrail = 31.5;
static const CGFloat kMentionLead = 1.4, kMentionD = 17.4, kMentionTrail = 2.9, kMentionLift = 5.4;

NSString *CFTimeString(NSDate *date) {
    static NSDateFormatter *f; static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        f.dateFormat = @"h:mm a";
    });
    return [f stringFromDate:date];
}

NSString *CFDayString(NSDate *date) {
    static NSDateFormatter *f; static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        f.dateFormat = @"MMMM d, yyyy";
    });
    return [[f stringFromDate:date] uppercaseString];
}

void CFDrawSymbol(NSString *name, NSRect rect, CGFloat pointSize, NSFontWeight weight, NSColor *color) {
    NSImage *symbol = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    if (!symbol) return;
    NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    cfg = [cfg configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationPreferringMonochrome]];
    symbol = [symbol imageWithSymbolConfiguration:cfg];
    NSColor *resolved = [NSColor colorWithCGColor:color.CGColor] ?: color;
    NSSize s = symbol.size;
    // Tint the template: draw it, then fill over its own pixels.
    // (Drawn under the light appearance: in dark, template symbols render with a filled background layer.)
    NSImage *tinted = [NSImage imageWithSize:s flipped:NO drawingHandler:^BOOL(NSRect dst) {
        [[NSAppearance appearanceNamed:NSAppearanceNameAqua] performAsCurrentDrawingAppearance:^{
            [symbol drawInRect:dst];
            [resolved set];
            NSRectFillUsingOperation(dst, NSCompositingOperationSourceAtop);
        }];
        return YES;
    }];
    NSRect r = NSMakeRect(NSMidX(rect) - s.width / 2, NSMidY(rect) - s.height / 2, s.width, s.height);
    [tinted drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}

// ---- Run delegate for the inline mention avatar ----

typedef struct { CGFloat width, ascent, descent; } CFPlaceholderMetrics;
static void PHDealloc(void *ref) { free(ref); }
static CGFloat PHAscent(void *ref) { return ((CFPlaceholderMetrics *)ref)->ascent; }
static CGFloat PHDescent(void *ref) { return ((CFPlaceholderMetrics *)ref)->descent; }
static CGFloat PHWidth(void *ref) { return ((CFPlaceholderMetrics *)ref)->width; }

static NSAttributedString *MentionPlaceholder(NSInteger userID, NSString *name, NSFont *font, CGFloat s) {
    CFPlaceholderMetrics *m = malloc(sizeof *m);
    m->width = (kMentionLead + kMentionD + kMentionTrail) * s;
    m->ascent = font.ascender;
    m->descent = -font.descender;
    CTRunDelegateCallbacks cb = {kCTRunDelegateVersion1, PHDealloc, PHAscent, PHDescent, PHWidth};
    CTRunDelegateRef d = CTRunDelegateCreate(&cb, m);
    NSDictionary *attrs = @{(id)kCTRunDelegateAttributeName: (__bridge id)d,
                            NSFontAttributeName: font,
                            CFMentionAvatarAttributeName: @[@(userID), name ?: @"", @(kMentionD * s), @(kMentionLead * s), @(kMentionLift * s)]};
    CFRelease(d);
    return [[NSAttributedString alloc] initWithString:@"￼" attributes:attrs];
}

// ---- Code highlighting (a few token classes, GitHub colours like Campfire) ----

static NSAttributedString *HighlightedCode(NSString *src, NSString *language, NSFont *font) {
    NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:src
        attributes:@{NSFontAttributeName: font, CFColorAttributeName: CFTheme.text,
                     NSKernAttributeName: @([CFTheme monoKernForFont:font])}];
    NSString *lang = language.lowercaseString;
    NSSet *keywords = nil;
    NSString *comment = nil;
    NSSet *definers = nil;
    if ([lang isEqualToString:@"ruby"]) {
        keywords = [NSSet setWithArray:@[@"def", @"end", @"class", @"module", @"if", @"else", @"elsif", @"unless", @"do",
                                         @"return", @"while", @"yield", @"self", @"nil", @"true", @"false", @"then"]];
        definers = [NSSet setWithArray:@[@"def", @"class", @"module"]];
        comment = @"#";
    } else if ([lang isEqualToString:@"swift"]) {
        keywords = [NSSet setWithArray:@[@"let", @"var", @"func", @"return", @"if", @"else", @"guard", @"struct", @"class",
                                         @"enum", @"import", @"for", @"in", @"while", @"true", @"false", @"nil", @"self"]];
        definers = [NSSet setWithArray:@[@"func", @"struct", @"class", @"enum"]];
        comment = @"//";
    } else if ([lang isEqualToString:@"sh"] || [lang isEqualToString:@"bash"]) {
        keywords = [NSSet setWithArray:@[@"if", @"then", @"fi", @"for", @"do", @"done", @"echo", @"export"]];
        comment = @"#";
    } else {
        return a;
    }
    NSUInteger n = src.length, i = 0;
    BOOL expectName = NO;
    NSCharacterSet *ident = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?!"];
    while (i < n) {
        unichar c = [src characterAtIndex:i];
        if (comment && [src compare:comment options:0 range:NSMakeRange(i, MIN(comment.length, n - i))] == NSOrderedSame &&
            !(c == '#' && i + 1 < n && [src characterAtIndex:i + 1] == '{')) {
            NSUInteger e = i;
            while (e < n && [src characterAtIndex:e] != '\n') e++;
            [a addAttribute:CFColorAttributeName value:CFTheme.codeComment range:NSMakeRange(i, e - i)];
            i = e;
            continue;
        }
        if (c == '"' || c == '\'') {
            NSUInteger e = i + 1;
            while (e < n && [src characterAtIndex:e] != c && [src characterAtIndex:e] != '\n') {
                if ([src characterAtIndex:e] == '\\') e++;
                e++;
            }
            if (e < n && [src characterAtIndex:e] == c) e++;
            [a addAttribute:CFColorAttributeName value:CFTheme.codeString range:NSMakeRange(i, MIN(e, n) - i)];
            i = MIN(e, n);
            continue;
        }
        if ([ident characterIsMember:c]) {
            NSUInteger e = i;
            while (e < n && [ident characterIsMember:[src characterAtIndex:e]]) e++;
            NSString *word = [src substringWithRange:NSMakeRange(i, e - i)];
            unichar first = [word characterAtIndex:0];
            if (expectName) {
                [a addAttribute:CFColorAttributeName value:CFTheme.codeEntity range:NSMakeRange(i, e - i)];
                expectName = NO;
            } else if ([keywords containsObject:word]) {
                [a addAttribute:CFColorAttributeName value:CFTheme.codeKeyword range:NSMakeRange(i, e - i)];
                expectName = [definers containsObject:word];
            } else if (first >= '0' && first <= '9') {
                [a addAttribute:CFColorAttributeName value:CFTheme.codeConstant range:NSMakeRange(i, e - i)];
            }
            i = e;
            continue;
        }
        if (c == '\n') expectName = NO;
        i++;
    }
    return a;
}

// ---- Layout ----

static CFTextSource *CachedSource(CFMessage *m, NSString *key, NSAttributedString *(^build)(void)) {
    CFTextSource *src = m.layoutCache[key];
    if (!src) {
        src = [[CFTextSource alloc] initWithString:build()];
        m.layoutCache[key] = src;
    }
    return src;
}

@implementation CFTextFragment
- (NSRect)frame {
    return NSMakeRect(_origin.x, _origin.y, _layout.size.width, _layout.size.height);
}
@end

typedef NS_ENUM(NSInteger, CFItemKind) {
    CFItemCodeBox,
    CFItemImage,
    CFItemFile,
    CFItemPill,
    CFItemAddBoost,
};

@interface CFRowItem : NSObject
@property (nonatomic) CFItemKind kind;
@property (nonatomic) NSRect rect;
@property (nonatomic, strong) CFBoostItem *boost;
@property (nonatomic, strong) CFTextLayout *text;   // pill content
@property (nonatomic) NSRect textRect;
@property (nonatomic) NSRect avatarRect;
@property (nonatomic) NSRect iconRect, downloadRect, shareRect;
@end
@implementation CFRowItem
@end

@implementation CFRowLayout {
    CFTextLayout *_nameLayout, *_timeLayout, *_sepLayout;
    NSPoint _nameOrigin, _timeOrigin;
    NSRect _dotsRect;
    NSRect _sepPill;
    CGFloat _sepLineY;
    NSRect _avatarRect;
    NSMutableArray<CFRowItem *> *_items;
    BOOL _transparentBubble;
}

+ (instancetype)layoutForMessage:(CFMessage *)message width:(CGFloat)width scale:(CGFloat)scale {
    CFRowLayout *l = [[self alloc] init];
    [l layoutMessage:message width:width scale:scale];
    return l;
}

- (CFTextLayout *)lineLayout:(NSAttributedString *)s font:(NSFont *)font line:(CGFloat)line {
    return [CFTextLayout layoutWithString:s width:CGFLOAT_MAX lineHeight:line strutFont:font];
}

// Single-line labels (names, times, dates, boosts) repeat a lot: share their (immutable) layouts. Thread-safe.
- (CFTextLayout *)cachedLine:(NSString *)text font:(NSFont *)font color:(nullable NSColor *)color line:(CGFloat)line {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 20000; });
    NSString *key = [NSString stringWithFormat:@"%@|%@|%.3f|%p|%.3f", text, font.fontName, font.pointSize, color, line];
    CFTextLayout *l = [cache objectForKey:key];
    if (!l) {
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
        if (color) attrs[CFColorAttributeName] = color;
        l = [self lineLayout:[[NSAttributedString alloc] initWithString:text attributes:attrs] font:font line:line];
        [cache setObject:l forKey:key];
    }
    return l;
}

- (void)layoutMessage:(CFMessage *)m width:(CGFloat)W scale:(CGFloat)s {
    _message = m;
    _width = W;
    _scale = s;
    _items = [NSMutableArray array];
    NSMutableArray<CFTextFragment *> *fragments = [NSMutableArray array];

    NSFont *body = [CFTheme fontOfSize:kBodySize * s weight:NSFontWeightRegular];
    NSFont *meta = [CFTheme fontOfSize:kMetaSize * s weight:NSFontWeightRegular];
    NSFont *metaBold = [CFTheme fontOfSize:kMetaSize * s weight:NSFontWeightBold];

    _marginTop = m.isThreaded ? CFRowGap + CFThreadedMarginTop : CFRowGap;

    // Day separator.
    CGFloat y = 0;
    if (m.isFirstOfDay) {
        NSFont *sepFont = [CFTheme fontOfSize:kSepSize * s weight:NSFontWeightSemibold];
        _sepLayout = [self cachedLine:CFDayString(m.createdAt) font:sepFont color:nil line:kSepLine * s];
        CGFloat pillH = kSepLine * s + 2 * kSepPadY;
        CGFloat pillW = _sepLayout.size.width + 2 * kSepPadX;
        _sepPill = NSMakeRect(round((W - pillW) / 2 * 100) / 100, kSepMarginY, pillW, pillH);
        _sepLineY = kSepMarginY + pillH / 2;
        y = kSepMarginY * 2 + pillH;
    }

    CGFloat bubbleTop = y + CFBubbleTopMargin;
    CGFloat maxBubbleW = MAX(W - CFBubbleInset - CFBubbleFarInset, 60);
    CGFloat contentMaxW = maxBubbleW - 2 * CFBubblePadX;

    // Header: name, time, dots.
    _timeLayout = [self cachedLine:CFTimeString(m.createdAt) font:meta color:CFTheme.dimText line:kMetaLine * s];
    CGFloat spaceW = CFSingleLineSize([[NSAttributedString alloc] initWithString:@" " attributes:@{NSFontAttributeName: meta}]).width + 0.8 * s;
    CGFloat headerW = _timeLayout.size.width + kDotsGap * s + (2 * kDotPitch + kDotD) * s;
    if (!m.isThreaded) {
        _nameLayout = [self cachedLine:m.authorName ?: @"" font:metaBold color:CFTheme.text line:kMetaLine * s];
        headerW += _nameLayout.size.width + spaceW;
    }

    // Body.
    CGFloat contentTop = bubbleTop + CFBubblePadY + kHeaderBlock * s;
    CGFloat contentW = 0;     // fit-content width of the body
    CGFloat cy = contentTop;  // running y, relative to the row
    CGFloat bottomPad = CFBubblePadY;
    BOOL imageRow = NO;
    // Positions inside the body are first computed with x relative to the content column, then shifted.
    NSMutableArray<CFTextFragment *> *bodyFragments = [NSMutableArray array];
    NSMutableArray<CFRowItem *> *bodyItems = [NSMutableArray array];

    if (m.isEmojiOnly) {
        _transparentBubble = YES;
        NSFont *ef = [CFTheme fontOfSize:kEmojiSize * s weight:NSFontWeightRegular];
        NSString *t = [m.blocks.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] ?: @"";
        CFTextSource *src = CachedSource(m, [NSString stringWithFormat:@"emoji@%.3f", s], ^NSAttributedString *{
            return [[NSAttributedString alloc] initWithString:t attributes:@{NSFontAttributeName: ef}];
        });
        CFTextLayout *tl = [CFTextLayout layoutWithSource:src width:contentMaxW lineHeight:kEmojiLine * s strutFont:ef
                                           baselineAdjust:kEmojiBaselineAdjust * s];
        CFTextFragment *f = [CFTextFragment new];
        f.layout = tl; f.origin = NSMakePoint(0, cy);
        [bodyFragments addObject:f];
        contentW = tl.wrapped ? contentMaxW : tl.size.width;
        cy += tl.size.height;
    } else {
        if (m.hasImage) {
            imageRow = YES;
            CGFloat bw = MIN(CFImageMaxWidth, maxBubbleW);
            CGFloat iw = bw - 2 * kImageInset;
            CGFloat ih = m.imageWidth > 0 ? round(iw * m.imageHeight / (CGFloat)m.imageWidth * 100) / 100 : iw;
            cy = contentTop + kImageTopExtra * s;
            CFRowItem *it = [CFRowItem new];
            it.kind = CFItemImage;
            it.rect = NSMakeRect(kImageInset - CFBubblePadX, cy, iw, ih);   // x relative to content column
            [bodyItems addObject:it];
            cy += ih;
            contentW = bw - 2 * CFBubblePadX;
            bottomPad = kImageInset;
        }
        // Text and code blocks, in order.
        NSMutableAttributedString *para = [[NSMutableAttributedString alloc] init];
        BOOL anyText = NO;
        CGFloat (^layoutText)(NSAttributedString *, CGFloat) = ^CGFloat(NSAttributedString *str, CGFloat top) {
            NSString *key = [NSString stringWithFormat:@"p%lu@%.3f", (unsigned long)bodyFragments.count, s];
            CFTextSource *src = CachedSource(m, key, ^NSAttributedString *{ return str; });
            CFTextLayout *tl = [CFTextLayout layoutWithSource:src width:contentMaxW lineHeight:kBodyLine * s strutFont:body
                                               baselineAdjust:kBodyBaselineAdjust * s];
            CFTextFragment *f = [CFTextFragment new];
            f.layout = tl; f.origin = NSMakePoint(0, top);
            [bodyFragments addObject:f];
            return tl.wrapped ? contentMaxW : tl.size.width;
        };
        for (CFBlockItem *b in m.blocks) {
            if (b.type == CFBlockTypeText) {
                [para appendAttributedString:[[NSAttributedString alloc] initWithString:b.text ?: @""
                    attributes:@{NSFontAttributeName: body, CFColorAttributeName: CFTheme.text}]];
            } else if (b.type == CFBlockTypeMention) {
                NSFont *mf = [CFTheme fontOfSize:kBodySize * s weight:NSFontWeightSemibold];
                [para appendAttributedString:MentionPlaceholder(b.mentionedUserID, b.mentionName, body, s)];
                [para appendAttributedString:[[NSAttributedString alloc] initWithString:b.mentionName ?: @""
                    attributes:@{NSFontAttributeName: mf, CFColorAttributeName: CFTheme.text, CFMentionNameAttributeName: @YES}]];
            } else if (b.type == CFBlockTypeCode) {
                if (para.length) {
                    CGFloat top = cy + (m.hasImage && !anyText ? kCaptionGap * s : 0);
                    contentW = MAX(contentW, layoutText(para, top));
                    cy = top + bodyFragments.lastObject.layout.size.height + kCodeAfterText * s;
                    [para setAttributedString:[NSAttributedString new]];
                    anyText = YES;
                }
                NSFont *mono = [CFTheme monoFontOfSize:kCodeSize * s];
                NSString *src = b.text ?: @"";
                CGFloat innerMax = contentMaxW - 2 * kCodeMarginX - 2 * kCodePad;
                NSString *key = [NSString stringWithFormat:@"c%lu@%.3f", (unsigned long)bodyFragments.count, s];
                CFTextSource *codeSource = CachedSource(m, key, ^NSAttributedString *{ return HighlightedCode(src, b.language, mono); });
                CFTextLayout *cl = [CFTextLayout layoutWithSource:codeSource width:innerMax lineHeight:kCodeLine * s
                                                        strutFont:mono baselineAdjust:-mono.pointSize / 16.0];
                CGFloat boxW = (cl.wrapped ? innerMax : cl.size.width) + 2 * kCodePad;
                CGFloat boxTop = cy + kCodeMarginTop;
                CFRowItem *box = [CFRowItem new];
                box.kind = CFItemCodeBox;
                box.rect = NSMakeRect(kCodeMarginX, boxTop, boxW, cl.size.height + 2 * kCodePad);
                [bodyItems addObject:box];
                CFTextFragment *f = [CFTextFragment new];
                f.layout = cl; f.origin = NSMakePoint(kCodeMarginX + kCodePad, boxTop + kCodePad);
                [bodyFragments addObject:f];
                contentW = MAX(contentW, boxW + 2 * kCodeMarginX);
                cy = NSMaxY(box.rect) + kCodeMarginBottom;
                anyText = YES;
            }
        }
        if (para.length) {
            CGFloat top = cy + (m.hasImage ? kCaptionGap * s : 0);
            contentW = MAX(contentW, layoutText(para, top));
            cy = top + bodyFragments.lastObject.layout.size.height;
            anyText = YES;
        }
        if (m.hasImage && anyText) bottomPad = CFBubblePadY;
        if (m.fileName) {
            NSAttributedString *fn = [[NSAttributedString alloc] initWithString:m.fileName
                attributes:@{NSFontAttributeName: body, CFColorAttributeName: CFTheme.text}];
            CGFloat nameX = kFileIconLead + kFileIconW + kFileNameGap;
            CGFloat nameMax = MAX(contentMaxW - nameX - (kFileDownloadOffset + kFileShareOffset + kFileTrail - CFBubblePadX), 40);
            CFTextSource *fsrc = CachedSource(m, [NSString stringWithFormat:@"f@%.3f", s], ^NSAttributedString *{ return fn; });
            CFTextLayout *tl = [CFTextLayout layoutWithSource:fsrc width:nameMax lineHeight:kBodyLine * s strutFont:body
                                               baselineAdjust:-body.pointSize / 16.0];
            CGFloat h = MAX(kFileContentH * s, tl.size.height);
            CGFloat mid = cy + h / 2;
            CFTextFragment *f = [CFTextFragment new];
            f.layout = tl; f.origin = NSMakePoint(nameX, mid - tl.size.height / 2);
            [bodyFragments addObject:f];
            CGFloat nameEnd = nameX + tl.size.width;
            CFRowItem *it = [CFRowItem new];
            it.kind = CFItemFile;
            it.iconRect = NSMakeRect(kFileIconLead, mid - kFileIconH / 2, kFileIconW, kFileIconH);
            CGFloat dl = nameEnd + kFileDownloadOffset, sh = dl + kFileShareOffset;
            it.downloadRect = NSMakeRect(dl - 12, mid - 12, 24, 24);
            it.shareRect = NSMakeRect(sh - 12, mid - 12, 24, 24);
            [bodyItems addObject:it];
            contentW = MAX(contentW, sh + kFileTrail - CFBubblePadX);
            cy += h;
        }
        if (!anyText && !m.hasImage && !m.fileName) {
            cy += kBodyLine * s;   // empty message: keep one line
        }
    }

    // Boost strip (pills wrap; the add-boost button closes the strip).
    NSMutableArray<CFRowItem *> *pills = [NSMutableArray array];
    if (m.boosts.count > 0) {
        NSFont *pe = [CFTheme fontOfSize:kPillEmojiSize * s weight:NSFontWeightRegular];
        NSFont *pt = [CFTheme fontOfSize:kPillTextSize * s weight:NSFontWeightRegular];
        for (CFBoostItem *b in m.boosts) {
            BOOL emoji = [self isEmoji:b.content];
            NSFont *f = emoji ? pe : pt;
            CFTextLayout *tl = [self cachedLine:b.content ?: @"" font:f color:CFTheme.text
                                           line:(emoji ? kPillEmojiH - 2 : kPillTextH - 2) * s];
            CFRowItem *p = [CFRowItem new];
            p.kind = CFItemPill;
            p.boost = b;
            p.text = tl;
            CGFloat w = kPillBorder + kPillPadL + kPillAvatar * s + kPillInnerGap * s + tl.size.width + (emoji ? kPillEmojiPadR : kPillPadR) * s + kPillBorder;
            p.rect = NSMakeRect(0, 0, w, (emoji ? kPillEmojiH : kPillTextH) * s);
            [pills addObject:p];
        }
        CFRowItem *add = [CFRowItem new];
        add.kind = CFItemAddBoost;
        add.rect = NSMakeRect(0, 0, kAddSize * s, kAddSize * s);
        [pills addObject:add];

        CGFloat padX = imageRow ? kImageStripPadX : CFBubblePadX;
        CGFloat stripMaxW = maxBubbleW - 2 * padX;
        CGFloat oneLineW = 0;
        for (CFRowItem *p in pills) oneLineW += p.rect.size.width + (oneLineW > 0 ? kPillGap : 0);
        // The strip's own fit-content width counts toward the bubble width.
        if (!imageRow) contentW = MAX(contentW, MIN(oneLineW, stripMaxW));
        CGFloat stripW = imageRow ? MIN(CFImageMaxWidth, maxBubbleW) - 2 * padX : MIN(MAX(contentW, oneLineW), stripMaxW);
        stripW = MIN(stripW, stripMaxW);

        CGFloat top = cy + (imageRow && bodyFragments.count == 0 ? kStripGapImage : kStripGapText) * s;
        NSMutableArray *line = [NSMutableArray array];
        CGFloat x = 0, lineH = 0, lineTop = top;
        for (CFRowItem *p in pills) {
            CGFloat w = p.rect.size.width;
            if (line.count > 0 && x + kPillGap + w > stripW + 0.01) {
                for (CFRowItem *q in line) {
                    NSRect r = q.rect; r.origin.y = lineTop + (lineH - r.size.height) / 2; q.rect = r;
                }
                lineTop += lineH + kPillRowGap;
                [line removeAllObjects];
                x = 0; lineH = 0;
            }
            NSRect r = p.rect;
            r.origin.x = (line.count > 0 ? x + kPillGap : 0) + (padX - CFBubblePadX);
            x = (line.count > 0 ? x + kPillGap : 0) + w;
            p.rect = r;
            lineH = MAX(lineH, r.size.height);
            [line addObject:p];
        }
        for (CFRowItem *q in line) {
            NSRect r = q.rect; r.origin.y = lineTop + (lineH - r.size.height) / 2; q.rect = r;
        }
        cy = lineTop + lineH;
        bottomPad = (imageRow && bodyFragments.count == 0) ? kStripBottomImage * s : CFBubblePadY;
        [bodyItems addObjectsFromArray:pills];
    }

    CGFloat bubbleH = cy + bottomPad - bubbleTop;
    CGFloat bubbleW = imageRow ? MIN(CFImageMaxWidth, maxBubbleW)
                               : MIN(maxBubbleW, MAX(headerW, contentW) + 2 * CFBubblePadX);
    bubbleW = ceil(bubbleW * 100) / 100;
    CGFloat bubbleX = m.isMine ? W - CFBubbleInset - bubbleW : CFBubbleInset;
    _bubbleRect = NSMakeRect(bubbleX, bubbleTop, bubbleW, bubbleH);
    _height = NSMaxY(_bubbleRect) + CFBubbleBottomMargin;

    // Avatar.
    if (!m.isThreaded) {
        CGFloat ax = m.isMine ? W - CFScreenPadX - CFAvatarSize : CFScreenPadX;
        _avatarRect = NSMakeRect(ax, bubbleTop, CFAvatarSize, CFAvatarSize);
    } else {
        _avatarRect = NSZeroRect;
    }

    // Header positions.
    CGFloat headerY = bubbleTop + CFBubblePadY + kHeaderTextDY * s;
    CGFloat dotsW = (2 * kDotPitch + kDotD) * s;
    if (m.isMine) {
        CGFloat right = NSMaxX(_bubbleRect) - CFBubblePadX;
        if (_nameLayout) {
            _nameOrigin = NSMakePoint(right - _nameLayout.size.width, headerY);
            right = _nameOrigin.x - spaceW;
        }
        _timeOrigin = NSMakePoint(right - _timeLayout.size.width, headerY);
        _dotsRect = NSMakeRect(_timeOrigin.x - kDotsGap * s - dotsW, headerY, dotsW, kMetaLine * s);
    } else {
        CGFloat x = bubbleX + CFBubblePadX;
        if (_nameLayout) {
            _nameOrigin = NSMakePoint(x, headerY);
            x += _nameLayout.size.width + spaceW;
        }
        _timeOrigin = NSMakePoint(x, headerY);
        _dotsRect = NSMakeRect(x + _timeLayout.size.width + kDotsGap * s, headerY, dotsW, kMetaLine * s);
    }

    // Shift body content into place (it was laid out relative to the content column).
    CGFloat colX = bubbleX + CFBubblePadX;
    for (CFTextFragment *f in bodyFragments) {
        f.origin = NSMakePoint(f.origin.x + colX, f.origin.y);
        [fragments addObject:f];
    }
    for (CFRowItem *it in bodyItems) {
        it.rect = NSOffsetRect(it.rect, colX, 0);
        if (it.kind == CFItemFile) {
            it.iconRect = NSOffsetRect(it.iconRect, colX, 0);
            it.downloadRect = NSOffsetRect(it.downloadRect, colX, 0);
            it.shareRect = NSOffsetRect(it.shareRect, colX, 0);
        } else if (it.kind == CFItemPill) {
            NSRect r = it.rect;
            CGFloat ad = kPillAvatar * s;
            it.avatarRect = NSMakeRect(r.origin.x + kPillBorder + kPillPadL, NSMidY(r) - ad / 2, ad, ad);
            it.textRect = NSMakeRect(NSMaxX(it.avatarRect) + kPillInnerGap * s, NSMidY(r) - it.text.size.height / 2,
                                     it.text.size.width, it.text.size.height);
        }
        [_items addObject:it];
    }
    _fragments = fragments;
}

- (BOOL)isEmoji:(NSString *)s {
    if (s.length == 0) return NO;
    __block BOOL all = YES;
    [s enumerateSubstringsInRange:NSMakeRange(0, s.length) options:NSStringEnumerationByComposedCharacterSequences
                       usingBlock:^(NSString *sub, NSRange r, NSRange er, BOOL *stop) {
        unichar c = [sub characterAtIndex:0];
        if (c < 0x2000) { all = NO; *stop = YES; }
    }];
    return all;
}

// ---- Drawing ----

- (void)drawWithSelection:(NSArray<NSValue *> *)selection {
    CFMessage *m = _message;
    CGFloat s = _scale;

    if (_sepLayout) {
        [CFTheme.border setFill];
        NSRectFill(NSMakeRect(CFScreenPadX, _sepLineY - 1, _width - 2 * CFScreenPadX, 2));
        [CFTheme.border setFill];
        [[NSBezierPath bezierPathWithRoundedRect:_sepPill xRadius:_sepPill.size.height / 2 yRadius:_sepPill.size.height / 2] fill];
        [_sepLayout drawAtPoint:NSMakePoint(_sepPill.origin.x + kSepPadX, _sepPill.origin.y + kSepPadY)];
    }

    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:_bubbleRect xRadius:CFBubbleRadius yRadius:CFBubbleRadius];
    if (!_transparentBubble) {
        if (m.mentionsMe) {
            [CFTheme.background setFill];
            [bubblePath fill];
            [CFTheme.mentionBubble setFill];
        } else {
            [CFTheme.bubble setFill];
        }
        [bubblePath fill];
    }

    // Selection highlights under the text.
    for (NSUInteger i = 0; i < _fragments.count && i < selection.count; i++) {
        NSRange r = selection[i].rangeValue;
        if (r.location == NSNotFound || r.length == 0) continue;
        CFTextFragment *f = _fragments[i];
        [CFTheme.selection setFill];
        [f.layout enumerateRectsForRange:r usingBlock:^(NSRect rect) {
            NSRectFillUsingOperation(NSOffsetRect(rect, f.origin.x, f.origin.y), NSCompositingOperationSourceOver);
        }];
    }

    for (CFRowItem *it in _items) {
        switch (it.kind) {
            case CFItemCodeBox: {
                [CFTheme.codeBackground setFill];
                [[NSBezierPath bezierPathWithRoundedRect:it.rect xRadius:kCodeRadius yRadius:kCodeRadius] fill];
                // Re-draw selection over the code box background.
                NSUInteger idx = [self fragmentIndexInRect:it.rect];
                if (idx != NSNotFound && idx < selection.count) {
                    NSRange r = selection[idx].rangeValue;
                    if (r.location != NSNotFound && r.length) {
                        CFTextFragment *f = _fragments[idx];
                        [CFTheme.selection setFill];
                        [f.layout enumerateRectsForRange:r usingBlock:^(NSRect rect) {
                            NSRectFillUsingOperation(NSOffsetRect(rect, f.origin.x, f.origin.y), NSCompositingOperationSourceOver);
                        }];
                    }
                }
                break;
            }
            case CFItemImage: {
                [NSGraphicsContext saveGraphicsState];
                [bubblePath addClip];
                [m.imageColor ?: NSColor.grayColor setFill];
                NSRectFill(it.rect);
                [NSGraphicsContext restoreGraphicsState];
                break;
            }
            case CFItemFile: {
                CFDrawSymbol(@"doc.text.fill", it.iconRect, 21 * s, NSFontWeightRegular, CFTheme.text);
                CFDrawSymbol(@"arrow.down.to.line.compact", it.downloadRect, 16 * s, NSFontWeightBold, CFTheme.text);
                CFDrawSymbol(@"square.and.arrow.up", it.shareRect, 15 * s, NSFontWeightMedium, CFTheme.text);
                break;
            }
            case CFItemPill: {
                NSRect r = it.rect;
                NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r, 0.5, 0.5)
                                                                  xRadius:r.size.height / 2 - 0.5 yRadius:r.size.height / 2 - 0.5];
                [CFTheme.pillBackground setFill];
                [p fill];
                [CFTheme.borderDark setStroke];
                p.lineWidth = kPillBorder;
                [p stroke];
                CFDrawAvatar(it.avatarRect, it.boost.boosterName, it.boost.boosterID, 11 * s);
                [it.text drawAtPoint:it.textRect.origin];
                break;
            }
            case CFItemAddBoost: {
                NSRect r = it.rect;
                NSBezierPath *p = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, 0.5, 0.5)];
                [CFTheme.pillBackground setFill];
                [p fill];
                [CFTheme.borderDark setStroke];
                p.lineWidth = kPillBorder;
                [p stroke];
                CFDrawSymbol(@"face.smiling", NSOffsetRect(r, -0.5, -0.5), 15 * s, NSFontWeightMedium, CFTheme.text);
                NSRect plus = NSMakeRect(NSMidX(r) + 3.2 * s, NSMidY(r) + 3.0 * s, 7 * s, 7 * s);
                [CFTheme.pillBackground setFill];
                [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(plus, -1, -1)] fill];
                CFDrawSymbol(@"plus", plus, 7.5 * s, NSFontWeightBold, CFTheme.text);
                break;
            }
        }
    }

    for (CFTextFragment *f in _fragments) [f.layout drawAtPoint:f.origin];

    // Header.
    if (_nameLayout) [_nameLayout drawAtPoint:_nameOrigin];
    [_timeLayout drawAtPoint:_timeOrigin];
    [CFTheme.dimText setFill];
    CGFloat dotY = _dotsRect.origin.y + _timeLayout.lineHeight / 2 + 0.6 * s;
    for (int i = 0; i < 3; i++) {
        CGFloat cx = _dotsRect.origin.x + kDotD * s / 2 + i * kDotPitch * s;
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - kDotD * s / 2, dotY - kDotD * s / 2, kDotD * s, kDotD * s)] fill];
    }

    // Avatar with a ring of page background where it overlaps the bubble.
    if (!NSIsEmptyRect(_avatarRect)) {
        [CFTheme.background setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(_avatarRect, -CFAvatarRing, -CFAvatarRing)] fill];
        CFDrawAvatar(_avatarRect, m.authorName, m.creatorID, 16 * 1.0);
    }
}

- (NSUInteger)fragmentIndexInRect:(NSRect)rect {
    for (NSUInteger i = 0; i < _fragments.count; i++) {
        if (NSContainsRect(rect, NSInsetRect(_fragments[i].frame, 0.5, 0.5)) ||
            NSPointInRect(_fragments[i].origin, rect)) return i;
    }
    return NSNotFound;
}

@end
