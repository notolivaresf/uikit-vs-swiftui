import UIKit
import QuartzCore

/// The first line of the app's own code: launch time is measured from here to the first rows on screen.
let appLaunchStart = CACurrentMediaTime()
DataBoot.start()
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
