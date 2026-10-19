# Menus, Siri and drag and drop

## Fewer menu images by default

On iPadOS 27 and macOS 27, the menu bar and context menus show a reduced set of images: images set on menu elements are not displayed by default. UIKit still shows default images for some common system commands.

`UIMenuElement.preferredImageVisibility` (iOS 27, a `UIMenuElementImageVisibility`) sets the preference per element: `UIMenuElementImageVisibilityAutomatic`, `...Hidden` and `...Visible`. `UIMenu`, `UIAction`, `UICommand` and `UIKeyCommand` also have updated initializers that take it; read their iOS 27 declarations before using them, or just set the property.

```objc
__weak typeof(self) weakSelf = self;
UIAction *favorite = [UIAction actionWithTitle:NSLocalizedString(@"Favorite", @"Menu action")
                                         image:[UIImage systemImageNamed:@"star"]
                                    identifier:nil
                                       handler:^(__kindof UIAction *action) { [weakSelf toggleFavorite]; }];
if (@available(iOS 27.0, *)) {
    favorite.preferredImageVisibility = UIMenuElementImageVisibilityVisible;
}
```

When to force an image:

- The image carries meaning the title does not: a color swatch, a person's avatar, a status.
- A palette menu (`UIMenuOptionsDisplayAsPalette`) made of icons.

When to leave automatic:

- Ordinary commands (Copy, Share, Delete, Rename). Follow the system look and the Human Interface Guidelines; do not mark everything visible to bring the old look back.

Keep setting images anyway: they still show where the system displays them (on iPhone, on buttons with menus) and in accessibility.

## Ask Siri in menus

Menus in iOS 27 can show an Ask Siri item that starts a conversation with Siri about the current context. The system adds it when there is content relevant for Siri; you do not create it. To give Siri better context, annotate views with your App Entities through the App Intents view annotation API (an App Intents feature, outside UIKit; check whether it has an Objective-C declaration before using it from `.m` code).

## Drag sessions can start without a gesture

On iOS and iPadOS 27, Siri can load content from the drag interactions in your interface. When Apple Intelligence is invoked from a context menu, the system calls your `UIDragInteractionDelegate` methods to get the items. So a drag session may begin with no finger moving anything.

Wrong: UI side effects at session start.

```objc
- (void)dragInteraction:(UIDragInteraction *)interaction sessionWillBegin:(id<UIDragSession>)session {
    [UIView animateWithDuration:0.2 animations:^{ self.trashTarget.alpha = 1; }];   // shows even for Siri
    [self presentViewController:self.dropHelpSheet animated:YES completion:nil];     // modal UI from nowhere
}
```

Right: keep `sessionWillBegin:` free of animation and modal UI; show drag-only UI once the session moves.

```objc
- (void)dragInteraction:(UIDragInteraction *)interaction sessionWillBegin:(id<UIDragSession>)session {
    self.dragging = YES;       // state only
}

- (void)dragInteraction:(UIDragInteraction *)interaction sessionDidMove:(id<UIDragSession>)session {
    if (self.trashTargetShown) { return; }
    self.trashTargetShown = YES;
    [UIView animateWithDuration:0.2 animations:^{ self.trashTarget.alpha = 1; }];
}

- (void)dragInteraction:(UIDragInteraction *)interaction session:(id<UIDragSession>)session
       didEndWithOperation:(UIDropOperation)operation {
    self.dragging = NO;
    self.trashTargetShown = NO;
    self.trashTarget.alpha = 0;
}
```

Also make item loading work without visible UI: `dragInteraction:itemsForBeginningSession:` must return providers that load on demand, never data that depends on an on-screen state set up by the gesture. The same rule is the safe choice for collection and table view drag delegates' session-begin methods.

## Pointer drags: `allowsPointerDragBeforeLiftDelay`

`UIDragInteraction.allowsPointerDragBeforeLiftDelay` (iOS 27, `BOOL`) controls on its own when a pointer-started drag may begin, separate from touch. Use it in views full of gestures (a canvas, a timeline) where a pointer click-and-move should start a drag at once, or where it should wait so clicks and selection gestures win.

```objc
UIDragInteraction *drag = [[UIDragInteraction alloc] initWithDelegate:self];     // the delegate is weak
if (@available(iOS 27.0, *)) {
    drag.allowsPointerDragBeforeLiftDelay = YES;
}
[self.canvas addInteraction:drag];
```

Test with a trackpad and a mouse on iPad, and in Mac Catalyst.

## `UIMenuLeaf.subtitle`

Fixed in iOS 27: the `UIMenuLeaf` protocol now includes the `subtitle` property (`@property (nonatomic, copy, nullable) NSString *subtitle`) that `UIAction` and `UICommand` have had since iOS 16. Code generic over `id<UIMenuLeaf>` can read and set `subtitle` without casting.

## Checks

1. Menu images that carry meaning set visible; the rest left automatic.
2. No animation or modal UI in `sessionWillBegin:`.
3. Drag items load lazily from providers.
4. Pointer drag timing tested in gesture-heavy views.

<!-- sources: Objective-C declarations on Apple's pages for UIMenuElement preferredImageVisibility, UIMenuElementImageVisibility and its cases, UIDragInteraction allowsPointerDragBeforeLiftDelay, UIMenuLeaf subtitle; iOS 27 release notes; WWDC26 session 278. Drag delegate selectors checked against the iOS 26.4 SDK headers. -->
