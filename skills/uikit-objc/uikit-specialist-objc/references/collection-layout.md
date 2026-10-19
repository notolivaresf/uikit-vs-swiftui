# Collection view layout

A modern UIKit list or grid has three parts, each with one job:

- a compositional layout says where things go (this file);
- a diffable data source says what is there (`diffable-data.md`);
- cell registrations and content configurations say what each item looks like (`cells.md`).

Keep the three apart. A layout that reads the model, or a cell that decides its own position, is the usual source of hard bugs.

## Choosing the layout

| Screen | Layout |
|---|---|
| A table-like list (settings, inbox, contacts) | `+[UICollectionViewCompositionalLayout layoutWithListConfiguration:]` |
| Sections of different kinds (carousel, list, grid) | `UICollectionViewCompositionalLayout` with a section provider |
| A uniform grid | compositional layout, item width as a fraction of the group |
| Horizontal rows inside a vertical list | a section with `orthogonalScrollingBehavior` |
| Existing working `UITableView` | keep it; see the end of this file |

Rule: in new code use `UICollectionView` with a compositional layout. Do not subclass `UICollectionViewFlowLayout` or write a custom `UICollectionViewLayout` unless the layout cannot be described with items, groups and sections (a free-form canvas, a timeline with overlapping events).

## Lists

The list configuration gives separators, swipe actions, headers, outline disclosure and the system look.

Wrong: a hand-made list with a fixed row height and drawn separators.

```objc
UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
layout.itemSize = CGSizeMake(CGRectGetWidth(self.view.bounds), 44);
```

Right:

```objc
UICollectionLayoutListConfiguration *config =
    [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearanceInsetGrouped];
config.headerMode = UICollectionLayoutListHeaderModeSupplementary;
__weak typeof(self) weakSelf = self;
config.trailingSwipeActionsConfigurationProvider = ^UISwipeActionsConfiguration * _Nullable(NSIndexPath *indexPath) {
    return [weakSelf trailingSwipeActionsAtIndexPath:indexPath];
};
UICollectionViewCompositionalLayout *layout =
    [UICollectionViewCompositionalLayout layoutWithListConfiguration:config];
```

- `appearance`: `UICollectionLayoutListAppearancePlain`, `Grouped`, `InsetGrouped`, `Sidebar`, `SidebarPlain`. Match the screen's role, not a color you want.
- `headerMode`: `...Supplementary` uses a supplementary registration for the header; `...FirstItemInSection` makes the first item the header (for expandable outlines).
- `showsSeparators` and `separatorConfiguration` control separators. Per-item separator changes go through `itemSeparatorHandler`, a block that receives the index path and the default configuration and returns the one to use.
- The list's swipe providers are blocks that receive an index path. Resolve the identifier from the data source inside the block; never keep the index path for later.
- Blocks stored on a configuration that the layout keeps are retained by it: capture `weakSelf`, not `self` (see `concurrency.md`).

## Mixed sections

Build the layout per section with a provider. The provider runs again whenever the container size or traits change.

```objc
__weak typeof(self) weakSelf = self;
UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc]
    initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(NSInteger sectionIndex,
                                                                  id<NSCollectionLayoutEnvironment> environment) {
    typeof(self) strongSelf = weakSelf;
    if (!strongSelf) { return nil; }
    NSNumber *section = [strongSelf.dataSource sectionIdentifierForIndex:sectionIndex];
    switch (section.integerValue) {
        case SectionFeatured:
            return [strongSelf carouselSectionWithEnvironment:environment];
        case SectionAll: {
            UICollectionLayoutListConfiguration *list =
                [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
            list.headerMode = UICollectionLayoutListHeaderModeSupplementary;
            return [NSCollectionLayoutSection sectionWithListConfiguration:list layoutEnvironment:environment];
        }
        default:
            return nil;
    }
}];
```

- Map the section index to a section identifier through the data source (`sectionIdentifierForIndex:`, iOS 15+; it returns `nil` for an index that is not there). Do not switch on the raw index; it breaks as soon as a section is hidden.
- Read `environment.container.effectiveContentSize` and `environment.traitCollection` inside the provider to choose columns or sizes. Since iOS 18 traits read there are tracked, so the layout updates when they change.
- Return a new section each time. Do not cache `NSCollectionLayoutSection` objects across calls.
- Keep the provider cheap: arithmetic and object creation only. No model queries that touch disk.
- Section identifiers in Objective-C are objects: box a `NS_ENUM` with `@(SectionFeatured)` or use constant `NSString *` values (see `diffable-data.md`).

