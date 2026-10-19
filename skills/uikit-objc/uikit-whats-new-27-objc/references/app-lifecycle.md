# App life cycle in the iOS 27 SDK

Two hard requirements arrive with the iOS 27 SDK: the scene-based life cycle and a launch screen. Both apply to any app built with the new SDK, whatever its deployment target.

## The scene life cycle is required

Apps built with the iOS 27 SDK that still use the app delegate life cycle fail to launch. The app must have a scene manifest and a scene delegate.

Wrong: the window lives on the app delegate.

```objc
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[RootViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
```

Right: the app delegate returns a scene configuration; the scene delegate owns the window.

```objc
@implementation AppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                              options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Default"
                                                                  sessionRole:connectingSceneSession.role];
    config.delegateClass = [SceneDelegate class];
    return config;
}
@end

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong, nullable) UIWindow *window;
@end

@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) { return; }
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.rootViewController = [[RootViewController alloc] init];
    [window makeKeyAndVisible];
    self.window = window;
    [self handleConnectionOptions:connectionOptions];   // URLs, user activities, shortcut items from launch
}
@end
```

`main.m` stays `UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]))`. Add `UIApplicationSceneManifest` to `Info.plist` (with `UIApplicationSupportsMultipleScenes` set to what the app supports). A configuration returned in code, as above, or a `UISceneConfigurations` entry in the manifest both work.

Move these as part of the migration:

| App delegate | Scene delegate |
|---|---|
| `applicationDidBecomeActive:` | `sceneDidBecomeActive:` |
| `applicationWillResignActive:` | `sceneWillResignActive:` |
| `applicationDidEnterBackground:` | `sceneDidEnterBackground:` |
| `applicationWillEnterForeground:` | `sceneWillEnterForeground:` |
| `application:openURL:options:` | `scene:openURLContexts:` and `connectionOptions.URLContexts` |
| `application:continueUserActivity:restorationHandler:` | `scene:continueUserActivity:` and `connectionOptions.userActivities` |
| `application:performActionForShortcutItem:completionHandler:` | `windowScene:performActionForShortcutItem:completionHandler:` and `connectionOptions.shortcutItem` |

Things that break most often during the move:

- Code that reads `[UIApplication sharedApplication].delegate.window`. Reach the window through `self.view.window` or the scene.
- Launch URLs and activities: on a cold launch they arrive in `connectionOptions`, not in the later delegate callbacks. Handle both paths.
- Work that ran once in `didFinishLaunchingWithOptions:` and touched UI. Keep process-wide setup there; move window and UI setup to the scene.
- Several scenes: anything stored as "the" window or "the" root controller becomes per scene. A singleton holding a `UIWindow *` is a bug.
- The scene delegate's `window` property must be `strong`; a weak window disappears immediately.

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

`-extendStateRestoration` and `-completeStateRestoration` on `UIScene` exist since iOS 15. When linked on the iOS 27 SDK they also extend restoration across a scene's move from background to foreground, not only at connection. Use them when restoring needs async work and the snapshot must not show until it is done.

```objc
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    // window setup...
    NSUserActivity *activity = session.stateRestorationActivity;
    if (!activity) { return; }
    [scene extendStateRestoration];
    __weak typeof(scene) weakScene = scene;
    [self restoreFromActivity:activity completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{ [weakScene completeStateRestoration]; });
    }];
}
```

Always call `-completeStateRestoration` on every path, including errors and cancellation, or the system waits for a call that never comes. Put it in the one completion block that every branch reaches.

## Scene closure confirmation

`UISceneClosureConfirmation` (iOS 27) now presents its confirmation dialog. If you set it up earlier and saw no dialog, test again on iOS 27 before adding a workaround, and remove workarounds that showed your own alert.

## Checks

1. `Info.plist` has `UIApplicationSceneManifest` and a launch screen key.
2. No UI created in `application:didFinishLaunchingWithOptions:`.
3. Launch URLs, activities and shortcut items handled from `connectionOptions`.
4. Every `extendStateRestoration` has a matching `completeStateRestoration`.

<!-- sources: Apple iOS 27 release notes, UIKit updates page, "Transitioning to the UIKit scene-based life cycle", UIScene extendStateRestoration and completeStateRestoration (Objective-C declarations), WWDC26 session 278. Selectors checked against the iOS 26.4 SDK headers. -->
