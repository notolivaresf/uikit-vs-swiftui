#import "CFTextLayout.h"
#import "CFTheme.h"
#import <CoreText/CoreText.h>

NSAttributedStringKey const CFColorAttributeName = @"CFColor";
NSAttributedStringKey const CFMentionAvatarAttributeName = @"CFMentionAvatar";
NSAttributedStringKey const CFMentionNameAttributeName = @"CFMentionName";

static BOOL IsEmojiSequence(NSString *seq) {
    unichar c = [seq characterAtIndex:0];
    if (CFStringIsSurrogateHighCharacter(c)) {
        UTF32Char u = CFStringGetLongCharacterForSurrogatePair(c, seq.length > 1 ? [seq characterAtIndex:1] : 0);
        return u >= 0x1F000;
    }
    if ([seq rangeOfString:@"\uFE0F"].location != NSNotFound) return YES;
    return (c >= 0x2600 && c <= 0x27BF) || (c >= 0x2B00 && c <= 0x2BFF);
}

// Chrome gives colour emoji an advance of exactly one em and draws the image at the pen position;
// CoreText adds side bearings. Kern each emoji so the advances match the browser.
static void ApplyBrowserEmojiMetrics(NSMutableAttributedString *s) {
    NSString *str = s.string;
    NSUInteger n = str.length;
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [str characterAtIndex:i];
        if (c < 0x2000) continue;
        NSRange r = [str rangeOfComposedCharacterSequenceAtIndex:i];
        NSString *seq = [str substringWithRange:r];
        if (IsEmojiSequence(seq) && ![s attribute:CFMentionAvatarAttributeName atIndex:r.location effectiveRange:NULL]) {
            NSFont *font = [s attribute:NSFontAttributeName atIndex:r.location effectiveRange:NULL];
            if (font) {
                NSAttributedString *one = [s attributedSubstringFromRange:r];
                NSMutableAttributedString *plain = [one mutableCopy];
                [plain removeAttribute:NSKernAttributeName range:NSMakeRange(0, plain.length)];
                CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)plain);
                double adv = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
                CFRelease(line);
                [s addAttribute:NSKernAttributeName value:@(font.pointSize - adv) range:r];
            }
        }
        i = NSMaxRange(r) - 1;
    }
}

@implementation CFTextSource {
    CTTypesetterRef _typesetter;
}

- (instancetype)initWithString:(NSAttributedString *)input {
    if ((self = [super init])) {
        // Glyphs take their colour from the context, set per run from CFColorAttributeName when drawing.
        NSMutableAttributedString *string = [input mutableCopy];
        [string addAttribute:(id)kCTForegroundColorFromContextAttributeName value:@YES range:NSMakeRange(0, string.length)];
        ApplyBrowserEmojiMetrics(string);
        _attributedString = string;
    }
    return self;
}

- (CTTypesetterRef)typesetter {
    if (!_typesetter && _attributedString.length) {
        _typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedString);
    }
    return _typesetter;
}

- (void)dealloc {
    if (_typesetter) CFRelease(_typesetter);
}

@end

@implementation CFTextLayout {
    NSArray *_lines;          // CTLineRef
    NSArray<NSValue *> *_ranges;
    CGFloat _baseline;        // baseline offset from each line top
}

+ (instancetype)layoutWithString:(NSAttributedString *)string width:(CGFloat)width lineHeight:(CGFloat)lineHeight
                       strutFont:(NSFont *)font {
    return [self layoutWithString:string width:width lineHeight:lineHeight strutFont:font baselineAdjust:-font.pointSize / 16.0];
}

+ (instancetype)layoutWithString:(NSAttributedString *)string width:(CGFloat)width lineHeight:(CGFloat)lineHeight
                       strutFont:(NSFont *)font baselineAdjust:(CGFloat)adjust {
    return [self layoutWithSource:[[CFTextSource alloc] initWithString:string] width:width lineHeight:lineHeight
                        strutFont:font baselineAdjust:adjust];
}

