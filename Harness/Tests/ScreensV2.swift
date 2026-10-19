import XCTest

/// Second round of screenshots, matched to the reference names in screenshots/ (light `<name>`, dark
/// `<name>-dark`). Harness/screens-v2.sh exports them to runs/screens-v2/<build>/ and writes notes.md from the
/// `UVS_SHOT`, `UVS_MISS` and `UVS_BAR` lines this prints.
///   testBottom: launched WITHOUT -uvsBenchmark (no debug bar), at the newest messages.
///   testTop:    Jump to 2500, Load older until first 1, then scrolled to the very top.
///   testRows:   one shot per message id in the UVS_ROWS environment (`kind:id,kind:id`; passed from the Mac as
///               TEST_RUNNER_UVS_ROWS), with that row at the top of the room.
final class ScreensV2: BenchCase {
    private func shot(_ name: String, label: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        print("UVS_SHOT \(name) | \(label)")
    }

    /// Light shot, then dark at the same place, then back to light. Re-reads the label after each switch.
    private func pair(_ name: String, readLabel: Bool = true, frame: ((String) -> Void)? = nil) {
        XCUIDevice.shared.appearance = .light
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        shot(name, label: readLabel ? settled().raw : "(no debug bar, no label)")
        frame?(name)
        XCUIDevice.shared.appearance = .dark
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        shot("\(name)-dark", label: readLabel ? settled().raw : "(no debug bar, no label)")
        frame?("\(name)-dark")
        XCUIDevice.shared.appearance = .light
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    private func reportBar() {
        let w = app.windows.firstMatch.frame
        let r = button(Bar.reset).frame
        let l = stateLabel.frame
        let lst = list.frame
        print("UVS_BAR window \(fmt(w)) | Reset button \(fmt(r)) | state label \(fmt(l)) | list \(fmt(lst))")
    }

    private func fmt(_ f: CGRect) -> String {
        String(format: "x %.0f y %.0f w %.0f h %.0f", f.minX, f.minY, f.width, f.height)
    }

    /// A slow drag of `dy` points on the list (positive: finger moves down, older content comes in), held at the
    /// end so it does not fling.
    private func drag(_ dy: CGFloat) {
        let f = list.frame
        let midY = f.midY
        // Start below the floating header (about 120 pt) and end inside the list, so the press lands on rows.
        let startY = dy > 0 ? max(f.minY + 160, min(midY - dy / 2, f.maxY - 40 - dy)) : min(f.maxY - 40, max(midY - dy / 2, f.minY + 160 - dy))
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: startY))
        let end = start.withOffset(CGVector(dx: 0, dy: dy))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 600, thenHoldForDuration: 0.3)
    }

    func testBottom() {
        app.launchArguments = []
        app.terminate()
        XCUIDevice.shared.appearance = .light
        app.launch()
        XCTAssertTrue(list.waitForExistence(timeout: 30), "room missing")
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        pair("room-bottom", readLabel: false)
        // The same place with the debug bar on, for the notes: where the bar sits and the bottom label.
        app.terminate()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch(); waitForBar()
        reset()
        reportBar()
        print("UVS_SHOT (no shot) bottom state with the debug bar on | \(settled().raw)")
    }

    /// Load older until the first loaded id is at most `id`. False when it stops moving.
    private func loadOlder(until id: Int) -> Bool {
        var s = state()
        var taps = 0
        while s.first > id && taps < 90 {
            let before = s.first
            s = tap(Bar.older)
            taps += 1
            if s.first == before && !lastTapChanged {
                s = tap(Bar.older)   // one more try before giving up
                taps += 1
                if s.first == before { break }
            }
        }
        print("UVS_INFO load older taps \(taps): \(s.raw)")
        return s.first <= id
    }

    func testTop() {
        XCUIDevice.shared.appearance = .light
        app.terminate()
        app.launch(); waitForBar()
        reportBar()
        _ = tap(Bar.jump)
        if !loadOlder(until: 1) { print("UVS_MISS room-top: Load older never reached first 1 (\(state().raw))") }
        // Scroll to the very top: swipe down until the label stops changing twice in a row.
        var last = settled()
        var still = 0
        for _ in 0..<200 {   // a fast swipe moves about 6 rows; from top ~312 that is ~50 swipes
            list.swipeDown(velocity: .fast)
            let now = settled()
            if now.top <= 1 && now.top == last.top && abs(now.y - last.y) < 0.5 { still += 1; if still >= 2 { break } } else { still = 0 }
            last = now
        }
        if state().top > 1 { print("UVS_MISS room-top: swiping stopped before message 1 (\(state().raw))") }
        pair("room-top")
    }

    /// Scrolls the loaded window until message `id` is the top row with its top at or just below the header.
    /// At the bottom, a row newer than the top row counts as shown. Returns false if it gave up.
    private func bringToTop(_ id: Int) -> Bool {
        var s = settled()
        var stuck = 0
        for _ in 0..<60 {
            if s.top == id && s.y >= -0.5 { return true }
            let gap = abs(s.top - id)
            var dy: CGFloat
            if s.top == id { dy = CGFloat(-s.y) + 6 }               // partly under the header: pull it down
            else if s.top < id { dy = -(gap > 4 ? 450 : (gap > 1 ? 180 : 60)) }   // need newer rows: finger up
            else { dy = gap > 4 ? 450 : (gap > 1 ? 180 : 60) }                     // need older rows: finger down
            if dy > 0 && dy < 20 { dy = 20 }
            drag(dy)
            let now = settled()
            if now.top == s.top && abs(now.y - s.y) < 1 {
                stuck += 1
                if s.top < id && id <= now.last && stuck >= 2 { return true }   // at the bottom: it is on screen below
                if stuck >= 3 { return false }
            } else { stuck = 0 }
            s = now
        }
        return s.top == id
    }

    func testRows() {
        let spec = ProcessInfo.processInfo.environment["UVS_ROWS"] ?? ""
        let rows: [(kind: String, id: Int, words: String)] = spec.split(separator: ";").compactMap { part in
            let bits = part.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard bits.count >= 2, let id = Int(bits[1]) else { return nil }
            return (String(bits[0]), id, bits.count > 2 ? String(bits[2]) : "")
        }
        XCTAssertFalse(rows.isEmpty, "UVS_ROWS empty")
        XCUIDevice.shared.appearance = .light
        app.terminate()
        app.launch(); waitForBar()
        for row in rows {
            let name = "row-\(row.kind)-\(row.id)"
            reset()
            var s = state()
            if row.id < s.first && row.id >= s.first - 800 {
                // Within 20 pages of the newest: Load older from the bottom.
                if !loadOlder(until: row.id) {
                    print("UVS_MISS \(name): could not load it from the bottom (\(state().raw))"); continue
                }
            } else if row.id < s.first {
                // Low ids: Jump to 2500, then Load older as needed. Relaunch first so the window is small.
                app.terminate(); app.launch(); waitForBar()
                s = tap(Bar.jump)
                if row.id < s.first && !loadOlder(until: row.id) {
                    print("UVS_MISS \(name): could not load it (\(state().raw))"); continue
                }
                if row.id > state().last {
                    print("UVS_MISS \(name): not in the Jump window and not in the newest 40 (\(state().raw))"); continue
                }
            }
            if !bringToTop(row.id) {
                print("UVS_INFO \(name): not the top row, shot anyway (\(state().raw)); see whole_on_screen in its json")
            }
            pair(name) { shotName in self.reportFrame(shotName, id: row.id, words: row.words) }
        }
    }

    /// The on-screen frame of the row holding `words`: its cell when one holds it, else the text element.
    private func rowRect(_ words: String) -> CGRect? {
        let window = app.windows.firstMatch.frame
        let match = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)
        let texts = app.descendants(matching: .any).matching(match).allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty && window.intersects($0.frame) }
        guard let text = texts.min(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else { return nil }
        let cellMatch = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)
        let cell = app.cells.containing(cellMatch).allElementsBoundByIndex
            .filter { $0.exists && window.intersects($0.frame) }
            .min(by: { $0.frame.height < $1.frame.height })
        if let cell, cell.frame.height < window.height * 0.9 { return cell.frame }
        return text.frame
    }

    /// testRows by one sweep: from the bottom, drag up the room a bit at a time; each target row is shot (light
    /// and dark) the first time it is wholly on screen between the header and the list's bottom edge.
    func testRowsSweep() {
        let spec = ProcessInfo.processInfo.environment["UVS_ROWS"] ?? ""
        var pending: [(kind: String, id: Int, words: String)] = spec.split(separator: ";").compactMap { part in
            let bits = part.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard bits.count == 3, let id = Int(bits[1]), !bits[2].isEmpty else { return nil }
            return (String(bits[0]), id, String(bits[2]))
        }
        XCTAssertFalse(pending.isEmpty, "UVS_ROWS empty")
        let lowest = pending.map(\.id).min() ?? 0
        XCUIDevice.shared.appearance = .light
        app.terminate()
        app.launch(); waitForBar()
        reset()
        reportBar()
        let bottomLimit = min(list.frame.maxY, button(Bar.reset).frame.minY - 60)
        var passedLowest = 0
        for step in 0..<60 {
            if pending.isEmpty { break }
            var done: [Int] = []
            for row in pending {
                guard let r = rowRect(row.words), r.minY >= 100, r.maxY <= bottomLimit + 1 else { continue }
                let name = "row-\(row.kind)-\(row.id)"
                print("UVS_INFO \(name): wholly on screen at sweep step \(step), frame \(box(r))")
                pair(name) { shotName in self.reportFrame(shotName, id: row.id, words: row.words) }
                done.append(row.id)
            }
            pending.removeAll { done.contains($0.id) }
            if pending.isEmpty { break }
            let s = settled()
            if s.top < lowest - 1 { passedLowest += 1; if passedLowest >= 3 { break } }
            drag(220)
        }
        for row in pending {
            print("UVS_MISS row-\(row.kind)-\(row.id): never wholly on screen in the sweep (\(state().raw))")
        }
    }

    /// Prints `UVS_FRAME <shot> {json}`: the frame in points of the cell holding the row's first words, or of
    /// the element itself when no cell holds it (lazy stacks); the export writes it to <shot>.json.
    private func reportFrame(_ shotName: String, id: Int, words: String) {
        var info: [String: Any] = ["id": id, "words": words,
                                   "scale": XCUIScreen.main.screenshot().image.scale]
        guard !words.isEmpty else { info["frame"] = NSNull(); info["source"] = "no words"; emit(shotName, info); return }
        let match = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)
        let window = app.windows.firstMatch.frame
        let elements = app.descendants(matching: .any).matching(match).allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty && window.intersects($0.frame) }
        // The smallest element holding the words is the text itself; cells and containers are larger.
        guard let text = elements.min(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
            info["frame"] = NSNull(); info["source"] = "words not found"; emit(shotName, info)
            print("UVS_MISS \(shotName): no frame, words not found (\(words))"); return
        }
        info["text_frame"] = box(text.frame)
        info["text_type"] = text.elementType.rawValue
        let cellMatch = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)
        let cell = app.cells.containing(cellMatch).allElementsBoundByIndex
            .filter { $0.exists && window.intersects($0.frame) }
            .min(by: { $0.frame.height < $1.frame.height })
        if let cell, cell.frame.height < window.height * 0.9 {
            info["frame"] = box(cell.frame); info["source"] = "cell"
        } else {
            info["frame"] = box(text.frame); info["source"] = "text element"
        }
        // Whole row on screen: below the floating header (about 110 pt) and above the list's bottom edge.
        let chosen = (cell != nil && cell!.frame.height < window.height * 0.9) ? cell!.frame : text.frame
        let whole = chosen.minY >= 100 && chosen.maxY <= list.frame.maxY + 1
        info["whole_on_screen"] = whole
        if !whole { print("UVS_MISS \(shotName): row not wholly on screen, frame \(box(chosen))") }
        emit(shotName, info)
    }

    private func box(_ f: CGRect) -> [Double] {
        [f.minX, f.minY, f.width, f.height].map { (Double($0) * 10).rounded() / 10 }
    }

    private func emit(_ shotName: String, _ info: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: info, options: [.sortedKeys]),
           let line = String(data: data, encoding: .utf8) {
            print("UVS_FRAME \(shotName) \(line)")
        }
    }
}
