# Cells: registrations, configurations and reuse

A cell is a reusable view that shows one item. Its job is to look up the item, set a few properties, and react to its state (selected, highlighted, editing, disabled). Everything here keeps that job small and reuse-safe.

## Registrations

Create a `UICollectionViewCellRegistration` once, and dequeue with it in the cell provider.

Wrong: string identifiers, casts, and a registration made inside the provider.

```objc
[self.collectionView registerClass:[MessageCell class] forCellWithReuseIdentifier:@"Message"];
self.dataSource = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView
    cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *indexPath, NSUUID *itemID) {
    MessageCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"Message" forIndexPath:indexPath];
    return cell;
}];
```

```objc
cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *indexPath, NSUUID *itemID) {
    UICollectionViewCellRegistration *registration = [UICollectionViewCellRegistration
        registrationWithCellClass:[UICollectionViewListCell class]
             configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *ip, NSUUID *item) {}];
    return [cv dequeueConfiguredReusableCellWithRegistration:registration forIndexPath:indexPath item:itemID];  // raises an exception
}
```

Right:

```objc
__weak typeof(self) weakSelf = self;
UICollectionViewCellRegistration *messageCell = [UICollectionViewCellRegistration
    registrationWithCellClass:[UICollectionViewListCell class]
         configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *indexPath, NSUUID *itemID) {
    typeof(self) strongSelf = weakSelf;
    Message *message = strongSelf.store[itemID];
    if (!message) { return; }
    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = message.sender;
    content.secondaryText = message.preview;
    cell.contentConfiguration = content;
    cell.accessories = message.isUnread ? @[strongSelf.unreadDotAccessory] : @[];
}];

self.dataSource = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView
    cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *indexPath, NSUUID *itemID) {
    return [cv dequeueConfiguredReusableCellWithRegistration:messageCell forIndexPath:indexPath item:itemID];
}];
```

- The registration is not generic in Objective-C: the item arrives as `id`, and the cell as `__kindof UICollectionViewCell *`. The handler block may declare the narrower types (`UICollectionViewListCell *`, `NSUUID *`) as shown. The `__kindof` return type of the dequeue method assigns to a subclass pointer without a cast.
- The registration's item can be the identifier. Look up the model inside the handler.
- A registration made inside the cell provider is a new registration per call; UIKit raises an exception for it. Make registrations before the data source, as local variables the provider block captures, or as properties.
- A registration handler is retained by the registration, which the provider block retains, which the data source retains, which the controller owns. Capture `weakSelf` when the handler reads the controller (see the retain-cycle section in `concurrency.md`).
- One registration per cell kind. Choose the registration in the provider by switching on the section or on the identifier.
- Supplementary views use `UICollectionViewSupplementaryRegistration`, created with `+registrationWithSupplementaryClass:elementKind:configurationHandler:`, and `-dequeueConfiguredReusableSupplementaryViewWithRegistration:forIndexPath:` in `dataSource.supplementaryViewProvider`.

## Content configurations

A content configuration is an object that describes what a cell shows. The cell turns it into views.

- `UIListContentConfiguration` covers most rows: image, text, secondary text, and their properties. Start from `[cell defaultContentConfiguration]`, which matches the cell's list style. Other starting points: `+cellConfiguration`, `+subtitleCellConfiguration`, `+valueCellConfiguration`, `+headerConfiguration` and `+footerConfiguration` (iOS 18+), `+prominentInsetGroupedHeaderConfiguration`.
- Change appearance through the configuration's properties (`textProperties.font`, `textProperties.numberOfLines`, `imageProperties.tintColor`, `directionalLayoutMargins`, `imageToTextPadding`) instead of reaching into subviews.
- Assign a new configuration on every configuration pass. Do not keep a configuration from a previous item.
- Configurations are value-like but are classes: they are `NSCopying`. Copy before changing a shared one (`[config copy]`), and never mutate an instance another cell holds.

### Custom content configurations

When the list configuration is not enough, write a configuration and a content view.

