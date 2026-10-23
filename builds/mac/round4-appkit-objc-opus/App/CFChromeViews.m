#import "CFChromeViews.h"
#import "CFTheme.h"
#import "CFRowLayout.h"

const CGFloat CFWelcomeHeight = 401.88;

static void StrokeCircle(NSRect r, NSColor *fill, NSColor *stroke) {
    NSBezierPath *p = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, 0.5, 0.5)];
    [fill setFill];
    [p fill];
    p.lineWidth = 1;
    [stroke setStroke];
    [p stroke];
}

static void DrawCentered(NSString *s, NSDictionary *attrs, CGFloat centerX, CGFloat capTop) {
    NSFont *f = attrs[NSFontAttributeName];
    NSSize size = [s sizeWithAttributes:attrs];
    // drawAtPoint puts the line's top at y; the cap top sits (ascender - capHeight) below it.
    CGFloat y = capTop - (f.ascender - f.capHeight) + 1.33;   // + measured offset of AppKit string drawing
    [s drawAtPoint:NSMakePoint(round((centerX - size.width / 2) * 3) / 3, y) withAttributes:attrs];
}

#pragma mark - Header

@implementation CFHeaderView

- (BOOL)isFlipped { return YES; }

- (NSView *)hitTest:(NSPoint)point {
    // Only the drawn buttons take clicks; the fade lets clicks through to the room.
    NSPoint p = [self convertPoint:point fromView:self.superview];
    if (!NSPointInRect(p, self.bounds)) return nil;
    for (NSValue *v in [self buttonRects]) if (NSPointInRect(p, v.rectValue)) return self;
    return nil;
}

- (NSArray<NSValue *> *)buttonRects {
    CGFloat W = self.bounds.size.width;
    return @[[NSValue valueWithRect:NSMakeRect(10, 8, 97, 42)], [NSValue valueWithRect:NSMakeRect(113, 8, 42, 42)],
             [NSValue valueWithRect:NSMakeRect(157, 5, 48, 48)], [NSValue valueWithRect:NSMakeRect(W - 53, 8, 42, 42)]];
}

- (void)mouseDown:(NSEvent *)event {
    // Header buttons are drawn but do nothing.
}

- (void)scrollWheel:(NSEvent *)event {
    if (self.scrollView) [self.scrollView scrollWheel:event]; else [super scrollWheel:event];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect b = self.bounds;
    CGFloat W = b.size.width;
    NSColor *bg = CFTheme.background;
    NSColor *solid = [NSColor colorWithCGColor:bg.CGColor];
    NSGradient *g = [[NSGradient alloc] initWithColorsAndLocations:solid, 0.0, solid, 0.2,
                     [solid colorWithAlphaComponent:0], 1.0, nil];
    [g drawInRect:b angle:90];   // flipped view: 90 degrees runs top to bottom

    // "General" room pill.
    NSRect pill = NSMakeRect(10, 8, 97, 42);
    [CFTheme.text setFill];
    [[NSBezierPath bezierPathWithRoundedRect:pill xRadius:10.56 yRadius:10.56] fill];
    NSDictionary *pillAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:16 weight:NSFontWeightBold],
                                NSForegroundColorAttributeName: bg};
    DrawCentered(@"General", pillAttrs, NSMidX(pill), 22.67);

    // Room options (ellipsis).
    NSRect more = NSMakeRect(113, 8, 42, 42);
    StrokeCircle(more, bg, CFTheme.borderDarker);
    [CFTheme.text setFill];
    for (int i = 0; i < 3; i++) {
        CGFloat cx = 126.17 + i * 7.33;
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - 2.5, 29 - 2.5, 5, 5)] fill];
    }

    // Notifications (bell with a warning), circled in orange.
    NSRect bell = NSMakeRect(160, 8, 42, 42);
    NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(bell, -1.5, -1.5)];
    ring.lineWidth = 3;
    [CFTheme.orange setStroke];
    [ring stroke];
    StrokeCircle(bell, bg, CFTheme.borderDarker);
    CFDrawSymbol(@"bell.fill", NSOffsetRect(bell, -1, -1), 17, NSFontWeightBold, CFTheme.text);
    NSRect warn = NSMakeRect(NSMidX(bell) + 0.5, NSMidY(bell) + 0.5, 11, 10);
    [bg setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(warn, -2, -2)] fill];
    CFDrawSymbol(@"exclamationmark.triangle.fill", warn, 10, NSFontWeightBold, CFTheme.text);

    // Menu (hamburger).
    NSRect menu = NSMakeRect(W - 53, 8, 42, 42);
    StrokeCircle(menu, bg, CFTheme.borderDarker);
    [CFTheme.text setFill];
    for (int i = 0; i < 3; i++) {
        NSRect bar = NSMakeRect(NSMinX(menu) + 11.5, 21.33 + i * 6.67, 19, 2);
        [[NSBezierPath bezierPathWithRoundedRect:bar xRadius:1 yRadius:1] fill];
    }
}

