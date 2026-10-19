# Traits, appearance and environment

Traits describe the environment a view lives in: size classes, text size, color scheme, display scale, layout direction, and your own custom values. They flow down from the window scene through controllers and views.

## Reading traits

- Read `self.traitCollection` on the view or controller at the moment you need a value, inside an update method. Do not cache trait values in properties or ivars.
- `[UITraitCollection currentTraitCollection]` is set during trait-tracked methods and during `-performAsCurrentTraitCollection:`. Use it when resolving dynamic colors or images outside a view method.

## Responding to changes

On iOS 18 and later, UIKit tracks traits read inside these methods and reruns them on change:

- `UIView`: `layoutSubviews`, `updateConstraints`, `drawRect:`, `updateProperties` (iOS 26)
- `UIViewController`: `viewWillLayoutSubviews`, `viewDidLayoutSubviews`, `updateViewConstraints`, `updateContentUnavailableConfigurationUsingState:`, `updateProperties` (iOS 26)
- cells and buttons: `updateConfigurationUsingState:`, `configurationUpdateHandler`
- compositional layout section providers

So most code needs no registration at all: read the trait in one of those methods. This tracking belongs to UIKit's update cycle and applies to Objective-C code the same way as to Swift (it is separate from Swift Observation; see `dataflow.md`).

For work outside those methods, register (iOS 17+). `-traitCollectionDidChange:` is deprecated.

Wrong:

```objc
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previous.preferredContentSizeCategory]) {
        [self rebuildAttributedText];
    }
}
```

Right:

```objc
self.sizeRegistration = [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class]
                                          withHandler:^(__kindof id<UITraitEnvironment> env, UITraitCollection *previous) {
    [(MyView *)env rebuildAttributedText];      // the first parameter is the object itself: no weakSelf needed
}];
```

- The handler runs only for the listed traits (`UITrait` is a `Class<UITraitDefinition>`: pass `UITraitHorizontalSizeClass.class`, `UITraitUserInterfaceStyle.class`, and so on). Ready-made sets: `+[UITraitCollection systemTraitsAffectingColorAppearance]` and `systemTraitsAffectingImageLookup`.
- The handler form passes the environment (the view or controller) in, so use that parameter instead of capturing `self`: the view owns the registration token, so a block that captured `self` strongly would be a cycle.
- Target-action forms: `-registerForTraitChanges:withTarget:action:` (the action takes the environment and the previous collection) and `-registerForTraitChanges:withAction:`.
- Keep the returned `id<UITraitChangeRegistration>` only to unregister early with `-unregisterForTraitChanges:`.

## Overriding traits

`traitOverrides` (iOS 17+, an `id<UITraitOverrides>`) on a view, view controller, presentation controller or window scene changes traits for that object and everything below it.

```objc
readerViewController.traitOverrides.userInterfaceStyle = UIUserInterfaceStyleDark;
previewContainer.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraLarge;
```

- It replaces `overrideTraitCollection` and `-setOverrideTraitCollection:forChildViewController:`, both deprecated.
- Remove an override with `-removeTrait:`; check with `-containsTrait:` (pass a trait class such as `UITraitUserInterfaceStyle.class`).
- Prefer overrides on the smallest subtree that needs them.

## Custom traits

Pass app-wide values down the hierarchy with a custom trait instead of threading them through initializers or reading a global.

```objc
typedef NS_ENUM(NSInteger, ListDensity) { ListDensityRegular, ListDensityCompact };

@interface ListDensityTrait : NSObject <UINSIntegerTraitDefinition>
@end

@implementation ListDensityTrait
+ (NSInteger)defaultValue { return ListDensityRegular; }
+ (NSString *)identifier { return @"com.example.listDensity"; }
+ (NSString *)name { return @"List Density"; }
+ (BOOL)affectsColorAppearance { return NO; }
@end

// set high in the tree
[windowScene.traitOverrides setNSIntegerValue:ListDensityCompact forTrait:ListDensityTrait.class];

// read low in the tree, inside a tracked method
- (void)layoutSubviews {
    [super layoutSubviews];
    ListDensity density = (ListDensity)[self.traitCollection valueForNSIntegerTrait:ListDensityTrait.class];
    self.stack.spacing = density == ListDensityCompact ? 4 : 10;
}
```

