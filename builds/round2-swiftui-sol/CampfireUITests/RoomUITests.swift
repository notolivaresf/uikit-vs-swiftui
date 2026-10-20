import XCTest

final class RoomUITests: XCTestCase {
    @MainActor func testJumpReturn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        let state = app.staticTexts["benchmark-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        app.buttons["Jump to 2500"].tap()
        wait(state, containing: "top 2500")
        app.buttons["jump-bottom"].tap()
        sleep(1)
        wait(state, containing: "last 50000 loaded 40 pinned yes")
    }

    @MainActor func testTouchScrollingAndPaging() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        let state = app.staticTexts["benchmark-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        let scroll = app.scrollViews["chat-scroll"]
        scroll.swipeDown(velocity: .fast)
        wait(state, containing: "pinned no")
        let original = parse(state.label)
        app.buttons["Load older"].tap()
        sleep(1)
        assertAnchor(original, parse(state.label))
        app.buttons["Text size +"].tap()
        sleep(1)
        assertAnchor(original, parse(state.label))
        app.buttons["Start stream"].tap()
        sleep(2)
        assertAnchor(original, parse(state.label))
        app.buttons["Reset"].tap()
        wait(state, containing: "loaded 40 pinned yes")
        for _ in 0..<10 {
            scroll.swipeDown(velocity: .fast)
            if !state.label.contains("first 49961") { break }
        }
        XCTAssertFalse(state.label.contains("first 49961"), state.label)
        let visibleRow = app.otherElements["message-\(parse(state.label).top)"]
        let candidates = visibleRow.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".{20,}"))
        if let text = candidates.allElementsBoundByIndex.prefix(8).first(where: { $0.isHittable }) {
            text.press(forDuration: 1.1)
            XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["Reply"].exists)
            app.buttons["Copy"].tap()
        } else { XCTFail("No visible message text") }
    }

    @MainActor
    func testAnchorsAndStream() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        let state = app.staticTexts["benchmark-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        wait(state, containing: "first 49961 last 50000 loaded 40 pinned yes")
        let launch = parse(state.label)
        XCTAssertLessThan(launch.ms, 1000, state.label)
        app.buttons["Jump to 2500"].tap()
        wait(state, containing: "top 2500")
        XCTAssertEqual(parse(state.label).y, 0, accuracy: 2, state.label)
        let original = parse(state.label)
        app.buttons["Load older"].tap()
        wait(state, containing: "first 2420")
        assertAnchor(original, parse(state.label))
        app.buttons["Text size +"].tap()
        wait(state, containing: "top 2500")
        assertAnchor(original, parse(state.label))
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        assertAnchor(original, parse(state.label))
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        assertAnchor(original, parse(state.label))
        app.buttons["Start stream"].tap()
        sleep(2)
        assertAnchor(original, parse(state.label))
        XCTAssertTrue(app.buttons["jump-bottom"].exists)
        app.buttons["Reset"].tap()
        wait(state, containing: "first 49961 last 50000 loaded 40 pinned yes")
        app.buttons["Boost burst"].tap()
        sleep(2)
        XCTAssertTrue(state.label.contains("pinned yes"), state.label)
        app.buttons["Start stream"].tap()
        XCTAssertTrue(app.staticTexts["stream-done"].waitForExistence(timeout: 40))
        XCTAssertTrue(state.label.contains("last 50600"), state.label)
        XCTAssertTrue(state.label.contains("pinned yes"), state.label)
        XCTAssertLessThanOrEqual(parse(state.label).loaded, 320)
        app.buttons["Jump to 2500"].tap()
        wait(state, containing: "top 2500")
        XCTAssertEqual(parse(state.label).y, 0, accuracy: 2, state.label)
        app.buttons["jump-bottom"].tap()
        wait(state, containing: "last 50600 loaded 40 pinned yes")
    }

    @MainActor private func wait(_ element: XCUIElement, containing value: String) {
        let predicate = NSPredicate { _, _ in element.label.contains(value) }
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }

    private struct State { let top: Int; let y: Double; let ms: Int; let loaded: Int }
    private func parse(_ label: String) -> State {
        let values = label.split(separator: " ").map(String.init)
        func value(_ key: String) -> String {
            guard let index = values.firstIndex(of: key), index + 1 < values.count else { return "-1" }
            return values[index + 1]
        }
        return State(top: Int(value("top")) ?? -1, y: Double(value("y")) ?? -1000,
                     ms: Int(value("ms")) ?? -1, loaded: Int(value("loaded")) ?? -1)
    }
    private func assertAnchor(_ before: State, _ after: State, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(before.top, after.top, file: file, line: line)
        XCTAssertEqual(before.y, after.y, accuracy: 2, file: file, line: line)
    }
}