```objc
@interface MessageContent : NSObject <UIContentConfiguration, NSCopying>
@property (nonatomic, copy) NSString *sender;
@property (nonatomic, copy) NSString *body;
@property (nonatomic) BOOL isOutgoing;
@end

@implementation MessageContent
- (__kindof UIView<UIContentView> *)makeContentView {
    return [[MessageContentView alloc] initWithConfiguration:self];
}
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state { return self; }
- (id)copyWithZone:(NSZone *)zone {
    MessageContent *copy = [[[self class] allocWithZone:zone] init];
    copy.sender = self.sender;
    copy.body = self.body;
    copy.isOutgoing = self.isOutgoing;
    return copy;
}
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MessageContent class]]) { return NO; }
    MessageContent *other = object;
    return [self.sender isEqual:other.sender] && [self.body isEqual:other.body] && self.isOutgoing == other.isOutgoing;
}
- (NSUInteger)hash { return self.sender.hash ^ self.body.hash ^ (NSUInteger)self.isOutgoing; }
@end

@interface MessageContentView : UIView <UIContentView>
- (instancetype)initWithConfiguration:(MessageContent *)configuration;
@end

@implementation MessageContentView {
    UILabel *_senderLabel;
    UILabel *_bodyLabel;
    MessageContent *_current;
}
@synthesize configuration = _configuration;   // required: the protocol declares the property

- (instancetype)initWithConfiguration:(MessageContent *)configuration {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _current = [configuration copy];
        [self buildHierarchy];           // subviews and constraints, once
        [self applyConfiguration:_current];
    }
    return self;
}

- (id<UIContentConfiguration>)configuration { return _current; }

- (void)setConfiguration:(id<UIContentConfiguration>)configuration {
    if (![configuration isKindOfClass:[MessageContent class]]) { return; }
    MessageContent *new = [(MessageContent *)configuration copy];
    if ([new isEqual:_current]) { return; }
    _current = new;
    [self applyConfiguration:new];
}

- (void)applyConfiguration:(MessageContent *)c {
    _senderLabel.text = c.sender;
    _bodyLabel.text = c.body;
}
@end
```

- Make the configuration implement `isEqual:`, `hash` and `copyWithZone:`, and skip the update when it equals the current one; configuration runs often. The protocol declares `configuration` as a `copy` property, so the setter receives a copy of whatever you assign.
- `@synthesize configuration` is not needed if you write both accessors yourself; if you write only one, add it. A content view that never implements the property does not compile cleanly.
- Build subviews and constraints once in the initializer. `applyConfiguration:` only sets properties and constraint constants.
- `updatedConfigurationForState:` returns a copy adjusted for the state (for example a different text color when selected). Keep it free of side effects.
- Content views are reused across items. Everything `applyConfiguration:` touches must be set every time, or old values leak to the next item.

## Backgrounds

Use `UIBackgroundConfiguration` for fills, strokes, corner radius and insets, not a custom `backgroundView` you style by hand.

```objc
UIBackgroundConfiguration *background = [UIBackgroundConfiguration listCellConfiguration];   // iOS 18+
background.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
background.cornerRadius = 12;
cell.backgroundConfiguration = background;
```

- iOS 18 replaced the per-style factories (`+listPlainCellConfiguration`, `+listGroupedCellConfiguration`, `+listSidebarCellConfiguration`) with `+listCellConfiguration`, `+listHeaderConfiguration` and `+listFooterConfiguration`, which adapt to the list they are in. `+clearConfiguration` gives no background.
- Background configurations have their own state handling: `backgroundColorTransformer` and `-updatedConfigurationForState:`.

## Configuration state

Cells and content react to state through one path:

```objc
cell.configurationUpdateHandler = ^(__kindof UICollectionViewCell *c, UICellConfigurationState *state) {
    UIListContentConfiguration *content = [[UIListContentConfiguration cellConfiguration]
                                           updatedConfigurationForState:state];
    content.text = title;
    content.textProperties.color = state.disabled ? [UIColor secondaryLabelColor] : [UIColor labelColor];
    c.contentConfiguration = content;

    UIBackgroundConfiguration *background = [[UIBackgroundConfiguration listCellConfiguration]
                                             updatedConfigurationForState:state];
    if (state.selected) {
        background.backgroundColor = [[c tintColor] colorWithAlphaComponent:0.15];
    }
    c.backgroundConfiguration = background;
};
```

- The state has `selected`, `highlighted`, `focused`, `disabled`, `editing`, `expanded`, `swiped`, `reordering`, `cellDropState` and `traitCollection`. In Objective-C the boolean properties are declared with getters (`isSelected`), and dot syntax uses the plain name (`state.selected`).
- Do not override `setSelected:` or `setHighlighted:` to restyle a cell. Use the handler, or override `-updateConfigurationUsingState:` in a subclass.
- Custom state: define a `UIConfigurationStateCustomKey` string constant, expose it through an `UICellConfigurationState` category (`-customStateForKey:` and the `objectForKeyedSubscript:` family), and override `configurationState` in the cell subclass to add your values; call `-setNeedsUpdateConfiguration` when they change.
- Traits read inside `-updateConfigurationUsingState:` or the handler are tracked on iOS 18+, so the cell updates on its own when those traits change.
- The handler is a `copy` block stored on the cell. Do not capture the cell strongly from outside it (the parameter is the cell; use that), and capture the controller weakly.

