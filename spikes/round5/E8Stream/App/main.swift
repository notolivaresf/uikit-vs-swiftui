import UIKit

/// Launch timing starts at the first line of the app's own code.
let launchStart = CACurrentMediaTime()
Store.shared.startLoading()

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
