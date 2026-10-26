import UIKit
import SpikeKit

/// E2 and E3 spikes (table view): one app delegate, the variant chosen by the target's compile flags. The adapter
/// (saved heights or self-sizing) comes from the target's source list; the way the place is kept when older messages
/// load comes from the flag: none = (a) top row, PREPEND_DELTA = (b) sum of the new rows' heights,
/// PREPEND_CONTENT = (b') change in content height. The clock is touch up to the next frame.
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DebugBar.nextFrameClock = true
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = RoomViewController(adapter: TableAdapter())
        #if PREPEND_DELTA
        vc.prependAnchor = .offsetDelta
        #elseif PREPEND_CONTENT
        vc.prependAnchor = .contentDelta
        #else
        vc.prependAnchor = .topRow
        #endif
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }
}