+ (instancetype)layoutWithSource:(CFTextSource *)source width:(CGFloat)width lineHeight:(CGFloat)lineHeight
                       strutFont:(NSFont *)font baselineAdjust:(CGFloat)adjust {
    CFTextLayout *l = [[self alloc] init];
    [l layout:source width:width lineHeight:lineHeight font:font adjust:adjust];
    return l;
}

- (void)layout:(CFTextSource *)source width:(CGFloat)width lineHeight:(CGFloat)lineHeight font:(NSFont *)font
        adjust:(CGFloat)adjust {
    NSAttributedString *string = source.attributedString;
    _attributedString = string;
    _string = string.string;
    _lineHeight = lineHeight;
    CGFloat ascent = font.ascender, descent = -font.descender;
    // CSS half-leading around the strut font, plus a small correction measured against the screenshots.
    _baseline = (lineHeight - (ascent + descent)) / 2 + ascent + adjust;

    NSMutableArray *lines = [NSMutableArray array];
    NSMutableArray *ranges = [NSMutableArray array];
    CGFloat maxWidth = 0;
    CFIndex length = (CFIndex)string.length;
    if (length > 0) {
        CTTypesetterRef ts = [source typesetter];
        CFIndex start = 0;
        while (start < length) {
            CFIndex n = CTTypesetterSuggestLineBreak(ts, start, MAX(width, 1));
            if (n <= 0) n = CTTypesetterSuggestClusterBreak(ts, start, MAX(width, 1));
            if (n <= 0) n = 1;
            CTLineRef line = CTTypesetterCreateLine(ts, CFRangeMake(start, n));
            double w = CTLineGetTypographicBounds(line, NULL, NULL, NULL) - CTLineGetTrailingWhitespaceWidth(line);
            maxWidth = MAX(maxWidth, (CGFloat)w);
            [lines addObject:(__bridge_transfer id)line];
            [ranges addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)n)]];
            start += n;
            if (start < length) {
                unichar last = [string.string characterAtIndex:(NSUInteger)(start - 1)];
                if (last != '\n' && last != '\r' && last != 0x2028 && last != 0x2029) _wrapped = YES;
            }
        }
        // A trailing newline starts one more (empty) line, as in a browser.
        if ([string.string hasSuffix:@"\n"]) {
            CTLineRef line = CTTypesetterCreateLine(ts, CFRangeMake(length, 0));
            [lines addObject:(__bridge_transfer id)line];
            [ranges addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)length, 0)]];
        }
    }
    _lines = lines;
    _ranges = ranges;
    _lineCount = lines.count;
    _size = NSMakeSize(ceil(maxWidth * 100) / 100, lines.count * lineHeight);
}

- (void)drawAtPoint:(NSPoint)origin {
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    if (!ctx || _lines.count == 0) return;
    for (NSUInteger i = 0; i < _lines.count; i++) {
        CTLineRef line = (__bridge CTLineRef)_lines[i];
        CGFloat baselineY = origin.y + i * _lineHeight + _baseline;
        NSArray *runs = (__bridge NSArray *)CTLineGetGlyphRuns(line);
        for (id r in runs) {
            CTRunRef run = (__bridge CTRunRef)r;
            NSDictionary *attrs = (__bridge NSDictionary *)CTRunGetAttributes(run);
            NSArray *mention = attrs[CFMentionAvatarAttributeName];
            if (mention) {
                // Placeholder run: draw the mentioned person's avatar instead of glyphs.
                CGPoint p = CGPointZero;
                CTRunGetPositions(run, CFRangeMake(0, 1), &p);
                CGFloat d = [mention[2] doubleValue], lead = [mention[3] doubleValue], lift = [mention[4] doubleValue];
                NSRect rect = NSMakeRect(origin.x + p.x + lead, baselineY - lift - d / 2, d, d);
                CFDrawAvatar(rect, mention[1], [mention[0] integerValue], d * 0.46);
                continue;
            }
            NSColor *color = attrs[CFColorAttributeName] ?: CFTheme.text;
            // Unflip around the baseline so glyphs (including colour emoji) draw the usual way up.
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, origin.x, baselineY);
            CGContextScaleCTM(ctx, 1, -1);
            CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
            CGContextSetTextPosition(ctx, 0, 0);
            CTFontRef runFont = (__bridge CTFontRef)attrs[NSFontAttributeName];
            if (runFont && (CTFontGetSymbolicTraits(runFont) & kCTFontTraitColorGlyphs)) {
                // Emoji image at the pen position, as the browser draws it.
                CGGlyph g = 0;
                CTRunGetGlyphs(run, CFRangeMake(0, 1), &g);
                CGRect bb = CTFontGetBoundingRectsForGlyphs(runFont, kCTFontOrientationDefault, &g, NULL, 1);
                CGContextTranslateCTM(ctx, -bb.origin.x, 0);
            }
            CGContextSetFillColorWithColor(ctx, color.CGColor);
            CTRunDraw(run, ctx, CFRangeMake(0, 0));
            CGContextRestoreGState(ctx);
        }
    }
}

