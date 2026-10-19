# Interactions: menus, swipes, drag and drop, pointer, keyboard, haptics

## Context menus in collection views

Use the delegate methods that take a set of index paths (iOS 16+). They support multiple selection.

```objc
- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView
    contextMenuConfigurationForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                                           point:(CGPoint)point {
    NSMutableArray<NSUUID *> *ids = [NSMutableArray array];
    for (NSIndexPath *indexPath in indexPaths) {
        NSUUID *itemID = [self.dataSource itemIdentifierForIndexPath:indexPath];
        if (itemID) { [ids addObject:itemID]; }
    }
    if (ids.count == 0) { return nil; }
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        UIAction *copy = [UIAction actionWithTitle:NSLocalizedString(@"Copy", @"Menu action")
                                             image:[UIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [weakSelf copyItems:ids]; }];
        UIAction *delete = [UIAction actionWithTitle:NSLocalizedString(@"Delete", @"Menu action")
                                               image:[UIImage systemImageNamed:@"trash"]
                                          identifier:nil
                                             handler:^(__kindof UIAction *action) { [weakSelf deleteItems:ids]; }];
        delete.attributes = UIMenuElementAttributesDestructive;
        return [UIMenu menuWithChildren:@[copy, delete]];
    }];
}
```

- Capture identifiers, never index paths; the list can change while the menu is open. Capture `weakSelf`, not `self`: the configuration outlives the call.
- Build the menu lazily in the action provider. `UIDeferredMenuElement` loads items that need async work; `+elementWithUncachedProvider:` reloads them each time.
- Customize the lifted preview with `collectionView:contextMenuConfiguration:highlightPreviewForItemAtIndexPath:` and `...dismissalPreviewForItemAtIndexPath:`, returning a `UITargetedPreview` with `UIPreviewParameters` (a `visiblePath` for rounded or bubble-shaped cells).
- For views that are not cells, add a `UIContextMenuInteraction`. Buttons show menus with `button.menu` and `showsMenuAsPrimaryAction = YES`.
- The same menu appears on secondary click with a pointer and on Mac, so it doubles as the right-click menu.
- `UIMenuOptions`: `UIMenuOptionsDisplayInline` for a section with separators, `UIMenuOptionsSingleSelection` for a picker, `UIMenuOptionsDisplayAsPalette` for a row of small items. `UIMenuElementAttributesKeepsMenuPresented` keeps the menu open after a toggle.

Wrong: actions that recompute from an index path later.

```objc
UIAction *archive = [UIAction actionWithTitle:@"Archive" image:nil identifier:nil
                                      handler:^(__kindof UIAction *a) { [self archive:self.items[indexPath.item]]; }];
```

Right: resolve once, capture the IDs and `weakSelf`.

## Menus on buttons and bars

- `+[UIButton buttonWithConfiguration:primaryAction:]`, `menu`, `showsMenuAsPrimaryAction`, and `changesSelectionAsPrimaryAction = YES` for a pop-up picker button.
- `-[UIBarButtonItem initWithPrimaryAction:menu:]`; a bar item with both a primary action and a menu shows the menu on long press.
- Pull-down and pop-up menus replace action sheets for choices attached to a control.

## Edit menus for custom views

For custom views that offer Copy, Paste or commands on a selection, use `UIEditMenuInteraction` (iOS 16+). `UIMenuController` is deprecated.

```objc
self.editMenu = [[UIEditMenuInteraction alloc] initWithDelegate:self];     // the view retains its interactions
[self.canvas addInteraction:self.editMenu];

- (void)showMenuAtPoint:(CGPoint)point {
    UIEditMenuConfiguration *config = [UIEditMenuConfiguration configurationWithIdentifier:nil sourcePoint:point];
    [self.editMenu presentEditMenuWithConfiguration:config];
}

- (UIMenu *)editMenuInteraction:(UIEditMenuInteraction *)interaction
           menuForConfiguration:(UIEditMenuConfiguration *)configuration
               suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    __weak typeof(self) weakSelf = self;
    UIAction *duplicate = [UIAction actionWithTitle:NSLocalizedString(@"Duplicate", @"Edit menu action")
                                              image:nil identifier:nil
                                            handler:^(__kindof UIAction *a) { [weakSelf duplicate]; }];
    return [UIMenu menuWithChildren:[suggestedActions arrayByAddingObject:duplicate]];
}
```

