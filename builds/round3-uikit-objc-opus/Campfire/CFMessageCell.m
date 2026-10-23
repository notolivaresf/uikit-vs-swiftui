#import "CFMessageCell.h"
#import "CFAvatar.h"
#import "CFIcons.h"

#pragma mark - Boost pill

@interface CFBoostPillView : UIView
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *label;
@end

@implementation CFBoostPillView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = CFTheme.pillBackground;
        self.layer.borderWidth = 1;
        _avatar = [[UIImageView alloc] init];
        _label = [[UILabel alloc] init];
        [self addSubview:_avatar];
        [self addSubview:_label];
        self.isAccessibilityElement = YES;
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateBorder)];
        [self updateBorder];
    }
    return self;
}
- (void)updateBorder { self.layer.borderColor = [CFTheme.borderDark resolvedColorWithTraitCollection:self.traitCollection].CGColor; }
@end

#pragma mark - Text view

/// Copies the selected text as plain text; attachment characters (mention avatars) are not text.
@interface CFMessageTextView : UITextView
@end

@implementation CFMessageTextView
- (void)copy:(id)sender {
    NSRange r = self.selectedRange;
    if (r.length == 0 || NSMaxRange(r) > self.textStorage.length) { [super copy:sender]; return; }
    NSString *text = [[self.textStorage.string substringWithRange:r] stringByReplacingOccurrencesOfString:@"\uFFFC" withString:@""];
    UIPasteboard.generalPasteboard.string = text;
}
@end

#pragma mark - Body text

/// Draws a row's body from the TextKit 1 layout its CFRowLayout already made off the main thread, with the
/// same NSLayoutManager drawing a TextKit 1 UITextView does, so showing a row never lays text out again.
/// The cell puts a real, selectable UITextView in its place when a touch lands on it.
@interface CFBodyTextView : UIView
@property (nonatomic, strong, nullable) NSLayoutManager *layoutManager;
@end

@implementation CFBodyTextView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
        self.contentMode = UIViewContentModeRedraw;
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitStaticText;
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(setNeedsDisplay)];
    }
    return self;
}

- (void)setLayoutManager:(NSLayoutManager *)layoutManager {
    if (_layoutManager == layoutManager) { return; }
    _layoutManager = layoutManager;
    NSString *text = layoutManager.textStorage.string ?: @"";
    self.accessibilityLabel = [text stringByReplacingOccurrencesOfString:@"\uFFFC" withString:@""];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    NSLayoutManager *lm = _layoutManager;
    NSTextContainer *tc = lm.textContainers.firstObject;
    if (!tc) { return; }
    NSRange glyphs = [lm glyphRangeForTextContainer:tc];
    [lm drawBackgroundForGlyphRange:glyphs atPoint:CGPointZero];
    [lm drawGlyphsForGlyphRange:glyphs atPoint:CGPointZero];
}
@end

#pragma mark - Cell

@interface CFMessageCell () <UITextViewDelegate, UIContextMenuInteractionDelegate>
@end

@implementation CFMessageCell {
    UIView *_separatorLine;
    UIView *_separatorPill;
    UILabel *_separatorLabel;
    UIView *_bubble;
    UILabel *_header;
    UIView *_dots;
    CFBodyTextView *_body;
    UITextView *_selectableBody;   // made and filled when a touch lands on the body
    UIView *_codeBox;
    UITextView *_code;
    UIView *_image;
    UIImageView *_fileIcon;
    UILabel *_fileName;
    UIImageView *_fileDownload;
    UIImageView *_fileShare;
    NSMutableArray<CFBoostPillView *> *_pills;
    UIView *_addBoost;
    UIImageView *_addBoostIcon;
    UIView *_avatarRing;
    UIImageView *_avatar;
    CFRowLayout *_layout;
    NSInteger _itemID;
    NSUInteger _revision;
    CGFloat _scale;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        UIView *cv = self;
        // Only what every row shows is made here; separators, code, files, images and boosts are made the
        // first time a row needs them.
        _bubble = [[UIView alloc] init];
        _bubble.layer.cornerRadius = 10.56;
        _bubble.layer.cornerCurve = kCACornerCurveCircular;
        _bubble.clipsToBounds = YES;
        [_bubble addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];

        _header = [[UILabel alloc] init];
        _header.numberOfLines = 0;
        _dots = [[UIView alloc] init];
        for (int i = 0; i < 3; i++) {
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(i * 6.2, 0, 4.6, 4.6)];
            dot.backgroundColor = CFTheme.secondaryText;
            dot.layer.cornerRadius = 2.3;
            [_dots addSubview:dot];
        }
        _body = [[CFBodyTextView alloc] init];
        _pills = [NSMutableArray array];

        _avatarRing = [[UIView alloc] init];
        _avatarRing.backgroundColor = CFTheme.background;
        _avatar = [[UIImageView alloc] init];

        for (UIView *v in @[_bubble, _header, _dots, _body, _avatarRing, _avatar]) {
            [cv addSubview:v];
        }
    }
    return self;
}

