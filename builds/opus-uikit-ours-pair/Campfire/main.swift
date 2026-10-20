import UIKit

/// The first line of the app's own code: the launch "ms" in the debug bar counts from here.
let appLaunchUptime = ProcessInfo.processInfo.systemUptime

// Build the 50,000 messages while UIKit sets up the app and its scene.
DatasetLoader.start()

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
