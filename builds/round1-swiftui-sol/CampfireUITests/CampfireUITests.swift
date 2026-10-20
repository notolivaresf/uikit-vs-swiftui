import XCTest

final class CampfireUITests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["benchmark-state"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func state(_ app: XCUIApplication) -> String {
        app.staticTexts["benchmark-state"].label
    }

    @MainActor private func wait(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        expectation(for: predicate, evaluatedWith: app.staticTexts["benchmark-state"])
        waitForExpectations(timeout: timeout)
    }

    private func number(_ key: String, in label: String) -> Double {
        let pieces = label.split(separator: " ").map(String.init)
        guard let index = pieces.firstIndex(of: key), index + 1 < pieces.count else { return .nan }
        return Double(pieces[index + 1]) ?? .nan
    }

    @MainActor func testLaunchJumpPrependAndTextSize() {
        let app = launch()
        wait(app, containing: "loaded 40 pinned yes")
        let initial = state(app)
        print("Launch benchmark: \(initial)")
        XCTAssertTrue(initial.contains("first 49961 last 50000"), initial)
        XCTAssertLessThan(number("ms", in: initial), 1000, initial)

        app.buttons["Jump to 2500"].tap()
        wait(app, containing: "top 2500 y 0.0")
        XCTAssertTrue(state(app).contains("pinned no"))
        let row = app.otherElements["message-2500"]
        XCTAssertEqual(row.frame.minY, app.scrollViews["timeline"].frame.minY, accuracy: 2)
        let before = state(app)
        app.buttons["Load older"].tap()
        wait(app, containing: "loaded 121")
        XCTAssertEqual(number("top", in: state(app)), number("top", in: before))
        XCTAssertEqual(number("y", in: state(app)), number("y", in: before), accuracy: 2)

        app.buttons["Text size +"].tap()
        wait(app, containing: "top 2500 y 0.0")
        XCTAssertEqual(number("y", in: state(app)), 0, accuracy: 2)

        XCUIDevice.shared.orientation = .landscapeLeft
        wait(app, containing: "top 2500 y 0.0")
        XCUIDevice.shared.orientation = .portrait
        wait(app, containing: "top 2500 y 0.0")

        app.buttons["Reset"].tap()
        wait(app, containing: "first 49961 last 50000 loaded 40 pinned yes")
    }

    @MainActor func testLiveFeedAndBoostsPreservePosition() {
        let app = launch()
        wait(app, containing: "pinned yes")
        app.buttons["Boost burst"].tap()
        let burst = expectation(description: "Five boosts laid out")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { burst.fulfill() }
        waitForExpectations(timeout: 3)
        XCTAssertTrue(state(app).contains("pinned yes"), state(app))

        app.buttons["Start stream"].tap()
        let progressed = NSPredicate { _, _ in self.number("last", in: self.state(app)) > 50020 }
        expectation(for: progressed, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(state(app).contains("pinned yes"), state(app))

        app.buttons["Jump to 2500"].tap()
        wait(app, containing: "top 2500 y 0.0")
        XCTAssertTrue(app.buttons["jump-bottom"].exists)
        XCTAssertTrue(app.staticTexts["stream-done"].waitForExistence(timeout: 35))
        XCTAssertTrue(state(app).contains("top 2500 y 0.0"), state(app))
        app.buttons["jump-bottom"].tap()
        wait(app, containing: "last 50600 loaded 40 pinned yes")
        XCTAssertLessThanOrEqual(number("loaded", in: state(app)), 300)
    }

    @MainActor func testScrollPagination() {
        let app = launch()
        wait(app, containing: "loaded 40 pinned yes")
        let timeline = app.scrollViews["timeline"]
        for _ in 0..<20 {
            timeline.swipeDown(velocity: .fast)
            if number("first", in: state(app)) < 49961 { break }
        }
        let paged = NSPredicate { _, _ in self.number("first", in: self.state(app)) < 49961 }
        expectation(for: paged, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertLessThanOrEqual(number("loaded", in: state(app)), 300)
        app.buttons["jump-bottom"].tap()
        wait(app, containing: "last 50000 loaded 40 pinned yes")
    }
    @MainActor func testTextRangeSelectionAndCopyMenu() {
        let app = launch()
        app.buttons["Jump to 2500"].tap()
        wait(app, containing: "top 2500 y 0.0")
        let text = app.staticTexts["Figma lunch night."]
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Reply"].exists)
        let handle = app.otherElements["selection-end"]
        XCTAssertTrue(handle.exists)
        if handle.exists {
            handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: text.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        }
        XCTAssertTrue(app.buttons["Copy"].exists)
        app.buttons["Copy"].tap()
        XCTAssertFalse(app.buttons["Reply"].exists)
        app.scrollViews["timeline"].swipeUp()
        XCTAssertTrue(app.staticTexts["benchmark-state"].exists)
    }

    @MainActor func testPartlyHiddenRowStaysInPlace() {
        let app = launch()
        app.buttons["Jump to 2500"].tap()
        wait(app, containing: "top 2500 y 0.0")
        let start = app.scrollViews["timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -35)),
                    withVelocity: .slow, thenHoldForDuration: 0.4)
        let before = state(app)
        XCTAssertLessThan(number("y", in: before), -2, before)
        app.buttons["Load older"].tap()
        wait(app, containing: "loaded 121")
        XCTAssertEqual(number("top", in: state(app)), number("top", in: before))
        XCTAssertEqual(number("y", in: state(app)), number("y", in: before), accuracy: 2)
        app.buttons["Text size +"].tap()
        XCTAssertEqual(number("top", in: state(app)), number("top", in: before))
        XCTAssertEqual(number("y", in: state(app)), number("y", in: before), accuracy: 2)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(number("top", in: state(app)), number("top", in: before))
        XCTAssertEqual(number("y", in: state(app)), number("y", in: before), accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
    }

}
