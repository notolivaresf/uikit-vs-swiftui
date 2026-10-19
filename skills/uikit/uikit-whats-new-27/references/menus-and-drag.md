# Menus, Siri and drag and drop

## Fewer menu images by default

On iPadOS 27 and macOS 27, the menu bar and context menus show a reduced set of images: images set on menu elements are not displayed by default. UIKit still shows default images for some common system commands.

`UIMenuElement.preferredImageVisibility` (iOS 27) sets the preference per element. `UIMenuElement.ImageVisibility` has `.automatic`, `.hidden` and `.visible`. `UIMenu`, `UIAction`, `UICommand` and `UIKeyCommand` also have updated initializers that take it.

```swift
let favorite = UIAction(title: String(localized: "Favorite"),
                        image: UIImage(systemName: "star")) { [weak self] _ in self?.toggleFavorite() }
if #available(iOS 27, *) {
    favorite.preferredImageVisibility = .visible
}
```

When to force an image:

- The image carries meaning the title does not: a color swatch, a person's avatar, a status.
- A palette menu (`.displayAsPalette`) made of icons.

When to leave `.automatic`:

- Ordinary commands (Copy, Share, Delete, Rename). Follow the system look and the Human Interface Guidelines; do not mark everything `.visible` to bring the old look back.

Keep setting images anyway: they still show where the system displays them (on iPhone, on buttons with menus) and in accessibility.

## Ask Siri in menus

Menus in iOS 27 can show an Ask Siri item that starts a conversation with Siri about the current context. The system adds it when there is content relevant for Siri; you do not create it. To give Siri better context, annotate views with your App Entities through the App Intents view annotation API (an App Intents feature, outside UIKit).

## Drag sessions can start without a gesture

On iOS and iPadOS 27, Siri can load content from the drag interactions in your interface. When Apple Intelligence is invoked from a context menu, the system calls your `UIDragInteractionDelegate` methods to get the items. So a drag session may begin with no finger moving anything.

Wrong: UI side effects at session start.

```swift
func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession) {
    UIView.animate(withDuration: 0.2) { self.trashTarget.alpha = 1 }   // shows even for Siri
    present(dropHelpSheet, animated: true)                               // modal UI from nowhere
}
```

Right: keep `sessionWillBegin` free of animation and modal UI; show drag-only UI once the session moves.

```swift
func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession) {
    isDragging = true   // state only
}

func dragInteraction(_ interaction: UIDragInteraction, sessionDidMove session: UIDragSession) {
    guard !trashTargetShown else { return }
    trashTargetShown = true
    UIView.animate(withDuration: 0.2) { self.trashTarget.alpha = 1 }
}

func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession,
                     didEndWith operation: UIDropOperation) {
    isDragging = false
    trashTargetShown = false
    trashTarget.alpha = 0
}
```

Also make item loading work without visible UI: `itemsForBeginning` must return providers that load on demand, never data that depends on an on-screen state set up by the gesture. The same rule is the safe choice for collection and table view drag delegates' session-begin methods.

## Pointer drags: `allowsPointerDragBeforeLiftDelay`

`UIDragInteraction.allowsPointerDragBeforeLiftDelay: Bool` (iOS 27) controls on its own when a pointer-started drag may begin, separate from touch. Use it in views full of gestures (a canvas, a timeline) where a pointer click-and-move should start a drag at once, or where it should wait so clicks and selection gestures win.

```swift
let drag = UIDragInteraction(delegate: self)
if #available(iOS 27, *) {
    drag.allowsPointerDragBeforeLiftDelay = true
}
canvas.addInteraction(drag)
```

Test with a trackpad and a mouse on iPad, and in Mac Catalyst.

## `UIMenuLeaf.subtitle`

Fixed in iOS 27: the `UIMenuLeaf` protocol now includes the `subtitle` property that `UIAction` and `UICommand` have had since iOS 16. Code generic over `UIMenuLeaf` can read and set `subtitle` without casting.

## Checks

1. Menu images that carry meaning set `.visible`; the rest left `.automatic`.
2. No animation or modal UI in drag `sessionWillBegin`.
3. Drag items load lazily from providers.
4. Pointer drag timing tested in gesture-heavy views.

<!-- sources: https://developer.apple.com/documentation/uikit/uimenuelement/preferredimagevisibility, https://developer.apple.com/documentation/uikit/uimenuelement/imagevisibility, https://developer.apple.com/documentation/uikit/uidraginteraction/allowspointerdragbeforeliftdelay, https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes, https://developer.apple.com/videos/play/wwdc2026/278/ -->