/// Content views made on demand go above the bubble and below the avatar ring.
- (void)addContentView:(UIView *)view {
    [self insertSubview:view belowSubview:_avatarRing];
}

/// A touch on the body swaps in a real text view (filled now, before the touch is delivered), so long
/// press and double tap select text with the system's selection and edit menu.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (event.type == UIEventTypeTouches && _layout.bodyText && !_body.hidden && CGRectContainsPoint(_body.frame, point)) {
        [self showSelectableBody];
    }
    return [super hitTest:point withEvent:event];
}

- (void)showSelectableBody {
    if (!_selectableBody) {
        _selectableBody = [self makeTextView];
        [self insertSubview:_selectableBody aboveSubview:_body];
    }
    [UIView performWithoutAnimation:^{
        self->_selectableBody.attributedText = self->_layout.bodyText;
        self->_selectableBody.frame = self->_layout.textFrame;
        self->_selectableBody.hidden = NO;
        self->_body.hidden = YES;
    }];
}

- (void)makeSeparator {
    _separatorLine = [[UIView alloc] init];
    _separatorLine.backgroundColor = CFTheme.bubble;
    _separatorPill = [[UIView alloc] init];
    _separatorPill.backgroundColor = CFTheme.bubble;
    _separatorLabel = [[UILabel alloc] init];
    _separatorLabel.textAlignment = NSTextAlignmentCenter;
    [_separatorPill addSubview:_separatorLabel];
    [self insertSubview:_separatorLine belowSubview:_bubble];
    [self insertSubview:_separatorPill belowSubview:_bubble];
}

- (void)makeCode {
    _codeBox = [[UIView alloc] init];
    _codeBox.backgroundColor = CFTheme.pillBackground;
    _codeBox.layer.cornerRadius = 6.4;
    _code = [self makeTextView];
    [_codeBox addSubview:_code];
    [self addContentView:_codeBox];
}

- (void)makeImage {
    // CampfireKit's placeholder images are solid colour: a filled view draws the same pixels.
    _image = [[UIView alloc] init];
    [_bubble addSubview:_image];
}

- (void)makeFile {
    _fileIcon = [[UIImageView alloc] initWithImage:[CFIcons fileIcon]];
    _fileIcon.tintColor = CFTheme.text;
    _fileName = [[UILabel alloc] init];
    _fileDownload = [[UIImageView alloc] initWithImage:[CFIcons downloadIcon]];
    _fileDownload.tintColor = CFTheme.text;
    _fileShare = [[UIImageView alloc] initWithImage:[CFIcons shareIcon]];
    _fileShare.tintColor = CFTheme.text;
    for (UIView *v in @[_fileIcon, _fileName, _fileDownload, _fileShare]) { [self addContentView:v]; }
}

- (void)makeAddBoost {
    _addBoost = [[UIView alloc] init];
    _addBoost.backgroundColor = CFTheme.pillBackground;
    _addBoost.layer.borderWidth = 1;
    _addBoost.isAccessibilityElement = YES;
    _addBoost.accessibilityLabel = @"Add boost";
    _addBoost.accessibilityTraits = UIAccessibilityTraitButton;
    _addBoostIcon = [[UIImageView alloc] initWithImage:[CFIcons addBoostIcon]];
    _addBoostIcon.tintColor = CFTheme.text;
    [_addBoost addSubview:_addBoostIcon];
    [self addContentView:_addBoost];
    [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateCGColors)];
    [self updateCGColors];
}

