# App life cycle in the iOS 27 SDK

Two hard requirements arrive with the iOS 27 SDK: the scene-based life cycle and a launch screen. Both apply to any app built with the new SDK, whatever its deployment target.

## The scene life cycle is required

Apps built with the iOS 27 SDK that still use the app delegate life cycle fail to launch. The app must have a scene manifest and a scene delegate.

Wrong: the window lives on the app delegate.

```swift
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = RootViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
```

Right: the app delegate returns a scene configuration; the scene delegate owns the window.

```swift
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootViewController()
        window.makeKeyAndVisible()
        self.window = window
        handle(connectionOptions)   // URLs, user activities, shortcut items from launch
    }
}
```

Add `UIApplicationSceneManifest` to `Info.plist` (with `UIApplicationSupportsMultipleScenes` set to what the app supports). A configuration returned in code, as above, or a `UISceneConfigurations` entry in the manifest both work.

Move these as part of the migration:

| App delegate | Scene delegate |
|---|---|
| `applicationDidBecomeActive(_:)` | `sceneDidBecomeActive(_:)` |
| `applicationWillResignActive(_:)` | `sceneWillResignActive(_:)` |
| `applicationDidEnterBackground(_:)` | `sceneDidEnterBackground(_:)` |
| `applicationWillEnterForeground(_:)` | `sceneWillEnterForeground(_:)` |
| `application(_:open:options:)` | `scene(_:openURLContexts:)` and `connectionOptions.urlContexts` |
| `application(_:continue:restorationHandler:)` | `scene(_:continue:)` and `connectionOptions.userActivities` |
| `application(_:performActionFor:completionHandler:)` | `windowScene(_:performActionFor:completionHandler:)` and `connectionOptions.shortcutItem` |

Things that break most often during the move:

- Code that reads `UIApplication.shared.delegate?.window`. Reach the window through `view.window` or the scene.
- Launch URLs and activities: on a cold launch they arrive in `connectionOptions`, not in the later delegate callbacks. Handle both paths.
- Work that ran once in `didFinishLaunching` and touched UI. Keep process-wide setup there; move window and UI setup to the scene.
- Several scenes: anything stored as "the" window or "the" root controller becomes per scene.

Apple's guide: "Transitioning to the UIKit scene-based life cycle".

## A launch screen is required

iOS and iPadOS apps built with the 27.0 SDK must include a launch screen. `Info.plist` must contain one of:

- `UILaunchStoryboardName` (a launch storyboard),
- `UILaunchStoryboards` (storyboards per URL scheme or activity),
- `UILaunchScreen` (a dictionary describing a plain launch screen),
- `UILaunchScreens` (several of those).

Apps without one are rejected once the App Store accepts 27.0 SDK builds. The smallest valid setup is an empty `UILaunchScreen` dictionary, which shows the system background color:

```xml
<key>UILaunchScreen</key>
<dict/>
```

Add `UIColorName` or `UIImageName` inside it to match the first screen. A launch screen is not a splash screen: make it look like the app's first frame without content.

## State restoration extended into foreground

`UIScene.extendStateRestoration()` and `completeStateRestoration()` exist since iOS 15. When linked on the iOS 27 SDK they also extend restoration across a scene's move from `.background` to `.foregroundActive` or `.foregroundInactive`, not only at connection. Use them when restoring needs async work and the snapshot must not show until it is done.

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    // window setup...
    guard let activity = session.stateRestorationActivity else { return }
    scene.extendStateRestoration()
    Task { @MainActor in
        await restore(from: activity)
        scene.completeStateRestoration()
    }
}
```

Always call `completeStateRestoration()` on every path, including errors and cancellation, or the system waits for a call that never comes.

## Scene closure confirmation

`UISceneClosureConfirmation` now presents its confirmation dialog (a fix in iOS 27). If you set it up earlier and saw no dialog, test again on iOS 27 before adding a workaround, and remove workarounds that showed your own alert.

## Checks

1. `Info.plist` has `UIApplicationSceneManifest` and a launch screen key.
2. No UI created in `application(_:didFinishLaunchingWithOptions:)`.
3. Launch URLs, activities and shortcut items handled from `connectionOptions`.
4. Every `extendStateRestoration()` has a matching `completeStateRestoration()`.

<!-- sources: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes, https://developer.apple.com/documentation/updates/uikit, https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle, https://developer.apple.com/documentation/uikit/uiscene/extendstaterestoration(), https://developer.apple.com/documentation/uikit/uiscene/completestaterestoration(), https://developer.apple.com/videos/play/wwdc2026/278/ -->