## Accessories

List cells take `accessories`, an `NSArray<UICellAccessory *> *`. The classes are `UICellAccessoryDisclosureIndicator`, `UICellAccessoryCheckmark`, `UICellAccessoryDelete`, `UICellAccessoryReorder`, `UICellAccessoryOutlineDisclosure`, `UICellAccessoryLabel` (`-initWithText:`), `UICellAccessoryDetail`, `UICellAccessoryMultiselect`, `UICellAccessoryPopUpMenu` (`-initWithMenu:`) and `UICellAccessoryCustomView` (`-initWithCustomView:placement:`). Each takes `displayedState` (`UICellAccessoryDisplayedAlways`, `...WhenEditing`, `...WhenNotEditing`). Use them instead of adding buttons to the content view, so editing mode, layout and accessibility stay consistent.

```objc
UICellAccessoryDisclosureIndicator *chevron = [[UICellAccessoryDisclosureIndicator alloc] init];
chevron.displayedState = UICellAccessoryDisplayedWhenNotEditing;
cell.accessories = @[chevron];
```

Create an accessory once if its content does not change; do not allocate a new custom view per configuration pass.

## Reuse safety

A dequeued cell may have shown any other item a moment ago.

- Set every property the configuration path touches, every time. A field set only "if present" keeps the old item's value when absent.
- Cancel per-cell work in `-prepareForReuse` (always call `[super prepareForReuse]`) and re-check identity when async work finishes. See `list-performance.md` for the image pattern.
- Do not store the item's index path on the cell. If the cell needs to act for its item (a button inside it), store the identifier, or send the action up with the cell and resolve it through `-indexPathForCell:` then the data source.
- Never hold a strong reference to a cell outside the collection view. Ask for the visible cell with `-cellForItemAtIndexPath:` when you need it, and handle `nil`.

## Buttons and controls inside cells

Wrong: a block stored on the cell that captures an index path and `self`.

```objc
cell.onLike = ^{ [self likeAtIndexPath:indexPath]; };
```

Right: capture the identifier, weakly capture the controller, and set the action on every configuration.

```objc
__weak typeof(self) weakSelf = self;
UIAction *likeAction = [UIAction actionWithTitle:@"" image:nil identifier:@"like"
                                         handler:^(__kindof UIAction *action) {
    [weakSelf likeItem:itemID];
}];
[cell.likeButton addAction:likeAction forControlEvents:UIControlEventPrimaryActionTriggered];
```

Actions added on each configuration stack up unless they share an identifier: `-addAction:forControlEvents:` replaces an existing action with the same identifier. Without one, call `-removeActionForIdentifier:forControlEvents:` first. The identifier is a `UIActionIdentifier` (a string); use a constant.

## Empty and loading states

Show empty, loading and error states with `UIContentUnavailableConfiguration` (iOS 17+), not a label laid over the collection view.

```objc
- (void)updateContentUnavailableConfigurationUsingState:(UIContentUnavailableConfigurationState *)state {
    if (self.isLoading) {
        self.contentUnavailableConfiguration = [UIContentUnavailableConfiguration loadingConfiguration];
    } else if (self.items.count == 0) {
        UIContentUnavailableConfiguration *config = [UIContentUnavailableConfiguration emptyConfiguration];
        config.image = [UIImage systemImageNamed:@"tray"];
        config.text = NSLocalizedString(@"No Messages", @"Empty inbox title");
        config.secondaryText = NSLocalizedString(@"New messages appear here.", @"Empty inbox message");
        self.contentUnavailableConfiguration = config;
    } else {
        self.contentUnavailableConfiguration = nil;
    }
}
```

- Call `-setNeedsUpdateContentUnavailableConfiguration` when the inputs change (loading finished, items became empty).
- `+searchConfiguration` is the standard "no results" for a search query.
- Add a button through `config.button` and `config.buttonProperties.primaryAction` for "Try Again".

## Headers and footers

- Supplementary registrations configure headers the same way as cells: `+headerConfiguration` on a `UICollectionViewListCell`, or a custom content configuration.
- With `UICollectionLayoutListHeaderModeFirstItemInSection`, the header is an ordinary item; give it its own identifier and registration, and use a `UICellAccessoryOutlineDisclosure` accessory for expandable sections.

## Review checks

1. Registrations created once, never in the provider.
2. Every configured property set on every pass.
3. State changes go through the update handler or `-updateConfigurationUsingState:`.
4. No index paths stored on cells or in their blocks; no strong `self` in stored blocks.
5. Empty and loading states use `UIContentUnavailableConfiguration`.
