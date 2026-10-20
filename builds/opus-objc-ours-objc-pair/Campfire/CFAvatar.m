#import "CFAvatar.h"
#import "CFTheme.h"

@implementation CFAvatar

+ (NSString *)initialForName:(NSString *)name {
    if (name.length == 0) { return @"?"; }
    NSRange r = [name rangeOfComposedCharacterSequenceAtIndex:0];
    return [[name substringWithRange:r] uppercaseString];
}

+ (UIImage *)imageForUserID:(NSInteger)userID initial:(NSString *)initial diameter:(CGFloat)diameter {
    return [self imageForUserID:userID initial:initial diameter:diameter leftPadding:0 rightPadding:0];
}

+ (UIImage *)imageForUserID:(NSInteger)userID initial:(NSString *)initial diameter:(CGFloat)diameter
                leftPadding:(CGFloat)left rightPadding:(CGFloat)right {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
    NSString *key = [NSString stringWithFormat:@"%ld-%@-%.2f-%.2f-%.2f", (long)userID, initial, diameter, left, right];
    UIImage *image = [cache objectForKey:key];
    if (image) { return image; }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    CGSize size = CGSizeMake(left + diameter + right, diameter);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIColor *fill = [CFTheme avatarColorForUserID:userID];
    image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGRect circle = CGRectMake(left, 0, diameter, diameter);
        [fill setFill];
        [[UIBezierPath bezierPathWithOvalInRect:circle] fill];
        // Campfire draws the initial at about 0.45 of the avatar, bold.
        UIFont *font = [UIFont systemFontOfSize:diameter * 0.46 weight:UIFontWeightHeavy];
        NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.whiteColor};
        CGSize t = [initial sizeWithAttributes:attrs];
        CGPoint p = CGPointMake(CGRectGetMidX(circle) - t.width / 2, CGRectGetMidY(circle) - t.height / 2);
        [initial drawAtPoint:p withAttributes:attrs];
    }];
    [cache setObject:image forKey:key];
    return image;
}

@end
