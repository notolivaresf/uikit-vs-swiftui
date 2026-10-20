#import "CFTheme.h"

static UIColor *CFDynamic(uint32_t light, uint32_t dark) {
    UIColor *l = [CFTheme colorWithHex:light];
    UIColor *d = [CFTheme colorWithHex:dark];
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? d : l;
    }];
}

static uint32_t CFCRC32(NSString *string) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = data.bytes;
    uint32_t c = 0xFFFFFFFF;
    for (NSUInteger i = 0; i < data.length; i++) {
        c ^= bytes[i];
        for (int k = 0; k < 8; k++) { c = (c & 1) ? (c >> 1) ^ 0xEDB88320 : c >> 1; }
    }
    return ~c;
}

@implementation CFTheme

+ (UIColor *)colorWithHex:(uint32_t)hex {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1];
}

#define CF_COLOR(name, light, dark) \
+ (UIColor *)name { static UIColor *c; static dispatch_once_t once; dispatch_once(&once, ^{ c = CFDynamic(light, dark); }); return c; }

CF_COLOR(background, 0xFFFFFF, 0x000000)
CF_COLOR(text, 0x000000, 0xFFFFFF)
CF_COLOR(bubble, 0xF3F2EE, 0x222222)
CF_COLOR(borderDark, 0xE5E4E1, 0x2E2E2E)
CF_COLOR(borderDarker, 0xAFAEAA, 0x555555)
CF_COLOR(pillBackground, 0xFFFFFF, 0x000000)
CF_COLOR(codeKeyword, 0xD73A49, 0xFF7B72)
CF_COLOR(codeEntity, 0x6F42C1, 0xD2A8FF)
CF_COLOR(codeConstant, 0x005CC5, 0x79C0FF)
CF_COLOR(codeString, 0x032F62, 0x79C0FF)
CF_COLOR(codeComment, 0x6A737D, 0x8B949E)
CF_COLOR(orange, 0xFF6A0D, 0xFF6A0D)

+ (UIColor *)secondaryText {
    static UIColor *c; static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIColor *l = [UIColor colorWithWhite:0 alpha:0.5], *d = [UIColor colorWithWhite:1 alpha:0.5];
        c = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? d : l; }];
    });
    return c;
}

+ (UIColor *)mentionBubble {
    static UIColor *c; static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIColor *l = [[CFTheme colorWithHex:0xBE1600] colorWithAlphaComponent:0.10];
        UIColor *d = [[CFTheme colorWithHex:0xFF7563] colorWithAlphaComponent:0.20];
        c = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? d : l; }];
    });
    return c;
}

+ (UIColor *)avatarColorForUserID:(NSInteger)userID {
    static NSArray<UIColor *> *palette; static dispatch_once_t once;
    dispatch_once(&once, ^{
        uint32_t hex[] = {0xAF2E1B, 0xCC6324, 0x3B4B59, 0xBFA07A, 0xED8008, 0xED3F1C, 0xBF1B1B, 0x736B1E, 0xD07B53,
                          0x736356, 0xAD1D1D, 0xBF7C2A, 0xC09C6F, 0x698F9C, 0x7C956B, 0x5D618F, 0x3B3633, 0x67695E};
        NSMutableArray *a = [NSMutableArray array];
        for (int i = 0; i < 18; i++) { [a addObject:[CFTheme colorWithHex:hex[i]]]; }
        palette = a;
    });
    uint32_t crc = CFCRC32([NSString stringWithFormat:@"%ld", (long)userID]);
    return palette[crc % palette.count];
}

@end

@implementation CFMetrics

+ (CFMetrics *)metricsForTraitCollection:(UITraitCollection *)traits {
    static NSMutableDictionary<UIContentSizeCategory, CFMetrics *> *cache;
    if (!cache) { cache = [NSMutableDictionary dictionary]; }
    UIContentSizeCategory category = traits.preferredContentSizeCategory;
    if (!category || [category isEqualToString:UIContentSizeCategoryUnspecified]) { category = UIContentSizeCategoryLarge; }
    CFMetrics *m = cache[category];
    if (!m) {
        m = [[CFMetrics alloc] initWithCategory:category];
        cache[category] = m;
    }
    return m;
}

- (instancetype)initWithCategory:(UIContentSizeCategory)category {
    if ((self = [super init])) {
        _category = [category copy];
        UITraitCollection *t = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:category];
        CGFloat s = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledValueForValue:16 compatibleWithTraitCollection:t] / 16.0;
        _scale = s;
        _bodyFont = [UIFont systemFontOfSize:16 * s];
        _mentionFont = [UIFont systemFontOfSize:16 * s weight:UIFontWeightSemibold];
        _nameFont = [UIFont systemFontOfSize:12.8 * s weight:UIFontWeightBold];
        _timeFont = [UIFont systemFontOfSize:12.8 * s];
        _separatorFont = [UIFont systemFontOfSize:12.8 * s weight:UIFontWeightSemibold];
        _codeFont = [UIFont monospacedSystemFontOfSize:12.8 * s weight:UIFontWeightRegular];
        _emojiOnlyFont = [UIFont systemFontOfSize:38.4 * s];
        _boostEmojiFont = [UIFont systemFontOfSize:17.6 * s];
        _boostTextFont = [UIFont systemFontOfSize:13.6 * s];
        _titleFont = [UIFont systemFontOfSize:16 * s weight:UIFontWeightBold];
        _bodyLineHeight = 22.4 * s;
        _metaLineHeight = 19.2 * s;
        _separatorLineHeight = 17.92 * s;
        _codeLineHeight = 17.92 * s;
        _emojiLineHeight = 53.76 * s;
    }
    return self;
}

@end
