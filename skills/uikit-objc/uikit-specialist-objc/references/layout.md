# Layout

Auto Layout, guides, safe areas, the keyboard, size changes and the view controller lifecycle. Correct layout works at every size, orientation, text size and window arrangement without special cases per device.

## Auto Layout hygiene

- Set `translatesAutoresizingMaskIntoConstraints = NO` on every view you constrain in code. Never set it on a view whose frame UIKit manages: a cell's `contentView`, a view controller's root `view`, the cells themselves.
- Activate constraints together with `[NSLayoutConstraint activateConstraints:@[...]]`. Keep references only to constraints you will change, and change `constant` or `active` rather than removing and recreating them.
- Every view needs a full, unambiguous set: horizontal position and width, vertical position and height, from constraints or intrinsic content size. In the debugger use `[view hasAmbiguousLayout]` and `[view exerciseAmbiguityInLayout]`, or the view debugger's warnings.
- Fix every "Unable to simultaneously satisfy constraints" log. Set `identifier` on constraints so the log names them. A symbolic breakpoint on `UIViewAlertForUnsatisfiableConstraints` stops when it happens.
- Use priorities to say what gives way. Lower compression resistance on the label that may truncate; higher hugging on the label that should fit its text. Use 999 for a constraint that must yield briefly during transitions (a height while a cell resizes). Set it with `constraint.priority = UILayoutPriorityDefaultHigh` or `999`.
- Use leading and trailing, not left and right, so right-to-left languages mirror (`leadingAnchor`, `NSLayoutAttributeLeading`). Use `directionalLayoutMargins` and `NSDirectionalEdgeInsets`.
- Use `UIStackView` for rows and columns of controls. Collapse an arranged subview with `hidden = YES`; do not remove and re-add it.
- Use `UILayoutGuide` instead of empty spacer views.
- Do not mix frame layout and constraints on one view. If you lay out by hand in `layoutSubviews`, call `[super layoutSubviews]`, use `bounds` and margins, and keep it idempotent.
- Do not use the visual format language or `constraintWithItem:attribute:...` in new code; the anchor API reads better and is checked for type (a `NSLayoutXAxisAnchor` cannot be tied to a `NSLayoutYAxisAnchor` without a warning).

Wrong: constraints rebuilt in `layoutSubviews`.

```objc
- (void)layoutSubviews {
    [super layoutSubviews];
    [NSLayoutConstraint deactivateConstraints:self.constraints];
    [NSLayoutConstraint activateConstraints:[self constraintsForWidth:CGRectGetWidth(self.bounds)]];
}
```

Right: build once, adjust constants when the input changes.

```objc
@property (nonatomic, strong) NSLayoutConstraint *badgeWidthConstraint;

// in the initializer, once:
self.badgeWidthConstraint = [self.badge.widthAnchor constraintEqualToConstant:24];
self.badgeWidthConstraint.active = YES;

- (void)setBadgeWidth:(CGFloat)width {
    self.badgeWidthConstraint.constant = width;
}
```

## Guides

| Guide | Use for |
|---|---|
| `safeAreaLayoutGuide` | content that must avoid the sensor housing, home indicator and bars |
| `layoutMarginsGuide` | content that lines up with system margins |
| `readableContentGuide` | text on wide windows, so line length stays readable |
| `keyboardLayoutGuide` | anything that sits above the keyboard |
| layout regions (iOS 26+) | content that must avoid window controls or a sheet's rounded corners |

Scroll views and collection views should usually fill the whole view (edges to `view`, not the safe area) and let `contentInsetAdjustmentBehavior` (default `UIScrollViewContentInsetAdjustmentAutomatic`) turn the safe area into content inset, so content scrolls under the bars. Read the real inset from `adjustedContentInset`. Add extra space with `additionalSafeAreaInsets` on the controller or `contentInset` on the scroll view.

### Layout regions (iOS 26+)

`-layoutGuideForLayoutRegion:`, `-edgeInsetsForLayoutRegion:` and `-directionalEdgeInsetsForLayoutRegion:` on `UIView` take a `UIViewLayoutRegion`, created with `+safeAreaLayoutRegionWithCornerAdaptation:`, `+marginsLayoutRegionWithCornerAdaptation:` or `+readableContentLayoutRegionWithCornerAdaptation:`. Regions describe the safe area or margins, optionally adapted to corners, which matters when a window has controls in a corner (iPad windowing) or a view sits in a container with rounded corners. Use a region guide instead of hand-made insets when content collides with window controls. These methods are marked as refined for Swift, so the Objective-C names above are the real ones; read the adaptivity axis option names from `UIViewLayoutRegion.h`.

### Concentric corners (iOS 26+)

`cornerConfiguration` on a view sets its corners from a `UICornerConfiguration`: `+configurationWithRadius:`, `+configurationWithUniformRadius:`, `+capsuleConfiguration` and per-corner forms, with radii from `UICornerRadius` (`+fixedRadius:`, `+containerConcentricRadius`, `+containerConcentricRadiusWithMinimum:`). A concentric radius follows the corners of the window or the enclosing view, so nested shapes stay parallel. Read the resolved value with `-effectiveRadiusForCorner:`; when read inside `layoutSubviews` or `updateProperties` the view updates automatically when it changes.

