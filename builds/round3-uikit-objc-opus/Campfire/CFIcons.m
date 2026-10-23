#import "CFIcons.h"

@implementation CFIcons

+ (UIImage *)render:(CGSize)size actions:(void (^)(CGContextRef ctx))actions {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *image = [r imageWithActions:^(UIGraphicsImageRendererContext *c) { actions(c.CGContext); }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

/// Bounds of the drawn (non-transparent) pixels of an image, in points.
static CGRect CFInkBounds(UIImage *image) {
    CGImageRef cg = image.CGImage;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    uint8_t *px = calloc(w * h, 1);
    CGContextRef ctx = CGBitmapContextCreate(px, w, h, 8, w, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    size_t minX = w, minY = h, maxX = 0, maxY = 0;
    for (size_t y = 0; y < h; y++) {
        for (size_t x = 0; x < w; x++) {
            if (px[y * w + x] > 24) {
                if (x < minX) { minX = x; }
                if (x > maxX) { maxX = x; }
                if (y < minY) { minY = y; }
                if (y > maxY) { maxY = y; }
            }
        }
    }
    CGContextRelease(ctx);
    free(px);
    if (maxX < minX) { return CGRectMake(0, 0, image.size.width, image.size.height); }
    CGFloat s = image.scale;
    // Bitmap rows run top-down in memory for this context.
    return CGRectMake(minX / s, minY / s, (maxX - minX + 1) / s, (maxY - minY + 1) / s);
}

+ (UIImage *)symbol:(NSString *)name size:(CGSize)size weight:(UIImageSymbolWeight)weight {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size.height * 2 weight:weight];
    UIImage *symbol = [[UIImage systemImageNamed:name withConfiguration:config] imageWithTintColor:UIColor.blackColor
                                                                                    renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!symbol) { return [self render:size actions:^(CGContextRef ctx) {}]; }
    // Rasterise once, then fit the inked glyph (not the padded symbol box) into the target size.
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat preferredFormat];
    f.opaque = NO;
    UIImage *raster = [[[UIGraphicsImageRenderer alloc] initWithSize:symbol.size format:f] imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [symbol drawAtPoint:CGPointZero];
    }];
    CGRect ink = CFInkBounds(raster);
    return [self render:size actions:^(CGContextRef ctx) {
        CGFloat k = MIN(size.width / ink.size.width, size.height / ink.size.height);
        CGFloat ox = (size.width - ink.size.width * k) / 2 - ink.origin.x * k;
        CGFloat oy = (size.height - ink.size.height * k) / 2 - ink.origin.y * k;
        [raster drawInRect:CGRectMake(ox, oy, raster.size.width * k, raster.size.height * k)];
    }];
}

+ (UIImage *)fileIcon {
    static UIImage *i; static dispatch_once_t once;
    dispatch_once(&once, ^{
        i = [self render:CGSizeMake(18.7, 22) actions:^(CGContextRef ctx) {
            UIBezierPath *doc = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.3, 0, 18.1, 22) cornerRadius:2.6];
            [UIColor.blackColor setFill];
            [doc fill];
            CGContextSetBlendMode(ctx, kCGBlendModeClear);
            CGFloat widths[] = {10.5, 10.5, 6.5};
            for (int k = 0; k < 3; k++) {
                [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(4.2, 9.3 + k * 3.6, widths[k], 2.1) cornerRadius:1.05] fill];
            }
        }];
    });
    return i;
}

+ (UIImage *)downloadIcon {
    static UIImage *i; static dispatch_once_t once;
    dispatch_once(&once, ^{
        i = [self render:CGSizeMake(16, 16.7) actions:^(CGContextRef ctx) {
            [UIColor.blackColor setStroke];
            UIBezierPath *p = [UIBezierPath bezierPath];
            p.lineWidth = 2.2;
            p.lineCapStyle = kCGLineCapRound;
            p.lineJoinStyle = kCGLineJoinRound;
            [p moveToPoint:CGPointMake(8, 1.2)]; [p addLineToPoint:CGPointMake(8, 10.6)];
            [p moveToPoint:CGPointMake(3.9, 6.8)]; [p addLineToPoint:CGPointMake(8, 10.9)]; [p addLineToPoint:CGPointMake(12.1, 6.8)];
            [p moveToPoint:CGPointMake(1.2, 11.6)]; [p addLineToPoint:CGPointMake(1.2, 15.5)];
            [p addLineToPoint:CGPointMake(14.8, 15.5)]; [p addLineToPoint:CGPointMake(14.8, 11.6)];
            [p stroke];
        }];
    });
    return i;
}

+ (UIImage *)shareIcon {
    static UIImage *i; static dispatch_once_t once;
    dispatch_once(&once, ^{
        i = [self render:CGSizeMake(11.3, 16.7) actions:^(CGContextRef ctx) {
            [UIColor.blackColor setStroke];
            UIBezierPath *p = [UIBezierPath bezierPath];
            p.lineWidth = 1.7;
            p.lineCapStyle = kCGLineCapRound;
            p.lineJoinStyle = kCGLineJoinRound;
            [p moveToPoint:CGPointMake(5.65, 1.0)]; [p addLineToPoint:CGPointMake(5.65, 10.2)];
            [p moveToPoint:CGPointMake(2.6, 4.0)]; [p addLineToPoint:CGPointMake(5.65, 1.0)]; [p addLineToPoint:CGPointMake(8.7, 4.0)];
            [p moveToPoint:CGPointMake(3.4, 6.3)]; [p addLineToPoint:CGPointMake(0.9, 6.3)];
            [p addLineToPoint:CGPointMake(0.9, 15.8)]; [p addLineToPoint:CGPointMake(10.4, 15.8)];
            [p addLineToPoint:CGPointMake(10.4, 6.3)]; [p addLineToPoint:CGPointMake(7.9, 6.3)];
            [p stroke];
        }];
    });
    return i;
}

