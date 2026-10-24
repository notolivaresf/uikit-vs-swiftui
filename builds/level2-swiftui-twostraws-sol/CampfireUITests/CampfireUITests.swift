import XCTest

@MainActor final class CampfireUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        launchApp()
    }

    private func launchApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.staticTexts["benchmarkState"].waitForExistence(timeout: 10))
        waitForState { $0["top"] != "0" && $0["ms"] != "0" }
    }

    func testPagingJumpResizeRotationAndBoosts() {
        let launch = state()
        XCTAssertEqual(launch["first"], "49961")
        XCTAssertEqual(launch["last"], "50000")
        XCTAssertEqual(launch["loaded"], "40")
        XCTAssertEqual(launch["pinned"], "yes")
        print("LAUNCH STATE \(label)")
        attachScreenshot("initial-light")

        app.buttons["Jump to 2500"].tap()
        waitForState { $0["top"] == "2500" && abs(Double($0["y"] ?? "999") ?? 999) <= 2 }
        XCTAssertEqual(state()["loaded"], "81")
        assertPhysicalTop(id: 2500, y: 0)
        print("JUMP STATE \(label)")
        let beforeOlder = state()
        app.buttons["Load older"].tap()
        waitForState { $0["loaded"] == "121" }
        assertAnchor(beforeOlder)
        assertPhysicalTop(id: 2500, y: 0)
        print("OLDER STATE \(label)")

        let beforeTextSize = state()
        app.buttons["Text size +"].tap()
        waitForState { $0["ms"] != beforeTextSize["ms"] }
        assertAnchor(beforeTextSize)
        assertPhysicalTop(id: 2500, y: 0)
        attachScreenshot("larger-text")

        let beforeRotation = state()
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForState { $0["top"] == beforeRotation["top"] }
        // Rotation completes asynchronously, after the orientation notification.
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 3))
        assertAnchor(beforeRotation)
        assertPhysicalTop(id: 2500, y: 0)
        attachScreenshot("landscape")
        XCUIDevice.shared.orientation = .portrait
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            app.frame.height > app.frame.width && app.buttons["Reset"].frame.minY < app.frame.height * 0.3
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 5), .completed)
        // A snapshot synchronizes hit testing after the rotation animation.
        _ = app.screenshot()
        app.buttons["Reset"].tap()
        waitForState { $0["loaded"] == "40" && $0["pinned"] == "yes" && $0["last"] == "50000" }
        app.buttons["Boost burst"].tap()
        let boost = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "boosted 😂")).firstMatch
        XCTAssertTrue(boost.waitForExistence(timeout: 4))
        XCTAssertEqual(state()["pinned"], "yes")
        attachScreenshot("boost-burst")
    }

    func testLiveStreamPreservesReadingPositionAndJumpReturnsToNewest() {
        app.buttons["Jump to 2500"].tap()
        waitForState { $0["top"] == "2500" }
        let anchor = state()
        let ms = anchor["ms"]
        app.buttons["Start stream"].tap()
        XCTAssertTrue(app.staticTexts["streamDone"].waitForExistence(timeout: 40))
        assertAnchor(anchor)
        XCTAssertEqual(state()["ms"], ms)
        app.buttons["Jump to bottom"].tap()
        waitForState { $0["last"] == "50600" && $0["pinned"] == "yes" }
        XCTAssertEqual(state()["loaded"], "40")
        attachScreenshot("stream-complete")
    }

    func testPinnedStreamAndSelection() {
        app.buttons["Start stream"].tap()
        XCTAssertTrue(app.staticTexts["streamDone"].waitForExistence(timeout: 40))
        waitForState { $0["last"] == "50600" && $0["pinned"] == "yes" }
        XCTAssertLessThanOrEqual(Int(state()["loaded"] ?? "999") ?? 999, 300)
        print("STREAM STATE \(label)")
        app.buttons["Reset"].tap()
        waitForState { $0["last"] == "50000" }
        app.buttons["Jump to 2500"].tap()
        waitForState { $0["top"] == "2500" }
        app.staticTexts["Figma lunch night."].press(forDuration: 1)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Reply"].exists)
        attachScreenshot("context-menu")
    }

    func testSelectTextRange() {
        app.buttons["Jump to 2500"].tap()
        waitForState { $0["top"] == "2500" }
        let text = app.staticTexts["Figma lunch night."]
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Select text"].waitForExistence(timeout: 3))
        app.buttons["Select text"].tap()
        XCTAssertTrue(app.otherElements["Selection start"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["Selection end"].exists)
        attachScreenshot("text-range-selection")
        let end = app.otherElements["Selection end"]
        let destination = text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: destination)
        attachScreenshot("adjusted-text-range")
        app.buttons["Copy"].tap()
    }

    func testReachingTopLoadsOneOlderPage() {
        let transcript = app.scrollViews["transcript"]
        for _ in 0..<15 {
            if state()["first"] != "49961" { break }
            transcript.swipeDown(velocity: .fast)
        }
        waitForState { $0["first"] == "49921" && $0["loaded"] == "80" }
        XCTAssertEqual(state()["last"], "50000")
    }

    private var label: String { app.staticTexts["benchmarkState"].label }

    private func state() -> [String: String] {
        let words = label.split(separator: " ").map(String.init)
        var result: [String: String] = [:]
        for index in stride(from: 0, to: words.count - 1, by: 2) { result[words[index]] = words[index + 1] }
        return result
    }

    private func waitForState(timeout: Double = 8, _ condition: @escaping ([String: String]) -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in condition(state()) }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, label)
    }

    private func assertAnchor(_ prior: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        let current = state()
        XCTAssertEqual(current["top"], prior["top"], label, file: file, line: line)
        XCTAssertEqual(Double(current["y"] ?? "999") ?? 999, Double(prior["y"] ?? "0") ?? 0,
                       accuracy: 2, label, file: file, line: line)
    }

    private func assertPhysicalTop(id: Int, y: Double, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.otherElements["message-\(id)"].firstMatch
        XCTAssertTrue(row.exists, file: file, line: line)
        let header = app.otherElements["roomHeader"].firstMatch
        XCTAssertEqual(row.frame.minY - header.frame.maxY, y, accuracy: 2, file: file, line: line)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
