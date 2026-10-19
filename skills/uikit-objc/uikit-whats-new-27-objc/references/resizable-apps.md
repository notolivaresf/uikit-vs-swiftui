# Resizable apps

In iOS 27, iPhone apps are freely resizable in two places: iPhone Mirroring on a Mac, and iPhone-only apps running on iPad. iPad apps already resize, and they move between the device and external displays. An app built with the iOS 27 SDK must lay out for any scene size at any time.

Four things to audit: the scene life cycle (see `app-lifecycle.md`), `+[UIScreen mainScreen]`, idiom checks and orientation checks.

## Do not use the main screen

The screen a scene is on can change: a mirrored iPhone app, an iPad app moved to an external display. `+[UIScreen mainScreen]` (deprecated in iOS 26) always describes the device's built-in screen, so it gives the wrong answer in exactly these cases.

Wrong:

```objc
CGFloat scale = [UIScreen mainScreen].scale;
CGFloat width = CGRectGetWidth([UIScreen mainScreen].bounds);
```

Right, in order of preference:

1. Do not need the screen. Scale comes from traits; space comes from your own bounds.

```objc
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat scale = self.traitCollection.displayScale;     // tracked: a change calls layoutSubviews again
    CGFloat width = CGRectGetWidth(self.bounds);
    // ...
}
```

2. When code needs a screen, take it from the scene, or pass it in.

```objc
UIScreen *screen = self.view.window.windowScene.screen;

- (UIImage *)thumbnailForImage:(UIImage *)image onScreen:(UIScreen *)screen { /* ... */ }
```

Traits are tracked automatically in `layoutSubviews`, `updateProperties`, `drawRect:`, `viewWillLayoutSubviews` and other update methods: read a trait there and UIKit calls the method again when it changes. Where you cache something derived from a trait outside those methods, register for the change:

```objc
self.scaleRegistration = [self registerForTraitChanges:@[UITraitDisplayScale.class]
    withHandler:^(__kindof id<UITraitEnvironment> env, UITraitCollection *previous) {
    [((GalleryView *)env).thumbnailCache removeAllObjects];
}];
```

Views and view controllers have sensible trait values even before they join a window.

## Space comes from the view, not the screen

- In a view controller, use `self.view.bounds.size` in `viewDidLayoutSubviews` or `viewWillTransitionToSize:withTransitionCoordinator:`.
- In a view, use `bounds` or the superview's bounds in `layoutSubviews`.
- For the whole scene, use `windowScene.effectiveGeometry` (a `UIWindowSceneGeometry`) and watch changes in the window scene delegate:

```objc
- (void)windowScene:(UIWindowScene *)windowScene
didUpdateEffectiveGeometry:(UIWindowSceneGeometry *)previousEffectiveGeometry {
    CGRect available = windowScene.effectiveGeometry.coordinateSpace.bounds;
    // resize a game surface, update a cache keyed on size
}
```

Layout from your own view keeps a screen correct inside a split view, a sheet or a popover too.

## Idiom is not a layout input

An iPhone app running on iPad or in iPhone Mirroring keeps the phone idiom while being fully resizable. `userInterfaceIdiom == UIUserInterfaceIdiomPad` no longer means "lots of space", and `...Phone` no longer means "narrow".

Wrong:

```objc
NSInteger columns = self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad ? 3 : 1;
```

Right:

```objc
NSInteger columns = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ? 3 : 1;
// or, finer: from the layout environment's container width
NSInteger columns = MAX(1, (NSInteger)(environment.container.effectiveContentSize.width / 320.0));
```

Use idiom only for things that really depend on the input or platform conventions, never for sizes.

## Orientation is not a layout input

In iOS 27, the supported interface orientations are a preference to the system. They are ignored in resizable environments. In iPhone Mirroring the app always runs in portrait orientation, whatever the window's aspect ratio.

Wrong:

```objc
if (UIInterfaceOrientationIsLandscape(self.view.window.windowScene.effectiveGeometry.interfaceOrientation)) {
    self.stack.axis = UILayoutConstraintAxisHorizontal;
}
```

Right:

```objc
self.stack.axis = self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact
    ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
// or compare self.view.bounds width and height
```

Specific changes with the iOS 27 SDK:

- iPad: an iPad app whose `UISupportedInterfaceOrientations` lacks some of the four orientations is still continuously resizable; orientations are no longer a condition for it.
- iPad: an iPhone-only app ignores supported orientations after the user first resizes its window. Its layout must also hold when the iPad is in an orientation the app does not list.
- iPhone Mirroring: supported orientations are honored until the user starts resizing; after that the scene can take any size.

Rotation is an animated bounds change. Handle it in `viewWillTransitionToSize:withTransitionCoordinator:` and layout, not by reading orientation. Do not override `supportedInterfaceOrientations` to dodge layout work.

## Full-screen apps and games: discrete resizing

`UIRequiresFullScreen` is honored on iPhone in resizable environments starting in iOS 27, and it no longer opts an app out of resizing. It turns on discrete resizing:

- Each resize is delivered as a change to a new `UIScreen` with new bounds, not as a stream of continuous size updates.
- The supported orientations are honored.
- On iPad, the bounds of the main screen stay fixed once the screen connects; the scene moves to a new screen instead.

So a game that sets `UIRequiresFullScreen` must handle a screen change: re-read the scene's screen and effective geometry, and rebuild render targets at the new size and scale.

```objc
- (void)windowScene:(UIWindowScene *)windowScene
didUpdateEffectiveGeometry:(UIWindowSceneGeometry *)previous {
    CGSize size = windowScene.effectiveGeometry.coordinateSpace.bounds.size;
    [self.renderer resizeToSize:size scale:windowScene.traitCollection.displayScale];
}
```

## Presented view controllers inherit traits from their view's superviews

With the iOS 27 SDK, a presented view controller gets its trait collection by walking up its view's superview chain through the views of the presentation, instead of taking traits straight from the presentation controller.

- Most apps need no change.
- A custom `UIPresentationController` that overrides traits for the presented controller should set them where the walk will find them: `traitOverrides` on the presentation's container or intermediate views, or on the presented view controller itself.
- A presented controller that read `self.presentationController.traitCollection` to decide layout should read its own `traitCollection`.

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

1. No `mainScreen`, no `userInterfaceIdiom` or orientation in layout code.
2. Sizes from bounds, size classes or effective geometry.
3. Games with `UIRequiresFullScreen` rebuild on a screen change.
4. Custom presentation controllers pass traits through views.

<!-- sources: WWDC26 session 278, iOS 27 release notes, +[UIScreen mainScreen] Objective-C declaration. Selectors checked against the iOS 26.4 SDK headers. -->
