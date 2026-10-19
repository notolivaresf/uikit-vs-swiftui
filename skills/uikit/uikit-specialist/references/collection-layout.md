# Collection view layout

A modern UIKit list or grid has three parts, each with one job:

- a compositional layout says where things go (this file);
- a diffable data source says what is there (`diffable-data.md`);
- cell registrations and content configurations say what each item looks like (`cells.md`).

Keep the three apart. A layout that reads the model, or a cell that decides its own position, is the usual source of hard bugs.

## Choosing the layout

| Screen | Layout |
|---|---|
| A table-like list (settings, inbox, contacts) | `UICollectionViewCompositionalLayout.list(using:)` |
| Sections of different kinds (carousel, list, grid) | `UICollectionViewCompositionalLayout` with a section provider |
| A uniform grid | compositional layout, item width as a fraction of the group |
| Horizontal rows inside a vertical list | a section with `orthogonalScrollingBehavior` |
| Existing working `UITableView` | keep it; see the end of this file |

Rule: in new code use `UICollectionView` with a compositional layout. Do not subclass `UICollectionViewFlowLayout` or write a custom `UICollectionViewLayout` unless the layout cannot be described with items, groups and sections (a free-form canvas, a timeline with overlapping events).

## Lists

The list configuration gives separators, swipe actions, headers, outline disclosure and the system look.

Wrong: a hand-made list with a fixed row height and drawn separators.

```swift
let layout = UICollectionViewFlowLayout()
layout.itemSize = CGSize(width: view.bounds.width, height: 44)
```

Right:

```swift
var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
config.headerMode = .supplementary
config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
    self?.trailingSwipeActions(at: indexPath)
}
let layout = UICollectionViewCompositionalLayout.list(using: config)
```

- `appearance`: `.plain`, `.grouped`, `.insetGrouped`, `.sidebar`, `.sidebarPlain`. Match the screen's role, not a color you want.
- `headerMode`: `.supplementary` uses a supplementary registration for the header; `.firstItemInSection` makes the first item the header (for expandable outlines).
- `showsSeparators` and `separatorConfiguration` control separators. Per-item separator changes go through `itemSeparatorHandler`, which receives the index path and the default configuration.
- The list's swipe providers receive an index path. Resolve the identifier from the data source inside the provider; never capture an index path for later.

## Mixed sections

Build the layout per section with a provider. The provider runs again whenever the container size or traits change.

```swift
let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
    guard let self, let section = self.dataSource.sectionIdentifier(for: sectionIndex) else { return nil }
    switch section {
    case .featured:
        return Self.carouselSection(environment: environment)
    case .all:
        var list = UICollectionLayoutListConfiguration(appearance: .plain)
        list.headerMode = .supplementary
        return NSCollectionLayoutSection.list(using: list, layoutEnvironment: environment)
    }
}
```

- Map the section index to a section identifier through the data source (`sectionIdentifier(for:)`, iOS 15+). Do not switch on the raw index; it breaks as soon as a section is hidden.
- Read `environment.container.effectiveContentSize` and `environment.traitCollection` inside the provider to choose columns or sizes. Since iOS 18 traits read there are tracked, so the layout updates when they change.
- Return a new section each time. Do not cache `NSCollectionLayoutSection` objects across calls.
- Keep the provider cheap: arithmetic and object creation only. No model queries that touch disk.

## Sizes: items, groups and sections

Every item and group has an `NSCollectionLayoutSize` with a width and a height dimension.

| Dimension | Meaning | Use for |
|---|---|---|
| `.fractionalWidth(x)` / `.fractionalHeight(x)` | fraction of the containing group | columns, square tiles |
| `.absolute(x)` | fixed points | things that truly never change, such as a fixed avatar strip |
| `.estimated(x)` | starting guess; the cell decides | anything that holds text |
| `.uniformAcrossSiblings(estimate:)` (iOS 17+) | all items in the group share the tallest height | cards in a row that should line up |

Rule: any dimension that depends on text must be `.estimated`. A fixed height on a text cell clips at large text sizes.

Wrong: an absolute row height for text.

```swift
let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                    heightDimension: .absolute(60)))
```

Right:

```swift
let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                    heightDimension: .estimated(60)))
```

- Fractional sizes are relative to the containing group, not the screen. An item at `.fractionalWidth(0.5)` inside a group at `.fractionalWidth(0.8)` is 40% of the section width.
- If an item is `.estimated` in a dimension, its group must be `.estimated` in that dimension too, or the group cannot grow.
- `.uniformAcrossSiblings` has to measure every sibling in the group before it can place any of them. Use it for small groups (a row of two to four cards), not for a group with many items.
- Choose estimates near the typical real size. A wildly wrong estimate makes the scroll indicator jump and adds layout passes.

## Grids

Compute the column count from the container, not from the device.

```swift
static func gridSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let width = environment.container.effectiveContentSize.width
    let columns = max(2, Int(width / 180))
    let item = NSCollectionLayoutItem(layoutSize: .init(
        widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
        heightDimension: .estimated(220)))
    let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(220)),
        repeatingSubitem: item, count: columns)
    group.interItemSpacing = .fixed(8)
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsetsReference = .layoutMargins
    return section
}
```

