# Accessibility

Accessibility in UIKit is mostly free when you use standard controls, text styles and list configurations. Custom views need labels, traits, actions and order set on purpose.

## Elements, labels and traits

- Every interactive element needs an `accessibilityLabel`: a short noun or verb phrase, no control type ("Delete", not "Delete button"). A button configuration with a title uses the title.
- Image-only buttons and bar items always need a label.
- `accessibilityValue` for the current value of a control (a slider's "40 percent", a toggle's state if custom).
- `accessibilityHint` only when the result of the action is not obvious; hints can be turned off.
- Traits: `.button`, `.link`, `.header`, `.selected`, `.notEnabled`, `.adjustable`, `.image`, `.updatesFrequently`, `.toggleButton` (iOS 17+). Mark section titles `.header` so the rotor can jump between them.
- `accessibilityUserInputLabels` gives Voice Control short alternative names for long labels.

Wrong:

```swift
let like = UIButton(type: .system)
like.setImage(UIImage(systemName: "heart"), for: .normal)
```

Right:

```swift
var config = UIButton.Configuration.plain()
config.image = UIImage(systemName: "heart")
let like = UIButton(configuration: config)
like.accessibilityLabel = String(localized: "Like")
```

## Grouping cell content

A cell that reads as one thing should be one element.

```swift
cell.isAccessibilityElement = true
cell.accessibilityLabel = "\(message.sender), \(message.preview)"
cell.accessibilityValue = message.isUnread ? String(localized: "Unread") : nil
```

- List content configurations compose the label for you; custom content views must do it.
- Set labels in the configuration path, so reused cells never keep another item's label.
- iOS 17+: the block properties (`accessibilityLabelBlock`, `accessibilityValueBlock` and friends) compute values only when assistive technology asks, which avoids building strings for every cell during scrolling.

## Custom actions

Expose secondary actions as `accessibilityCustomActions` so VoiceOver and Switch Control users do not need swipes or long presses.

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: String(localized: "Reply")) { [weak self] _ in self?.reply(id); return true },
    UIAccessibilityCustomAction(name: String(localized: "Delete")) { [weak self] _ in self?.delete([id]); return true },
]
```

Every swipe action and every context menu action that matters belongs here too.

## Adjustable and custom controls

- A custom slider or stepper: add the `.adjustable` trait and implement `accessibilityIncrement()` and `accessibilityDecrement()`, updating `accessibilityValue`.
- A custom control that draws its own content: subclass `UIControl` and send actions, so it takes part in the responder chain and accessibility like a system control.
- `accessibilityActivate()` for a non-standard primary action when activated.
- `accessibilityRespondsToUserInteraction` tells Voice Control an element is interactive when that is not obvious from traits.

## Order and containers

- VoiceOver order follows the view hierarchy top-left to bottom-right. If the visual order differs, set `accessibilityElements` on the container in the order to read.
- `shouldGroupAccessibilityChildren = true` keeps a container's children together during navigation.
- `accessibilityContainerType` (`.list`, `.landmark`, `.semanticGroup`) helps navigation in complex screens.
- Hide decorative views with `isAccessibilityElement = false` or `accessibilityElementsHidden = true`.
- A modal custom view that covers the screen sets `accessibilityViewIsModal = true` so VoiceOver ignores what is behind it.

## Announcements and screen changes

- `UIAccessibility.post(notification: .screenChanged, argument: firstElement)` after a large change (new screen content without a navigation transition).
- `.layoutChanged` after a partial change, pointing at the element to focus.
- `.announcement` sparingly, for status the user would otherwise miss (an upload finished off screen). On iOS 17+ an `AttributedString` announcement can carry `accessibilitySpeechAnnouncementPriority`.

## Settings to respect

| Setting | Read | React |
|---|---|---|
| Reduce Motion | `UIAccessibility.isReduceMotionEnabled` | fades instead of movement (see `animation.md`) |
| Reduce Transparency | `isReduceTransparencyEnabled` | opaque backgrounds for custom blurs |
| Increase Contrast | `traitCollection.accessibilityContrast` | asset colors with high-contrast variants |
| Bold Text | `traitCollection.legibilityWeight` | custom fonts pick a heavier weight |
| Button Shapes / Show Borders | `UIAccessibility.buttonShapesEnabled` (replaced by `AXShowBordersEnabled` in iOS 26.1) | underline or outline custom text buttons |
| Differentiate Without Color | `shouldDifferentiateWithoutColor` | add shapes or symbols to color-only status |

Each has a change notification in `UIAccessibility` (for example `reduceMotionStatusDidChangeNotification`). Trait-based settings update through trait tracking.

## Large content and text size

- Text sizes: see `text.md`. Layouts must work at the largest accessibility size.
- Bars and tab bars show the large content viewer on long press at accessibility sizes. Custom bar-like controls adopt `UILargeContentViewerInteraction` and set `showsLargeContentViewer`, `largeContentTitle` and `largeContentImage`.

## Hit targets

- At least 44 by 44 points for anything tappable.
- Grow the target with `point(inside:with:)` or larger insets in the button configuration, not by enlarging the art.

## Testing

- Run the Accessibility Inspector's audit on each screen.
- XCTest: `try app.performAccessibilityAudit()` (iOS 17+) in UI tests catches missing labels, small targets, contrast and clipped text.
- Try the screen with VoiceOver on a device, with Voice Control, and at the largest text size.

## Review checks

1. Labels on every interactive element, set per configuration in cells.
2. Cells grouped into one element with a composed label.
3. Swipe and menu actions also exposed as custom actions.
4. Order and modal state correct in custom containers.
5. A UI test runs `performAccessibilityAudit()`.
