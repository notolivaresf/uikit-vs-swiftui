import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
        let w = UIWindow(windowScene: ws)
        w.rootViewController = ChatViewController(benchmark: benchmark)
        #if DEBUG
        if let f = UserDefaults.standard.string(forKey: "uvsFixtures") {
            let vc = FixtureViewController(atBottom: f == "bottom")
            vc.midRow = Int(f)
            w.rootViewController = vc
        }
        #endif
        w.makeKeyAndVisible()
        window = w
    }
}
