import UIKit
import CampfireKit

/// Builds the 50,000 messages off the main thread before the first view controller loads.
enum DataBoot {
    private static var dataset: Dataset?
    private static var feed: FakeLiveFeed?
    private static let group = DispatchGroup()

    static func start() {
        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let d = FakeData.generate(size: .k50)
            dataset = d
            group.leave()
            let f = FakeLiveFeed(dataset: d)
            DispatchQueue.main.async { feed = f }
        }
    }

    static func whenReady(_ body: @escaping (Dataset) -> Void) {
        group.notify(queue: .main) { body(dataset!) }
    }

    static func liveFeed() -> FakeLiveFeed? {
        if feed == nil, let d = dataset { feed = FakeLiveFeed(dataset: d) }
        return feed
    }
}

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
        let w = UIWindow(windowScene: ws)
        let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
        w.rootViewController = RoomViewController(benchmark: benchmark)
        w.makeKeyAndVisible()
        window = w
    }
}
