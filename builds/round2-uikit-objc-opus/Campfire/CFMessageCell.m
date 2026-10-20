#import "CFMessageCell.h"
#import "CFAvatar.h"
#import "CFIcons.h"

#pragma mark - Image loader

@implementation CFImageLoader {
    NSCache<NSString *, UIImage *> *_cache;
    NSMutableDictionary<NSString *, NSMutableArray *> *_waiting;
    dispatch_queue_t _queue;
}

+ (instancetype)shared {
    static CFImageLoader *loader; static dispatch_once_t once;
    dispatch_once(&once, ^{ loader = [[CFImageLoader alloc] init]; });
    return loader;
}

- (instancetype)init {
    if ((self = [super init])) {
        _cache = [[NSCache alloc] init];
        _cache.totalCostLimit = 64 * 1024 * 1024;
        _waiting = [NSMutableDictionary dictionary];
        _queue = dispatch_queue_create("campfire.images", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

static NSString *CFImageKey(CFKAttachment *a) {
    return [NSString stringWithFormat:@"%ldx%ld-%ld-%ld-%ld", (long)a.width, (long)a.height, (long)a.red, (long)a.green, (long)a.blue];
}

- (UIImage *)cachedImageForAttachment:(CFKAttachment *)attachment {
    return [_cache objectForKey:CFImageKey(attachment)];
}

- (void)loadImageForAttachment:(CFKAttachment *)attachment completion:(void (^)(UIImage *))completion {
    NSString *key = CFImageKey(attachment);
    UIImage *cached = [_cache objectForKey:key];
    if (cached) { completion(cached); return; }
    NSMutableArray *waiters = _waiting[key];
    if (waiters) { [waiters addObject:[completion copy]]; return; }
    _waiting[key] = [NSMutableArray arrayWithObject:[completion copy]];
    dispatch_async(_queue, ^{
        NSData *png = attachment.placeholderPNGData;
        UIImage *image = png ? [UIImage imageWithData:png scale:1] : nil;
        // Decode at the size it is shown (300 pt at 3x) so the main thread never decodes.
        CGFloat targetW = MIN((CGFloat)attachment.width, 900);
        CGSize target = CGSizeMake(targetW, targetW * attachment.height / MAX(attachment.width, 1));
        UIImage *prepared = [image imageByPreparingThumbnailOfSize:target] ?: image;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *list = self->_waiting[key];
            [self->_waiting removeObjectForKey:key];
            if (!prepared) { return; }
            [self->_cache setObject:prepared forKey:key cost:(NSUInteger)(target.width * target.height * 4)];
            for (void (^c)(UIImage *) in list) { c(prepared); }
        });
    });
}

@end

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
    UITextView *_body;
    UIView *_codeBox;
    UITextView *_code;
    UIImageView *_image;
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
    NSString *_imageKey;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        UIView *cv = self.contentView;
        _separatorLine = [[UIView alloc] init];
        _separatorLine.backgroundColor = CFTheme.bubble;
        _separatorPill = [[UIView alloc] init];
        _separatorPill.backgroundColor = CFTheme.bubble;
        _separatorLabel = [[UILabel alloc] init];
        _separatorLabel.textAlignment = NSTextAlignmentCenter;
        [_separatorPill addSubview:_separatorLabel];

        _bubble = [[UIView alloc] init];
        _bubble.layer.cornerRadius = 10.56;
        _bubble.layer.cornerCurve = kCACornerCurveCircular;
        _bubble.clipsToBounds = YES;
        [_bubble addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];

        _image = [[UIImageView alloc] init];
        _image.contentMode = UIViewContentModeScaleToFill;
        [_bubble addSubview:_image];

        _header = [[UILabel alloc] init];
        _header.numberOfLines = 0;
        _dots = [[UIView alloc] init];
        for (int i = 0; i < 3; i++) {
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(i * 6.2, 0, 4.6, 4.6)];
            dot.backgroundColor = CFTheme.secondaryText;
            dot.layer.cornerRadius = 2.3;
            [_dots addSubview:dot];
        }

        _body = [self makeTextView];
        _codeBox = [[UIView alloc] init];
        _codeBox.backgroundColor = CFTheme.pillBackground;
        _codeBox.layer.cornerRadius = 6.4;
        _code = [self makeTextView];
        [_codeBox addSubview:_code];

        _fileIcon = [[UIImageView alloc] initWithImage:[CFIcons fileIcon]];
        _fileIcon.tintColor = CFTheme.text;
        _fileName = [[UILabel alloc] init];
        _fileDownload = [[UIImageView alloc] initWithImage:[CFIcons downloadIcon]];
        _fileDownload.tintColor = CFTheme.text;
        _fileShare = [[UIImageView alloc] initWithImage:[CFIcons shareIcon]];
        _fileShare.tintColor = CFTheme.text;

        _pills = [NSMutableArray array];
        _addBoost = [[UIView alloc] init];
        _addBoost.backgroundColor = CFTheme.pillBackground;
        _addBoost.layer.borderWidth = 1;
        _addBoost.isAccessibilityElement = YES;
        _addBoost.accessibilityLabel = @"Add boost";
        _addBoost.accessibilityTraits = UIAccessibilityTraitButton;
        _addBoostIcon = [[UIImageView alloc] initWithImage:[CFIcons addBoostIcon]];
        _addBoostIcon.tintColor = CFTheme.text;
        [_addBoost addSubview:_addBoostIcon];

        _avatarRing = [[UIView alloc] init];
        _avatarRing.backgroundColor = CFTheme.background;
        _avatar = [[UIImageView alloc] init];

        for (UIView *v in @[_separatorLine, _separatorPill, _bubble, _header, _dots, _body, _codeBox, _fileIcon, _fileName,
                            _fileDownload, _fileShare, _addBoost, _avatarRing, _avatar]) {
            [cv addSubview:v];
        }
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(updateCGColors)];
        [self updateCGColors];
    }
    return self;
}

