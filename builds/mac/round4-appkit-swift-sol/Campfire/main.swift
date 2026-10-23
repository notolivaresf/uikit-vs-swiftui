import AppKit

let launchTime = ProcessInfo.processInfo.systemUptime
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