+ (UIImage *)addBoostIcon {
    static UIImage *i; static dispatch_once_t once;
    dispatch_once(&once, ^{
        i = [self render:CGSizeMake(20, 20) actions:^(CGContextRef ctx) {
            [UIColor.blackColor setStroke];
            [UIColor.blackColor setFill];
            UIBezierPath *face = [UIBezierPath bezierPathWithArcCenter:CGPointMake(9, 9) radius:7.6 startAngle:M_PI * 0.42 endAngle:M_PI * 0.08 clockwise:YES];
            face.lineWidth = 1.7;
            face.lineCapStyle = kCGLineCapRound;
            [face stroke];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(5.6, 5.6, 2.2, 2.6)] fill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.2, 5.6, 2.2, 2.6)] fill];
            UIBezierPath *smile = [UIBezierPath bezierPathWithArcCenter:CGPointMake(9, 9.6) radius:3.6 startAngle:M_PI * 0.15 endAngle:M_PI * 0.85 clockwise:YES];
            smile.lineWidth = 1.6;
            smile.lineCapStyle = kCGLineCapRound;
            [smile stroke];
            UIBezierPath *plus = [UIBezierPath bezierPath];
            plus.lineWidth = 1.9;
            plus.lineCapStyle = kCGLineCapRound;
            [plus moveToPoint:CGPointMake(15.6, 12.4)]; [plus addLineToPoint:CGPointMake(15.6, 19)];
            [plus moveToPoint:CGPointMake(12.3, 15.7)]; [plus addLineToPoint:CGPointMake(18.9, 15.7)];
            [plus stroke];
        }];
    });
    return i;
}

+ (UIImage *)campfireLogo {
    static UIImage *i; static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGSize size = CGSizeMake(69, 69);
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
        i = [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
            CGContextRef ctx = c.CGContext;
            UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 69, 69) cornerRadius:12];
            [box addClip];
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            NSArray *colors = @[(id)[UIColor colorWithRed:0.50 green:0.11 blue:0.53 alpha:1].CGColor,
                                (id)[UIColor colorWithRed:0.24 green:0.05 blue:0.27 alpha:1].CGColor];
            CGGradientRef g = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
            CGContextDrawLinearGradient(ctx, g, CGPointMake(10, 0), CGPointMake(55, 69),
                                        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
            CGGradientRelease(g);
            // Flame: a zigzag scribble inside a circle, magenta at the top through orange to a white-blue core.
            CGPoint center = CGPointMake(35, 35);
            CGFloat r = 19.5, step = 4.3;
            CGPoint d = CGPointMake(0.45, 0.89), n = CGPointMake(0.89, -0.45);
            UIBezierPath *zig = [UIBezierPath bezierPath];
            BOOL down = YES;
            for (int k = -4; k <= 4; k++) {
                CGFloat off = k * step;
                CGFloat half = sqrt(MAX(r * r - off * off, 4)) * (k % 2 ? 0.92 : 1.0);
                CGPoint mid = CGPointMake(center.x + n.x * off, center.y + n.y * off);
                CGPoint a = CGPointMake(mid.x - d.x * half, mid.y - d.y * half);
                CGPoint b = CGPointMake(mid.x + d.x * half, mid.y + d.y * half);
                CGPoint from = down ? a : b, to = down ? b : a;
                if (k == -4) { [zig moveToPoint:from]; } else { [zig addLineToPoint:from]; }
                [zig addLineToPoint:to];
                down = !down;
            }
            CGContextSaveGState(ctx);
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.5), 3, [UIColor colorWithWhite:0 alpha:0.45].CGColor);
            CGContextAddPath(ctx, zig.CGPath);
            CGContextSetLineWidth(ctx, 2.7);
            CGContextSetLineCap(ctx, kCGLineCapRound);
            CGContextSetLineJoin(ctx, kCGLineJoinRound);
            CGContextReplacePathWithStrokedPath(ctx);
            CGContextClip(ctx);
            NSArray *flame = @[(id)[UIColor colorWithRed:0.93 green:0.10 blue:0.55 alpha:1].CGColor,
                               (id)[UIColor colorWithRed:1.00 green:0.27 blue:0.33 alpha:1].CGColor,
                               (id)[UIColor colorWithRed:1.00 green:0.55 blue:0.18 alpha:1].CGColor,
                               (id)[UIColor colorWithRed:1.00 green:0.78 blue:0.22 alpha:1].CGColor];
            CGGradientRef fg = CGGradientCreateWithColors(space, (__bridge CFArrayRef)flame, NULL);
            CGContextDrawLinearGradient(ctx, fg, CGPointMake(22, 14), CGPointMake(46, 58), 0);
            CGGradientRelease(fg);
            NSArray *core = @[(id)[UIColor colorWithRed:0.95 green:0.97 blue:1.0 alpha:1].CGColor,
                              (id)[UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:0.9].CGColor,
                              (id)[UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:0].CGColor];
            CGFloat locs[] = {0, 0.45, 1};
            CGGradientRef cg = CGGradientCreateWithColors(space, (__bridge CFArrayRef)core, locs);
            CGContextDrawRadialGradient(ctx, cg, CGPointMake(40, 43), 0, CGPointMake(40, 43), 11, 0);
            CGGradientRelease(cg);
            CGContextRestoreGState(ctx);
            CGColorSpaceRelease(space);
        }];
    });
    return i;
}

@end
