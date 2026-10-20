import XCTest

/// Drives the benchmark debug bar and checks the state label:
/// `first F last L loaded N pinned yes|no top T y Y ms M`.
final class RoomUITests: XCTestCase {
    struct State {
        var first = 0, last = 0, loaded = 0, top = 0, ms = 0
        var pinned = false
        var y: Double = 0
    }

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["debug-state"].waitForExistence(timeout: 5))
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func state() -> State {
        let text = app.staticTexts["debug-state"].label
        let parts = text.split(separator: " ").map(String.init)
        var s = State()
        var i = 0
        while i + 1 < parts.count {
            let v = parts[i + 1]
            switch parts[i] {
            case "first": s.first = Int(v)!
            case "last": s.last = Int(v)!
            case "loaded": s.loaded = Int(v)!
            case "pinned": s.pinned = v == "yes"
            case "top": s.top = Int(v)!
            case "y": s.y = Double(v)!
            case "ms": s.ms = Int(v)!
            default: break
            }
            i += 2
        }
        return s
    }

    func tap(_ name: String) {
        app.buttons[name].tap()
        usleep(600_000)
    }

    func testLaunchState() {
        let s = state()
        print("STATE launch", app.staticTexts["debug-state"].label)
        XCTAssertEqual(s.first, 49961)
        XCTAssertEqual(s.last, 50000)
        XCTAssertEqual(s.loaded, 40)
        XCTAssertTrue(s.pinned)
        XCTAssertLessThan(s.ms, 1000)
    }

    func testLoadOlderKeepsPosition() {
        let before = state()
        tap("Load older")
        let after = state()
        print("STATE load older", before, after)
        XCTAssertEqual(after.loaded, 80)
        XCTAssertEqual(after.first, 49921)
        XCTAssertEqual(after.top, before.top)
        XCTAssertEqual(after.y, before.y, accuracy: 2)
    }

    func testJumpTo2500() {
        tap("Jump to 2500")
        let s = state()
        print("STATE jump", app.staticTexts["debug-state"].label)
        XCTAssertEqual(s.top, 2500)
        XCTAssertEqual(s.y, 0, accuracy: 2)
        XCTAssertFalse(s.pinned)
        // The cell's frame agrees with the label.
        let header = app.otherElements["room-header"].frame
        let cell = app.cells["message-2500"].frame
        XCTAssertEqual(cell.minY, header.maxY, accuracy: 2)
    }

    func testTextSizeKeepsTopRow() {
        tap("Jump to 2500")
        app.swipeUp()
        usleep(1_500_000)
        let before = state()
        for _ in 0..<3 {
            tap("Text size +")
            let after = state()
            print("STATE text size", before, after)
            XCTAssertEqual(after.top, before.top)
            XCTAssertEqual(after.y, before.y, accuracy: 2)
        }
        tap("Reset")
        XCTAssertTrue(state().pinned)
    }

    func testTextSizeKeepsPinned() {
        for _ in 0..<13 {
            tap("Text size +")
            let s = state()
            XCTAssertTrue(s.pinned)
            XCTAssertEqual(s.last, 50000)
        }
    }

    func testRotationKeepsTopRow() {
        tap("Jump to 2500")
        let before = state()
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        let land = state()
        print("STATE rotate", before, land)
        XCTAssertEqual(land.top, before.top)
        XCTAssertEqual(land.y, before.y, accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        let back = state()
        XCTAssertEqual(back.top, before.top)
        XCTAssertEqual(back.y, before.y, accuracy: 2)
    }

    func testRotationKeepsPinned() {
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        XCTAssertTrue(state().pinned)
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        XCTAssertTrue(state().pinned)
    }

    func testStreamPinnedAndDone() {
        tap("Start stream")
        sleep(3)
        let s = state()
        print("STATE stream", app.staticTexts["debug-state"].label)
        XCTAssertTrue(s.pinned)
        XCTAssertGreaterThan(s.last, 50020)
        XCTAssertTrue(app.staticTexts["Stream done"].waitForExistence(timeout: 40))
        let end = state()
        print("STATE stream end", app.staticTexts["debug-state"].label)
        XCTAssertEqual(end.last, 50600)
        XCTAssertTrue(end.pinned)
    }

    func testStreamWhileScrolledAway() {
        app.swipeDown()
        usleep(1_500_000)
        let before = state()
        XCTAssertFalse(before.pinned)
        tap("Start stream")
        sleep(3)
        let after = state()
        print("STATE stream away", before, after)
        XCTAssertEqual(after.top, before.top)
        XCTAssertEqual(after.y, before.y, accuracy: 2)
        XCTAssertTrue(app.buttons["jump-to-bottom"].exists)
    }

    func testBoostBurstStaysPinned() {
        tap("Boost burst")
        sleep(2)
        XCTAssertTrue(state().pinned)
    }

    func testScrollingToTopLoadsOlder() {
        for _ in 0..<12 { app.swipeDown(velocity: .fast) }
        sleep(1)
        let s = state()
        print("STATE scroll top", app.staticTexts["debug-state"].label)
        XCTAssertGreaterThanOrEqual(s.loaded, 80)
    }

    func testLongPressShowsCopyAndReply() {
        let cell = app.cells["message-50000"]
        let text = cell.textViews.firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 2))
        text.press(forDuration: 1.2)
        XCTAssertTrue(app.menuItems["Copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuItems["Reply"].exists)
        app.menuItems["Copy"].tap()
        app.swipeDown()
    }
}
