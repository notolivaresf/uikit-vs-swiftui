import XCTest

@MainActor
final class RoomUITests: XCTestCase {
    var app: XCUIApplication!
    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["benchmark-state"].waitForExistence(timeout: 5))
        waitForState { $0.contains("loaded 40") }
    }
    private var state: String { app.staticTexts["benchmark-state"].label }
    private func waitForState(_ condition: @escaping (String) -> Bool, timeout: TimeInterval = 5) {
        let predicate = NSPredicate { [weak self] _, _ in condition(self?.state ?? "") }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout), .completed, state)
    }
    private func rotate(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        // XCTest can report idle before the rotation moves button hit targets to their final frames.
        let deadline = Date().addingTimeInterval(0.8)
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in Date() >= deadline }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
    }
    private func value(_ key: String, in text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        guard let i = tokens.firstIndex(of: key), i + 1 < tokens.count else { return "" }
        return tokens[i + 1]
    }
    private func assertAnchor(_ before: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(value("top", in: state), value("top", in: before), file: file, line: line)
        XCTAssertEqual(Double(value("y", in: state)) ?? 9999, Double(value("y", in: before)) ?? -9999, accuracy: 2, file: file, line: line)
    }
    func testLaunchPagingJumpTextAndRotation() {
        launch()
        XCTAssertTrue(state.contains("first 49961 last 50000 loaded 40 pinned yes"), state)
        XCTAssertLessThan(Int(value("ms", in: state)) ?? 9999, 1000, state)
        let start = state
        app.buttons["Load older"].tap()
        waitForState { $0.contains("loaded 80") }
        assertAnchor(start)
        app.buttons["Jump to 2500"].tap()
        waitForState { $0.contains("top 2500") }
        XCTAssertEqual(Double(value("y", in: state)) ?? 999, 0, accuracy: 2)
        let jumped = state
        app.buttons["Text size +"].tap()
        waitForState { $0 != jumped }
        assertAnchor(jumped)
        let resized = state
        rotate(.landscapeLeft)
        waitForState { $0.contains("top 2500") }
        assertAnchor(resized)
        rotate(.portrait)
        app.buttons["Reset"].tap()
        waitForState { $0.contains("loaded 40 pinned yes") }
        rotate(.landscapeLeft)
        waitForState { $0.contains("pinned yes") }
        rotate(.portrait)
        waitForState { $0.contains("pinned yes") }
    }
    func testBoostGrowthAndPinnedStream() {
        launch()
        app.buttons["Boost burst"].tap()
        let boosted = NSPredicate { [weak self] _, _ in
            (self?.app.otherElements.matching(NSPredicate(format: "label CONTAINS 'boosted' ")).count ?? 0) >= 5
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: boosted, object: nil)], timeout: 4), .completed)
        XCTAssertTrue(state.contains("pinned yes"), state)
        app.buttons["Start stream"].tap()
        waitForState({ $0.contains("last 50600") }, timeout: 36)
        XCTAssertTrue(app.staticTexts["Stream done"].waitForExistence(timeout: 5))
        XCTAssertTrue(state.contains("pinned yes"), state)
        app.buttons["Reset"].tap()
        waitForState { $0.contains("first 49961 last 50000 loaded 40 pinned yes") }
    }
    func testUnpinnedStreamPreservesAnchor() {
        launch()
        app.buttons["Jump to 2500"].tap()
        waitForState { $0.contains("top 2500") }
        let before = state
        app.buttons["Start stream"].tap()
        waitForState({ $0.contains("last 50040") || (Int(self.value("last", in: $0)) ?? 0) > 50040 }, timeout: 8)
        assertAnchor(before)
        XCTAssertTrue(app.buttons["jump-to-bottom"].exists)
        app.buttons["jump-to-bottom"].tap()
        waitForState { $0.contains("pinned yes") }
    }
    func testReachingTopAutomaticallyLoadsOlder() {
        launch()
        app.buttons["Jump to 2500"].tap()
        waitForState { $0.contains("top 2500") }
        let list = app.collectionViews["room-messages"]
        for _ in 0..<12 {
            if (Int(value("first", in: state)) ?? 2460) < 2460 { break }
            list.swipeDown(velocity: .fast)
        }
        waitForState { (Int(self.value("first", in: $0)) ?? 2460) < 2460 }
    }
    func testSelectionAndContextMenu() {
        launch()
        app.buttons["Jump to 2500"].tap()
        waitForState { $0.contains("top 2500") }
        let text = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'text-2500-'")).firstMatch
        XCTAssertTrue(text.exists)
        text.press(forDuration: 1.1)
        XCTAssertTrue(app.menuItems["Copy"].waitForExistence(timeout: 3) || app.buttons["Copy"].exists)
        XCTAssertTrue(app.menuItems["Reply"].exists || app.buttons["Reply"].exists)
        XCTAssertTrue(["Select All", "Look Up", "Translate"].contains {
            app.menuItems[$0].exists || app.buttons[$0].exists
        })
    }
}
