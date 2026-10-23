import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var room: RoomController!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("-selfTest") {
            NSApp.appearance = NSAppearance(named: ProcessInfo.processInfo.arguments.contains("-dark") ? .darkAqua : .aqua)
        }
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Campfire", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Quit Campfire", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; menu.addItem(editItem)
        NSApplication.shared.mainMenu = menu
        room = RoomController()
        let viewItem = NSMenuItem(); let viewMenu = NSMenu(title: "View")
        let larger = NSMenuItem(title: "Larger Text", action: #selector(RoomController.textSize), keyEquivalent: "+"); larger.target = room
        let defaultSize = NSMenuItem(title: "Default Text Size", action: #selector(RoomController.defaultTextSize), keyEquivalent: "0"); defaultSize.target = room
        viewMenu.addItem(larger); viewMenu.addItem(defaultSize); viewItem.submenu = viewMenu; menu.addItem(viewItem)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 393, height: 852), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Campfire"; window.contentViewController = room
        window.setContentSize(NSSize(width: 393, height: 852))
        window.contentMinSize = NSSize(width: 393, height: 600)
        window.isRestorable = false; window.delegate = self
        room.root.layoutSubtreeIfNeeded(); room.resizeRoom()
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.arguments.contains("-selfTest") {
            DispatchQueue.main.async { SmokeCheck.run(app: self) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowDidEndLiveResize(_ notification: Notification) { room.updateState() }
}
