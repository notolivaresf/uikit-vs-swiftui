import UIKit
import CampfireKit

// The benchmark starts before UIApplication or any app-owned initialization.
let appLaunchTime = CACurrentMediaTime()
// Generate the room while UIKit connects the scene and creates its chrome.
let initialRoomData = Task.detached(priority: .userInitiated) {
    let dataset = FakeData.generate(size: .k50)
    return (dataset, FakeLiveFeed(dataset: dataset))
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))

@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Campfire", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = RoomViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
