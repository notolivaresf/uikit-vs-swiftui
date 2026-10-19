# Cells: registrations, configurations and reuse

A cell is a reusable view that shows one item. Its job is to look up the item, set a few properties, and react to its state (selected, highlighted, editing, disabled). Everything here keeps that job small and reuse-safe.

## Registrations

Create a `UICollectionView.CellRegistration` once, and dequeue with it in the cell provider.

Wrong: string identifiers, casts, and a registration made inside the provider.

```swift
collectionView.register(MessageCell.self, forCellWithReuseIdentifier: "Message")
dataSource = .init(collectionView: collectionView) { cv, indexPath, id in
    let cell = cv.dequeueReusableCell(withReuseIdentifier: "Message", for: indexPath) as! MessageCell
    return cell
}
```

```swift
dataSource = .init(collectionView: collectionView) { cv, indexPath, id in
    let registration = UICollectionView.CellRegistration<UICollectionViewListCell, MessageID> { _, _, _ in }
    return cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)   // raises an exception
}
```

Right:

```swift
let messageCell = UICollectionView.CellRegistration<UICollectionViewListCell, MessageID> { [weak self] cell, _, id in
    guard let self, let message = self.store[id] else { return }
    var content = cell.defaultContentConfiguration()
    content.text = message.sender
    content.secondaryText = message.preview
    cell.contentConfiguration = content
    cell.accessories = message.isUnread ? [.customView(configuration: self.unreadDot)] : []
}

dataSource = .init(collectionView: collectionView) { cv, indexPath, id in
    cv.dequeueConfiguredReusableCell(using: messageCell, for: indexPath, item: id)
}
```

- The registration's item type can be the identifier. Look up the model inside the handler.
- A registration made inside the cell provider is a new registration per call; UIKit raises an exception for it. Make registrations before the data source, as local constants captured by the provider, or as stored properties.
- Registrations capture what their handler uses. Capture `[weak self]` when the handler reads the controller, since the data source holds the registration for its lifetime.
- One registration per cell kind. Choose the registration in the provider by switching on the identifier (an enum with associated IDs) or on the section.
- Supplementary views use `UICollectionView.SupplementaryRegistration` with the element kind, and `dequeueConfiguredReusableSupplementary(using:for:)` in `dataSource.supplementaryViewProvider`.

## Content configurations

A content configuration is a value that describes what a cell shows. The cell turns it into views.

- `UIListContentConfiguration` covers most rows: image, text, secondary text, and their properties. Start from `cell.defaultContentConfiguration()`, which matches the cell's list style. Other starting points: `.cell()`, `.subtitleCell()`, `.valueCell()`, `.header()` and `.footer()` (iOS 18+), `.prominentInsetGroupedHeader()`.
- Change appearance through the configuration's properties (`textProperties.font`, `textProperties.numberOfLines`, `imageProperties.tintColor`, `directionalLayoutMargins`, `imageToTextPadding`) instead of reaching into subviews.
- Assign a new configuration on every configuration pass. Do not keep a configuration from a previous item.

### Custom content configurations

When the list configuration is not enough, write a configuration and a content view.

```swift
struct MessageContent: UIContentConfiguration, Hashable {
    var sender = ""
    var body = ""
    var isOutgoing = false

    func makeContentView() -> any UIView & UIContentView { MessageContentView(configuration: self) }
    func updated(for state: any UIConfigurationState) -> Self { self }
}

final class MessageContentView: UIView, UIContentView {
    private let senderLabel = UILabel()
    private let bodyLabel = UILabel()
    private var current: MessageContent

    var configuration: any UIContentConfiguration {
        get { current }
        set {
            guard let new = newValue as? MessageContent, new != current else { return }
            current = new
            apply(new)
        }
    }

    init(configuration: MessageContent) {
        current = configuration
        super.init(frame: .zero)
        buildHierarchy()           // subviews and constraints, once
        apply(configuration)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func apply(_ c: MessageContent) {
        senderLabel.text = c.sender
        bodyLabel.text = c.body
    }
}
```

- Make the configuration `Hashable` and skip the update when it is equal to the current one; configuration runs often.
- Build subviews and constraints once in `init`. `apply` only sets properties and constraint constants.
- `updated(for:)` returns a copy adjusted for the state (for example a different text color when selected). Keep it pure.
- Content views are reused across items. Everything `apply` touches must be set every time, or old values leak to the next item.

## Backgrounds

Use `UIBackgroundConfiguration` for fills, strokes, corner radius and insets, not a custom `backgroundView` you style by hand.

```swift
var background = UIBackgroundConfiguration.listCell()      // iOS 18+
background.backgroundColor = .secondarySystemGroupedBackground
background.cornerRadius = 12
cell.backgroundConfiguration = background
```

