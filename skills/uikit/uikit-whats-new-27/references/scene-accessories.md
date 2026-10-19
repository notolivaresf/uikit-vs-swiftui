# Scene accessories and external displays

## External display content is no longer automatic

With the iOS 27 SDK, the system no longer offers `windowExternalDisplayNonInteractive` scenes on its own. An app that showed a presentation, a scoreboard or a video on a connected display by answering `application(_:configurationForConnecting:options:)` for that role stops getting those scenes. It must ask for them through a scene accessory registered by a view controller.

Wrong (no longer called for the non-interactive role with the iOS 27 SDK):

```swift
func application(_ application: UIApplication,
                 configurationForConnecting session: UISceneSession,
                 options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    if session.role == .windowExternalDisplayNonInteractive {
        let config = UISceneConfiguration(name: "External", sessionRole: session.role)
        config.delegateClass = ExternalSceneDelegate.self
        return config
    }
    // ...
}
```

Right: the view controller that owns the content registers an accessory.

```swift
final class SlideshowViewController: UIViewController {
    private var externalRegistration: UISceneAccessoryRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard #available(iOS 27, *) else { return }
        let config = UISceneConfiguration(name: "External",
                                          sessionRole: .windowExternalDisplayNonInteractive)
        config.delegateClass = ExternalSceneDelegate.self
        externalRegistration = registerSceneAccessory(
            .externalNonInteractive(sceneConfiguration: config))
    }

    func setPresenting(_ presenting: Bool) {
        externalRegistration?.isEnabled = presenting
    }
}
```

The API (iOS 27, iOS and iPadOS and Mac Catalyst):

- `UIViewController.registerSceneAccessory(_:) -> UISceneAccessoryRegistration` registers an accessory configuration tied to that view controller.
- `UISceneAccessory.externalNonInteractive(sceneConfiguration:)` and `externalNonInteractive(sceneConfiguration:userInfo:)` create one for non-interactive content on an external display. Use `userInfo` to tell the external scene what to show.
- `UISceneAccessoryRegistration.isEnabled` (read and write) says whether the accessory's content should be displayed now.
- `UISceneAccessoryRegistration.isAvailable` (read only) says whether the system can display it at all (for example, whether a display is connected).

Design rules:

- Register from the view controller whose content goes to the other display, not from the app delegate. The registration belongs to that screen.
- Keep the registration in a property; you need it to switch `isEnabled`.
- Drive any "Show on display" control from `isAvailable`.
- The external scene's delegate still builds its own window with `UIWindow(windowScene:)` and reads its size from the scene, never from `UIScreen.main`.
- Pass identifiers through `userInfo`, then load the model in the external scene; do not pass views.

## Camera capture accessory (iOS 27.1)

iOS 27.1 adds a second accessory: content on the outer display of a foldable iPhone (Apple's docs name iPhone Duo) while the device is open, the app is in the foreground and a camera capture session is running. A use: a framing preview or a countdown for the person being photographed.

- `UISceneAccessory.cameraCapture(sceneConfiguration:)` and `cameraCapture(sceneConfiguration:userInfo:)` (iOS 27.1; iOS, iPadOS, Mac Catalyst).
- Scenes created from it have the session role `UISceneSession.Role.windowCameraCaptureAccessory`.

```swift
if #available(iOS 27.1, *) {
    let config = UISceneConfiguration(name: "Subject Preview",
                                      sessionRole: .windowCameraCaptureAccessory)
    config.delegateClass = SubjectPreviewSceneDelegate.self
    cameraRegistration = registerSceneAccessory(.cameraCapture(sceneConfiguration: config))
}
```

Register it from the capture screen. The content appears only while all the conditions hold, so the scene must cope with being connected and disconnected as the session starts and stops.

## Checks

1. No code depends on the system offering `windowExternalDisplayNonInteractive` by itself.
2. Registrations stored and toggled with `isEnabled`; UI gated on `isAvailable`.
3. Accessory scenes size from their own scene.
4. 27.0 and 27.1 APIs behind matching `#available` checks.

<!-- sources: https://developer.apple.com/documentation/uikit/uiviewcontroller/registersceneaccessory(_:), https://developer.apple.com/documentation/uikit/uisceneaccessory, https://developer.apple.com/documentation/uikit/uisceneaccessoryregistration, https://developer.apple.com/documentation/uikit/uiscenesession/role-swift.struct/windowcameracaptureaccessory, https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes, https://developer.apple.com/documentation/updates/uikit -->
