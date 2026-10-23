#import "CFChrome.h"
#import "CFIcons.h"
#import "CFRowLayout.h"

#pragma mark - Circle button

@implementation CFCircleButton

- (instancetype)initWithImage:(UIImage *)image diameter:(CGFloat)diameter {
    if ((self = [super initWithFrame:CGRectMake(0, 0, diameter, diameter)])) {
        self.backgroundColor = CFTheme.pillBackground;
        self.layer.cornerRadius = diameter / 2;
        self.layer.borderWidth = 1;
        self.tintColor = CFTheme.text;
        [self setImage:image forState:UIControlStateNormal];
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateBorder)];
        [self updateBorder];
    }
    return self;
}

- (void)updateBorder {
    self.layer.borderColor = [CFTheme.borderDarker resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

@end

#pragma mark - Welcome card

static const CGFloat kLogoTop = 85;
static const CGFloat kCardTop = 109;
static const CGFloat kCardInsetX = 14;
static const CGFloat kTitleTop = 75.7;
static const CGFloat kTextInsetX = 30;
static const CGFloat kLinkGap = 17.1;
static const CGFloat kLinkHeight = 40;
static const CGFloat kButtonsGap = 16;
static const CGFloat kButtonSize = 42;
static const CGFloat kCardBottomPad = 11;
static const CGFloat kAfterCard = 1.72;

static NSString *const kWelcomeTitle = @"Welcome to Campfire";
static NSString *const kWelcomeBody = @"To invite people to chat, share the join link below.";
static NSString *const kJoinURL = @"http://127.0.0.1:3055/join/GwHG-HbZN";

@implementation CFWelcomeCell {
    UIImageView *_logo;
    UIView *_card;
    CFCircleButton *_globe;
    UILabel *_text;
    UIView *_link;
    UIImageView *_linkIcon;
    UILabel *_linkLabel;
    NSArray<CFCircleButton *> *_buttons;
    CFMetrics *_metrics;
}

+ (NSAttributedString *)textWithMetrics:(CFMetrics *)m {
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] init];
    NSMutableDictionary *title = [[CFText attributesWithFont:m.titleFont color:CFTheme.text lineHeight:m.bodyLineHeight] mutableCopy];
    NSMutableDictionary *body = [[CFText attributesWithFont:m.bodyFont color:CFTheme.text lineHeight:m.bodyLineHeight] mutableCopy];
    for (NSMutableDictionary *d in @[title, body]) {
        NSMutableParagraphStyle *p = [d[NSParagraphStyleAttributeName] mutableCopy];
        p.alignment = NSTextAlignmentCenter;
        d[NSParagraphStyleAttributeName] = p;
    }
    [s appendAttributedString:[[NSAttributedString alloc] initWithString:[kWelcomeTitle stringByAppendingString:@"\n"] attributes:title]];
    [s appendAttributedString:[[NSAttributedString alloc] initWithString:kWelcomeBody attributes:body]];
    return s;
}

+ (CGFloat)textHeightForWidth:(CGFloat)width metrics:(CFMetrics *)m {
    CGFloat textW = width - 2 * kCardInsetX - 2 * kTextInsetX;
    return [CFText sizeOfAttributedString:[self textWithMetrics:m] width:textW].height;
}

+ (CGFloat)heightForWidth:(CGFloat)width metrics:(CFMetrics *)m {
    CGFloat textH = [self textHeightForWidth:width metrics:m];
    CGFloat linkH = MAX(kLinkHeight, m.bodyLineHeight + 17.6);
    return kCardTop + kTitleTop + textH + kLinkGap + linkH + kButtonsGap + kButtonSize + kCardBottomPad + kAfterCard;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _card = [[UIView alloc] init];
        _card.backgroundColor = CFTheme.bubble;
        _card.layer.cornerRadius = 10.56;
        [self addSubview:_card];

        _logo = [[UIImageView alloc] initWithImage:[CFIcons campfireLogo]];
        [self addSubview:_logo];

        _globe = [[CFCircleButton alloc] initWithImage:[self emojiImage:@"🌎" size:17] diameter:42];
        [_card addSubview:_globe];

        _text = [[UILabel alloc] init];
        _text.numberOfLines = 0;
        [_card addSubview:_text];

        _link = [[UIView alloc] init];
        _link.backgroundColor = CFTheme.pillBackground;
        _link.layer.cornerRadius = 8;
        _link.layer.borderWidth = 1;
        [_card addSubview:_link];
        _linkIcon = [[UIImageView alloc] initWithImage:[CFIcons symbol:@"person.fill.badge.plus" size:CGSizeMake(16, 20) weight:UIImageSymbolWeightRegular]];
        _linkIcon.tintColor = CFTheme.text;
        [_link addSubview:_linkIcon];
        _linkLabel = [[UILabel alloc] init];
        _linkLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_link addSubview:_linkLabel];

        NSArray *icons = @[[CFIcons symbol:@"qrcode.viewfinder" size:CGSizeMake(19.3, 20) weight:UIImageSymbolWeightMedium],
                           [CFIcons symbol:@"doc.on.clipboard" size:CGSizeMake(19.7, 20) weight:UIImageSymbolWeightMedium],
                           [CFIcons symbol:@"square.and.arrow.up" size:CGSizeMake(13.3, 20) weight:UIImageSymbolWeightMedium]];
        NSArray *labels = @[@"Show QR code", @"Copy join link", @"Share join link"];
        NSMutableArray *buttons = [NSMutableArray array];
        for (NSUInteger i = 0; i < icons.count; i++) {
            CFCircleButton *b = [[CFCircleButton alloc] initWithImage:icons[i] diameter:kButtonSize];
            b.accessibilityLabel = labels[i];
            [_card addSubview:b];
            [buttons addObject:b];
        }
        _buttons = buttons;
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateBorder)];
        [self updateBorder];
    }
    return self;
}