- iOS 18 replaced the per-style factories (`listPlainCell()`, `listGroupedCell()`, `listSidebarCell()`) with `listCell()`, `listHeader()` and `listFooter()`, which adapt to the list they are in. `.clear()` gives no background.
- Background configurations have their own state handling: `backgroundColorTransformer` and `updated(for:)`.

## Configuration state

Cells and content react to state through one path:

```swift
cell.configurationUpdateHandler = { cell, state in
    var content = UIListContentConfiguration.cell().updated(for: state)
    content.text = title
    content.textProperties.color = state.isDisabled ? .secondaryLabel : .label
    cell.contentConfiguration = content

    var background = UIBackgroundConfiguration.listCell().updated(for: state)
    if state.isSelected { background.backgroundColor = .tintColor.withAlphaComponent(0.15) }
    cell.backgroundConfiguration = background
}
```

- The state has `isSelected`, `isHighlighted`, `isFocused`, `isDisabled`, `isEditing`, `isExpanded`, `isSwiped`, `isReordering`, `cellDropState` and `traitCollection`.
- Do not override `isSelected` or `isHighlighted` setters to restyle a cell. Use the handler, or override `updateConfiguration(using:)` in a subclass.
- Custom state: extend `UIConfigurationStateCustomKey` and override `configurationState` in the cell subclass to add your values; call `setNeedsUpdateConfiguration()` when they change.
- Traits read inside `updateConfiguration(using:)` or the handler are tracked on iOS 18+, so the cell updates on its own when those traits change.

## Accessories

List cells take `accessories`: `.disclosureIndicator()`, `.checkmark()`, `.delete()`, `.reorder()`, `.outlineDisclosure()`, `.label(text:)`, `.detail()`, `.multiselect()`, `.popUpMenu(_:)` and `.customView(configuration:)`. Each has display options (`displayed: .always`, `.whenEditing`, `.whenNotEditing`). Use them instead of adding buttons to the content view, so editing mode, layout and accessibility stay consistent.

## Reuse safety

A dequeued cell may have shown any other item a moment ago.

- Set every property the configuration path touches, every time. A field set only "if present" keeps the old item's value when absent.
- Cancel per-cell work in `prepareForReuse()` (always call `super`) and re-check identity when async work finishes. See `list-performance.md` for the image pattern.
- Do not store the item's index path on the cell. If the cell needs to act for its item (a button inside it), store the identifier, or send the action up with the cell and resolve it through `collectionView.indexPath(for:)` then the data source.
- Never hold a strong reference to a cell outside the collection view. Ask for the visible cell with `collectionView.cellForItem(at:)` when you need it, and handle `nil`.

## Buttons and controls inside cells

Wrong: a closure stored on the cell that captures an index path.

```swift
cell.onLike = { self.like(at: indexPath) }
```

Right: capture the identifier, weakly capture the controller, and set the closure on every configuration.

```swift
let likeAction = UIAction(identifier: .init("like")) { [weak self] _ in self?.like(id) }
cell.likeButton.addAction(likeAction, for: .primaryActionTriggered)
```

Actions added on each configuration stack up unless they share an identifier: `addAction` replaces an existing action with the same identifier. Without one, call `removeAction(identifiedBy:for:)` first.

## Empty and loading states

Show empty, loading and error states with `UIContentUnavailableConfiguration` (iOS 17+), not a label laid over the collection view.

```swift
override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
    if isLoading {
        contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
    } else if items.isEmpty {
        var config = UIContentUnavailableConfiguration.empty()
        config.image = UIImage(systemName: "tray")
        config.text = String(localized: "No Messages")
        config.secondaryText = String(localized: "New messages appear here.")
        contentUnavailableConfiguration = config
    } else {
        contentUnavailableConfiguration = nil
    }
}
```

- Call `setNeedsUpdateContentUnavailableConfiguration()` when the inputs change (loading finished, items became empty).
- `.search()` is the standard "no results" for a search query.
- Add a button through `config.button` and `config.buttonProperties.primaryAction` for "Try Again".

## Headers and footers

- Supplementary registrations configure headers the same way as cells: `UIListContentConfiguration.header()` on a `UICollectionViewListCell`, or a custom content configuration.
- With `headerMode = .firstItemInSection`, the header is an ordinary item; give it its own identifier case and registration, and use the `.outlineDisclosure()` accessory for expandable sections.

## Review checks

1. Registrations created once, never in the provider.
2. Every configured property set on every pass.
3. State changes go through the update handler or `updateConfiguration(using:)`.
4. No index paths stored on cells or in their closures.
5. Empty and loading states use `UIContentUnavailableConfiguration`.
