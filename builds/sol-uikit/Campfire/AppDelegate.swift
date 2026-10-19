import UIKit
import CampfireKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = RoomViewController(dataset: FakeData.generate(size: .k50))
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
