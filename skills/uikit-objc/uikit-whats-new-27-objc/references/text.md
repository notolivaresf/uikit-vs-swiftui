# Text and TextKit

The iOS 27 UIKit updates bring several TextKit 2 additions to `UITextView`. Some of the types involved are older (their documentation lists early iOS versions); what is new is that UIKit text views now use them in these ways. Check each on an iOS 27 device before relying on it with an older deployment target.

## Viewport layout in a `UITextView` subclass

A `UITextView` subclass can now override the `NSTextViewportLayoutControllerDelegate` methods directly, instead of replacing the layout controller's delegate (which broke the text view's own layout).

`-[UITextView viewportBoundsForTextViewportLayoutController:]` (iOS 27) is the delegate method the framework calls for the current viewport, the visible bounds plus the overdraw area. An override must call `super`.

Wrong: taking over the delegate.

```objc
textView.textLayoutManager.textViewportLayoutController.delegate = self;   // the text view stops laying out
```

Right: subclass and call `super`, and guard the override, because `super` has no such method before iOS 27.

```objc
@interface NotesTextView : UITextView
@end

@implementation NotesTextView
- (CGRect)viewportBoundsForTextViewportLayoutController:(NSTextViewportLayoutController *)controller {
    if (@available(iOS 27.0, *)) {
        CGRect bounds = [super viewportBoundsForTextViewportLayoutController:controller];
        return CGRectInset(bounds, 0, -200);        // lay out a little further ahead
    }
    return CGRectZero;                              // not called before iOS 27
}
@end
```

Other delegate methods in the protocol: `textViewportLayoutControllerWillLayout:`, `textViewportLayoutController:configureRenderingSurfaceForTextLayoutFragment:`, `textViewportLayoutControllerDidLayout:`. Keep overrides small and always call `super`; they run on every layout pass while scrolling.

## Attachment view reuse

`UITextAttachmentViewProviderReusePolicy` is an option set that controls whether a text view reuses attachment view providers when scrolling or editing: `UITextAttachmentViewProviderReusePolicyOnScrollingOutOfViewport` and `...OnEditingInlineParagraphs`. Register a policy on the text view for a provider class with `-registerTextAttachmentViewProviderReusePolicy:forTextAttachmentViewProviderType:` (iOS 27; the type is a `Class`) to keep attachment views alive during scrolling and editing. This stops flicker and keeps state in views such as embedded players or checkboxes.

```objc
if (@available(iOS 27.0, *)) {
    [textView registerTextAttachmentViewProviderReusePolicy:UITextAttachmentViewProviderReusePolicyOnScrollingOutOfViewport
                         forTextAttachmentViewProviderType:[PlayerAttachmentViewProvider class]];
}
```

- Use it for attachments with expensive or stateful views.
- Plain image attachments do not need it.
- The views kept alive still cost memory; do not keep hundreds.

## Rendering surfaces

`NSTextViewportRenderingSurface` (iOS 27) is a protocol that marks a view or layer as the drawable element for a text layout fragment. Use it to draw text in custom views and layers. `NSTextViewportRenderingSurfaceKey` (iOS 18) identifies a surface for caching through the delegate methods `textViewportLayoutController:cacheRenderingSurface:forTextLayoutFragment:` and `textViewportLayoutController:retrieveCachedRenderingSurfaceForTextLayoutFragment:`. Read the exact signatures in the iOS 27 header or documentation before implementing them.

Use it when one fragment is drawn by a custom layer (a code block with its own background, a highlighted quote), so the layout controller can reuse surfaces instead of rebuilding them on every scroll.

## Text tables

The iOS 27 updates list `NSTextTable`, `NSTextBlock` and `NSTextTableBlock` as usable to represent tables in attributed strings, with `NSParagraphStyle.textBlocks` (`NSArray<__kindof NSTextBlock *> *`) to read which blocks contain a paragraph.

```objc
NSTextTable *table = [[NSTextTable alloc] init];
table.numberOfColumns = 2;

- (NSAttributedString *)cellWithText:(NSString *)text row:(NSInteger)row column:(NSInteger)column table:(NSTextTable *)table {
    NSTextTableBlock *block = [[NSTextTableBlock alloc] initWithTable:table startingRow:row rowSpan:1
                                                       startingColumn:column columnSpan:1];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.textBlocks = @[block];
    return [[NSAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"]
                                           attributes:@{NSParagraphStyleAttributeName: style}];
}
```

- Each cell is one paragraph ending in a newline.
- Read the structure back with `paragraphStyle.textBlocks`, outermost to innermost.
- Test pasting from and to other apps, and with VoiceOver, before shipping a table feature.

## Checks

1. No replaced viewport layout delegate on a text view; subclass overrides call `super` and are guarded.
2. Stateful attachments use a reuse policy.
3. Table content tested on iOS 27 devices.

<!-- sources: Objective-C declarations on Apple's pages for -[UITextView viewportBoundsForTextViewportLayoutController:], the other viewport delegate methods, -[UITextView registerTextAttachmentViewProviderReusePolicy:forTextAttachmentViewProviderType:], UITextAttachmentViewProviderReusePolicy, NSTextViewportRenderingSurface, NSTextTable, NSTextTableBlock, NSParagraphStyle textBlocks; UIKit updates page. -->
