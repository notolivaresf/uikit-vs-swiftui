# Text: Dynamic Type, labels, text views and localization

## Dynamic Type

All text grows and shrinks with the user's text size, including the accessibility sizes.

Wrong:

```swift
title.font = .systemFont(ofSize: 17, weight: .semibold)
```

Right:

```swift
title.font = .preferredFont(forTextStyle: .headline)
title.adjustsFontForContentSizeCategory = true
title.numberOfLines = 0
```

- Use text styles: `.largeTitle`, `.title1` to `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption1`, `.caption2`.
- `adjustsFontForContentSizeCategory = true` updates the font live. It works on `UILabel`, `UITextField`, `UITextView`, and button configurations whose fonts come from text styles.
- Custom fonts: scale with `UIFontMetrics`.

```swift
let base = UIFont(name: "Avenir-Medium", size: 17) ?? .systemFont(ofSize: 17)
label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
label.adjustsFontForContentSizeCategory = true
```

- Scale spacing and fixed sizes beside text with `UIFontMetrics(forTextStyle:).scaledValue(for:)`. Symbols scale with `preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)`.
- Weight changes keep the scaled size: take the text-style font's descriptor, `withSymbolicTraits(.traitBold)`, then `UIFont(descriptor:size: 0)`.
- Cap growth only where layout truly cannot grow: `maximumContentSizeCategory` on a view (iOS 15+). Never cap body text.
- Fonts inside attributed strings do not update by themselves. Rebuild attributed strings when `UITraitPreferredContentSizeCategory` changes.

### Large sizes

- At accessibility sizes (`traitCollection.preferredContentSizeCategory.isAccessibilityCategory`), switch horizontal rows to vertical stacks, let labels wrap, let cells grow.
- Never clip text with fixed heights. Every text container in a list needs an estimated height.
- `UILabel.showsExpansionTextWhenTruncated` shows the full text in the large content viewer. Bars and tab items get the large content viewer automatically; custom controls adopt `UILargeContentViewerInteraction`.
- Test at the largest accessibility size in Xcode's environment overrides or the Accessibility Inspector.

## Labels

- `numberOfLines = 0` for text that may wrap; `lineBreakMode` and `lineBreakStrategy` for truncation and line breaks.
- `adjustsFontSizeToFitWidth` shrinks text below the user's chosen size; use it only for short labels such as a numeric display, with a `minimumScaleFactor`.
- `UILabel` cannot select text. When users may select part of the text, use a text view.

## Selectable text

Show selectable, non-editable text in a `UITextView` set up like a label:

```swift
let textView = UITextView(usingTextLayoutManager: true)
textView.isEditable = false
textView.isSelectable = true
textView.isScrollEnabled = false          // sizes to content, works in self-sizing cells
textView.backgroundColor = .clear
textView.textContainerInset = .zero
textView.textContainer.lineFragmentPadding = 0
textView.font = .preferredFont(forTextStyle: .body)
textView.adjustsFontForContentSizeCategory = true
textView.dataDetectorTypes = [.link]
```

- With scrolling off, the text view has an intrinsic size and self-sizes in cells.
- Remove the default insets so it lines up with neighbouring labels.
- Selection competes with the cell's own long press. Decide which wins: either the context menu owns the cell and offers "Copy" and "Select Text", or selection stays active and the menu attaches outside the text. Test on device.
- If only whole-message copy is needed, skip the text view: a context menu action that writes to `UIPasteboard.general` is cheaper.
- A text view costs more than a label. In very long lists, measure; consider a label that swaps to a text view when the user starts selecting.

## Edit menus on text

Customize the menu for a text selection through `UITextViewDelegate`.

- iOS 26 SDK: implement `textView(_:editMenuForTextInRanges:suggestedActions:)`, which receives every selected range (selections can be discontiguous). The single-range `textView(_:editMenuForTextIn:suggestedActions:)` is marked to be deprecated; UIKit calls it with the union of the ranges when the new method is missing.
- Return a `UIMenu` that adds your actions to `suggestedActions`, or `nil` for the default.

