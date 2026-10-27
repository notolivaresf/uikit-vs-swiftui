import UIKit
import CampfireKit

// Start both clocks and data creation before constructing the screen.
let launchInstant = CACurrentMediaTime()
let initialDataset = Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = launchInstant
        _ = initialDataset
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = RoomViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
