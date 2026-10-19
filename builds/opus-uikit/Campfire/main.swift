import UIKit

/// First line of the app's own code: the launch "ms" in the debug bar is measured from here.
let appLaunchTime = CACurrentMediaTime()

// Build the 50,000 messages while UIKit starts up.
DatasetPreload.start()

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
