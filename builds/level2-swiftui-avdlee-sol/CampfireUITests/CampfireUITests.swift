import XCTest

@MainActor
final class CampfireUITests: XCTestCase {
    private var app: XCUIApplication!
    private var state: XCUIElement { app.staticTexts["benchmark-state"] }

    private func launchRoom() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        XCTAssertTrue(state.waitForExistence(timeout: 8), app.debugDescription)
        waitUntil { self.fields()["loaded"] == "40" && self.fields()["top"] != "0" && Int(self.fields()["ms"] ?? "0") ?? 0 > 0 }
        print("Launch: \(state.label)")
    }

    private func fields() -> [String: String] {
        let tokens = state.label.split(separator: " ").map(String.init)
        guard tokens.count == 14 else { return [:] }
        return Dictionary(uniqueKeysWithValues: stride(from: 0, to: tokens.count, by: 2).map { (tokens[$0], tokens[$0 + 1]) })
    }

    private func waitUntil(timeout: TimeInterval = 6, _ condition: @escaping () -> Bool) {
        let predicate = NSPredicate { _, _ in MainActor.assumeIsolated { self.state.value as? String == "ready" && condition() } }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout)
        XCTAssertEqual(result, .completed, "Current state: \(state.label)")
    }

    private func tap(_ title: String) {
        let button = app.buttons[title]
        if !button.isHittable {
            app.scrollViews.containing(.button, identifier: "Reset").firstMatch.swipeLeft()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        button.tap()
    }

    private func assertAnchor(_ before: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        let after = fields()
        XCTAssertEqual(after["top"], before["top"], file: file, line: line)
        XCTAssertEqual(Double(after["y"] ?? "999")!, Double(before["y"] ?? "-999")!, accuracy: 2, file: file, line: line)
    }

    func testPagingJumpReflowAndRotation() {
        launchRoom()
        XCTAssertEqual(fields()["first"], "49961")
        XCTAssertEqual(fields()["last"], "50000")
        XCTAssertEqual(fields()["pinned"], "yes")
        XCTAssertLessThan(Int(fields()["ms"]!)!, 1000)

        let initial = fields()
        tap("Load older")
        waitUntil { self.fields()["loaded"] == "80" }
        assertAnchor(initial)

        tap("Jump to 2500")
        waitUntil { self.fields()["top"] == "2500" }
        XCTAssertEqual(Double(fields()["y"]!)!, 0, accuracy: 2)
        XCTAssertEqual(fields()["pinned"], "no")
        let jumped = fields()
        tap("Load older")
        waitUntil { self.fields()["loaded"] == "121" }
        assertAnchor(jumped)

        tap("Text size +")
        waitUntil { self.app.buttons["Jump to bottom"].exists }
        assertAnchor(jumped)
        XCUIDevice.shared.orientation = .landscapeLeft
        waitUntil { self.app.frame.width > self.app.frame.height }
        assertAnchor(jumped)
        XCUIDevice.shared.orientation = .portrait
        waitUntil { self.app.frame.width < self.app.frame.height }
        assertAnchor(jumped)

        app.buttons["Jump to bottom"].tap()
        waitUntil { self.fields()["pinned"] == "yes" && self.fields()["last"] == "50000" }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Newest page"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBoostGrowthAndLiveStream() {
        launchRoom()
        let originalTiming = fields()["ms"]
        let boosts = app.otherElements["message-50000"].descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'boosted'"))
        tap("Boost burst")
        waitUntil { boosts.count == 5 }
        tap("Boost burst")
        waitUntil { boosts.count == 10 }
        XCTAssertEqual(fields()["ms"], originalTiming)
        XCTAssertEqual(fields()["pinned"], "yes")
        tap("Start stream")
        waitUntil(timeout: 8) { Int(self.fields()["last"] ?? "0")! > 50040 }
        XCTAssertEqual(fields()["pinned"], "yes")
        app.scrollViews["room-scroll"].swipeDown()
        waitUntil { self.fields()["pinned"] == "no" }
        let before = fields()
        waitUntil(timeout: 35) { self.app.staticTexts["stream-done"].exists }
        assertAnchor(before)
        XCTAssertEqual(fields()["pinned"], "no")
        app.buttons["Jump to bottom"].tap()
        waitUntil { self.fields()["last"] == "50600" && self.fields()["pinned"] == "yes" }
        XCTAssertLessThanOrEqual(Int(fields()["loaded"]!)!, 300)
    }

    func testPinnedStreamAndReflow() {
        launchRoom()
        tap("Text size +")
        waitUntil { self.fields()["pinned"] == "yes" }
        XCUIDevice.shared.orientation = .landscapeLeft
        waitUntil { self.app.frame.width > self.app.frame.height }
        XCTAssertEqual(fields()["pinned"], "yes")
        XCUIDevice.shared.orientation = .portrait
        waitUntil { self.app.frame.width < self.app.frame.height }
        XCTAssertEqual(fields()["pinned"], "yes")
        tap("Reset")
        waitUntil { self.fields()["loaded"] == "40" && self.fields()["pinned"] == "yes" }
        tap("Start stream")
        waitUntil(timeout: 36) { self.app.staticTexts["stream-done"].exists }
        XCTAssertEqual(fields()["last"], "50600")
        XCTAssertEqual(fields()["loaded"], "40")
        XCTAssertEqual(fields()["pinned"], "yes")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Pinned room after stream"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testContextMenuAndUnpinnedScrolling() {
        launchRoom()
        let scroll = app.scrollViews["room-scroll"]
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        waitUntil { self.fields()["pinned"] == "no" }
        let reading = fields()
        tap("Text size +")
        waitUntil { self.fields()["pinned"] == "no" }
        assertAnchor(reading)
        let id = fields()["top"]!
        let row = app.descendants(matching: .any)["message-\(id)"].firstMatch
        if row.exists { row.press(forDuration: 1) }
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Reply"].exists)
        XCTAssertTrue(app.buttons["Select text"].exists)
        app.buttons["Select text"].tap()
        XCTAssertTrue(app.textViews["range-selection"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap()
    }
}
