# Observation, sensor bodies and Mac Catalyst controls

## Section providers are tracked: Swift Observation only

In iOS 27, the section provider block of a `UICollectionViewCompositionalLayout` takes part in automatic observation tracking. If the block reads a property of a Swift `@Observable` object, a change to that property invalidates the layout and the section is rebuilt.

That tracking belongs to the Swift Observation framework. In Objective-C it does nothing for your models: reading an `NSObject` property, a KVO-compliant property or any Objective-C object inside the provider block registers no dependency, and no Objective-C selector turns it on. Do not write a provider that relies on it. (Trait reads, for example `environment.traitCollection`, stay tracked, as since iOS 18.)

What to do in Objective-C: invalidate the layout yourself when the setting changes, and read the setting inside the provider.

```objc
// the model calls this block (or a delegate method, or posts a notification) when columns change
__weak typeof(self) weakSelf = self;
self.settings.onChange = ^{
    [weakSelf.collectionView.collectionViewLayout invalidateLayout];
};

UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc]
    initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> environment) {
    NSInteger columns = weakSelf.settings.columns;          // plain read: not tracked in Objective-C
    return [weakSelf gridSectionWithColumns:columns environment:environment];
}];
```

Rules:

- Read only what the layout needs, and keep the provider cheap.
- Do not read data that changes often (scroll progress, download percent) in the provider; that belongs in cells.
- Item content still goes through the data source (`-reconfigureItemsWithIdentifiers:`); a layout change does not refresh cells.
- If part of the app is Swift with `@Observable` models, a Swift function that builds the section can read them and get tracking on iOS 27; the Objective-C provider calls into it. Keep the explicit invalidate path for older systems.
- Observation tracking in UIKit is on by default from iOS 26; on iOS 18 it needs the `UIObservationTrackingEnabled` `Info.plist` key. This only affects Swift reads.

## `UIView` as the motion and heading body

In iOS 27, `UIView` conforms to new body protocols from Core Motion and Core Location. Set a view as the body and the sensor data comes in that view's interface orientation, so a compass or level stays right whatever the orientation or window shape.

- `CMMotionManager.deviceMotionBody` (`id<CMBodyIdentifiable>`, nullable, iOS 27, Core Motion)
- `CLLocationManager.headingBody` (`id<CLBodyIdentifiable>`, nullable, iOS 27, Core Location)

Both are declared `retain`, so the manager holds the view; clear them when the screen goes away.

Wrong: rotating readings by hand from the interface orientation.

```objc
UIInterfaceOrientation orientation = self.view.window.windowScene.effectiveGeometry.interfaceOrientation;
heading = [self adjustHeading:rawHeading forOrientation:orientation];
```

Right:

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 27.0, *)) {
        self.motionManager.deviceMotionBody = self.compassView;
        self.locationManager.headingBody = self.compassView;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (@available(iOS 27.0, *)) {
        self.motionManager.deviceMotionBody = nil;
        self.locationManager.headingBody = nil;
    }
}
```

Use the view that shows the data (the compass dial, the map), not the window. This matters more in iOS 27 because orientation no longer tracks the window shape in resizable environments (see `resizable-apps.md`).

## Mac Catalyst: refresh control and stepper

`UIRefreshControl` and `UIStepper` are now fully supported in the Mac idiom for Mac Catalyst apps. Remove workarounds such as a separate Refresh toolbar button shown only on Mac, or a custom stepper for the Mac build, after checking the controls on macOS 27. Keep a Refresh menu command with a keyboard shortcut anyway; Mac users expect it.

## Checks

1. No Objective-C code relies on observation tracking in a section provider; an explicit invalidate path exists.
2. Sensor views set as the motion or heading body and cleared on exit.
3. Catalyst-only replacements for refresh and stepper removed.

<!-- sources: Objective-C declarations on Apple's pages for CMMotionManager deviceMotionBody and CLLocationManager headingBody; UIKit updates page and WWDC26 session 278 for section provider tracking (a Swift Observation feature). -->
