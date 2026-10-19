# Text: Dynamic Type, labels, text views and localization

## Dynamic Type

All text grows and shrinks with the user's text size, including the accessibility sizes.

Wrong:

```objc
title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
```

Right:

```objc
title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
title.adjustsFontForContentSizeCategory = YES;
title.numberOfLines = 0;
```

- Use text styles: `UIFontTextStyleLargeTitle`, `...Title1` to `...Title3`, `...Headline`, `...Body`, `...Callout`, `...Subheadline`, `...Footnote`, `...Caption1`, `...Caption2`.
- `adjustsFontForContentSizeCategory = YES` updates the font live. It works on `UILabel`, `UITextField`, `UITextView`, and button configurations whose fonts come from text styles. It does nothing for a fixed-size font that did not come from a text style or `UIFontMetrics`.
- Custom fonts: scale with `UIFontMetrics`.

```objc
UIFont *base = [UIFont fontWithName:@"Avenir-Medium" size:17] ?: [UIFont systemFontOfSize:17];
label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:base];
label.adjustsFontForContentSizeCategory = YES;
```

(`fontWithName:size:` is `nullable`; the `?:` fallback is not optional.)

- Scale spacing and fixed sizes beside text with `-[UIFontMetrics scaledValueForValue:]`. Symbols scale with `imageView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody]`.
- Weight changes keep the scaled size: take the text-style font's descriptor, `-fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold` (it returns `nil` if no such face exists), then `+[UIFont fontWithDescriptor:size:]` with size `0`.
- Cap growth only where layout truly cannot grow: `maximumContentSizeCategory` on a view (iOS 15+). Never cap body text.
- Fonts inside attributed strings do not update by themselves. Rebuild attributed strings when `UITraitPreferredContentSizeCategory` changes (register for it, see `traits-and-environment.md`).

### Large sizes

- At accessibility sizes (`UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)`), switch horizontal rows to vertical stacks, let labels wrap, let cells grow.
- Never clip text with fixed heights. Every text container in a list needs an estimated height.
- `UILabel.showsExpansionTextWhenTruncated` shows the full text in the large content viewer. Bars and tab items get the large content viewer automatically; custom controls adopt `UILargeContentViewerInteraction`.
- Test at the largest accessibility size in Xcode's environment overrides or the Accessibility Inspector.

## Labels

- `numberOfLines = 0` for text that may wrap; `lineBreakMode` and `lineBreakStrategy` for truncation and line breaks.
- `adjustsFontSizeToFitWidth` shrinks text below the user's chosen size; use it only for short labels such as a numeric display, with a `minimumScaleFactor`.
- `UILabel` cannot select text. When users may select part of the text, use a text view.

## Selectable text

Show selectable, non-editable text in a `UITextView` set up like a label:

```objc
UITextView *textView = [UITextView textViewUsingTextLayoutManager:YES];
textView.editable = NO;
textView.selectable = YES;
textView.scrollEnabled = NO;          // sizes to content, works in self-sizing cells
textView.backgroundColor = [UIColor clearColor];
textView.textContainerInset = UIEdgeInsetsZero;
textView.textContainer.lineFragmentPadding = 0;
textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
textView.adjustsFontForContentSizeCategory = YES;
textView.dataDetectorTypes = UIDataDetectorTypeLink;
```

- With scrolling off, the text view has an intrinsic size and self-sizes in cells.
- Remove the default insets so it lines up with neighbouring labels.
- Selection competes with the cell's own long press. Decide which wins: either the context menu owns the cell and offers "Copy" and "Select Text", or selection stays active and the menu attaches outside the text. Test on device.
- If only whole-message copy is needed, skip the text view: a context menu action that sets `[UIPasteboard generalPasteboard].string` is cheaper.
- A text view costs more than a label. In very long lists, measure; consider a label that swaps to a text view when the user starts selecting.

## Edit menus on text

Customize the menu for a text selection through `UITextViewDelegate`.

- iOS 26 SDK: implement `textView:editMenuForTextInRanges:suggestedActions:`, which receives every selected range as `NSValue`s (selections can be discontiguous). The single-range `textView:editMenuForTextInRange:suggestedActions:` is deprecated.
- Return a `UIMenu` that adds your actions to `suggestedActions`, or `nil` for the default.

```objc
- (UIMenu *)textView:(UITextView *)textView
editMenuForTextInRanges:(NSArray<NSValue *> *)ranges
    suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    __weak typeof(self) weakSelf = self;
    UIAction *quote = [UIAction actionWithTitle:NSLocalizedString(@"Quote", @"Edit menu action")
                                          image:[UIImage systemImageNamed:@"quote.opening"]
                                     identifier:nil
                                        handler:^(__kindof UIAction *action) {
        [weakSelf quoteRanges:ranges];
    }];
    return [UIMenu menuWithChildren:[suggestedActions arrayByAddingObject:quote]];
}
```