## Sizes: items, groups and sections

Every item and group has an `NSCollectionLayoutSize` with a width and a height dimension.

| Dimension | Meaning | Use for |
|---|---|---|
| `+fractionalWidthDimension:` / `+fractionalHeightDimension:` | fraction of the containing group | columns, square tiles |
| `+absoluteDimension:` | fixed points | things that truly never change, such as a fixed avatar strip |
| `+estimatedDimension:` | starting guess; the cell decides | anything that holds text |
| `+uniformAcrossSiblingsWithEstimate:` (iOS 17+) | all items in the group share the tallest height | cards in a row that should line up |

All of these are class methods on `NSCollectionLayoutDimension`.

Rule: any dimension that depends on text must be estimated. A fixed height on a text cell clips at large text sizes.

Wrong: an absolute row height for text.

```objc
NSCollectionLayoutSize *size = [NSCollectionLayoutSize
    sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
           heightDimension:[NSCollectionLayoutDimension absoluteDimension:60]];
NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:size];
```

Right:

```objc
NSCollectionLayoutSize *size = [NSCollectionLayoutSize
    sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
           heightDimension:[NSCollectionLayoutDimension estimatedDimension:60]];
NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:size];
```

- Fractional sizes are relative to the containing group, not the screen. An item at `0.5` inside a group at `0.8` is 40% of the section width.
- If an item is estimated in a dimension, its group must be estimated in that dimension too, or the group cannot grow.
- `uniformAcrossSiblingsWithEstimate:` has to measure every sibling in the group before it can place any of them. Use it for small groups (a row of two to four cards), not for a group with many items.
- Choose estimates near the typical real size. A wildly wrong estimate makes the scroll indicator jump and adds layout passes.
- Write a small helper (`static NSCollectionLayoutSize *LayoutSize(CGFloat fractionalWidth, CGFloat estimatedHeight)`) so a layout file does not repeat the long class-method chain.

## Grids

Compute the column count from the container, not from the device.

```objc
- (NSCollectionLayoutSection *)gridSectionWithEnvironment:(id<NSCollectionLayoutEnvironment>)environment {
    CGFloat width = environment.container.effectiveContentSize.width;
    NSInteger columns = MAX(2, (NSInteger)(width / 180.0));
    NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize
        sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0 / columns]
               heightDimension:[NSCollectionLayoutDimension estimatedDimension:220]];
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize
        sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
               heightDimension:[NSCollectionLayoutDimension estimatedDimension:220]];
    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                                           repeatingSubitem:item
                                                                                      count:columns];
    group.interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:8];
    NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
    section.interGroupSpacing = 8;
    section.contentInsetsReference = UIContentInsetsReferenceLayoutMargins;
    return section;
}
```

- Use `+horizontalGroupWithLayoutSize:repeatingSubitem:count:` (iOS 16+) for a fixed number of columns. The older `+horizontalGroupWithLayoutSize:subitem:count:` form is deprecated.
- Spacing: `interItemSpacing` on the group, `interGroupSpacing` on the section. Avoid `contentInsets` on items to make gaps; they shrink the item instead of spacing it.
- `contentInsetsReference` set to `UIContentInsetsReferenceLayoutMargins` or `...ReadableContent` keeps the grid aligned with the rest of the screen on wide windows.
- Square tiles: item `fractionalWidthDimension:1.0 / n` and group height `fractionalWidthDimension:1.0 / n` (a fraction of the group width works for the height too).
- `columns` is `NSInteger`; divide a `CGFloat`, never two integers (`1 / columns` is `0`).

## Horizontal rows inside a vertical list

Wrong: a collection view inside a cell.

```objc
@interface CarouselCell : UICollectionViewCell
@property (nonatomic, strong) UICollectionView *innerCollectionView;   // own layout, own data source
@end
```

Right: one collection view, with a section that scrolls on the other axis.

```objc
NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered;
section.interGroupSpacing = 12;
```

Nested collection views duplicate reuse, prefetching and focus, and their scroll positions are lost when the outer cell is reused. Orthogonal sections keep one data source and one set of cells.