- (UITextView *)makeTextView {
    UITextView *t = [UITextView textViewUsingTextLayoutManager:NO];
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

- (void)prepareForReuse {
    [super prepareForReuse];
    _imageKey = nil;
}

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
    _body.hidden = L.bodyText == nil;
    if (L.bodyText) {
        if (!sameContent || ![_body.attributedText isEqualToAttributedString:L.bodyText]) {
            _body.attributedText = L.bodyText;
        }
        _body.frame = L.textFrame;
    }
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
    _image.hidden = !hasImage;
    if (hasImage) {
        _image.frame = CGRectOffset(L.imageFrame, -L.bubbleFrame.origin.x, -L.bubbleFrame.origin.y);
        _image.backgroundColor = [UIColor colorWithRed:a.red / 255.0 green:a.green / 255.0 blue:a.blue / 255.0 alpha:1];
        NSString *key = [NSString stringWithFormat:@"%ld", (long)item.itemID];
        if (![_imageKey isEqualToString:key]) {
            _imageKey = key;
            UIImage *cached = [[CFImageLoader shared] cachedImageForAttachment:a];
            _image.image = cached;
            if (!cached) {
                __weak typeof(self) weakSelf = self;
                [[CFImageLoader shared] loadImageForAttachment:a completion:^(UIImage *image) {
                    typeof(self) strongSelf = weakSelf;
                    if (strongSelf && [strongSelf->_imageKey isEqualToString:key]) { strongSelf->_image.image = image; }
                }];
            }
        }
    } else {
        _image.image = nil;
        _imageKey = nil;
    }

    // File.
    BOOL hasFile = !CGRectIsEmpty(L.fileIconFrame);
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
    while (_pills.count < frames.count) {
        CFBoostPillView *p = [[CFBoostPillView alloc] init];
        [self.contentView insertSubview:p belowSubview:_addBoost];
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

- (UIMenu *)menuForTextView:(UITextView *)textView ranges:(NSArray<NSValue *> *)ranges {
    __weak UITextView *weakText = textView;
    UIAction *copy = [UIAction actionWithTitle:@"Copy" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:@"campfire.copy"
                                       handler:^(__kindof UIAction *action) {
        UITextView *t = weakText;
        NSMutableString *out = [NSMutableString string];
        for (NSValue *v in ranges) {
            NSRange r = v.rangeValue;
            if (NSMaxRange(r) <= t.attributedText.length) { [out appendString:[t.attributedText.string substringWithRange:r]]; }
        }
        // Attachment characters (mention avatars) are not text.
        [out replaceOccurrencesOfString:@"￼" withString:@"" options:0 range:NSMakeRange(0, out.length)];
        UIPasteboard.generalPasteboard.string = out;
    }];
    UIAction *reply = [UIAction actionWithTitle:@"Reply" image:[UIImage systemImageNamed:@"arrowshape.turn.up.left"]
                                     identifier:@"campfire.reply" handler:^(__kindof UIAction *action) {}];
    return [UIMenu menuWithChildren:@[copy, reply]];
}

- (UIMenu *)textView:(UITextView *)textView editMenuForTextInRanges:(NSArray<NSValue *> *)ranges suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    return [self menuForTextView:textView ranges:ranges];
}

- (UIMenu *)textView:(UITextView *)textView editMenuForTextInRange:(NSRange)range suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    return [self menuForTextView:textView ranges:@[[NSValue valueWithRange:range]]];
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
