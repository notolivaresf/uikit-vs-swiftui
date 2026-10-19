# Resizable apps

In iOS 27, iPhone apps are freely resizable in two places: iPhone Mirroring on a Mac, and iPhone-only apps running on iPad. iPad apps already resize, and they move between the device and external displays. An app built with the iOS 27 SDK must lay out for any scene size at any time.

Four things to audit: the scene life cycle (see `app-lifecycle.md`), `UIScreen.main`, idiom checks and orientation checks.

## Do not use the main screen

The screen a scene is on can change: a mirrored iPhone app, an iPad app moved to an external display. `UIScreen.main` (deprecated in iOS 26) always describes the device's built-in screen, so it gives the wrong answer in exactly these cases.

Wrong:

```swift
let scale = UIScreen.main.scale
let width = UIScreen.main.bounds.width
```

Right, in order of preference:

1. Do not need the screen. Scale comes from traits; space comes from your own bounds.

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    let scale = traitCollection.displayScale     // tracked: a change calls layoutSubviews again
    let width = bounds.width
    // ...
}
```

2. When code needs a screen, take it from the scene, or pass it in.

```swift
let screen = view.window?.windowScene?.screen

func thumbnail(for image: UIImage, screen: UIScreen) -> UIImage { /* ... */ }
```

Traits are tracked automatically in `layoutSubviews()`, `updateProperties()`, `draw(_:)`, `viewWillLayoutSubviews()` and other update methods: read a trait there and UIKit calls the method again when it changes. Where you cache something derived from a trait outside those methods, register for the change:

```swift
registerForTraitChanges([UITraitDisplayScale.self]) { (view: GalleryView, _: UITraitCollection) in
    view.thumbnailCache.removeAll()
}
```

Views and view controllers have sensible trait values even before they join a window.

## Space comes from the view, not the screen

- In a view controller, use `view.bounds.size` in `viewDidLayoutSubviews()` or `viewWillTransition(to:with:)`.
- In a view, use `bounds` or the superview's bounds in `layoutSubviews()`.
- For the whole scene, use `windowScene.effectiveGeometry` and watch changes in the window scene delegate:

```swift
func windowScene(_ windowScene: UIWindowScene,
                 didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
    let available = windowScene.effectiveGeometry.coordinateSpace.bounds
    // resize a game surface, update a cache keyed on size
}
```

Layout from your own view keeps a screen correct inside a split view, a sheet or a popover too.

## Idiom is not a layout input

An iPhone app running on iPad or in iPhone Mirroring keeps the phone idiom while being fully resizable. `traitCollection.userInterfaceIdiom == .pad` no longer means "lots of space", and `.phone` no longer means "narrow".

Wrong:

```swift
let columns = traitCollection.userInterfaceIdiom == .pad ? 3 : 1
```

Right:

```swift
let columns = traitCollection.horizontalSizeClass == .regular ? 3 : 1
// or, finer: from the layout environment's container width
let columns = max(1, Int(environment.container.effectiveContentSize.width / 320))
```

Use idiom only for things that really depend on the input or platform conventions, never for sizes.

## Orientation is not a layout input

In iOS 27, the supported interface orientations are a preference to the system. They are ignored in resizable environments. In iPhone Mirroring the app always runs in portrait orientation, whatever the window's aspect ratio.

Wrong:

```swift
if view.window?.windowScene?.effectiveGeometry.interfaceOrientation.isLandscape == true {
    stack.axis = .horizontal
}
```

Right:

```swift
stack.axis = traitCollection.verticalSizeClass == .compact ? .horizontal : .vertical
// or compare view.bounds.width and height
```

Specific changes with the iOS 27 SDK:

- iPad: an iPad app whose `UISupportedInterfaceOrientations` lacks some of the four orientations is still continuously resizable; orientations are no longer a condition for it.
- iPad: an iPhone-only app ignores supported orientations after the user first resizes its window. Its layout must also hold when the iPad is in an orientation the app does not list.
- iPhone Mirroring: supported orientations are honored until the user starts resizing; after that the scene can take any size.

Rotation is an animated bounds change. Handle it in `viewWillTransition(to:with:)` and layout, not by reading orientation.

## Full-screen apps and games: discrete resizing

`UIRequiresFullScreen` is honored on iPhone in resizable environments starting in iOS 27, and it no longer opts an app out of resizing. It turns on discrete resizing:

- Each resize is delivered as a change to a new `UIScreen` with new bounds, not as a stream of continuous size updates.
- The supported orientations are honored.
- On iPad, the bounds of `UIScreen.main` stay fixed once the screen connects; the scene moves to a new screen instead.

So a game that sets `UIRequiresFullScreen` must handle a screen change: re-read the scene's screen and effective geometry, and rebuild render targets at the new size and scale.

```swift
func windowScene(_ windowScene: UIWindowScene,
                 didUpdateEffectiveGeometry previous: UIWindowScene.Geometry) {
    let size = windowScene.effectiveGeometry.coordinateSpace.bounds.size
    renderer.resize(to: size, scale: windowScene.traitCollection.displayScale)
}
```

## Presented view controllers inherit traits from their view's superviews

With the iOS 27 SDK, a presented view controller gets its trait collection by walking up its view's superview chain through the views of the presentation, instead of taking traits straight from the presentation controller.

- Most apps need no change.
- A custom `UIPresentationController` that overrides traits for the presented controller should set them where the walk will find them: `traitOverrides` on the presentation's container or intermediate views, or on the presented view controller itself.
- A presented controller that read `presentationController?.traitCollection` to decide layout should read its own `traitCollection`.

## Status bar accessors

The status bar accessors on `UIApplication` (`statusBarFrame`, `statusBarOrientation`, `statusBarStyle`, `isStatusBarHidden`) are long deprecated. With the iOS 27 SDK they may return NaN or nil-like values. Replace them:

- frame and hidden state: `windowScene.statusBarManager`,
- orientation: size classes or `effectiveGeometry`,
- style: `preferredStatusBarStyle` on the view controller.

## Testing

- Xcode 27's Device Hub app and Xcode Previews have a resize mode: drag the device edges to any size.
- Test iPhone Mirroring on macOS 27 and an iPhone app on a real iPad.
- Check the narrowest and widest sizes, very short heights, and the largest text size together.

## Checks

1. No `UIScreen.main`, no `userInterfaceIdiom` or orientation in layout code.
2. Sizes from bounds, size classes or effective geometry.
3. Games with `UIRequiresFullScreen` rebuild on a screen change.
4. Custom presentation controllers pass traits through views.

<!-- sources: https://developer.apple.com/videos/play/wwdc2026/278/, https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes, https://developer.apple.com/documentation/uikit/uiscreen/main -->
