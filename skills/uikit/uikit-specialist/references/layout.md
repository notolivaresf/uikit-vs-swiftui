# Layout

Auto Layout, guides, safe areas, the keyboard, size changes and the view controller lifecycle. Correct layout works at every size, orientation, text size and window arrangement without special cases per device.

## Auto Layout hygiene

- Set `translatesAutoresizingMaskIntoConstraints = false` on every view you constrain in code. Never set it on a view whose frame UIKit manages: a cell's `contentView`, a view controller's root `view`, the cells themselves.
- Activate constraints together with `NSLayoutConstraint.activate([...])`. Keep references only to constraints you will change, and change `constant` or `isActive` rather than removing and recreating them.
- Every view needs a full, unambiguous set: horizontal position and width, vertical position and height, from constraints or intrinsic content size. In the debugger use `hasAmbiguousLayout` and `exerciseAmbiguityInLayout()`, or the view debugger's warnings.
- Fix every "Unable to simultaneously satisfy constraints" log. Set `identifier` on constraints so the log names them. A symbolic breakpoint on `UIViewAlertForUnsatisfiableConstraints` stops when it happens.
- Use priorities to say what gives way. Lower compression resistance on the label that may truncate; higher hugging on the label that should fit its text. Use 999 for a constraint that must yield briefly during transitions (a height while a cell resizes).
- Use leading and trailing, not left and right, so right-to-left languages mirror. Use `directionalLayoutMargins` and `NSDirectionalEdgeInsets`.
- Use `UIStackView` for rows and columns of controls. Collapse an arranged subview with `isHidden`; do not remove and re-add it.
- Use `UILayoutGuide` instead of empty spacer views.
- Do not mix frame layout and constraints on one view. If you lay out by hand in `layoutSubviews`, call `super`, use `bounds` and margins, and keep it idempotent.

Wrong: constraints rebuilt in `layoutSubviews`.

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    NSLayoutConstraint.deactivate(constraints)
    NSLayoutConstraint.activate(makeConstraints(for: bounds.width))
}
```

Right: build once, adjust constants when the input changes.

```swift
private lazy var widthConstraint = badge.widthAnchor.constraint(equalToConstant: 24)