Because the method exists only in the newer SDK, build with Xcode 26 or later. Older SDKs reject the method as an unknown protocol method (a warning), so keep the old single-range method too if you build with both.

## Links and text items

- `textView:primaryActionForTextItem:defaultAction:` and `textView:menuConfigurationForTextItem:defaultMenu:` (iOS 17+) handle taps and menus on links, attachments and custom tagged ranges. The `shouldInteractWithURL` and attachment methods are deprecated.
- Tag custom ranges with the `UITextItemTagAttributeName` attribute (an `NSString` value) in the attributed string, then match `textItem.contentType == UITextItemContentTypeTag` and read `textItem.tagContent` in those methods.

## Editing

- `UITextField` for one line, `UITextView` for many. Set `textContentType`, `keyboardType`, `autocapitalizationType`, `returnKeyType` and `autocorrectionType` for every field; they drive AutoFill and the right keyboard.
- Handle return with `-addAction:forControlEvents:` on `UIControlEventEditingDidEndOnExit` or the delegate's `textFieldShouldReturn:`.
- Validate with the delegate's change methods (`textField:shouldChangeCharactersInRange:replacementString:`), not by observing `UITextFieldTextDidChangeNotification` and rewriting `text` (that breaks marked text for input methods). Do not change `text` while `markedTextRange` is non-nil.
- Find: `findInteractionEnabled = YES` on a text view (iOS 16+).
- Writing Tools (iOS 18+): `writingToolsBehavior` (`UIWritingToolsBehaviorDefault`, `...Complete`, `...Limited`, `...None`) and `allowedWritingToolsResultOptions`. During a Writing Tools session (`isWritingToolsActive`), do not rewrite the text from your own code; wait for the delegate's end callback.

## TextKit 2

- New text views use TextKit 2 (`+textViewUsingTextLayoutManager:YES` is the default since iOS 16).
- Reading `textView.layoutManager` switches that text view to TextKit 1 compatibility mode, permanently, which loses TextKit 2 behavior and performance. This also happens when you read `textView.textContainer.layoutManager`. Use `textLayoutManager` and `NSTextContentStorage` instead.
- Layout queries: `-enumerateTextLayoutFragmentsFromLocation:options:usingBlock:` on `NSTextLayoutManager` and `textLayoutManager.textViewportLayoutController` for what is on screen.
- Ranges in TextKit 2 are `NSTextRange` over `id<NSTextLocation>`; convert from `NSRange` with `-[NSTextContentManager locationFromLocation:withOffset:]` starting at `documentRange.location`, then `-[NSTextRange initWithLocation:endLocation:]`, not by integer math on characters.

## Localization

- `NSLocalizedString(key, comment)` or `String(localized:)`-style string catalogs (`.xcstrings`) for every user-visible string, including accessibility labels. The key and the comment are literals that tooling extracts: do not build them at runtime.

Wrong:

```objc
label.text = [NSString stringWithFormat:@"%ld %@", (long)count, count == 1 ? @"message" : @"messages"];
```

Right:

```objc
// "%ld messages" with plural variants in the string catalog
label.text = [NSString localizedStringWithFormat:NSLocalizedString(@"%ld messages", @"Inbox count"), (long)count];
```

- Never build sentences by concatenation. Use one string with arguments so translators can reorder and pluralize. Use `localizedStringWithFormat:`, not `stringWithFormat:`, so numbers follow the locale.
- Add a useful comment; `nil` or `@""` hides the meaning from translators.
- Format numbers, dates, durations, measurements, names and lists with `NSNumberFormatter`, `NSDateFormatter` (or `+dateFormatFromTemplate:options:locale:`), `NSDateComponentsFormatter`, `NSMeasurementFormatter`, `NSPersonNameComponentsFormatter` and `NSListFormatter`, so they follow the user's locale and region. Cache the formatter.
- Let text wrap or truncate instead of fixing widths to English. Test with the double-length and right-to-left pseudolanguages in the scheme's options.
- Use leading and trailing everywhere. Set `semanticContentAttribute = UISemanticContentAttributeForceLeftToRight` only on views that must not mirror, such as media playback controls.
- Symbols that imply direction (arrows, `chevron.forward`) mirror automatically when you use the `forward` and `backward` names; prefer them to `left` and `right`.
- String compares for display order use `localizedStandardCompare:` or `localizedCaseInsensitiveCompare:`, not `compare:`.

## Review checks

1. Every font from a text style or `UIFontMetrics`, with `adjustsFontForContentSizeCategory`.
2. No fixed heights on text; layouts tested at the largest accessibility size.
3. Selectable text in a text view; multi-range edit menu implemented with the iOS 26 SDK.
4. No `layoutManager` access on TextKit 2 text views.
5. All strings localized with arguments, not concatenation; `copy` on string properties.
