# Traits, appearance and environment

Traits describe the environment a view lives in: size classes, text size, color scheme, display scale, layout direction, and your own custom values. They flow down from the window scene through controllers and views.

## Reading traits

- Read `traitCollection` on the view or controller at the moment you need a value, inside an update method. Do not cache trait values in stored properties.
- `UITraitCollection.current` is set during trait-tracked methods and during `performAsCurrent(_:)`. Use it when resolving dynamic colors or images outside a view method.

## Responding to changes

On iOS 18 and later, UIKit tracks traits read inside these methods and reruns them on change:

- `UIView`: `layoutSubviews()`, `updateConstraints()`, `draw(_:)`, `updateProperties()` (iOS 26)
- `UIViewController`: `viewWillLayoutSubviews()`, `viewDidLayoutSubviews()`, `updateViewConstraints()`, `updateContentUnavailableConfiguration(using:)`, `updateProperties()` (iOS 26)
- cells and buttons: `updateConfiguration(using:)`, `configurationUpdateHandler`
- compositional layout section providers

So most code needs no registration at all: read the trait in one of those methods.

For work outside those methods, register (iOS 17+). `traitCollectionDidChange(_:)` is deprecated.

Wrong:

```swift
override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    if traitCollection.preferredContentSizeCategory != previous?.preferredContentSizeCategory {
        rebuildAttributedText()
    }
}
```

Right:

```swift
registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, previous: UITraitCollection) in
    self.rebuildAttributedText()
}
```

- The handler runs only for the listed traits. Ready-made sets: `UITraitCollection.systemTraitsAffectingColorAppearance` and `systemTraitsAffectingImageLookup`.
- The handler form passes `self` in, so no `[weak self]` is needed. The registration lives as long as the object; keep the returned token only to unregister early with `unregisterForTraitChanges(_:)`.
- Target-action forms exist: `registerForTraitChanges(_:target:action:)` and `registerForTraitChanges(_:action:)`.

## Overriding traits

`traitOverrides` (iOS 17+) on a view, view controller or window scene changes traits for that object and everything below it.

```swift
readerViewController.traitOverrides.userInterfaceStyle = .dark
previewContainer.traitOverrides.preferredContentSizeCategory = .accessibilityExtraLarge
```

- It replaces `overrideTraitCollection` and `setOverrideTraitCollection(_:forChild:)`, both deprecated.
- Remove an override with `traitOverrides.remove(_:)`; check with `contains(_:)`.
- Prefer overrides on the smallest subtree that needs them.

## Custom traits

Pass app-wide values down the hierarchy with a custom trait instead of threading them through initializers or reading a global.

```swift
enum ListDensity: Int { case regular, compact }

struct ListDensityTrait: UITraitDefinition {
    static let defaultValue = ListDensity.regular
    static let affectsColorAppearance = false
}

extension UITraitCollection {
    var listDensity: ListDensity { self[ListDensityTrait.self] }
}

extension UIMutableTraits {
    var listDensity: ListDensity {
        get { self[ListDensityTrait.self] }
        set { self[ListDensityTrait.self] = newValue }
    }
}

// set high in the tree
windowScene.traitOverrides.listDensity = .compact

// read low in the tree, inside a tracked method
override func layoutSubviews() {
    super.layoutSubviews()
    stack.spacing = traitCollection.listDensity == .compact ? 4 : 10
}
```

- Value types for trait values. Keep them small and `Equatable`; changes are compared to decide what reruns.
- Set `affectsColorAppearance = true` only if the trait changes how colors resolve; it costs extra work on every change.
- Typed shortcuts for numeric traits: `UICGFloatTraitDefinition` and `UINSIntegerTraitDefinition`. `UIObjectTraitDefinition` for reference values, used sparingly.

## Colors and materials

- Use semantic system colors: `.label`, `.secondaryLabel`, `.systemBackground`, `.secondarySystemGroupedBackground`, `.separator`, `.tintColor`, or asset catalog colors with dark and increased-contrast variants. They resolve per trait automatically.
- Dynamic colors in code: `UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }`.
- `CGColor` does not update with traits. When setting `layer.borderColor` or `layer.shadowColor`, resolve with `color.resolvedColor(with: traitCollection).cgColor` inside a trait-tracked method.
- `tintColor` flows down the view hierarchy. Set it on the window or a container, not on every control. Views get `tintColorDidChange()` when it changes, including when a sheet dims them.

Wrong:

```swift
override func awakeFromNib() {
    super.awakeFromNib()
    layer.borderColor = UIColor.separator.cgColor        // resolved once, stays light in dark mode
}
```

Right:

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
}
```

### Liquid Glass (iOS 26+)

- Standard bars, tab bars, toolbars, sheets, menus and controls adopt the glass material automatically when built with the iOS 26 SDK. Remove custom bar backgrounds that hide it.
- Custom glass surfaces: a `UIVisualEffectView` with `UIGlassEffect` (set `isInteractive` for touch response, `tintColor` for tint). Group several glass views in a `UIVisualEffectView` with `UIGlassContainerEffect` so they blend and merge by `spacing`.
- Buttons: `UIButton.Configuration.glass()`, `.prominentGlass()`, `.clearGlass()`, `.prominentClearGlass()`.
- Use glass for controls that float above content, not for content itself, and not inside every cell.
- `UIBackgroundExtensionView` extends content (an image at the top of a screen) under a sidebar or inspector so it shows through the glass.
- When accessibility settings reduce transparency or increase contrast, the system adjusts glass. Do not fight it with custom alpha.

## Display scale and screen

- Pixel math uses `traitCollection.displayScale`, never `UIScreen.main.scale`. `UIScreen.main` is deprecated in the iOS 26 SDK.
- The screen a view is on: `view.window?.windowScene?.screen`. It can change when a window moves to another display.
- Hairlines: `1 / traitCollection.displayScale`.

## Appearance proxies

`UIAppearance` (`UILabel.appearance(whenContainedInInstancesOf:)`) applies styling broadly but is applied at view insertion time and is hard to trace. Prefer configurations, tint and custom traits. Bar appearance belongs on navigation items (see `navigation-and-bars.md`).

## Review checks

1. No `traitCollectionDidChange(_:)`; traits read in tracked methods or registered explicitly.
2. No cached trait values.
3. `CGColor` values resolved with the current traits.
4. Custom environment values passed as custom traits, not globals.
5. No `UIScreen.main`.