- (NSUInteger)lineIndexForY:(CGFloat)y {
    if (_lines.count == 0) return 0;
    NSInteger i = (NSInteger)floor(y / _lineHeight);
    if (i < 0) i = 0;
    if (i >= (NSInteger)_lines.count) i = (NSInteger)_lines.count - 1;
    return (NSUInteger)i;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {
    if (_lines.count == 0) return 0;
    if (point.y < 0) return 0;
    if (point.y >= _lines.count * _lineHeight) return _string.length;
    NSUInteger i = [self lineIndexForY:point.y];
    CTLineRef line = (__bridge CTLineRef)_lines[i];
    NSRange r = [_ranges[i] rangeValue];
    if (point.x <= 0) return r.location;
    CFIndex idx = CTLineGetStringIndexForPosition(line, CGPointMake(point.x, 0));
    if (idx == kCFNotFound) idx = (CFIndex)r.location;
    NSUInteger end = NSMaxRange(r);
    // Do not land after the line's own newline or trailing space: that would be the next line.
    while (end > r.location && end <= _string.length &&
           [[NSCharacterSet newlineCharacterSet] characterIsMember:[_string characterAtIndex:end - 1]]) end--;
    if ((NSUInteger)idx > end) idx = (CFIndex)end;
    if ((NSUInteger)idx < r.location) idx = (CFIndex)r.location;
    return (NSUInteger)idx;
}

- (void)enumerateRectsForRange:(NSRange)range usingBlock:(void (^)(NSRect))block {
    for (NSUInteger i = 0; i < _lines.count; i++) {
        NSRange lr = [_ranges[i] rangeValue];
        NSUInteger a = MAX(range.location, lr.location);
        NSUInteger b = MIN(NSMaxRange(range), NSMaxRange(lr));
        if (b <= a) continue;
        CTLineRef line = (__bridge CTLineRef)_lines[i];
        CGFloat x1 = CTLineGetOffsetForStringIndex(line, (CFIndex)a, NULL);
        CGFloat x2;
        if (b == NSMaxRange(lr)) {
            // Selection runs to the end of this line (and maybe beyond): cover the whole rest of the line.
            x2 = MAX(CTLineGetTypographicBounds(line, NULL, NULL, NULL), x1 + 4);
        } else {
            x2 = CTLineGetOffsetForStringIndex(line, (CFIndex)b, NULL);
        }
        if (x2 <= x1) x2 = x1 + 4;
        block(NSMakeRect(x1, i * _lineHeight, x2 - x1, _lineHeight));
    }
}

@end

NSSize CFSingleLineSize(NSAttributedString *string) {
    if (string.length == 0) return NSZeroSize;
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
    CGFloat ascent = 0, descent = 0;
    double w = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
    CFRelease(line);
    return NSMakeSize(w, ascent + descent);
}
