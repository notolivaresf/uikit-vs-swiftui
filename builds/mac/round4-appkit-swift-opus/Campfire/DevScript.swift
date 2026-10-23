import AppKit

/// Development aid: CF_SCRIPT="cmd;cmd;…" runs commands against the room and prints the debug state.
/// Commands: click:<debug button title>, wait:<seconds>, wheel:<points> (synthesised scroll-wheel event, positive =
/// up), size:<w>x<h>, state, label, snap:<path>, drag:x1,y1,x2,y2, dbl:x,y, quit.
enum DevScript {
    static func runIfRequested(controller: RoomController, window: NSWindow) {
        guard let script = ProcessInfo.processInfo.environment["CF_SCRIPT"] else { return }
        let commands = script.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
        run(commands[...], controller: controller, window: window)
    }

    private static func run(_ commands: ArraySlice<String>, controller c: RoomController, window: NSWindow) {
        guard let cmd = commands.first else { return }
        let rest = commands.dropFirst()
        var delay = 0.05
        let parts = cmd.split(separator: ":", maxSplits: 1).map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        switch parts[0] {
        case "click":
            c.debugBar?.buttons.first { $0.title == arg }?.performClick(nil)
        case "wait":
            delay = Double(arg) ?? 0.5
        case "wheel":
            let dy = Int32(Double(arg) ?? 0)
            if let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: dy, wheel2: 0, wheel3: 0),
               let e = NSEvent(cgEvent: cg) {
                c.scrollView.scrollWheel(with: e)
            }
        case "size":
            let p = arg.split(separator: "x").compactMap { Double($0) }
            if p.count == 2 { window.setContentSize(NSSize(width: p[0], height: p[1])) }
        case "state":
            print("[\(arg)] \(c.stateText())\(c.debugBar?.doneLabel.isHidden == false ? " | Stream done" : "")")
        case "label":
            print("[\(arg)] label: \(c.debugBar?.stateLabel.stringValue ?? "-")")
        case "snap":
            DevSnapshot.write(c.rootView, to: arg)
        case "drag":
            // drag:x1,y1,x2,y2 in content coordinates from the top left; then prints the copied text.
            let v = arg.split(separator: ",").compactMap { Double($0) }
            guard v.count == 4, let content = window.contentView else { break }
            func loc(_ x: Double, _ y: Double) -> NSPoint { NSPoint(x: x, y: content.bounds.height - y) }
            func ev(_ type: NSEvent.EventType, _ p: NSPoint, clicks: Int = 1) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                   windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1)!
            }
            let a = loc(v[0], v[1]), b = loc(v[2], v[3])
            for k in 1...5 {
                let t = Double(k) / 5
                NSApp.postEvent(ev(.leftMouseDragged, NSPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)), atStart: false)
            }
            NSApp.postEvent(ev(.leftMouseUp, b), atStart: false)
            let down = ev(.leftMouseDown, a)
            if let hit = content.hitTest(a) { hit.mouseDown(with: down) }
            NSApp.sendAction(#selector(NSText.copy(_:)), to: window.firstResponder, from: nil)
            print("[drag] copied: \(NSPasteboard.general.string(forType: .string) ?? "-")")
        case "dbl":
            // dbl:x,y double-clicks at content coordinates from the top left; then prints the copied text.
            let v = arg.split(separator: ",").compactMap { Double($0) }
            guard v.count == 2, let content = window.contentView else { break }
            let p = NSPoint(x: v[0], y: content.bounds.height - v[1])
            func ev(_ type: NSEvent.EventType, clicks: Int) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                   windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1)!
            }
            NSApp.postEvent(ev(.leftMouseUp, clicks: 2), atStart: false)
            let hit = content.hitTest(p)
            hit?.mouseDown(with: ev(.leftMouseDown, clicks: 2))
            NSApp.sendAction(#selector(NSText.copy(_:)), to: window.firstResponder, from: nil)
            print("[dbl] copied: \(NSPasteboard.general.string(forType: .string) ?? "-")")
        case "quit":
            exit(0)
        default:
            print("unknown command \(cmd)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { run(rest, controller: c, window: window) }
    }
}
