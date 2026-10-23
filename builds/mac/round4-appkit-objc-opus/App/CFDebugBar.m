#import "CFDebugBar.h"

@implementation CFDebugBar {
    NSArray<NSView *> *_items;   // buttons, then the stream-done label
}

static NSTextField *Label(NSString *text) {
    NSTextField *l = [NSTextField labelWithString:text];
    l.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    l.lineBreakMode = NSLineBreakByClipping;
    return l;
}

- (instancetype)initWithTarget:(id)target {
    if ((self = [super initWithFrame:NSZeroRect])) {
        NSArray *specs = @[@[@"Reset", @"debugReset:"], @[@"Jump to 2500", @"debugJump:"], @[@"Load older", @"debugLoadOlder:"],
                           @[@"Start stream", @"debugStartStream:"], @[@"Text size +", @"debugTextSize:"],
                           @[@"Boost burst", @"debugBoostBurst:"]];
        NSMutableArray *items = [NSMutableArray array];
        for (NSArray *spec in specs) {
            NSButton *b = [NSButton buttonWithTitle:spec[0] target:target action:NSSelectorFromString(spec[1])];
            b.controlSize = NSControlSizeSmall;
            b.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
            b.bezelStyle = NSBezelStylePush;
            [b sizeToFit];
            [self addSubview:b];
            [items addObject:b];
        }
        _streamDoneLabel = Label(@"Stream done");
        _streamDoneLabel.hidden = YES;
        [self addSubview:_streamDoneLabel];
        [items addObject:_streamDoneLabel];
        _items = items;

        _stateLabel = [NSTextField wrappingLabelWithString:@"first 0 last 0 loaded 0 pinned yes top 0 y 0.0 ms 0"];
        _stateLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
        _stateLabel.selectable = NO;
        [self addSubview:_stateLabel];
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    [NSColor.windowBackgroundColor setFill];
    NSRectFill(self.bounds);
    [NSColor.separatorColor setFill];
    NSRectFill(NSMakeRect(0, NSMaxY(self.bounds) - 1, self.bounds.size.width, 1));
}

// Lays the items out left to right, wrapping; the state label gets its own line. Returns the height used.
- (CGFloat)flowForWidth:(CGFloat)width apply:(BOOL)apply {
    CGFloat pad = 4, gap = 2, x = pad, y = 3, lineH = 0;
    for (NSView *v in _items) {
        NSSize s = v.fittingSize;
        if ([v isKindOfClass:NSButton.class]) s = ((NSButton *)v).frame.size;
        if (x > pad && x + s.width > width - pad) {
            x = pad;
            y += lineH + 1;
            lineH = 0;
        }
        if (apply) v.frame = NSMakeRect(x, y, s.width, s.height);
        x += s.width + gap;
        lineH = MAX(lineH, s.height);
    }
    y += lineH + 1;
    CGFloat lw = width - 2 * pad - 2;
    // Room for two lines, so the full state always shows even on the narrowest window.
    NSSize ls = [_stateLabel.cell cellSizeForBounds:NSMakeRect(0, 0, lw, 1000)];
    ls.height = MAX(ls.height, 2 * ceil(_stateLabel.font.boundingRectForFont.size.height * 0.85));
    if (apply) _stateLabel.frame = NSMakeRect(pad + 2, y, lw, ls.height);
    y += ls.height + 4;
    return ceil(y);
}

- (CGFloat)heightForWidth:(CGFloat)width {
    return [self flowForWidth:width apply:NO];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [self flowForWidth:self.bounds.size.width apply:YES];
}

@end
