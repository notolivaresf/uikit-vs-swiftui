import XCTest

/// Screenshots for a by-eye comparison with reference/screens (Fernando, 18 Oct: "We'll just use screenshots").
/// Saves full-screen XCUIScreen attachments named `<state>-<light|dark>`; Harness/screens.sh exports them.
/// States: room-bottom (after Reset), room-top (scrolled up as far as the loaded window goes, no Load older),
/// jump-2500 (after "Jump to 2500"), context-menu (long press on a text message). The debug bar stays: the
/// builds only offer Reset and Jump with it, and they are frozen.
final class Screenshots: BenchCase {
    private func shot(_ state: String, _ theme: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "\(state)-\(theme)"
        a.lifetime = .keepAlways
        add(a)
    }

    private func messageText() -> XCUIElement? {
        let candidates = list.textViews.allElementsBoundByIndex + list.staticTexts.allElementsBoundByIndex
        let texts = candidates.filter { e in
            guard e.exists, e.isHittable else { return false }
            let text = (e.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? e.label
            return text.split(separator: " ").count >= 4
        }
        return texts.max { $0.frame.midY < $1.frame.midY }
    }

    private func capture(_ theme: String) {
        app.terminate()
        app.launch(); waitForBar()
        reset()
        shot("room-bottom", theme)

        // Scroll up until the first loaded message is at the top (state label stops changing), never Load older.
        var last = state()
        for _ in 0..<12 {
            list.swipeDown(velocity: .fast)
            let now = settled()
            if now.top == last.top && now.y == last.y { break }
            last = now
        }
        shot("room-top", theme)

        _ = tap(Bar.jump)
        shot("jump-2500", theme)

        reset()
        if let text = messageText() {
            text.press(forDuration: 1.2)
            _ = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Reply'")).firstMatch.waitForExistence(timeout: 3)
            shot("context-menu", theme)
            stateLabel.tap()
        } else {
            XCTFail("no message text on screen")
        }
    }

    func testScreenshots() {
        XCUIDevice.shared.appearance = .light
        capture("light")
        XCUIDevice.shared.appearance = .dark
        capture("dark")
        XCUIDevice.shared.appearance = .light
    }
}
