#import "CFMessage.h"

@implementation CFBlockItem
@end

@implementation CFBoostItem
@end

@implementation CFMessage

- (instancetype)init {
    if ((self = [super init])) {
        _boosts = [NSMutableArray array];
        _blocks = @[];
        _layoutCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *)displayText {
    NSMutableString *s = [NSMutableString string];
    for (CFBlockItem *b in self.blocks) {
        switch (b.type) {
            case CFBlockTypeText: [s appendString:b.text ?: @""]; break;
            case CFBlockTypeMention: [s appendString:b.mentionName ?: @""]; break;
            case CFBlockTypeCode:
                if (s.length && ![s hasSuffix:@"\n"]) [s appendString:@"\n"];
                [s appendString:b.text ?: @""];
                break;
        }
    }
    if (self.fileName) {
        if (s.length) [s appendString:@"\n"];
        [s appendString:self.fileName];
    }
    return s;
}

@end
