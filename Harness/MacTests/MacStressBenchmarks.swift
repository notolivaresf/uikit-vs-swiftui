import AppKit
import XCTest

/// The Mac twin of Harness/Tests/StressBenchmarks.swift. Text size uses the app's own "Text size +" control
/// (macOS has no system text-size setting apps follow). Window resize replaces rotation: the bottom-right corner
/// is dragged from 393 to 852 points wide and back. Context menu = right-click; copy is checked for real on the
/// pasteboard.
final class MacStressBenchmarks: MacBenchCase {

    func testTextSizeAtBottom() {
        launch()
        bench(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            startMeasuring()
            var steps: [[String: Any]] = []
            for _ in 0..<3 {
                let s = tap(Bar.textSize)
                steps.append(["app_ms": s.ms as Any, "pinned": s.pinned, "label_changed": lastTapChanged])
            }
            stopMeasuring()
            record("testTextSizeAtBottom", ["steps": steps])
        }
    }

    func testTextSizeMidScroll() {
        launch()
        bench(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            var before = tap(Bar.jump)
            startMeasuring()
            var steps: [[String: Any]] = []
            for _ in 0..<3 {
                let s = tap(Bar.textSize)
                steps.append(["app_ms": s.ms as Any, "label_changed": lastTapChanged,
                              "top_before": before.top, "top_after": s.top,
                              "drift_pt": drift(before, s) as Any])
                before = s
            }
            stopMeasuring()
            record("testTextSizeMidScroll", ["steps": steps])
        }
    }

    // Resize at the bottom: wide and back; the room stays pinned.
    func testResizeAtBottom() {
        launch()
        bench(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            startMeasuring()
            let (wide, wideW) = resize(toWidth: Self.wideWidth)
            let (narrow, narrowW) = resize(toWidth: Self.narrow.width)
            stopMeasuring()
            record("testResizeAtBottom", ["pinned_wide": wide.pinned, "pinned_narrow": narrow.pinned,
                                          "width_wide": wideW, "width_narrow": narrowW,
                                          "resized": Self.didResize(wideW, narrowW)])
        }
    }

    // Resize at message 2,500: wide and back; the row at the top stays in place.
    func testResizeAt2500() {
        launch()
        bench(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            let before = tap(Bar.jump)
            startMeasuring()
            let (wide, wideW) = resize(toWidth: Self.wideWidth)
            let (narrow, narrowW) = resize(toWidth: Self.narrow.width)
            stopMeasuring()
            record("testResizeAt2500", ["top_before": before.top, "top_wide": wide.top, "top_narrow": narrow.top,
                                        "drift_wide_pt": drift(before, wide) as Any,
                                        "drift_narrow_pt": drift(wide, narrow) as Any,
                                        "drift_round_trip_pt": drift(before, narrow) as Any,
                                        "width_wide": wideW, "width_narrow": narrowW,
                                        "resized": Self.didResize(wideW, narrowW)])
        }
    }

    /// The drag really changed the window: wide within 20 pt of the target, and back within 20 pt of 393.
    /// A window that does not resize fails the resize checks instead of passing them by staying still.
    static func didResize(_ wide: CGFloat, _ narrow: CGFloat) -> Bool {
        abs(wide - wideWidth) <= 20 && abs(narrow - Self.narrow.width) <= 20
    }

    /// Text with runs of whitespace collapsed to one space, trimmed.
    static func squeezed(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    func testBoostBurst() {
        launch()
        bench(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            let before = state()
            startMeasuring()
            button(Bar.boostBurst).click()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            let s = settled()
            stopMeasuring()
            record("testBoostBurst", ["pinned": s.pinned, "room_moved": s.top != before.top || s.y != before.y])
        }
    }

    /// The newest message text on screen: a text view or static text in the list with at least 4 words.
    private func messageText() -> XCUIElement? {
        let candidates = list.textViews.allElementsBoundByIndex + list.staticTexts.allElementsBoundByIndex
        let texts = candidates.filter { e in
            guard e.exists, e.isHittable else { return false }
            return text(of: e).split(separator: " ").count >= 4
        }
        return texts.max { $0.frame.midY < $1.frame.midY }
    }

    private func menuItem(_ title: String) -> XCUIElement {
        app.menuItems.matching(NSPredicate(format: "title == %@ OR label == %@", title, title)).firstMatch
    }

    /// Puts a sentinel on the general pasteboard, so a later change can only come from the app.
    private func seedPasteboard() -> (count: Int, sentinel: String) {
        let sentinel = "uvs-sentinel-\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sentinel, forType: .string)
        return (NSPasteboard.general.changeCount, sentinel)
    }

    /// What the app put on the pasteboard since `seed`: nil when nothing changed.
    private func copied(since seed: (count: Int, sentinel: String)) -> String? {
        _ = waitUntil(timeout: 2) { NSPasteboard.general.changeCount != seed.count }
        guard NSPasteboard.general.changeCount != seed.count else { return nil }
        let s = NSPasteboard.general.string(forType: .string) ?? ""
        return s == seed.sentinel ? nil : s
    }

    // Capability, not speed. context_menu: a right-click on a message shows Copy and Reply, and Copy puts text on
    // the pasteboard. text_selection: a double-click selects a word in a message and Command-C copies it.
    func testTextSelectionAndContextMenu() {
        launch()
        reset()
        guard let text = messageText() else {
            record("testTextSelectionAndContextMenu", ["context_menu": false, "text_selection": false, "note": "no message text found"])
            XCTFail("no message text on screen")
            return
        }
        let message = self.text(of: text)
        var seed = seedPasteboard()
        text.rightClick()
        let menu = menuItem("Reply").waitForExistence(timeout: 3) && menuItem("Copy").exists
        var menuCopy: String?
        if menu {
            menuItem("Copy").click()
            menuCopy = copied(since: seed)
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
        _ = settled()

        guard let again = messageText() else { XCTFail("message text gone"); return }
        seed = seedPasteboard()
        again.doubleClick()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        app.typeKey("c", modifierFlags: .command)
        let selectionCopy = copied(since: seed)
        // Click the state label (it does nothing) to drop the selection.
        stateLabel.click()
        // Copy must give the message's own text (the accessibility text of the row's message, whitespace
        // squeezed): equal to it, or holding it whole (a copy that adds the name or time still counts).
        let body = Self.squeezed(message)
        let menuText = Self.squeezed(menuCopy ?? "")
        let menuCopiedMessage = !body.isEmpty && (menuText == body || menuText.contains(body))
        // A double-click selects one word: the copy is a single word that appears in the message.
        let word = Self.squeezed(selectionCopy ?? "")
        let wordCopied = !word.isEmpty && !word.contains(" ") && body.contains(word)
        record("testTextSelectionAndContextMenu", ["context_menu": menu && menuCopiedMessage,
                                                   "message_text": message,
                                                   "menu_shown": menu,
                                                   "menu_copy_text": menuCopy as Any,
                                                   "text_selection": wordCopied,
                                                   "selection_copy_text": selectionCopy as Any])
    }
}
