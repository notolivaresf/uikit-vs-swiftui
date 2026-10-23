#if DEBUG
import AppKit
import CampfireKit

enum SmokeCheck {
    static func run(app: AppDelegate) {
        var results: [String] = []
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            let success = value(); results.append("\(success ? "PASS" : "FAIL") \(name)")
        }
        let r = app.room!
        app.window.setContentSize(NSSize(width: 393, height: 852))
        r.root.layoutSubtreeIfNeeded(); r.resizeRoom()
        check(r.loaded.count == 40 && r.loaded.first?.id == 49961 && r.loaded.last?.id == 50000, "newest 40")
        check(r.isPinned, "initially pinned")
        check(r.buttons.map { $0.accessibilityLabel() ?? "" } == ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"], "debug accessibility labels")
        check(r.buttons.allSatisfy { $0.accessibilityRole() == .button } && r.state.accessibilityRole() == .staticText, "standard accessibility roles")
        check(r.lastMS < 1000, "launch under 1s (\(r.lastMS) ms)")
        results.append("window \(app.window.frame) visible \(app.window.isVisible) content \(r.root.frame)")
        save(view: r.root, path: ProcessInfo.processInfo.arguments.contains("-dark") ? "/tmp/campfire-dark.png" : "/tmp/campfire-light.png")
        r.jump2500()
        check(r.topAnchor()?.id == 2500 && abs(r.topAnchor()?.y ?? 99) < 0.1, "jump row 2500 exactly below header (\(String(describing: r.topAnchor())))")
        r.rebuilding = true; r.restore(anchor: (2500, -12.5), pinned: false); r.rebuilding = false; r.updateVisible(); r.updateState()
        check(r.topAnchor()?.id == 2500 && abs((r.topAnchor()?.y ?? 99) + 12.5) < 0.1, "partial row position")
        let a = r.topAnchor()!
        r.loadOlderClick()
        check(r.loaded.count == 121 && r.topAnchor()?.id == a.id && abs((r.topAnchor()?.y ?? 99) - a.y) < 0.1, "prepend preserves anchor")
        for _ in 0..<4 { r.textSize(); check(r.topAnchor()?.id == a.id && abs((r.topAnchor()?.y ?? 99) - a.y) < 0.1, "text step \(r.scaleStep) preserves anchor") }
        app.window.setContentSize(NSSize(width: 1200, height: 1200)); r.root.layoutSubtreeIfNeeded(); r.resizeRoom()
        check(r.topAnchor()?.id == a.id && abs((r.topAnchor()?.y ?? 99) - a.y) < 0.1, "1200x1200 preserves anchor (before \(a) after \(String(describing: r.topAnchor())))")
        r.reset(); check(r.isPinned, "reset pinned")
        r.textSize(); check(r.isPinned, "pinned text size")
        app.window.setContentSize(NSSize(width: 393, height: 852)); r.root.layoutSubtreeIfNeeded(); r.resizeRoom(); check(r.isPinned, "pinned resize")
        r.reset()
        let feed = FakeLiveFeed(dataset: r.dataset)
        let time = ProcessInfo.processInfo.systemUptime
        for event in feed.script { autoreleasepool { r.receive(event.event) } }
        check(r.all.last?.id == 50600 && r.isPinned, "600 stream messages pinned")
        check(r.loaded.count <= Windowing.maxLoaded, "stream bounded window (\(r.loaded.count))")
        results.append("600 message replay \(Int((ProcessInfo.processInfo.systemUptime - time) * 1000)) ms")
        r.reset()
        r.rebuilding = true; r.restore(anchor: (49980, -12.5), pinned: false); r.rebuilding = false; r.updateVisible()
        let partial = r.topAnchor()!
        let growthID = r.loaded.last!.id
        r.extraBoosts[growthID] = (2...15).map { DisplayBoost(boosterID: $0, content: "Agreed!") }; r.layoutCache.removeValue(forKey: growthID)
        r.rebuild(anchor: partial, pinned: false)
        check(r.topAnchor()?.id == partial.id && abs((r.topAnchor()?.y ?? 99) - partial.y) < 0.1, "unpinned boost growth preserves partial row")
        check(r.layouts.last!.pills.map { $0.rect.minY }.max()! > r.layouts.last!.pills.first!.rect.minY, "boost pills wrap")
        r.reset(); r.jump2500(); let unpinned = r.topAnchor()!
        for event in feed.script { autoreleasepool { r.receive(event.event) } }
        check(r.topAnchor()?.id == unpinned.id && abs((r.topAnchor()?.y ?? 99) - unpinned.y) < 0.1 && !r.jump.isHidden, "stream preserves unpinned history and offers jump")
        r.jumpBottom(); check(r.isPinned && r.loaded.last?.id == 50600, "jump returns to live edge")
        r.reset()
        if let row = r.rowViews[50000], let text = row.subviews.compactMap({ $0 as? MessageTextView }).first {
            let old = NSPasteboard.general.string(forType: .string)
            text.setSelectedRange(NSRange(location: 0, length: 8)); text.copy(nil)
            check(NSPasteboard.general.string(forType: .string) == (text.string as NSString).substring(to: 8), "native selected range copies")
            text.copyMessage(nil); check(NSPasteboard.general.string(forType: .string) == row.plainText, "context Copy copies message")
            let menu = messageMenu(text: row.plainText, target: row)
            check(menu.items.map(\.title) == ["Copy", "Reply"], "context menu Copy and Reply")
            NSPasteboard.general.clearContents(); if let old { NSPasteboard.general.setString(old, forType: .string) }
        } else { check(false, "native selectable text exists") }
        r.layoutCache.removeValue(forKey: 50000)
        r.extraBoosts[50000] = (2...6).map { DisplayBoost(boosterID: $0, content: "👍") }
        r.rebuild(anchor: nil, pinned: true)
        check(r.isPinned && (r.layouts.last?.pills.count ?? 0) >= 6, "boost growth stays pinned")
        save(view: r.root, path: "/tmp/campfire-boosts.png")
        try? results.joined(separator: "\n").write(toFile: "/tmp/campfire-smoke.txt", atomically: true, encoding: .utf8)
        r.reset()
        if ProcessInfo.processInfo.arguments.contains("-timedStream") {
            r.startStream()
            DispatchQueue.main.asyncAfter(deadline: .now() + 31) {
                let text = "\n\(r.all.last?.id == 50600 && r.done.stringValue == "Stream done" && r.isPinned ? "PASS" : "FAIL") timed 30s stream and completion label"
                if let handle = FileHandle(forWritingAtPath: "/tmp/campfire-smoke.txt") { handle.seekToEndOfFile(); handle.write(Data(text.utf8)); try? handle.close() }
                NSApp.terminate(nil)
            }
        } else { NSApplication.shared.terminate(nil) }
    }
    static func save(view: NSView, path: String) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
#else
import AppKit
enum SmokeCheck { static func run(app: AppDelegate) {} }
#endif