@end

#pragma mark - Composer

@implementation CFComposerView

- (BOOL)isFlipped { return YES; }

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    CGFloat W = self.bounds.size.width;
    [CFTheme.background setFill];
    NSRectFill(self.bounds);

    NSRect search = NSMakeRect(14, 24, 42, 42);
    StrokeCircle(search, CFTheme.background, CFTheme.borderDarker);
    CFDrawSymbol(@"magnifyingglass", search, 19, NSFontWeightBold, CFTheme.text);

    NSRect field = NSMakeRect(66, 24, W - 66 - 14, 42);
    NSBezierPath *fp = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(field, 0.5, 0.5) xRadius:20.5 yRadius:20.5];
    [CFTheme.background setFill];
    [fp fill];
    fp.lineWidth = 1;
    [CFTheme.borderDarker setStroke];
    [fp stroke];
    CFDrawSymbol(@"bubble.left", NSMakeRect(91 - 12, 45 - 12, 24, 24), 19, NSFontWeightMedium, CFTheme.text);
    CFDrawSymbol(@"paperclip", NSMakeRect(W - 79 - 12, 45 - 12, 24, 24), 18, NSFontWeightMedium, CFTheme.text);

    NSRect send = NSMakeRect(W - 53, 28, 34, 34);
    [CFTheme.text setFill];
    [[NSBezierPath bezierPathWithOvalInRect:send] fill];
    CFDrawSymbol(@"arrow.up", send, 17, NSFontWeightBold, CFTheme.background);
}

@end

#pragma mark - Welcome card

@implementation CFWelcomeView

- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

