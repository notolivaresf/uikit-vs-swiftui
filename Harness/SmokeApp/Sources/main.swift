import UIKit

/// When the app's own code starts running; the state label's launch "ms" counts from here.
let launchStart = CACurrentMediaTime()

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
