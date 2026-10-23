import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var controller: RoomController!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Never bring back an earlier window size or position.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
        controller = RoomController(benchmark: benchmark)

        let size = NSSize(width: 393, height: 852)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Campfire"
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 393, height: 600)
        window.delegate = self
        window.contentView = controller.rootView
        window.setContentSize(size)
        window.center()
        controller.start()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.didShowWindow()
        DevSnapshot.runIfRequested(controller: controller, window: window)
        DevScript.runIfRequested(controller: controller, window: window)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    func applicationShouldSaveApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldRestoreApplicationState(_ sender: NSApplication) -> Bool { false }

    func windowDidEndLiveResize(_ notification: Notification) { controller.resizeEnded() }

    @objc func biggerText(_ sender: Any?) { controller.changeTextSize(by: 1) }
    @objc func smallerText(_ sender: Any?) { controller.changeTextSize(by: -1) }
    @objc func actualSizeText(_ sender: Any?) { controller.resetTextSize() }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Campfire", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Campfire", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Campfire", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Bigger Text", action: #selector(biggerText(_:)), keyEquivalent: "+").target = self
        let equals = viewMenu.addItem(withTitle: "Bigger Text", action: #selector(biggerText(_:)), keyEquivalent: "=")
        equals.target = self
        equals.isAlternate = false
        equals.isHidden = true
        equals.allowsKeyEquivalentWhenHidden = true
        viewMenu.addItem(withTitle: "Smaller Text", action: #selector(smallerText(_:)), keyEquivalent: "-").target = self
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(actualSizeText(_:)), keyEquivalent: "0").target = self
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        return main
    }
}
