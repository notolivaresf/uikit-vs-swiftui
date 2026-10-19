import XCTest

/// Drives the debug bar the way the benchmark does and checks the state label.
final class RoomUITests: XCTestCase {
    var app: XCUIApplication!
    let shotDir = ProcessInfo.processInfo.environment["CF_SHOTS"] ?? "/tmp/cf/ui"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        XCUIDevice.shared.orientation = .portrait
    }

    var state: String { app.staticTexts["debugState"].label }

    func field(_ name: String) -> String {
        let parts = state.split(separator: " ").map(String.init)
        guard let i = parts.firstIndex(of: name), i + 1 < parts.count else { return "" }
        return parts[i + 1]
    }

    func shot(_ name: String) {
        try? FileManager.default.createDirectory(atPath: shotDir, withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    func tap(_ title: String) {
        app.buttons[title].tap()
        Thread.sleep(forTimeInterval: 0.4)
    }

    func log(_ what: String) { print("STATE [\(what)] \(state)") }

    func testLaunchAndJump() {
        app.launch()
        XCTAssertTrue(app.staticTexts["debugState"].waitForExistence(timeout: 5))
        log("launch")
        XCTAssertEqual(field("first"), "49961")
        XCTAssertEqual(field("last"), "50000")
        XCTAssertEqual(field("pinned"), "yes")
        tap("Jump to 2500")
        log("jump")
        XCTAssertEqual(field("top"), "2500")
        XCTAssertLessThan(abs(Double(field("y")) ?? 99), 2)
        shot("jump2500")
        let topBefore = field("top"), yBefore = Double(field("y")) ?? 0
        tap("Load older")
        log("load older")
        XCTAssertEqual(field("top"), topBefore)
        XCTAssertLessThan(abs((Double(field("y")) ?? 99) - yBefore), 2)
        tap("Text size +")
        log("text size +")
        XCTAssertEqual(field("top"), topBefore)
        XCTAssertLessThan(abs((Double(field("y")) ?? 99) - yBefore), 2)
        shot("textsize1")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        log("landscape")
        XCTAssertEqual(field("top"), topBefore)
        XCTAssertLessThan(abs((Double(field("y")) ?? 99) - yBefore), 2)
        shot("landscape")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        log("portrait")
        XCTAssertEqual(field("top"), topBefore)
        tap("Reset")
        log("reset")
        XCTAssertEqual(field("pinned"), "yes")
        XCTAssertEqual(field("last"), "50000")
    }

    func testScrollTopLoadsOlder() {
        app.launch()
        XCTAssertTrue(app.staticTexts["debugState"].waitForExistence(timeout: 5))
        let room = app.collectionViews["room"]
        for i in 0..<6 {
            room.swipeDown(velocity: .fast)
            Thread.sleep(forTimeInterval: 1.2)
            log("swipe \(i)")
        }
        XCTAssertNotEqual(field("first"), "49961")
        XCTAssertEqual(field("pinned"), "no")
        XCTAssertTrue(app.otherElements["Jump to bottom"].exists || app.buttons["Jump to bottom"].exists)
    }

    func testStreamPinnedAndBoosts() {
        app.launch()
        XCTAssertTrue(app.staticTexts["debugState"].waitForExistence(timeout: 5))
        tap("Start stream")
        Thread.sleep(forTimeInterval: 3)
        log("stream 3s")
        XCTAssertEqual(field("pinned"), "yes")
        tap("Boost burst")
        Thread.sleep(forTimeInterval: 1.5)
        log("burst")
        XCTAssertEqual(field("pinned"), "yes")
        shot("stream")
        // Scroll up: stays put while the stream continues.
        app.collectionViews["room"].swipeDown(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.5)
        let top = field("top"), y = Double(field("y")) ?? 0
        log("scrolled up")
        Thread.sleep(forTimeInterval: 2)
        log("scrolled up later")
        XCTAssertEqual(field("pinned"), "no")
        XCTAssertEqual(field("top"), top)
        XCTAssertLessThan(abs((Double(field("y")) ?? 99) - y), 2)
        XCTAssertTrue(app.staticTexts["Stream done"].waitForExistence(timeout: 40))
        log("done")
    }

    func testScreenshots() {
        app.launchArguments = []
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        shot("bottom-0")
        let room = app.collectionViews["room"]
        for i in 1...7 {
            room.swipeDown(velocity: 600)
            Thread.sleep(forTimeInterval: 1.2)
            shot("bottom-\(i)")
        }
    }

    func testPinnedSurvivesRotationAndTextSize() {
        app.launch()
        XCTAssertTrue(app.staticTexts["debugState"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeRight
        Thread.sleep(forTimeInterval: 1.5)
        log("pinned landscape")
        XCTAssertEqual(field("pinned"), "yes")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        log("pinned portrait")
        XCTAssertEqual(field("pinned"), "yes")
        for i in 0..<9 {
            tap("Text size +")
            log("pinned text size \(i)")
            XCTAssertEqual(field("pinned"), "yes")
            if i == 7 { shot("textsize-largest") }
        }
        tap("Text size +")
        log("text size back to default")
        XCTAssertEqual(field("pinned"), "yes")
        tap("Text size +")
        tap("Text size +")
        tap("Reset")
        log("reset")
        XCTAssertEqual(field("pinned"), "yes")
    }

    func testLongPressMenu() {
        app.launch()
        XCTAssertTrue(app.staticTexts["debugState"].waitForExistence(timeout: 5))
        let text = app.textViews.firstMatch
        XCTAssertTrue(text.exists)
        text.press(forDuration: 1.0)
        Thread.sleep(forTimeInterval: 0.8)
        shot("longpress")
        XCTAssertTrue(app.menuItems["Reply"].exists || app.buttons["Reply"].exists || app.staticTexts["Reply"].exists)
        XCTAssertTrue(app.menuItems["Copy"].exists || app.buttons["Copy"].exists || app.staticTexts["Copy"].exists)
        let copy = app.menuItems["Copy"].exists ? app.menuItems["Copy"] : app.buttons["Copy"]
        copy.tap()
        Thread.sleep(forTimeInterval: 0.5)
        text.press(forDuration: 1.0)
        Thread.sleep(forTimeInterval: 0.8)
        // Scrolling still works around a selection.
        let before = state
        app.collectionViews["room"].swipeDown(velocity: .slow)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(state, before)
    }
}
