import AppKit

/// Development aid: with CF_SNAPSHOT=/path.png in the environment the app renders its window content at 3× to
/// that file and quits. CF_APPEARANCE=light|dark, CF_TOP=1 (scroll to the very top of history),
/// CF_JUMP=<id> (jump to a message), CF_SCROLL=<points> (scroll up by that much).
enum DevSnapshot {
    static func write(_ view: NSView, to path: String) {
        let b = view.bounds
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(b.width * 3), pixelsHigh: Int(b.height * 3),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = b.size
        view.cacheDisplay(in: b, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    static func runIfRequested(controller: RoomController, window: NSWindow) {
        let env = ProcessInfo.processInfo.environment
        if let a = env["CF_APPEARANCE"] { NSApp.appearance = NSAppearance(named: a == "dark" ? .darkAqua : .aqua) }
        guard let path = env["CF_SNAPSHOT"] else { return }
        if env["CF_TOP"] != nil { controller.devScrollToTop() }
        if let j = env["CF_JUMP"], let id = Int(j) { controller.jump(to: id) }
        if let s = env["CF_SCROLL"], let d = Double(s) { controller.devScroll(by: CGFloat(d)) }
        if let w = env["CF_SIZE"] {
            let parts = w.split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 { window.setContentSize(NSSize(width: parts[0], height: parts[1])) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            write(controller.rootView, to: path)
            print(controller.stateText())
            exit(0)
        }
    }
}