- Use `NSCollectionLayoutGroup.horizontal(layoutSize:repeatingSubitem:count:)` (iOS 16+) for a fixed number of columns. The older `subitem:count:` form is deprecated.
- Spacing: `interItemSpacing` on the group, `interGroupSpacing` on the section. Avoid `contentInsets` on items to make gaps; they shrink the item instead of spacing it.
- `contentInsetsReference = .layoutMargins` or `.readableContent` keeps the grid aligned with the rest of the screen on wide windows.
- Square tiles: item `.fractionalWidth(1/n)` and group height `.fractionalWidth(1/n)` (fraction of the group width works for the height too).

## Horizontal rows inside a vertical list

Wrong: a collection view inside a cell.

```swift
final class CarouselCell: UICollectionViewCell {
    let innerCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
}
```

Right: one collection view, with a section that scrolls on the other axis.

```swift
let section = NSCollectionLayoutSection(group: group)
section.orthogonalScrollingBehavior = .groupPagingCentered
section.interGroupSpacing = 12
```

Nested collection views duplicate reuse, prefetching and focus, and their scroll positions are lost when the outer cell is reused. Orthogonal sections keep one data source and one set of cells.

- Behaviours: `.continuous`, `.continuousGroupLeadingBoundary`, `.paging`, `.groupPaging`, `.groupPagingCentered`.
- `orthogonalScrollingProperties` (iOS 17+) sets deceleration rate and bounce for that section.
- To react to orthogonal scrolling (a page indicator), use the section's `visibleItemsInvalidationHandler`; it receives the visible items and the scroll offset.

## Headers, footers, badges and decorations

- Boundary supplementary items (`NSCollectionLayoutBoundarySupplementaryItem`) are section headers and footers. Set `pinToVisibleBounds = true` for sticky headers.
- Item supplementary items (`NSCollectionLayoutSupplementaryItem` with an `NSCollectionLayoutAnchor`) put badges on items.
- Decoration items (`NSCollectionLayoutDecorationItem.background(elementKind:)`) draw a section background. Register the decoration view class on the layout with `register(_:forDecorationViewOfKind:)`.
- Give each element kind a constant string, and use the same constant in the layout and in the supplementary registration.

## Layout configuration

`UICollectionViewCompositionalLayoutConfiguration` holds settings for the whole layout: `scrollDirection`, `interSectionSpacing`, global boundary supplementary items, and `contentInsetsReference`.

## Visible-items effects

`section.visibleItemsInvalidationHandler = { items, offset, environment in ... }` lets you change `transform`, `alpha` or `zIndex` of visible items as the section scrolls. It runs every frame during scrolling: keep it to arithmetic on the items you receive. Never query the model or the data source there.

## Self-sizing

Self-sizing is the default for estimated dimensions. For it to work:

1. The dimension is `.estimated` on the item and its group.
2. The cell's content is constrained to all four edges of `contentView` (or its `layoutMarginsGuide`) with an unbroken vertical chain.
3. Multi-line labels have `numberOfLines = 0`. Do not set `preferredMaxLayoutWidth` in cells.
4. `collectionView.selfSizingInvalidation` stays `.enabled` (the default since iOS 16), or `.enabledIncludingConstraints` when constraint changes inside the cell should resize it.

With self-sizing invalidation on, a cell whose content changes size (expanded text, an image that loaded) calls `invalidateIntrinsicContentSize()` on the changed view, or on the cell, and the layout resizes it, animated if inside an animation block. Without it, reconfigure the item through the data source.

Wrong: measuring cells yourself.

```swift
let sizingCell = MessageCell()
sizingCell.configure(with: message)
let height = sizingCell.systemLayoutSizeFitting(CGSize(width: width, height: 0)).height
```

Right: an estimated height and complete constraints; the layout measures.

- If an image's aspect ratio is known from metadata, add an aspect-ratio constraint up front so the cell does not jump when the image arrives.
- A known constant height (a fixed-height row of icons) can be `.absolute`; it skips measuring. Use it for truly fixed rows, never to hide a constraint bug.
- `UICollectionLayoutListConfiguration` lists self-size by default.

## Changing the layout

- To switch between two layouts (list and grid), call `collectionView.setCollectionViewLayout(_:animated:)`. Keep the data source and the snapshot as they are.
- To re-run the section provider without changing data (a setting changed how many columns to show), call `collectionView.collectionViewLayout.invalidateLayout()`. Prefer reading a trait inside the provider so the change happens on its own.

## Table views

`UITableView` is not deprecated and stays fine for existing screens. The same rules apply:

- `UITableViewDiffableDataSource` instead of index-path bookkeeping;
- content configurations through `cell.defaultContentConfiguration()`, never `textLabel` or `detailTextLabel` (see `deprecated-apis.md`);
- self-sizing rows with `rowHeight = UITableView.automaticDimension` and a realistic `estimatedRowHeight`;
- `reconfigureRows(at:)` or snapshot `reconfigureItems(_:)` to refresh content.

Do not migrate a working table view to a collection view as a side task. Migrate when the screen needs something a table view cannot do (grids, orthogonal sections) or when asked.
