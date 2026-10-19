import XCTest

final class RoomUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch(); XCTAssertTrue(app.staticTexts["benchmark.state"].waitForExistence(timeout: 5))
        return app
    }
    private func state(_ app: XCUIApplication) -> String { app.staticTexts["benchmark.state"].label }
    private func value(_ key: String, in state: String) -> String {
        let tokens = state.split(separator: " ").map(String.init)
        guard let i = tokens.firstIndex(of: key), i+1 < tokens.count else { return "" }
        return tokens[i+1]
    }
    private func settle(_ app: XCUIApplication, until condition: @escaping (String) -> Bool, timeout: TimeInterval = 5) {
        let p = NSPredicate { _, _ in condition(self.state(app)) }
        expectation(for: p, evaluatedWith: nil)
        waitForExpectations(timeout: timeout)
    }

    @MainActor func testBenchmarkNavigationResizeRotationAndReset() {
        let app = launch()
        XCTAssertTrue(state(app).contains("first 49961 last 50000 loaded 40 pinned yes"))
        XCTAssertLessThan(Int(value("ms", in: state(app))) ?? 9999, 1000)
        app.buttons["Jump to 2500"].tap()
        settle(app) { $0.contains("top 2500 y 0.0") }
        XCTAssertEqual(app.cells["message.2500"].frame.minY, app.collectionViews["room.messages"].frame.minY, accuracy: 2)
        let before = state(app)
        app.buttons["Load older"].tap()
        settle(app) { $0.contains("first 2420") }
        XCTAssertEqual(value("top", in: state(app)), value("top", in: before))
        XCTAssertEqual(value("y", in: state(app)), value("y", in: before))
        app.buttons["Text size +"].tap()
        settle(app) { $0.contains("top 2500 y 0.0") }
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(app) { $0.contains("top 2500 y 0.0") }
        XCTAssertEqual(app.cells["message.2500"].frame.minY, app.collectionViews["room.messages"].frame.minY, accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
        let portrait = NSPredicate { _, _ in app.buttons["Reset"].frame.width < 150 }
        expectation(for: portrait, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.cells["message.2500"].frame.minY, app.collectionViews["room.messages"].frame.minY, accuracy: 2)
        app.buttons["Reset"].tap()
        settle(app) { $0.contains("first 49961 last 50000 loaded 40 pinned yes") }
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Room newest page"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testLiveStreamAndBoostsPreserveReaderThenJump() {
        let app = launch()
        app.buttons["Boost burst"].tap()
        settle(app) { $0.contains("pinned yes") }
        app.buttons["Start stream"].tap()
        settle(app) { (Int(self.value("last", in: $0)) ?? 0) >= 50010 }
        XCTAssertEqual(value("pinned", in: state(app)), "yes")
        app.buttons["Jump to 2500"].tap()
        settle(app) { $0.contains("top 2500 y 0.0") }
        XCTAssertTrue(app.buttons["Jump to bottom"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stream done"].waitForExistence(timeout: 40))
        XCTAssertEqual(value("top", in: state(app)), "2500")
        XCTAssertEqual(value("y", in: state(app)), "0.0")
        app.buttons["Jump to bottom"].tap()
        settle(app) { $0.contains("last 50600 loaded 40 pinned yes") }
    }

    @MainActor func testTextSelectionExposesCopyAndReply() {
        let app = launch()
        let text = app.textViews.matching(identifier: "text.50000").firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.press(forDuration: 1.2)
        XCTAssertTrue(app.menuItems["Copy"].waitForExistence(timeout: 3) || app.buttons["Copy"].exists)
        XCTAssertTrue(app.menuItems["Reply"].exists || app.buttons["Reply"].exists)
    }
}