- (UITextView *)makeTextView {
    UITextView *t = [CFMessageTextView textViewUsingTextLayoutManager:NO];
    t.editable = NO;
    t.selectable = YES;
    t.scrollEnabled = NO;
    t.backgroundColor = UIColor.clearColor;
    t.textContainerInset = UIEdgeInsetsZero;
    t.textContainer.lineFragmentPadding = 0;
    t.delegate = self;
    t.dataDetectorTypes = UIDataDetectorTypeNone;
    t.clipsToBounds = NO;
    return t;
}

- (void)updateCGColors {
    _addBoost.layer.borderColor = [CFTheme.borderDark resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

- (NSInteger)itemID { return _itemID; }
- (CFRowLayout *)layout { return _layout; }

- (void)configureWithLayout:(CFRowLayout *)L item:(CFMessageItem *)item store:(CFRoomStore *)store {
    BOOL sameContent = _layout && _itemID == item.itemID && _revision == item.revision && _scale == L.scale;
    _layout = L;
    _itemID = item.itemID;
    _revision = item.revision;
    _scale = L.scale;

    [UIView performWithoutAnimation:^{
        [self applyLayout:L item:item store:store sameContent:sameContent];
    }];
}

- (void)applyLayout:(CFRowLayout *)L item:(CFMessageItem *)item store:(CFRoomStore *)store sameContent:(BOOL)sameContent {
    // Separator.
    if (L.hasSeparator && !_separatorLine) { [self makeSeparator]; }
    _separatorLine.hidden = _separatorPill.hidden = !L.hasSeparator;
    if (L.hasSeparator) {
        _separatorLine.frame = L.separatorLineFrame;
        _separatorPill.frame = L.separatorPillFrame;
        _separatorPill.layer.cornerRadius = L.separatorPillFrame.size.height / 2;
        _separatorLabel.attributedText = L.separatorText;
        _separatorLabel.frame = _separatorPill.bounds;
    }

    // Bubble.
    _bubble.frame = L.bubbleFrame;
    switch (L.bubbleStyle) {
        case CFBubbleStyleNormal: _bubble.backgroundColor = CFTheme.bubble; break;
        case CFBubbleStyleMention: _bubble.backgroundColor = CFTheme.mentionBubble; break;
        case CFBubbleStyleNone: _bubble.backgroundColor = UIColor.clearColor; break;
    }

    _header.attributedText = L.headerText;
    _header.frame = L.headerFrame;
    _dots.frame = L.dotsFrame;

    // Body text.
    BOOL selectable = sameContent && _selectableBody && !_selectableBody.hidden;
    _body.hidden = L.bodyText == nil || selectable;
    if (!selectable) { _selectableBody.hidden = YES; }
    if (L.bodyText) {
        _body.layoutManager = L.bodyLayoutManager;
        _body.frame = L.textFrame;
        _selectableBody.frame = L.textFrame;
    }
    if (L.codeText && !_codeBox) { [self makeCode]; }
    _codeBox.hidden = L.codeText == nil;
    if (L.codeText) {
        _codeBox.frame = L.codeBoxFrame;
        if (!sameContent || ![_code.attributedText isEqualToAttributedString:L.codeText]) {
            _code.attributedText = L.codeText;
        }
        _code.frame = L.codeTextFrame;
    }

    // Image.
    CFKAttachment *a = item.message.attachment;
    BOOL hasImage = !CGRectIsEmpty(L.imageFrame) && a;
    if (hasImage && !_image) { [self makeImage]; }
    _image.hidden = !hasImage;
    if (hasImage) {
        _image.frame = CGRectOffset(L.imageFrame, -L.bubbleFrame.origin.x, -L.bubbleFrame.origin.y);
        _image.backgroundColor = [UIColor colorWithRed:a.red / 255.0 green:a.green / 255.0 blue:a.blue / 255.0 alpha:1];
    }

    // File.
    BOOL hasFile = !CGRectIsEmpty(L.fileIconFrame);
    if (hasFile && !_fileIcon) { [self makeFile]; }
    _fileIcon.hidden = _fileName.hidden = _fileDownload.hidden = _fileShare.hidden = !hasFile;
    if (hasFile) {
        _fileIcon.frame = L.fileIconFrame;
        _fileName.attributedText = L.fileNameText;
        _fileName.frame = L.fileNameFrame;
        _fileDownload.frame = L.fileDownloadFrame;
        _fileShare.frame = L.fileShareFrame;
    }

    // Boosts.
    NSArray<NSValue *> *frames = L.boostFrames;
    if (frames.count && !_addBoost) { [self makeAddBoost]; }
    while (_pills.count < frames.count) {
        CFBoostPillView *p = [[CFBoostPillView alloc] init];
        [self insertSubview:p belowSubview:_addBoost];
        [_pills addObject:p];
    }
    for (NSUInteger i = 0; i < _pills.count; i++) {
        CFBoostPillView *p = _pills[i];
        p.hidden = i >= frames.count;
        if (p.hidden) { continue; }
        CGRect f = frames[i].CGRectValue;
        CFBoostItem *b = L.boosts[i];
        p.frame = f;
        p.layer.cornerRadius = f.size.height / 2;
        CGFloat as = L.boostAvatarSize;
        CFKUser *u = [store userWithID:b.boosterID];
        p.avatar.image = [CFAvatar imageForUserID:b.boosterID initial:[CFAvatar initialForName:u.name ?: @"?"] diameter:as];
        p.avatar.frame = CGRectMake(1 + 1.6 * L.scale, (f.size.height - as) / 2, as, as);
        p.label.attributedText = L.boostTexts[i];
        CGFloat lx = CGRectGetMaxX(p.avatar.frame) + 4.5 * L.scale;
        p.label.frame = CGRectMake(lx, 0, f.size.width - lx, f.size.height);
        p.accessibilityLabel = [NSString stringWithFormat:@"%@ by %@", b.content, u.name ?: @""];
    }
    _addBoost.hidden = frames.count == 0;
    if (frames.count) {
        _addBoost.frame = L.addBoostFrame;
        _addBoost.layer.cornerRadius = L.addBoostFrame.size.height / 2;
        CGFloat icon = 20 * L.scale;
        _addBoostIcon.frame = CGRectMake((L.addBoostFrame.size.width - icon) / 2, (L.addBoostFrame.size.height - icon) / 2, icon, icon);
    }

    // Avatar, drawn over the bubble corner with a background-coloured ring.
    _avatar.hidden = _avatarRing.hidden = !L.showsAvatar;
    if (L.showsAvatar) {
        CGRect f = L.avatarFrame;
        _avatar.frame = f;
        _avatar.image = [CFAvatar imageForUserID:L.avatarUserID initial:L.avatarInitial diameter:f.size.width];
        _avatarRing.frame = CGRectInset(f, -2.2, -2.2);
        _avatarRing.layer.cornerRadius = _avatarRing.frame.size.width / 2;
    }

    self.accessibilityLabel = L.accessibilityText;
}

#pragma mark Copy and Reply

/// The system edit menu of the selected range (Copy, Look Up, Translate, Select All...) plus Reply.
- (UIMenu *)menuWithSuggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    UIAction *reply = [UIAction actionWithTitle:@"Reply" image:[UIImage systemImageNamed:@"arrowshape.turn.up.left"]
                                     identifier:@"campfire.reply" handler:^(__kindof UIAction *action) {}];
    // Reply first, so it is on the menu's first page next to Copy.
    return [UIMenu menuWithChildren:[@[reply] arrayByAddingObjectsFromArray:suggestedActions]];
}

- (UIMenu *)textView:(UITextView *)textView editMenuForTextInRanges:(NSArray<NSValue *> *)ranges suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    return [self menuWithSuggestedActions:suggestedActions];
}

- (UIMenu *)textView:(UITextView *)textView editMenuForTextInRange:(NSRange)range suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    return [self menuWithSuggestedActions:suggestedActions];
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    NSString *text = _layout.plainText ?: @"";
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *copy = [UIAction actionWithTitle:@"Copy" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil
                                           handler:^(__kindof UIAction *action) { UIPasteboard.generalPasteboard.string = text; }];
        UIAction *reply = [UIAction actionWithTitle:@"Reply" image:[UIImage systemImageNamed:@"arrowshape.turn.up.left"] identifier:nil
                                            handler:^(__kindof UIAction *action) {}];
        return [UIMenu menuWithChildren:@[copy, reply]];
    }];
}

@end
