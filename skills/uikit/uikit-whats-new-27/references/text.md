# Text and TextKit

The iOS 27 UIKit updates bring several TextKit 2 additions to `UITextView`. Some of the types involved are older (their documentation lists early iOS versions); what is new is that UIKit text views now use them in these ways. Check each on an iOS 27 device before relying on it with an older deployment target.

## Viewport layout in a `UITextView` subclass

A `UITextView` subclass can now override the `NSTextViewportLayoutControllerDelegate` methods directly, instead of replacing the layout controller's delegate (which broke the text view's own layout).

`UITextView.viewportBounds(for:)` (iOS 27) is documented as the delegate method the framework calls for the current viewport, the visible bounds plus the overdraw area. It requires a call to `super`.

Wrong: taking over the delegate.

```swift
textView.textLayoutManager?.textViewportLayoutController.delegate = self   // the text view stops laying out
```

Right: subclass and call `super`.

```swift
@available(iOS 27, *)
final class NotesTextView: UITextView {
    override func viewportBounds(for controller: NSTextViewportLayoutController) -> CGRect {
        var bounds = super.viewportBounds(for: controller)
        bounds = bounds.insetBy(dx: 0, dy: -200)   // lay out a little further ahead
        return bounds
    }
}
```

Other delegate methods in the protocol: `textViewportLayoutControllerWillLayout(_:)`, `textViewportLayoutController(_:configureRenderingSurfaceFor:)`, `textViewportLayoutControllerDidLayout(_:)`. Keep overrides small and always call `super`; they run on every layout pass while scrolling.

## Attachment view reuse

`UITextAttachmentViewProviderReusePolicy` is an option set that controls whether a text view reuses attachment view providers when scrolling or editing. Options: `onScrollingOutOfViewport` and `onEditingInlineParagraphs`. Register a policy on the `UITextView` to keep attachment views alive during scrolling and editing. This stops flicker and keeps state in views such as embedded players or checkboxes.

- Use it for attachments with expensive or stateful views.
- Plain image attachments do not need it.
- The views kept alive still cost memory; do not keep hundreds.

The registration method's exact name is in the iOS 27 SDK `UITextView` header; look it up there.

## Rendering surfaces

`NSTextViewportRenderingSurface` (iOS 27) is a protocol that marks a view or layer as the drawable element for a text layout fragment. Use it to draw text in custom views and layers. `NSTextViewportRenderingSurfaceKey` (iOS 18) identifies a surface for caching through the delegate methods `textViewportLayoutController(_:cacheRenderingSurface:for:)` and `textViewportLayoutController(_:retrieveCachedRenderingSurfaceFor:)`.

Use it when one fragment is drawn by a custom layer (a code block with its own background, a highlighted quote), so the layout controller can reuse surfaces instead of rebuilding them on every scroll.

## Text tables

The iOS 27 updates list `NSTextTable`, `NSTextBlock` and `NSTextTableBlock` as usable to represent tables in attributed strings, with `NSParagraphStyle.textBlocks` to read which blocks contain a paragraph.

```swift
let table = NSTextTable()
table.numberOfColumns = 2

func cell(_ text: String, row: Int, column: Int) -> NSAttributedString {
    let block = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1,
                                 startingColumn: column, columnSpan: 1)
    let style = NSMutableParagraphStyle()
    style.textBlocks = [block]
    return NSAttributedString(string: text + "\n", attributes: [.paragraphStyle: style])
}
```

- Each cell is one paragraph ending in a newline.
- Read the structure back with `paragraphStyle.textBlocks`, outermost to innermost.
- Test pasting from and to other apps, and with VoiceOver, before shipping a table feature.

## Checks

1. No replaced viewport layout delegate on a text view; subclass overrides call `super`.
2. Stateful attachments use a reuse policy.
3. Table content tested on iOS 27 devices.

<!-- sources: https://developer.apple.com/documentation/updates/uikit, https://developer.apple.com/documentation/uikit/uitextview/viewportbounds(for:), https://developer.apple.com/documentation/uikit/nstextviewportlayoutcontrollerdelegate, https://developer.apple.com/documentation/uikit/uitextattachmentviewproviderreusepolicy, https://developer.apple.com/documentation/uikit/nstextviewportrenderingsurface, https://developer.apple.com/documentation/uikit/nstexttable, https://developer.apple.com/documentation/uikit/nstexttableblock, https://developer.apple.com/documentation/uikit/nsmutableparagraphstyle/textblocks -->