- (void)drawLogoInRect:(NSRect)r {
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:r xRadius:15 yRadius:15];
    NSGradient *bg = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.47 green:0.10 blue:0.49 alpha:1]
                                                   endingColor:[NSColor colorWithSRGBRed:0.24 green:0.04 blue:0.26 alpha:1]];
    [bg drawInBezierPath:clip angle:-60];
    [NSGraphicsContext saveGraphicsState];
    [clip addClip];
    NSArray *colors = @[[NSColor colorWithSRGBRed:0.93 green:0.15 blue:0.45 alpha:1], [NSColor colorWithSRGBRed:0.98 green:0.35 blue:0.25 alpha:1],
                        [NSColor colorWithSRGBRed:1.0 green:0.62 blue:0.18 alpha:1], [NSColor colorWithSRGBRed:0.98 green:0.85 blue:0.55 alpha:1],
                        [NSColor colorWithSRGBRed:0.55 green:0.75 blue:0.98 alpha:1]];
    NSAffineTransform *t = [NSAffineTransform transform];
    [t translateXBy:NSMidX(r) yBy:NSMidY(r)];
    [t rotateByDegrees:-50];
    [t concat];
    for (NSInteger i = 0; i < 9; i++) {
        NSBezierPath *line = [NSBezierPath bezierPath];
        CGFloat x = -16 + i * 4.0;
        CGFloat len = 30 - fabs((CGFloat)i - 4) * 4.5;
        [line moveToPoint:NSMakePoint(x, -len / 2)];
        [line lineToPoint:NSMakePoint(x, len / 2)];
        line.lineWidth = 2.2;
        line.lineCapStyle = NSLineCapStyleRound;
        [(NSColor *)colors[(NSUInteger)(i * colors.count / 9)] setStroke];
        [line stroke];
    }
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGFloat W = self.bounds.size.width;
    CGFloat cx = W / 2;
    // Card (y values are the screenshot's minus the 57.6 pt header).
    NSRect card = NSMakeRect(14, 109.4, W - 28, 269);
    [CFTheme.bubble setFill];
    [[NSBezierPath bezierPathWithRoundedRect:card xRadius:11 yRadius:11] fill];

    [self drawLogoInRect:NSMakeRect(round((cx - 34.5) * 3) / 3, 85.4, 69, 69)];

    NSRect globe = NSMakeRect(30, 125.4, 42, 42);
    StrokeCircle(globe, CFTheme.background, CFTheme.borderDarker);
    NSDictionary *emoji = @{NSFontAttributeName: [NSFont systemFontOfSize:17]};
    NSSize es = [@"🌍" sizeWithAttributes:emoji];
    [@"🌍" drawAtPoint:NSMakePoint(NSMidX(globe) - es.width / 2, NSMidY(globe) - es.height / 2) withAttributes:emoji];

    NSDictionary *title = @{NSFontAttributeName: [NSFont systemFontOfSize:16 weight:NSFontWeightBold],
                            NSForegroundColorAttributeName: CFTheme.text};
    DrawCentered(@"Welcome to Campfire", title, cx, 190.73);
    NSDictionary *body = @{NSFontAttributeName: [NSFont systemFontOfSize:16], NSForegroundColorAttributeName: CFTheme.text};
    DrawCentered(@"To invite people to chat, share the join link", body, cx, 213.07);
    DrawCentered(@"below.", body, cx, 236.4);

    NSRect link = NSMakeRect(29, 269.4, W - 58, 39.6);
    NSBezierPath *lp = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(link, 0.5, 0.5) xRadius:8 yRadius:8];
    [CFTheme.background setFill];
    [lp fill];
    lp.lineWidth = 1;
    [CFTheme.borderDarker setStroke];
    [lp stroke];
    CFDrawSymbol(@"person.fill.badge.plus", NSMakeRect(40, NSMidY(link) - 11, 22, 22), 17, NSFontWeightRegular, CFTheme.text);
    NSFont *lf = [NSFont systemFontOfSize:16];
    [@"http://127.0.0.1:3055/join/GwHG-HbZN" drawAtPoint:NSMakePoint(71, 283.07 - (lf.ascender - lf.capHeight) + 1.33)
                                       withAttributes:@{NSFontAttributeName: lf, NSForegroundColorAttributeName: CFTheme.text}];

    NSArray *icons = @[@"qrcode", @"doc.on.clipboard", @"square.and.arrow.up"];
    CGFloat offsets[] = {-57.5, -5.1, 47.3};
    for (NSUInteger i = 0; i < 3; i++) {
        NSRect r = NSMakeRect(cx + offsets[i] - 21, 326, 42, 42);
        StrokeCircle(r, CFTheme.background, CFTheme.borderDarker);
        CFDrawSymbol(icons[i], r, 18, NSFontWeightMedium, CFTheme.text);
    }
}

@end

#pragma mark - Jump to bottom

@implementation CFJumpButton

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.bordered = NO;
        self.title = @"";
        self.buttonType = NSButtonTypeMomentaryChange;
        self.accessibilityLabel = @"Jump to bottom";
        self.toolTip = @"Jump to the newest message";
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    NSRect r = NSInsetRect(self.bounds, 1, 1);
    StrokeCircle(r, CFTheme.background, CFTheme.borderDarker);
    CFDrawSymbol(@"arrow.down", r, 17, NSFontWeightBold, CFTheme.text);
}

@end
