import XCTest

/// The stress cases from the spec's Benchmarks section: text size, rotation, boost burst, text selection and
/// context menu. Same rules as ChatBenchmarks: only the debug bar and the state label, never anything per build.
/// Drift and pinned are reported (UVS_RESULT lines), not asserted: the pass bar is the behaviour tests.
final class StressBenchmarks: BenchCase {

    // Text size at the bottom: 3 steps of "Text size +"; the room must stay pinned. Re-layout time from `ms`.
    func testTextSizeAtBottom() {
        app.launch(); waitForBar()
        measure(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
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

    // Text size mid-scroll (at message 2,500): 3 steps; the row at the top stays in place. Drift per step.
    func testTextSizeMidScroll() {
        app.launch(); waitForBar()
        measure(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
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

    // Rotation at the bottom: landscape and back; the room stays pinned.
    func testRotationAtBottom() {
        app.launch(); waitForBar()
        measure(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            startMeasuring()
            let land = rotate(.landscapeLeft)
            let port = rotate(.portrait)
            stopMeasuring()
            record("testRotationAtBottom", ["pinned_landscape": land.pinned, "pinned_portrait": port.pinned])
        }
    }

    // Rotation at message 2,500: landscape and back; the row at the top stays in place. Drift per turn.
    func testRotationAt2500() {
        app.launch(); waitForBar()
        measure(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            let before = tap(Bar.jump)
            startMeasuring()
            let land = rotate(.landscapeLeft)
            let port = rotate(.portrait)
            stopMeasuring()
            record("testRotationAt2500", ["top_before": before.top, "top_landscape": land.top, "top_portrait": port.top,
                                          "drift_landscape_pt": drift(before, land) as Any,
                                          "drift_portrait_pt": drift(land, port) as Any,
                                          "drift_round_trip_pt": drift(before, port) as Any])
        }
    }

    // Boost burst: 5 boosts on the newest message, one every 200 ms, while pinned; must still be pinned.
    func testBoostBurst() {
        app.launch(); waitForBar()
        measure(metrics: hitchMetric + [XCTClockMetric()], options: manualOptions) {
            reset()
            let before = state()
            startMeasuring()
            button(Bar.boostBurst).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            let s = settled()
            stopMeasuring()
            // The label can't count boosts; the only sign they landed is the newest row growing, which moves
            // the row at the top (a different top row, or a different y) while the room stays pinned.
            record("testBoostBurst", ["pinned": s.pinned, "room_moved": s.top != before.top || s.y != before.y])
        }
    }

    /// The newest message text on screen: a text view, or else a static text in the list longer than a few words.
    private func messageText() -> XCUIElement? {
        let candidates = list.textViews.allElementsBoundByIndex + list.staticTexts.allElementsBoundByIndex
        let texts = candidates.filter { e in
            guard e.exists, e.isHittable else { return false }
            let text = (e.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? e.label
            return text.split(separator: " ").count >= 4
        }
        return texts.max { $0.frame.midY < $1.frame.midY }
    }

    private func menuItem(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func dismissMenu() {
        // The state label does nothing when tapped, so it is a safe place to tap the menu away.
        stateLabel.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
    }

    // Capability, not speed. context_menu: a long press on a message shows Copy and Reply. text_selection: the
    // system edit menu of a selected range (Look Up, Translate, Select All...) shows after the long press or,
    // failing that, a double tap on the text. Whether Copy really copies is not checked (reading the
    // pasteboard from the test runner raises a paste prompt).
    func testTextSelectionAndContextMenu() {
        app.launch(); waitForBar()
        reset()
        guard let text = messageText() else {
            record("testTextSelectionAndContextMenu", ["context_menu": false, "text_selection": false, "note": "no message text found"])
            XCTFail("no message text on screen")
            return
        }
        text.press(forDuration: 1.2)
        let menu = menuItem("Reply").waitForExistence(timeout: 3) && menuItem("Copy").exists
        // The system text-edit menu (a selected range) shows items a context menu with Copy and Reply doesn't.
        let editItems = ["Look Up", "Translate", "Select All", "Search Web", "Share…", "Select"]
        let selectedOnPress = editItems.contains { menuItem($0).exists }
        dismissMenu()

        _ = settled()
        guard let again = messageText() else { XCTFail("message text gone"); return }
        again.doubleTap()
        _ = menuItem("Copy").waitForExistence(timeout: 3)
        let selectedOnDoubleTap = editItems.contains { menuItem($0).exists }
        dismissMenu()
        record("testTextSelectionAndContextMenu", ["context_menu": menu,
                                                   "text_selection": selectedOnPress || selectedOnDoubleTap,
                                                   "selection_on_long_press": selectedOnPress,
                                                   "selection_on_double_tap": selectedOnDoubleTap])
    }
}
