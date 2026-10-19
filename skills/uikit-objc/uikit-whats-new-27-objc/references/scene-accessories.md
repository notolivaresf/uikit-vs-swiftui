# Scene accessories and external displays

## External display content is no longer automatic

With the iOS 27 SDK, the system no longer offers external-display non-interactive scenes (`UIWindowSceneSessionRoleExternalDisplayNonInteractive`) on its own. An app that showed a presentation, a scoreboard or a video on a connected display by answering `application:configurationForConnectingSceneSession:options:` for that role stops getting those scenes. It must ask for them through a scene accessory registered by a view controller.

Wrong (no longer called for the non-interactive role with the iOS 27 SDK):

```objc
- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if ([session.role isEqualToString:UIWindowSceneSessionRoleExternalDisplayNonInteractive]) {
        UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"External" sessionRole:session.role];
        config.delegateClass = [ExternalSceneDelegate class];
        return config;
    }
    // ...
}
```

Right: the view controller that owns the content registers an accessory.

```objc
@interface SlideshowViewController ()
@property (nonatomic, strong, nullable) UISceneAccessoryRegistration *externalRegistration;
@end

@implementation SlideshowViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 27.0, *)) {
        UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"External"
                                                                      sessionRole:UIWindowSceneSessionRoleExternalDisplayNonInteractive];
        config.delegateClass = [ExternalSceneDelegate class];
        self.externalRegistration = [self registerSceneAccessory:
            [UISceneAccessory externalNonInteractiveSceneAccessoryWithConfiguration:config]];
    }
}

- (void)setPresenting:(BOOL)presenting {
    if (@available(iOS 27.0, *)) { self.externalRegistration.enabled = presenting; }
}
@end
```

The API (iOS 27, iOS and iPadOS and Mac Catalyst):

- `-[UIViewController registerSceneAccessory:]` returns a `UISceneAccessoryRegistration` tied to that view controller.
- `+[UISceneAccessory externalNonInteractiveSceneAccessoryWithConfiguration:]` and `...WithConfiguration:userInfo:` create one for non-interactive content on an external display. Use `userInfo` to tell the external scene what to show.
- `UISceneAccessoryRegistration.enabled` (read and write; the getter is `isEnabled`) says whether the accessory's content should be displayed now.
- `UISceneAccessoryRegistration.available` (read only; the getter is `isAvailable`) says whether the system can display it at all (for example, whether a display is connected).

Design rules:

- Register from the view controller whose content goes to the other display, not from the app delegate. The registration belongs to that screen.
- Keep the registration in a `strong` property; you need it to switch `enabled`.
- Drive any "Show on display" control from `available`.
- The external scene's delegate still builds its own window with `-initWithWindowScene:` and reads its size from the scene, never from the main screen.
- Pass identifiers through `userInfo`, then load the model in the external scene; do not pass views.

## Camera capture accessory (iOS 27.1)

iOS 27.1 adds a second accessory: content on the outer display of a foldable iPhone (Apple's docs name iPhone Duo) while the device is open, the app is in the foreground and a camera capture session is running. A use: a framing preview or a countdown for the person being photographed.

- `+[UISceneAccessory cameraCaptureSceneAccessoryWithConfiguration:]` and `...WithConfiguration:userInfo:` (iOS 27.1).
- Scenes created from it have the session role `UIWindowSceneSessionRoleCameraCaptureAccessory`.

```objc
if (@available(iOS 27.1, *)) {
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Subject Preview"
                                                                  sessionRole:UIWindowSceneSessionRoleCameraCaptureAccessory];
    config.delegateClass = [SubjectPreviewSceneDelegate class];
    self.cameraRegistration = [self registerSceneAccessory:
        [UISceneAccessory cameraCaptureSceneAccessoryWithConfiguration:config]];
}
```

Register it from the capture screen. The content appears only while all the conditions hold, so the scene must cope with being connected and disconnected as the session starts and stops.

## Checks

1. No code depends on the system offering the external-display non-interactive role by itself.
2. Registrations stored and toggled with `enabled`; UI gated on `available`.
3. Accessory scenes size from their own scene.
4. 27.0 and 27.1 APIs behind matching `@available` checks.

<!-- sources: Objective-C declarations on Apple's pages for -[UIViewController registerSceneAccessory:], UISceneAccessory (external and camera capture factories), UISceneAccessoryRegistration enabled and available, UIWindowSceneSessionRoleCameraCaptureAccessory, UIWindowSceneSessionRoleExternalDisplayNonInteractive; iOS 27 release notes. -->