- Behaviours (all `UICollectionLayoutSectionOrthogonalScrollingBehavior...`): `Continuous`, `ContinuousGroupLeadingBoundary`, `Paging`, `GroupPaging`, `GroupPagingCentered`.
- `orthogonalScrollingProperties` (iOS 17+) sets deceleration rate and bounce for that section.
- To react to orthogonal scrolling (a page indicator), use the section's `visibleItemsInvalidationHandler`; it receives the visible items, the scroll offset and the environment.

## Headers, footers, badges and decorations

- Boundary supplementary items (`NSCollectionLayoutBoundarySupplementaryItem`, created with `+boundarySupplementaryItemWithLayoutSize:elementKind:alignment:`) are section headers and footers. Set `pinToVisibleBounds = YES` for sticky headers.
- Item supplementary items (`NSCollectionLayoutSupplementaryItem` with an `NSCollectionLayoutAnchor`) put badges on items.
- Decoration items (`+[NSCollectionLayoutDecorationItem backgroundDecorationItemWithElementKind:]`) draw a section background. Register the decoration view class on the layout with `-registerClass:forDecorationViewOfKind:`, then add the item to `section.decorationItems`.
- Give each element kind a constant string (`static NSString * const kHeaderKind = @"header";`, or `extern` in a header), and use the same constant in the layout and in the supplementary registration. A typo in a string literal fails at runtime only.

## Layout configuration

`UICollectionViewCompositionalLayoutConfiguration` holds settings for the whole layout: `scrollDirection`, `interSectionSpacing`, global boundary supplementary items (`boundarySupplementaryItems`), and `contentInsetsReference`. Pass it to `-initWithSectionProvider:configuration:`.

## Visible-items effects

```objc
section.visibleItemsInvalidationHandler = ^(NSArray<id<NSCollectionLayoutVisibleItem>> *items,
                                            CGPoint offset,
                                            id<NSCollectionLayoutEnvironment> environment) {
    // adjust transform, alpha, zIndex of items
};
```

It runs every frame during scrolling: keep it to arithmetic on the items you receive. Never query the model or the data source there, and capture nothing strongly that owns the layout.

## Self-sizing

Self-sizing is the default for estimated dimensions. For it to work:

1. The dimension is estimated on the item and its group.
2. The cell's content is constrained to all four edges of `contentView` (or its `layoutMarginsGuide`) with an unbroken vertical chain.
3. Multi-line labels have `numberOfLines = 0`. Do not set `preferredMaxLayoutWidth` in cells.
4. `collectionView.selfSizingInvalidation` stays `UICollectionViewSelfSizingInvalidationEnabled` (the default since iOS 16), or `...EnabledIncludingConstraints` when constraint changes inside the cell should resize it.

With self-sizing invalidation on, a cell whose content changes size (expanded text, an image that loaded) calls `-invalidateIntrinsicContentSize` on the changed view, or on the cell, and the layout resizes it, animated if inside an animation block. Without it, reconfigure the item through the data source.

Wrong: measuring cells yourself.

```objc
MessageCell *sizingCell = [[MessageCell alloc] init];
[sizingCell configureWithMessage:message];
CGFloat height = [sizingCell systemLayoutSizeFittingSize:CGSizeMake(width, 0)].height;
```

Right: an estimated height and complete constraints; the layout measures.

- If an image's aspect ratio is known from metadata, add an aspect-ratio constraint up front so the cell does not jump when the image arrives.
- A known constant height (a fixed-height row of icons) can be absolute; it skips measuring. Use it for truly fixed rows, never to hide a constraint bug.
- List configurations self-size by default.

## Changing the layout

- To switch between two layouts (list and grid), call `-setCollectionViewLayout:animated:`. Keep the data source and the snapshot as they are.
- To re-run the section provider without changing data (a setting changed how many columns to show), call `[self.collectionView.collectionViewLayout invalidateLayout]`. Prefer reading a trait inside the provider so the change happens on its own.

## Table views

`UITableView` is not deprecated and stays fine for existing screens. The same rules apply:

- `UITableViewDiffableDataSource<SectionType, ItemType>` instead of index-path bookkeeping;
- content configurations through `-defaultContentConfiguration`, never `textLabel` or `detailTextLabel` (see `deprecated-apis.md`);
- self-sizing rows with `tableView.rowHeight = UITableViewAutomaticDimension` and a realistic `estimatedRowHeight`;
- `-reconfigureRowsAtIndexPaths:` or snapshot `-reconfigureItemsWithIdentifiers:` to refresh content.

Do not migrate a working table view to a collection view as a side task. Migrate when the screen needs something a table view cannot do (grids, orthogonal sections) or when asked.
