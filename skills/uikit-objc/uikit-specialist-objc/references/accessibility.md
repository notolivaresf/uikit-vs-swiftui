# Accessibility

Accessibility in UIKit is mostly free when you use standard controls, text styles and list configurations. Custom views need labels, traits, actions and order set on purpose.

## Elements, labels and traits

- Every interactive element needs an `accessibilityLabel`: a short noun or verb phrase, no control type ("Delete", not "Delete button"). A button configuration with a title uses the title.
- Image-only buttons and bar items always need a label.
- `accessibilityValue` for the current value of a control (a slider's "40 percent", a toggle's state if custom).
- `accessibilityHint` only when the result of the action is not obvious; hints can be turned off.
- Traits are a bitmask on `accessibilityTraits`: `UIAccessibilityTraitButton`, `...Link`, `...Header`, `...Selected`, `...NotEnabled`, `...Adjustable`, `...Image`, `...UpdatesFrequently`, `...ToggleButton` (iOS 17+). Combine them with `|`, and add to the existing value (`view.accessibilityTraits |= UIAccessibilityTraitHeader`) so you do not erase the default traits. Mark section titles `...Header` so the rotor can jump between them.
- `accessibilityUserInputLabels` gives Voice Control short alternative names for long labels.
- Strings shown to VoiceOver are user-visible text: localize them (`NSLocalizedString`), and declare string properties `copy`.

Wrong:

```objc
UIButton *like = [UIButton buttonWithType:UIButtonTypeSystem];
[like setImage:[UIImage systemImageNamed:@"heart"] forState:UIControlStateNormal];
```

Right:

```objc
UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
config.image = [UIImage systemImageNamed:@"heart"];
UIButton *like = [UIButton buttonWithConfiguration:config primaryAction:nil];
like.accessibilityLabel = NSLocalizedString(@"Like", @"Accessibility label for the like button");
```

## Grouping cell content

A cell that reads as one thing should be one element.

```objc
cell.isAccessibilityElement = YES;
cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", message.sender, message.preview];
cell.accessibilityValue = message.isUnread ? NSLocalizedString(@"Unread", @"Message state") : nil;
```

- List content configurations compose the label for you; custom content views must do it.
- Set labels in the configuration path, so reused cells never keep another item's label.
- iOS 17+: the block properties (`accessibilityLabelBlock`, `accessibilityValueBlock` and friends) compute values only when assistive technology asks, which avoids building strings for every cell during scrolling. They are `copy` blocks stored on the view: capture `weakSelf` or the item's ID, never the cell.

## Custom actions

Expose secondary actions as `accessibilityCustomActions` so VoiceOver and Switch Control users do not need swipes or long presses.

```objc
__weak typeof(self) weakSelf = self;
cell.accessibilityCustomActions = @[
    [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"Reply", @"Action")
        actionHandler:^BOOL(UIAccessibilityCustomAction *action) { [weakSelf replyToItem:itemID]; return YES; }],
    [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"Delete", @"Action")
        actionHandler:^BOOL(UIAccessibilityCustomAction *action) { [weakSelf deleteItems:@[itemID]]; return YES; }],
];
```

Every swipe action and every context menu action that matters belongs here too.

## Adjustable and custom controls

- A custom slider or stepper: add `UIAccessibilityTraitAdjustable` and implement `-accessibilityIncrement` and `-accessibilityDecrement`, updating `accessibilityValue`.
- A custom control that draws its own content: subclass `UIControl` and send actions, so it takes part in the responder chain and accessibility like a system control.
- `-accessibilityActivate` (return `YES` when handled) for a non-standard primary action when activated.
- `accessibilityRespondsToUserInteraction` tells Voice Control an element is interactive when that is not obvious from traits.

## Order and containers

- VoiceOver order follows the view hierarchy top-left to bottom-right. If the visual order differs, set `accessibilityElements` on the container in the order to read.
- `shouldGroupAccessibilityChildren = YES` keeps a container's children together during navigation.
- `accessibilityContainerType` (`UIAccessibilityContainerTypeList`, `...Landmark`, `...SemanticGroup`) helps navigation in complex screens.
- Hide decorative views with `isAccessibilityElement = NO` or `accessibilityElementsHidden = YES`.
- A modal custom view that covers the screen sets `accessibilityViewIsModal = YES` so VoiceOver ignores what is behind it.
- In Objective-C a property named `isAccessibilityElement` is accessed as `view.isAccessibilityElement` (the property keeps the "is" prefix); do not write `view.accessibilityElement`.

## Announcements and screen changes

- `UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, firstElement)` after a large change (new screen content without a navigation transition).
- `UIAccessibilityLayoutChangedNotification` after a partial change, pointing at the element to focus.
- `UIAccessibilityAnnouncementNotification` sparingly, for status the user would otherwise miss (an upload finished off screen). On iOS 17+ an attributed announcement can carry `UIAccessibilitySpeechAttributeQueueAnnouncement`.
- Post from the main thread.

## Settings to respect

| Setting | Read | React |
|---|---|---|
| Reduce Motion | `UIAccessibilityIsReduceMotionEnabled()` | fades instead of movement (see `animation.md`) |
| Reduce Transparency | `UIAccessibilityIsReduceTransparencyEnabled()` | opaque backgrounds for custom blurs |
| Increase Contrast | `traitCollection.accessibilityContrast` | asset colors with high-contrast variants |
| Bold Text | `traitCollection.legibilityWeight` | custom fonts pick a heavier weight |
| Button Shapes / Show Borders | `UIAccessibilityButtonShapesEnabled()` (replaced by `AXShowBordersEnabled` in iOS 26.1) | underline or outline custom text buttons |
| Differentiate Without Color | `UIAccessibilityShouldDifferentiateWithoutColor()` | add shapes or symbols to color-only status |

Each has a change notification (for example `UIAccessibilityReduceMotionStatusDidChangeNotification`). Observe with a block observer whose token you remove, or the selector form with `-removeObserver:` in `dealloc`. Trait-based settings update through trait tracking.

## Large content and text size

- Text sizes: see `text.md`. Layouts must work at the largest accessibility size.
- Bars and tab bars show the large content viewer on long press at accessibility sizes. Custom bar-like controls adopt `UILargeContentViewerInteraction` and set `showsLargeContentViewer`, `largeContentTitle` and `largeContentImage`.

## Hit targets

- At least 44 by 44 points for anything tappable.
- Grow the target with `-pointInside:withEvent:` or larger insets in the button configuration, not by enlarging the art.

## Testing

- Run the Accessibility Inspector's audit on each screen.
- XCTest: `[app performAccessibilityAuditWithAuditTypes:XCUIAccessibilityAuditTypeAll issueHandler:nil error:&error]` (iOS 17+) in UI tests catches missing labels, small targets, contrast and clipped text; `XCTAssertTrue(ok, ...)` on the result.
- Try the screen with VoiceOver on a device, with Voice Control, and at the largest text size.

## Review checks

1. Labels on every interactive element, set per configuration in cells.
2. Cells grouped into one element with a composed label.
3. Swipe and menu actions also exposed as custom actions.
4. Order and modal state correct in custom containers.
5. A UI test runs `performAccessibilityAuditWithAuditTypes:issueHandler:error:`.
