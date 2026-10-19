# Interactions: menus, swipes, drag and drop, pointer, keyboard, haptics

## Context menus in collection views

Use the delegate methods that take a set of index paths (iOS 16+). They support multiple selection.

```swift
func collectionView(_ collectionView: UICollectionView,
                    contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                    point: CGPoint) -> UIContextMenuConfiguration? {
    let ids = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
    guard !ids.isEmpty else { return nil }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
        guard let self else { return nil }
        let copy = UIAction(title: String(localized: "Copy"), image: UIImage(systemName: "doc.on.doc")) { _ in
            self.copy(ids)
        }
        let delete = UIAction(title: String(localized: "Delete"), image: UIImage(systemName: "trash"),
                              attributes: .destructive) { _ in
            self.delete(ids)
        }
        return UIMenu(children: [copy, delete])
    }
}
```

- Capture identifiers, never index paths; the list can change while the menu is open.
- Build the menu lazily in the action provider. `UIDeferredMenuElement` loads items that need async work; `.uncached` reloads them each time.
- Customize the lifted preview with `collectionView(_:contextMenuConfiguration:highlightPreviewForItemAt:)` and `...dismissalPreviewForItemAt:`, returning a `UITargetedPreview` with `UIPreviewParameters` (a `visiblePath` for rounded or bubble-shaped cells).
- For views that are not cells, add a `UIContextMenuInteraction`. Buttons show menus with `button.menu` and `showsMenuAsPrimaryAction = true`.
- The same menu appears on secondary click with a pointer and on Mac, so it doubles as the right-click menu.
- `UIMenu.Options`: `.displayInline` for a section with separators, `.singleSelection` for a picker, `.displayAsPalette` for a row of small items. `UIMenuElement.Attributes.keepsMenuPresented` keeps the menu open after a toggle.

Wrong: actions that recompute from an index path later.

```swift
UIAction(title: "Archive") { _ in self.archive(self.items[indexPath.item]) }
```

Right: resolve once, capture the IDs.

## Menus on buttons and bars

- `UIButton(configuration:primaryAction:)`, `menu`, `showsMenuAsPrimaryAction`, and `changesSelectionAsPrimaryAction = true` for a pop-up picker button.
- `UIBarButtonItem(title:image:primaryAction:menu:)`; a bar item with both a primary action and a menu shows the menu on long press.
- Pull-down and pop-up menus replace action sheets for choices attached to a control.

## Edit menus for custom views

For custom views that offer Copy, Paste or commands on a selection, use `UIEditMenuInteraction` (iOS 16+). `UIMenuController` is deprecated.

```swift
let editMenu = UIEditMenuInteraction(delegate: self)
canvas.addInteraction(editMenu)

func showMenu(at point: CGPoint) {
    editMenu.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point))
}

func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                         menuFor configuration: UIEditMenuConfiguration,
                         suggestedActions: [UIMenuElement]) -> UIMenu? {
    UIMenu(children: suggestedActions + [UIAction(title: String(localized: "Duplicate")) { [weak self] _ in self?.duplicate() }])
}
```

Standard commands (copy, paste, select all) come from the responder chain: override `canPerformAction(_:withSender:)` and implement `copy(_:)` on the responder. Text view menus are in `text.md`.

## Swipe actions

With list layouts, set `leadingSwipeActionsConfigurationProvider` and `trailingSwipeActionsConfigurationProvider` on `UICollectionLayoutListConfiguration`. Return `UISwipeActionsConfiguration` with `UIContextualAction`s, and call the completion handler with `true` when done. Resolve the item from the data source inside the provider.

```swift
config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
    guard let self, let id = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
    let delete = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { _, _, done in
        self.delete([id])
        done(true)
    }
    return UISwipeActionsConfiguration(actions: [delete])
}
```

Every swipe action must also be in the context menu and in `accessibilityCustomActions`, because swipes are not discoverable.

## Drag and drop

- Collection views: set `dragDelegate` and `dropDelegate`. Return `UIDragItem`s with `NSItemProvider`s from `collectionView(_:itemsForBeginning:at:)`. `dragInteractionEnabled = true` on iPhone (on by default on iPad).
- Reorder within a diffable data source with `reorderingHandlers` (see `diffable-data.md`), not the drop delegate.
- Any view: `UIDragInteraction` and `UIDropInteraction`.
- Load dropped data asynchronously from the item provider (`loadObject(ofClass:)`, `loadFileRepresentation(forTypeIdentifier:)`); never block waiting.
- Put the local model object in `UIDragItem.localObject` so drops inside the app skip serialization.
- Keep the drag delegate's begin methods free of UI work that assumes a finger on screen; the system can start a drag session without a direct touch on recent releases (see the whats-new skill).

## Pointer and hover

- Buttons and bar items have pointer effects. For custom views, add `UIPointerInteraction` and return a `UIPointerStyle` (`.init(effect: .highlight(targetedPreview))` or `.lift`).
- `hoverStyle` (iOS 17+) on a view gives the hover highlight on iPad with a pointer and on visionOS.
- `UIHoverGestureRecognizer` for custom hover behavior.
- Tool tips: `UIToolTipInteraction` (iOS 15+), or `toolTip` on controls.

## Keyboard

- Add commands to the main menu with `buildMenu(with:)` on the app delegate or a responder, so they appear in the iPad shortcut overlay and the Mac menu bar. A `UIKeyCommand` there needs a title and a discoverability title.
- Per-screen shortcuts: `keyCommands` on the responder that handles them.
- `wantsPriorityOverSystemBehavior = true` only when a shortcut must beat a text field's default (rare).
- Focus: collection views support arrow-key navigation with `allowsFocus = true`; `selectionFollowsFocus` where arrows should select. Custom focusable views override `canBecomeFocused` and use `focusGroupIdentifier`.
- Return and Escape: put a `UIKeyCommand` with `UIKeyCommand.inputEscape` on sheets and popovers so Escape dismisses.

## Gestures

- Prefer controls and built-in interactions to raw gesture recognizers.
- Resolve conflicts with `require(toFail:)` or the delegate's `shouldRecognizeSimultaneouslyWith`, not with delays.
- A long press recognizer on a cell fights the context menu; use the context menu.
- Hit targets at least 44 by 44 points. Grow a small control's target by overriding `point(inside:with:)`, not by making it look bigger.

## Haptics

Use `UIFeedbackGenerator` subclasses (`UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator`). On iOS 17.5+ create them with `init(view:)` and trigger with the `at:` location variants (`impactOccurred(at:)`), so feedback works with a pointer and on other inputs. Call `prepare()` just before an expected event. Standard controls already play haptics; do not double them.

## Review checks

1. Menus capture identifiers.
2. Swipe actions duplicated in context menus and accessibility actions.
3. Drops load asynchronously.
4. Keyboard commands in the main menu with titles.
5. Haptic generators made with a view on iOS 17.5+.
