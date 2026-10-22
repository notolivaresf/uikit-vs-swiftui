import AppKit

/// When the app's own code starts running; the state label's launch "ms" counts from here.
let launchStart = CACurrentMediaTime()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = SmokeViewController()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 393, height: 852),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Campfire"
        window.isRestorable = false
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 393, height: 852))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
        controller.windowShown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