- The protocol is `UINSIntegerTraitDefinition` for integers and enums, `UICGFloatTraitDefinition` for `CGFloat` (`setCGFloatValue:forTrait:`, `valueForCGFloatTrait:`) and `UIObjectTraitDefinition` for reference values (`setObject:forTrait:`, `objectForTrait:`); the object form needs `isEqual:` and should be immutable. Use it sparingly.
- A trait definition is a class whose class properties supply `defaultValue`, `identifier`, `name` and `affectsColorAppearance`. Use a reverse-DNS `identifier`.
- Keep values small; changes are compared to decide what reruns.
- Set `affectsColorAppearance` to `YES` only if the trait changes how colors resolve; it costs extra work on every change.
- Add a small category on `UITraitCollection` (`-listDensity`) and on `UIMutableTraits` so call sites do not repeat the class and cast.

## Colors and materials

- Use semantic system colors: `[UIColor labelColor]`, `secondaryLabelColor`, `systemBackgroundColor`, `secondarySystemGroupedBackgroundColor`, `separatorColor`, `tintColor`, or asset catalog colors with dark and increased-contrast variants (`[UIColor colorNamed:]`). They resolve per trait automatically.
- Dynamic colors in code: `[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) { return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light; }]`.
- `CGColor` does not update with traits. When setting `layer.borderColor` or `layer.shadowColor`, resolve with `[color resolvedColorWithTraitCollection:self.traitCollection].CGColor` inside a trait-tracked method.
- `tintColor` flows down the view hierarchy. Set it on the window or a container, not on every control. Views get `-tintColorDidChange` when it changes, including when a sheet dims them.

Wrong:

```objc
- (void)awakeFromNib {
    [super awakeFromNib];
    self.layer.borderColor = [UIColor separatorColor].CGColor;     // resolved once, stays light in dark mode
}
```

Right:

```objc
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.borderColor = [[UIColor separatorColor] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}
```

### Liquid Glass (iOS 26+)

- Standard bars, tab bars, toolbars, sheets, menus and controls adopt the glass material automatically when built with the iOS 26 SDK. Remove custom bar backgrounds that hide it.
- Custom glass surfaces: a `UIVisualEffectView` with a `UIGlassEffect` (set `interactive` for touch response, `tintColor` for tint). Group several glass views in a `UIVisualEffectView` with `UIGlassContainerEffect` so they blend and merge by `spacing`. These classes do not exist before iOS 26: guard with `@available(iOS 26.0, *)` and fall back to a system blur or a plain background.
- Buttons: `+[UIButtonConfiguration glassButtonConfiguration]`, `+prominentGlassButtonConfiguration`, and the clear variants declared next to them in `UIButtonConfiguration.h`.
- Use glass for controls that float above content, not for content itself, and not inside every cell.
- `UIBackgroundExtensionView` extends content (an image at the top of a screen) under a sidebar or inspector so it shows through the glass.
- When accessibility settings reduce transparency or increase contrast, the system adjusts glass. Do not fight it with custom alpha.

## Display scale and screen

- Pixel math uses `self.traitCollection.displayScale`, never `[UIScreen mainScreen].scale`. `+[UIScreen mainScreen]` is deprecated in the iOS 26 SDK.
- The screen a view is on: `self.view.window.windowScene.screen`. It can change when a window moves to another display.
- Hairlines: `1.0 / self.traitCollection.displayScale`.

## Appearance proxies

`UIAppearance` (`+appearanceWhenContainedInInstancesOfClasses:`) applies styling broadly but is applied at view insertion time and is hard to trace. Prefer configurations, tint and custom traits. Bar appearance belongs on navigation items (see `navigation-and-bars.md`).

## Review checks

1. No `-traitCollectionDidChange:`; traits read in tracked methods or registered explicitly.
2. No cached trait values.
3. `CGColor` values resolved with the current traits.
4. Custom environment values passed as custom traits, not globals.
5. No `+[UIScreen mainScreen]`.
6. iOS 26 classes behind `@available`.
