#import "CFTheme.h"
#import <CoreText/CoreText.h>

const CGFloat CFScreenPadX = 14.01;
const CGFloat CFAvatarSize = 35.27;
const CGFloat CFAvatarRing = 2.4;
const CGFloat CFBubbleInset = 40.8;
const CGFloat CFBubbleFarInset = 14.0;
const CGFloat CFBubbleRadius = 10.56;
const CGFloat CFBubblePadY = 10.56;
const CGFloat CFBubblePadX = 15.12;
const CGFloat CFBubbleTopMargin = 1.59;
const CGFloat CFBubbleBottomMargin = 1.6;
const CGFloat CFRowGap = 21.28;
const CGFloat CFThreadedMarginTop = -22.48;
const CGFloat CFHeaderHeight = 57.6;
const CGFloat CFComposerHeight = 90.0;
const CGFloat CFImageMaxWidth = 300.0;

static const CGFloat kScales[] = {1.0, 1.125, 1.25, 1.375, 1.5};
const NSInteger CFTextScaleCount = sizeof(kScales) / sizeof(kScales[0]);

CGFloat CFTextScaleAt(NSInteger step) {
    if (step < 0) step = 0;
    if (step >= CFTextScaleCount) step = CFTextScaleCount - 1;
    return kScales[step];
}

static NSColor *RGBA(unsigned hex, CGFloat alpha) {
    return [NSColor colorWithSRGBRed:((hex >> 16) & 255) / 255.0
                               green:((hex >> 8) & 255) / 255.0
                                blue:(hex & 255) / 255.0
                               alpha:alpha];
}

static NSColor *Dynamic(NSString *name, NSColor *light, NSColor *dark) {
    return [NSColor colorWithName:name dynamicProvider:^NSColor *(NSAppearance *appearance) {
        return [CFTheme isDark:appearance] ? dark : light;
    }];
}

#define DYNAMIC_COLOR(sel, lightHex, darkHex) \
    + (NSColor *)sel { \
        static NSColor *c; static dispatch_once_t once; \
        dispatch_once(&once, ^{ c = Dynamic(@#sel, RGBA(lightHex, 1), RGBA(darkHex, 1)); }); \
        return c; \
    }

@implementation CFTheme

+ (BOOL)isDark:(NSAppearance *)appearance {
    NSAppearanceName n = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    return [n isEqualToString:NSAppearanceNameDarkAqua];
}

DYNAMIC_COLOR(background, 0xFFFFFF, 0x000000)
DYNAMIC_COLOR(text, 0x000000, 0xFFFFFF)
DYNAMIC_COLOR(bubble, 0xF3F2EE, 0x222222)
DYNAMIC_COLOR(border, 0xF3F2EE, 0x222222)
DYNAMIC_COLOR(borderDark, 0xE5E4E1, 0x2E2E2E)
DYNAMIC_COLOR(borderDarker, 0xAFAEAA, 0x555555)
DYNAMIC_COLOR(pillBackground, 0xFFFFFF, 0x000000)
DYNAMIC_COLOR(codeBackground, 0xFFFFFF, 0x000000)
DYNAMIC_COLOR(codeKeyword, 0xD73A49, 0xFF7B72)
DYNAMIC_COLOR(codeEntity, 0x6F42C1, 0xD2A8FF)
DYNAMIC_COLOR(codeConstant, 0x005CC5, 0x79C0FF)
DYNAMIC_COLOR(codeString, 0x032F62, 0x79C0FF)
DYNAMIC_COLOR(codeComment, 0x6A737D, 0x8B949E)
DYNAMIC_COLOR(link, 0x0066EF, 0x43ABFF)
DYNAMIC_COLOR(selection, 0xB4D7FF, 0x2C5172)

+ (NSColor *)mentionBubble {
    static NSColor *c; static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Campfire's red at 10 % (light) and 20 % (dark), over the page background.
        c = Dynamic(@"mentionBubble", RGBA(0xBE1600, 0.10), RGBA(0xFF7563, 0.20));
    });
    return c;
}

+ (NSColor *)dimText {
    static NSColor *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = Dynamic(@"dimText", RGBA(0x000000, 0.5), RGBA(0xFFFFFF, 0.5)); });
    return c;
}

+ (NSColor *)orange {
    static NSColor *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = RGBA(0xFF6A0D, 1); });
    return c;
}

static uint32_t CRC32(const char *s, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= (uint8_t)s[i];
        for (int k = 0; k < 8; k++) c = (c & 1) ? (c >> 1) ^ 0xEDB88320u : c >> 1;
    }
    return ~c;
}

+ (NSColor *)avatarColorForUserID:(NSInteger)userID {
    static NSArray<NSColor *> *palette; static dispatch_once_t once;
    dispatch_once(&once, ^{
        unsigned hex[] = {0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
                          0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E};
        NSMutableArray *a = [NSMutableArray array];
        for (size_t i = 0; i < sizeof(hex) / sizeof(hex[0]); i++) [a addObject:RGBA(hex[i], 1)];
        palette = a;
    });
    // Campfire: crc32 of the decimal user id, modulo the palette size.
    char buf[32];
    int n = snprintf(buf, sizeof buf, "%ld", (long)userID);
    return palette[CRC32(buf, (size_t)n) % palette.count];
}

+ (NSFont *)fontOfSize:(CGFloat)size weight:(NSFontWeight)weight {
    return [NSFont systemFontOfSize:size weight:weight];
}

+ (NSFont *)monoFontOfSize:(CGFloat)size {
    return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
}

+ (CGFloat)monoKernForFont:(NSFont *)font {
    // The browser's SF Mono advances 0.6 em; the system monospaced font is a little wider.
    CTFontRef f = (__bridge CTFontRef)font;
    UniChar zero = '0';
    CGGlyph g = 0;
    CTFontGetGlyphsForCharacters(f, &zero, &g, 1);
    CGFloat advance = CTFontGetAdvancesForGlyphs(f, kCTFontOrientationHorizontal, &g, NULL, 1);
    return font.pointSize * 0.6 - advance;
}

@end

void CFDrawAvatar(NSRect rect, NSString *name, NSInteger userID, CGFloat fontSize) {
    [[CFTheme avatarColorForUserID:userID] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
    NSString *initial = name.length ? [[name substringToIndex:[name rangeOfComposedCharacterSequenceAtIndex:0].length] uppercaseString] : @"?";
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:fontSize weight:NSFontWeightBold],
                            NSForegroundColorAttributeName: NSColor.whiteColor};
    NSSize s = [initial sizeWithAttributes:attrs];
    [initial drawAtPoint:NSMakePoint(NSMidX(rect) - s.width / 2, NSMidY(rect) - s.height / 2) withAttributes:attrs];
}