- (UIImage *)emojiImage:(NSString *)emoji size:(CGFloat)size {
    UIFont *font = [UIFont systemFontOfSize:size * 0.86];
    NSDictionary *attrs = @{NSFontAttributeName: font};
    CGSize s = [emoji sizeWithAttributes:attrs];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    UIImage *image = [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [emoji drawAtPoint:CGPointMake((size - s.width) / 2, (size - s.height) / 2) withAttributes:attrs];
    }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)updateBorder {
    _link.layer.borderColor = [CFTheme.borderDarker resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

- (CFMetrics *)metrics { return _metrics; }

- (void)configureWithMetrics:(CFMetrics *)metrics {
    _metrics = metrics;
    _text.attributedText = [CFWelcomeCell textWithMetrics:metrics];
    _linkLabel.attributedText = [[NSAttributedString alloc] initWithString:kJoinURL attributes:@{
        NSFontAttributeName: metrics.bodyFont, NSForegroundColorAttributeName: CFTheme.text}];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CFMetrics *m = _metrics ?: [CFMetrics metricsForTraitCollection:self.traitCollection];
    CGFloat W = self.bounds.size.width;
    CGFloat cardW = W - 2 * kCardInsetX;
    _logo.frame = CGRectMake(round((W - 69) / 2 * 3) / 3, kLogoTop, 69, 69);
    _globe.frame = CGRectMake(16, 16, 42, 42);
    CGFloat textH = [CFWelcomeCell textHeightForWidth:W metrics:m];
    _text.frame = CGRectMake(kTextInsetX, kTitleTop, cardW - 2 * kTextInsetX, textH);
    CGFloat linkH = MAX(kLinkHeight, m.bodyLineHeight + 17.6);
    CGFloat y = kTitleTop + textH + kLinkGap;
    _link.frame = CGRectMake(15, y, cardW - 30, linkH);
    _linkIcon.frame = CGRectMake(15, (linkH - 20) / 2, 16, 20);
    _linkLabel.frame = CGRectMake(43, 0, cardW - 30 - 43 - 8, linkH);
    y += linkH + kButtonsGap;
    CGFloat centerX = cardW / 2 - 5;
    for (NSUInteger i = 0; i < _buttons.count; i++) {
        CGFloat cx = centerX + ((CGFloat)i - 1) * 52.5;
        _buttons[i].frame = CGRectMake(cx - kButtonSize / 2, y, kButtonSize, kButtonSize);
    }
    y += kButtonSize + kCardBottomPad;
    _card.frame = CGRectMake(kCardInsetX, kCardTop, cardW, y);
}

@end

#pragma mark - Header

@implementation CFHeaderView {
    UIView *_room;
    UILabel *_roomLabel;
    CFCircleButton *_more;
    CFCircleButton *_bell;
    UIView *_bellRing;
    CFCircleButton *_menu;
}

+ (CGFloat)height { return 58; }

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _room = [[UIView alloc] init];
        _room.backgroundColor = CFTheme.text;
        _room.layer.cornerRadius = 8;
        _room.isAccessibilityElement = YES;
        _room.accessibilityLabel = @"General";
        _room.accessibilityTraits = UIAccessibilityTraitHeader;
        [self addSubview:_room];
        _roomLabel = [[UILabel alloc] init];
        _roomLabel.text = @"General";
        _roomLabel.font = [UIFont systemFontOfSize:17.6 weight:UIFontWeightBold];
        _roomLabel.textColor = CFTheme.background;
        _roomLabel.textAlignment = NSTextAlignmentCenter;
        [_room addSubview:_roomLabel];

        _more = [[CFCircleButton alloc] initWithImage:[CFIcons symbol:@"ellipsis" size:CGSizeMake(20.3, 20.3) weight:UIImageSymbolWeightBlack] diameter:42];
        _more.accessibilityLabel = @"Room settings";
        _bellRing = [[UIView alloc] init];
        _bellRing.layer.borderWidth = 3;
        _bellRing.layer.borderColor = [CFTheme colorWithHex:0xFF6A0D].CGColor;
        _bell = [[CFCircleButton alloc] initWithImage:[self bellImage] diameter:42];
        _bell.accessibilityLabel = @"Notifications";
        _menu = [[CFCircleButton alloc] initWithImage:[self menuImage] diameter:42];
        _menu.accessibilityLabel = @"Menu";
        for (UIView *v in @[_more, _bellRing, _bell, _menu]) { [self addSubview:v]; }
    }
    return self;
}