func setBadgeWidth(_ width: CGFloat) {
    widthConstraint.constant = width
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

Scroll views and collection views should usually fill the whole view (edges to `view`, not the safe area) and let `contentInsetAdjustmentBehavior` (default `.automatic`) turn the safe area into content inset, so content scrolls under the bars. Read the real inset from `adjustedContentInset`. Add extra space with `additionalSafeAreaInsets` on the controller or `contentInset` on the scroll view.

### Layout regions (iOS 26+)

`UIView.layoutGuide(for:)`, `edgeInsets(for:)` and `directionalEdgeInsets(for:)` take a `UIView.LayoutRegion`. Regions describe the safe area or margins, optionally adapted to corners, which matters when a window has controls in a corner (iPad windowing) or a view sits in a container with rounded corners. Use a region guide instead of hand-made insets when content collides with window controls.

### Concentric corners (iOS 26+)

`cornerConfiguration` on a view sets its corners from a `UICornerConfiguration`: `.corners(radius:)`, `.uniformCorners(radius:)`, `.capsule()` and per-corner forms, with radii from `UICornerRadius` that can be fixed or concentric with the container. A concentric radius follows the corners of the window or the enclosing view, so nested shapes stay parallel. Read the resolved value with `effectiveRadius(corner:)`; when read inside `layoutSubviews()` or `updateProperties()` the view updates automatically when it changes.

```swift
card.cornerConfiguration = .corners(radius: .containerConcentric(minimum: 12))
```

## Keyboard

Use `keyboardLayoutGuide` (iOS 15+). It replaces keyboard notifications and frame conversion.

Wrong:

```swift
NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                       name: UIResponder.keyboardWillShowNotification, object: nil)
// convert the end frame, set a bottom constant, animate with the notification's curve
```

Right:

```swift
NSLayoutConstraint.activate([
    inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
    collectionView.topAnchor.constraint(equalTo: view.topAnchor),
    collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    collectionView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
])
```

- With the keyboard hidden, the guide's top sits at the bottom of the safe area, so the bar stays above the home indicator. Set `keyboardLayoutGuide.usesBottomSafeArea = false` to handle that inset yourself.
- On iPad, `followsUndockedKeyboard = true` makes the guide follow a floating or split keyboard.
- The guide animates with the keyboard. To keep a chat pinned to the bottom, decide "pinned" before the change and scroll to the last item when the collection view's height changes (see `updates-and-scrolling.md`).
- `keyboardDismissMode = .interactive` lets the user drag the keyboard down with the list.
- For a field in a scrolling form, call `scrollRectToVisible(_:animated:)` after layout. Never hard-code keyboard heights.

## Size classes, resizing and multitasking

Treat rotation and window resizing as one event: the container size changed.

- Read `traitCollection.horizontalSizeClass` and `verticalSizeClass`. An iPhone in landscape and an iPad in a narrow window are both compact width; design for the class, not the device.
- Derive layout from the view's own bounds or the layout environment's container size, never from the screen. Windows on iPad can be any size, and iPhone apps can be shown resized (see the iOS 27 notes in the whats-new skill).
- Respond in `viewWillTransition(to:with:)` and do size-dependent work inside the coordinator's `animate(alongsideTransition:completion:)`.
- In compositional layouts compute columns from `environment.container.effectiveContentSize` in the section provider; it runs again for the new size.
- Do not branch layout on `userInterfaceIdiom` or interface orientation. Use size classes and available width.
- Do not lock orientation to avoid layout work. If a screen really needs it, override `supportedInterfaceOrientations` on that controller and call `setNeedsUpdateOfSupportedInterfaceOrientations()`.
- Get the window and scene from the view (`view.window?.windowScene`), not from globals. A scene-based app can show several windows of the same scene type at once.

## View controller lifecycle

| Method | Do here |
|---|---|
| `loadView` | only when replacing the root view with a custom class |
| `viewDidLoad` | build the hierarchy and constraints once; bounds are not final |
| `viewIsAppearing(_:)` | work that needs correct traits and size: first scroll position, trait-based styling |
| `viewWillLayoutSubviews` / `viewDidLayoutSubviews` | cheap, idempotent adjustments; may run many times |
| `updateProperties()` (iOS 26+) | set view properties from model state; see `dataflow.md` |
| `viewDidDisappear(_:)` | stop timers, cancel work that only matters while visible |

- `viewIsAppearing(_:)` runs after the view is in the hierarchy with its traits and size, before the appearance transition draws. It is available back to iOS 13 with current Xcode. Prefer it to `viewWillAppear(_:)` for appearance setup.
- Compose screens from child controllers (`addChild`, add the view, `didMove(toParent:)`) instead of one large controller. Remove with `willMove(toParent: nil)`, remove the view, `removeFromParent()`.

## Custom views

- Override `intrinsicContentSize` for views with a natural size, and call `invalidateIntrinsicContentSize()` when it changes.
- Put constraint changes in `updateConstraints()` (call `super` last) when many inputs affect them, and request a pass with `setNeedsUpdateConstraints()`.
- `layoutSubviews()` must not change the view's own size or its superview's layout; that loops. The launch argument `-UIViewLayoutFeedbackLoopDebuggingThreshold 100` reports layout loops.
- `sizeThatFits(_:)` serves frame-based callers; keep it consistent with the constraints.

## Review checks

1. No constraints rebuilt during layout; constants changed instead.
2. Scroll views fill the view and rely on adjusted insets.
3. Keyboard handled by `keyboardLayoutGuide`.
4. Nothing sized from the screen, the idiom or the orientation.
5. Setup that needs size or traits in `viewIsAppearing(_:)`, not `viewDidLoad`.