```objc
card.cornerConfiguration = [UICornerConfiguration configurationWithRadius:
                            [UICornerRadius containerConcentricRadiusWithMinimum:12]];
```

## Keyboard

Use `keyboardLayoutGuide` (iOS 15+). It replaces keyboard notifications and frame conversion.

Wrong:

```objc
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                             name:UIKeyboardWillShowNotification object:nil];
// convert the end frame, set a bottom constant, animate with the notification's curve
```

Right:

```objc
[NSLayoutConstraint activateConstraints:@[
    [self.inputBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.inputBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.inputBar.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
    [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.collectionView.bottomAnchor constraintEqualToAnchor:self.inputBar.topAnchor],
]];
```

- With the keyboard hidden, the guide's top sits at the bottom of the safe area, so the bar stays above the home indicator. Set `keyboardLayoutGuide.usesBottomSafeArea = NO` to handle that inset yourself.
- On iPad, `followsUndockedKeyboard = YES` makes the guide follow a floating or split keyboard.
- The guide animates with the keyboard. To keep a chat pinned to the bottom, decide "pinned" before the change and scroll to the last item when the collection view's height changes (see `updates-and-scrolling.md`).
- `keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive` lets the user drag the keyboard down with the list.
- For a field in a scrolling form, call `-scrollRectToVisible:animated:` after layout. Never hard-code keyboard heights.

## Size classes, resizing and multitasking

Treat rotation and window resizing as one event: the container size changed.

- Read `traitCollection.horizontalSizeClass` and `verticalSizeClass` (`UIUserInterfaceSizeClassCompact`, `...Regular`). An iPhone in landscape and an iPad in a narrow window are both compact width; design for the class, not the device.
- Derive layout from the view's own bounds or the layout environment's container size, never from the screen. Windows on iPad can be any size, and iPhone apps can be shown resized (see the iOS 27 notes in the whats-new skill).
- Respond in `-viewWillTransitionToSize:withTransitionCoordinator:` and do size-dependent work inside the coordinator's `-animateAlongsideTransition:completion:`.
- In compositional layouts compute columns from `environment.container.effectiveContentSize` in the section provider; it runs again for the new size.
- Do not branch layout on `userInterfaceIdiom` or interface orientation. Use size classes and available width.
- Do not lock orientation to avoid layout work. If a screen really needs it, override `supportedInterfaceOrientations` on that controller and call `-setNeedsUpdateOfSupportedInterfaceOrientations`.
- Get the window and scene from the view (`self.view.window.windowScene`), not from globals. A scene-based app can show several windows of the same scene type at once. Any `[UIApplication sharedApplication].keyWindow` or `.windows.firstObject` is a bug in a multi-window app.

## View controller lifecycle

| Method | Do here |
|---|---|
| `loadView` | only when replacing the root view with a custom class |
| `viewDidLoad` | build the hierarchy and constraints once; bounds are not final |
| `viewIsAppearing:` | work that needs correct traits and size: first scroll position, trait-based styling |
| `viewWillLayoutSubviews` / `viewDidLayoutSubviews` | cheap, idempotent adjustments; may run many times |
| `updateProperties` (iOS 26+) | set view properties from model state; see `dataflow.md` |
| `viewDidDisappear:` | stop timers, cancel work that only matters while visible |

- `viewIsAppearing:` runs after the view is in the hierarchy with its traits and size, before the appearance transition draws. It is available back to iOS 13 with current Xcode. Prefer it to `viewWillAppear:` for appearance setup. Always call `[super viewIsAppearing:animated]`.
- Compose screens from child controllers (`addChildViewController:`, add the view, `didMoveToParentViewController:`) instead of one large controller. Remove with `willMoveToParentViewController:nil`, remove the view, `removeFromParentViewController`.

## Custom views

- Override `intrinsicContentSize` for views with a natural size, and call `-invalidateIntrinsicContentSize` when it changes.
- Put constraint changes in `updateConstraints` (call `[super updateConstraints]` last) when many inputs affect them, and request a pass with `setNeedsUpdateConstraints`.
- `layoutSubviews` must not change the view's own size or its superview's layout; that loops. The launch argument `-UIViewLayoutFeedbackLoopDebuggingThreshold 100` reports layout loops.
- `sizeThatFits:` serves frame-based callers; keep it consistent with the constraints.
- Designated initializers: a view created in code gets `initWithFrame:`; one loaded from a storyboard gets `initWithCoder:`. Put shared setup in one private method and call it from both.

## Review checks

1. No constraints rebuilt during layout; constants changed instead.
2. Scroll views fill the view and rely on adjusted insets.
3. Keyboard handled by `keyboardLayoutGuide`.
4. Nothing sized from the screen, the idiom or the orientation.
5. Setup that needs size or traits in `viewIsAppearing:`, not `viewDidLoad`.