- (UIImage *)menuImage {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(19.7, 16)];
    UIImage *image = [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [UIColor.blackColor setFill];
        for (int i = 0; i < 3; i++) {
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, i * 6.5, 19.7, 3) cornerRadius:1.5] fill];
        }
    }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)bellImage {
    UIImage *bell = [CFIcons symbol:@"bell.fill" size:CGSizeMake(19, 19) weight:UIImageSymbolWeightRegular];
    UIImage *warn = [CFIcons symbol:@"exclamationmark.triangle.fill" size:CGSizeMake(13, 12) weight:UIImageSymbolWeightBold];
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat preferredFormat];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(22, 22) format:f];
    UIImage *image = [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [bell drawInRect:CGRectMake(0, 0, 19, 19)];
        CGContextSetBlendMode(c.CGContext, kCGBlendModeClear);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.5, 8.5, 14, 14) cornerRadius:3] fill];
        CGContextSetBlendMode(c.CGContext, kCGBlendModeNormal);
        [warn drawInRect:CGRectMake(9, 10, 13, 12)];
    }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width;
    _room.frame = CGRectMake(10, 8, 97, 42);
    _roomLabel.frame = _room.bounds;
    _more.frame = CGRectMake(113, 8, 42, 42);
    _bell.frame = CGRectMake(160, 8, 42, 42);
    _bellRing.frame = CGRectInset(_bell.frame, -3, -3);
    _bellRing.layer.cornerRadius = _bellRing.frame.size.width / 2;
    _menu.frame = CGRectMake(W - 53, 8, 42, 42);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit; // the empty header area lets touches reach the room behind
}

@end

#pragma mark - Composer

@implementation CFComposerView {
    CFCircleButton *_search;
    UIView *_field;
    UIImageView *_bubbleIcon;
    UIButton *_attach;
    UIButton *_send;
}

+ (CGFloat)height { return 42; }

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _search = [[CFCircleButton alloc] initWithImage:[CFIcons symbol:@"magnifyingglass" size:CGSizeMake(20.3, 20) weight:UIImageSymbolWeightBold] diameter:42];
        _search.accessibilityLabel = @"Search";
        _field = [[UIView alloc] init];
        _field.backgroundColor = CFTheme.pillBackground;
        _field.layer.borderWidth = 1;
        _field.isAccessibilityElement = YES;
        _field.accessibilityLabel = @"Message";
        _field.accessibilityTraits = UIAccessibilityTraitSearchField;
        _bubbleIcon = [[UIImageView alloc] initWithImage:[CFIcons symbol:@"message" size:CGSizeMake(22, 20.7) weight:UIImageSymbolWeightMedium]];
        _bubbleIcon.tintColor = CFTheme.text;
        _attach = [UIButton buttonWithType:UIButtonTypeCustom];
        [_attach setImage:[CFIcons symbol:@"paperclip" size:CGSizeMake(20, 18) weight:UIImageSymbolWeightMedium] forState:UIControlStateNormal];
        _attach.tintColor = CFTheme.text;
        _attach.accessibilityLabel = @"Attach";
        _send = [UIButton buttonWithType:UIButtonTypeCustom];
        _send.backgroundColor = CFTheme.text;
        _send.layer.cornerRadius = 17;
        _send.tintColor = CFTheme.background;
        [_send setImage:[CFIcons symbol:@"arrow.up" size:CGSizeMake(16, 17) weight:UIImageSymbolWeightBlack] forState:UIControlStateNormal];
        _send.accessibilityLabel = @"Send";
        [self addSubview:_search];
        [self addSubview:_field];
        [_field addSubview:_bubbleIcon];
        [_field addSubview:_attach];
        [_field addSubview:_send];
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateBorder)];
        [self updateBorder];
    }
    return self;
}

- (void)updateBorder {
    _field.layer.borderColor = [CFTheme.borderDarker resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width;
    _search.frame = CGRectMake(14, 0, 42, 42);
    _field.frame = CGRectMake(66, 0, W - 66 - 14, 42);
    _field.layer.cornerRadius = 21;
    CGFloat fw = _field.bounds.size.width;
    _bubbleIcon.frame = CGRectMake(14, 10.65, 22, 20.7);
    _send.frame = CGRectMake(fw - 39, 4, 34, 34);
    _attach.frame = CGRectMake(fw - 76 - 10, 1, 40, 40);
}

@end