The interaction's delegate is weak. Standard commands (copy, paste, select all) come from the responder chain: override `-canPerformAction:withSender:` and implement `-copy:` on the responder. Text view menus are in `text.md`.

## Swipe actions

With list layouts, set `leadingSwipeActionsConfigurationProvider` and `trailingSwipeActionsConfigurationProvider` on `UICollectionLayoutListConfiguration`. Return a `UISwipeActionsConfiguration` with `UIContextualAction`s, and call the completion handler with `YES` when done. Resolve the item from the data source inside the provider.

```objc
__weak typeof(self) weakSelf = self;
config.trailingSwipeActionsConfigurationProvider = ^UISwipeActionsConfiguration * _Nullable(NSIndexPath *indexPath) {
    NSUUID *itemID = [weakSelf.dataSource itemIdentifierForIndexPath:indexPath];
    if (!itemID) { return nil; }
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
        title:NSLocalizedString(@"Delete", @"Swipe action")
        handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf deleteItems:@[itemID]];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
};
```

Every swipe action must also be in the context menu and in `accessibilityCustomActions`, because swipes are not discoverable.

## Drag and drop

- Collection views: set `dragDelegate` and `dropDelegate` (both weak). Return `UIDragItem`s with `NSItemProvider`s from `collectionView:itemsForBeginningDragSession:atIndexPath:`. `dragInteractionEnabled = YES` on iPhone (on by default on iPad).
- Reorder within a diffable data source with `reorderingHandlers` (see `diffable-data.md`), not the drop delegate.
- Any view: `UIDragInteraction` and `UIDropInteraction`.
- Load dropped data asynchronously from the item provider (`-loadObjectOfClass:completionHandler:`, `-loadFileRepresentationForTypeIdentifier:completionHandler:`); never block waiting, and hop to the main queue before updating UI.
- Put the local model object in `UIDragItem.localObject` so drops inside the app skip serialization.
- Keep the drag delegate's begin methods free of UI work that assumes a finger on screen; the system can start a drag session without a direct touch on recent releases (see the whats-new skill).

## Pointer and hover

- Buttons and bar items have pointer effects. For custom views, add a `UIPointerInteraction` and return a `UIPointerStyle` (`+styleWithEffect:shape:` with `+[UIPointerEffect effectWithPreview:]`, or a lift effect).
- `hoverStyle` (iOS 17+) on a view gives the hover highlight on iPad with a pointer and on visionOS.
- `UIHoverGestureRecognizer` for custom hover behavior.
- Tool tips: `UIToolTipInteraction` (iOS 15+), or `toolTip` on controls.

## Keyboard

- Add commands to the main menu with `-buildMenuWithBuilder:` on the app delegate or a responder, so they appear in the iPad shortcut overlay and the Mac menu bar. A `UIKeyCommand` there needs a title and a discoverability title.
- Per-screen shortcuts: `keyCommands` on the responder that handles them.
- `wantsPriorityOverSystemBehavior = YES` only when a shortcut must beat a text field's default (rare).
- Focus: collection views support arrow-key navigation with `allowsFocus = YES`; `selectionFollowsFocus` where arrows should select. Custom focusable views override `canBecomeFocused` and use `focusGroupIdentifier`.
- Return and Escape: put a `UIKeyCommand` with `UIKeyInputEscape` on sheets and popovers so Escape dismisses.

## Gestures

- Prefer controls and built-in interactions to raw gesture recognizers.
- Resolve conflicts with `-requireGestureRecognizerToFail:` or the delegate's `gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:`, not with delays.
- A recognizer's target is not retained: keep the target alive, and remove the recognizer from the view when the target goes away if it outlives it.
- A long press recognizer on a cell fights the context menu; use the context menu.
- Hit targets at least 44 by 44 points. Grow a small control's target by overriding `-pointInside:withEvent:`, not by making it look bigger.

## Haptics

Use `UIFeedbackGenerator` subclasses (`UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator`). On iOS 17.5+ create them with `-initWithView:` and trigger with the location variants (`-impactOccurredAtLocation:`), so feedback works with a pointer and on other inputs. Call `-prepare` just before an expected event. Standard controls already play haptics; do not double them.

## Review checks

1. Menus capture identifiers and `weakSelf`.
2. Swipe actions duplicated in context menus and accessibility actions.
3. Drops load asynchronously.
4. Keyboard commands in the main menu with titles.
5. Haptic generators made with a view on iOS 17.5+.