```swift
func textView(_ textView: UITextView,
              editMenuForTextInRanges ranges: [NSValue],
              suggestedActions: [UIMenuElement]) -> UIMenu? {
    let quote = UIAction(title: String(localized: "Quote"), image: UIImage(systemName: "quote.opening")) { [weak self] _ in
        self?.quote(ranges.map(\.rangeValue))
    }
    return UIMenu(children: suggestedActions + [quote])
}
```

## Links and text items

- `textView(_:primaryActionFor:defaultAction:)` and `textView(_:menuConfigurationFor:defaultMenu:)` (iOS 17+) handle taps and menus on links, attachments and custom tagged ranges. The `shouldInteractWith` URL and attachment methods are deprecated.
- Tag custom ranges with `.textItemTag` in the attributed string, then match `UITextItem.Content.tag(_:)` in those methods.

## Editing

- `UITextField` for one line, `UITextView` for many. Set `textContentType`, `keyboardType`, `autocapitalizationType`, `returnKeyType` and `autocorrectionType` for every field; they drive AutoFill and the right keyboard.
- Handle return with `UITextField`'s `addAction(_:for: .editingDidEndOnExit)` or the delegate.
- Validate with the delegate's change methods, not by observing `textDidChangeNotification` and rewriting `text` (that breaks marked text for input methods). Do not change `text` while `markedTextRange` is non-nil.
- Find: `isFindInteractionEnabled = true` on a text view (iOS 16+).
- Writing Tools (iOS 18+): `writingToolsBehavior` (`.default`, `.complete`, `.limited`, `.none`) and `allowedWritingToolsResultOptions`. During a Writing Tools session (`isWritingToolsActive`), do not rewrite the text from your own code; wait for the delegate's end callback.

## TextKit 2

- New text views use TextKit 2 (`UITextView(usingTextLayoutManager: true)` is the default since iOS 16).
- Reading `textView.layoutManager` switches that text view to TextKit 1 compatibility mode, permanently, which loses TextKit 2 behavior and performance. Use `textLayoutManager` and `NSTextContentStorage` instead.
- Layout queries: `textLayoutManager.enumerateTextLayoutFragments(from:options:using:)` and `textLayoutManager.textViewportLayoutController` for what is on screen.
- Ranges in TextKit 2 are `NSTextRange` over `NSTextLocation`; convert from `NSRange` through the content manager, not by integer math on characters.

## Localization

- `String(localized:)` and string catalogs (`.xcstrings`) for every user-visible string, including accessibility labels.

Wrong:

```swift
label.text = "\(count) " + (count == 1 ? "message" : "messages")
```

Right:

```swift
label.text = String(localized: "\(count) messages")   // plural variants in the string catalog
```

- Never build sentences by concatenation. Use one string with arguments so translators can reorder and pluralize.
- Add a `comment:` when the meaning is not obvious from the text.
- Format numbers, dates, durations, measurements, names and lists with `formatted()` or their format styles, so they follow the user's locale and region.
- Let text wrap or truncate instead of fixing widths to English. Test with the double-length and right-to-left pseudolanguages in the scheme's options.
- Use leading and trailing everywhere. Set `semanticContentAttribute = .forceLeftToRight` only on views that must not mirror, such as media playback controls.
- Symbols that imply direction (arrows, `chevron.forward`) mirror automatically when you use the `forward`/`backward` names; prefer them to `left`/`right`.

## Review checks

1. Every font from a text style or `UIFontMetrics`, with `adjustsFontForContentSizeCategory`.
2. No fixed heights on text; layouts tested at the largest accessibility size.
3. Selectable text in a text view; multi-range edit menu implemented with the iOS 26 SDK.
4. No `layoutManager` access on TextKit 2 text views.
5. All strings localized with arguments, not concatenation.
