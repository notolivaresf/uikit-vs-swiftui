import AppKit

/// The first line of the app's own code; the debug bar's launch "ms" is measured from here.
let launchStart = CACurrentMediaTime()

// Generate the 50,000 messages while AppKit starts up.
DatasetLoader.start()

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
