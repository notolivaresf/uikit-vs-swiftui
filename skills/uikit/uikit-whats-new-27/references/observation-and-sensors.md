# Observation, sensor bodies and Mac Catalyst controls

## Section providers are tracked

In iOS 27, the section provider closure of a `UICollectionViewCompositionalLayout` (`UICollectionViewCompositionalLayoutSectionProvider`) takes part in automatic observation tracking. If the closure reads a property of an `@Observable` object, a change to that property invalidates the layout and the section is rebuilt.

Wrong: invalidating by hand from a model callback.

```swift
settings.onChange = { [weak self] in
    self?.collectionView.collectionViewLayout.invalidateLayout()
}
```

Right (iOS 27): read the observable value inside the provider.

```swift
@Observable final class GridSettings {
    var columns = 3
    var showsHeaders = true
}

func makeLayout(settings: GridSettings) -> UICollectionViewCompositionalLayout {
    UICollectionViewCompositionalLayout { _, environment in
        let columns = settings.columns                     // tracked
        let width = NSCollectionLayoutDimension.fractionalWidth(1.0 / CGFloat(columns))
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: width,
                                                            heightDimension: .estimated(120)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120)),
            repeatingSubitem: item, count: columns)
        let section = NSCollectionLayoutSection(group: group)
        if settings.showsHeaders {                         // tracked
            section.boundarySupplementaryItems = [header()]
        }
        return section
    }
}
```

Rules:

- Read only what the layout needs. Every observable property read in the provider becomes a reason to rebuild the whole layout.
- Do not read data that changes often (scroll progress, download percent) in the provider; that belongs in cells.
- Item content still goes through the data source (`reconfigureItems(_:)`); a layout change does not refresh cells.
- On older systems the provider is not tracked. With a deployment target below iOS 27, keep an explicit `invalidateLayout()` path behind `#available`.
- Observation tracking itself is on by default from iOS 26; on iOS 18 it needs the `UIObservationTrackingEnabled` `Info.plist` key.

## `UIView` as the motion and heading body

In iOS 27, `UIView` conforms to new body protocols from Core Motion and Core Location. Set a view as the body and the sensor data comes in that view's interface orientation, so a compass or level stays right whatever the orientation or window shape.

- `CMMotionManager.deviceMotionBody: (any CMBodyIdentifiable)?` (iOS 27, Core Motion)
- `CLLocationManager.headingBody: (any CLBodyIdentifiable)?` (iOS 27, Core Location)

Wrong: rotating readings by hand from the interface orientation.

```swift
let orientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation
heading = adjust(rawHeading, for: orientation)
```

Right:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    if #available(iOS 27, *) {
        motionManager.deviceMotionBody = compassView
        locationManager.headingBody = compassView
    }
}
```

Use the view that shows the data (the compass dial, the map), not the window. This matters more in iOS 27 because orientation no longer tracks the window shape in resizable environments (see `resizable-apps.md`).

## Mac Catalyst: refresh control and stepper

`UIRefreshControl` and `UIStepper` are now fully supported in the Mac idiom for Mac Catalyst apps. Remove workarounds such as a separate Refresh toolbar button shown only on Mac, or a custom stepper for the Mac build, after checking the controls on macOS 27. Keep a Refresh menu command with a keyboard shortcut anyway; Mac users expect it.

## Checks

1. Layout code that reads observable models does so inside the section provider, with a fallback for older systems.
2. Sensor views set as the motion or heading body.
3. Catalyst-only replacements for refresh and stepper removed.

<!-- sources: https://developer.apple.com/documentation/updates/uikit, https://developer.apple.com/documentation/uikit/uicollectionviewcompositionallayoutsectionprovider, https://developer.apple.com/documentation/coremotion/cmmotionmanager, https://developer.apple.com/documentation/corelocation/cllocationmanager, https://developer.apple.com/videos/play/wwdc2026/278/ -->
