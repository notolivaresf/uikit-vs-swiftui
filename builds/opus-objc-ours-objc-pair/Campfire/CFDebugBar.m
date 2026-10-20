#import "CFDebugBar.h"

@implementation CFDebugBar {
    NSArray<UIButton *> *_buttons;
}

+ (BOOL)isWide:(CGFloat)width { return width >= 600; }
+ (CGFloat)heightForWidth:(CGFloat)width { return [self isWide:width] ? 64 : 96; }

- (UIButton *)makeButton:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    b.titleLabel.adjustsFontForContentSizeCategory = NO;
    b.backgroundColor = [UIColor tertiarySystemFillColor];
    b.layer.cornerRadius = 6;
    b.accessibilityIdentifier = title;
    b.accessibilityLabel = title;
    [self addSubview:b];
    return b;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.accessibilityIdentifier = @"debug.bar";
        self.maximumContentSizeCategory = UIContentSizeCategoryLarge;
        _resetButton = [self makeButton:@"Reset"];
        _jumpButton = [self makeButton:@"Jump to 2500"];
        _loadOlderButton = [self makeButton:@"Load older"];
        _streamButton = [self makeButton:@"Start stream"];
        _textSizeButton = [self makeButton:@"Text size +"];
        _boostBurstButton = [self makeButton:@"Boost burst"];
        _buttons = @[_resetButton, _jumpButton, _loadOlderButton, _streamButton, _textSizeButton, _boostBurstButton];

        _stateLabel = [[UILabel alloc] init];
        _stateLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        _stateLabel.adjustsFontSizeToFitWidth = YES;
        _stateLabel.minimumScaleFactor = 0.6;
        _stateLabel.accessibilityIdentifier = @"debug.state";
        [self addSubview:_stateLabel];

        _streamDoneLabel = [[UILabel alloc] init];
        _streamDoneLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _streamDoneLabel.text = @"Stream done";
        _streamDoneLabel.textAlignment = NSTextAlignmentRight;
        _streamDoneLabel.accessibilityIdentifier = @"debug.streamDone";
        _streamDoneLabel.hidden = YES;
        [self addSubview:_streamDoneLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat x0 = MAX(8, safe.left), W = self.bounds.size.width - x0 - MAX(8, safe.right);
    NSUInteger perRow = [CFDebugBar isWide:self.bounds.size.width] ? 6 : 3;
    CGFloat bw = (W - (perRow - 1) * 6) / perRow, bh = 28;
    for (NSUInteger i = 0; i < _buttons.count; i++) {
        NSUInteger row = i / perRow, col = i % perRow;
        _buttons[i].frame = CGRectMake(x0 + col * (bw + 6), 6 + row * (bh + 4), bw, bh);
    }
    CGFloat y = 6 + (_buttons.count / perRow) * (bh + 4);
    _streamDoneLabel.frame = CGRectMake(x0 + W - 80, y, 80, 22);
    _stateLabel.frame = CGRectMake(x0, y, W - 84, 22);
}

@end
