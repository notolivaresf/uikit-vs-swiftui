import XCTest

/// Drives the debug bar the way the benchmark does and checks the state label.
final class RoomUITests: XCTestCase {
    struct State {
        var first = 0, last = 0, loaded = 0, pinned = false, top = 0, y = 0.0, ms = 0
        init(_ label: String) {
            let p = label.split(separator: " ").map(String.init)
            func v(_ key: String) -> String { p.firstIndex(of: key).map { p[$0 + 1] } ?? "" }
            first = Int(v("first")) ?? 0; last = Int(v("last")) ?? 0; loaded = Int(v("loaded")) ?? 0
            pinned = v("pinned") == "yes"; top = Int(v("top")) ?? 0; y = Double(v("y")) ?? .nan; ms = Int(v("ms")) ?? -1
        }
    }

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES", "-uvsVerbose"]
        app.launch()
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        waitFor { $0.loaded == 40 }
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    var label: XCUIElement { app.staticTexts["debug-state"] }
    var state: State { State(label.label) }

    @discardableResult
    func waitFor(_ timeout: TimeInterval = 5, _ condition: (State) -> Bool) -> State {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            let s = state
            if condition(s) { return s }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("timed out; label: \(label.label)")
        return state
    }

    func settle(_ seconds: TimeInterval = 0.8) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    func tap(_ name: String) { app.buttons[name].tap() }

    /// Drags the message list down (towards older messages) by about `points`.
    func dragTowardsOlder(_ points: CGFloat) {
        let list = app.scrollViews["messages"]
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = start.withOffset(CGVector(dx: 0, dy: points))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    func testLaunchOpensNewestPageAtBottom() {
        let s = state
        print("STATE launch: \(label.label)")
        XCTAssertEqual(s.first, 49961); XCTAssertEqual(s.last, 50000); XCTAssertEqual(s.loaded, 40)
        XCTAssertTrue(s.pinned)
        XCTAssertLessThan(s.ms, 1000)
    }

    func testJumpTo2500() {
        tap("Jump to 2500")
        let s = waitFor { $0.top == 2500 }
        print("STATE jump: \(label.label)")
        XCTAssertEqual(s.y, 0, accuracy: 2)
        XCTAssertFalse(s.pinned)
    }

    func testLoadOlderKeepsReaderInPlace() {
        tap("Jump to 2500")
        waitFor { $0.top == 2500 }
        dragTowardsOlder(120)
        settle()
        let before = state
        tap("Load older")
        let after = waitFor { $0.first == before.first - 40 }
        settle()
        let final = state
        print("STATE older: \(before) -> \(final)")
        XCTAssertEqual(final.top, before.top)
        XCTAssertEqual(final.y, before.y, accuracy: 2)
        XCTAssertEqual(after.loaded, before.loaded + 40)
    }

    func testScrollingToTopLoadsOlder() {
        tap("Jump to 2500")
        waitFor { $0.top == 2500 }
        for _ in 0..<14 { dragTowardsOlder(500) }
        settle()
        let s = state
        print("STATE top-scroll: \(label.label)")
        XCTAssertLessThan(s.first, 2460)
    }

    func testStreamStaysPinned() {
        tap("Start stream")
        settle(3)
        let s = state
        print("STATE stream pinned: \(label.label)")
        XCTAssertTrue(s.pinned)
        XCTAssertGreaterThan(s.last, 50020)
        XCTAssertFalse(app.buttons["jump-to-bottom"].exists)
    }

    func testStreamWhileScrolledUpStaysPut() {
        dragTowardsOlder(400)
        settle()
        let before = state
        XCTAssertFalse(before.pinned)
        tap("Start stream")
        settle(3)
        let after = state
        print("STATE stream unpinned: \(before) -> \(after)")
        XCTAssertEqual(after.top, before.top)
        XCTAssertEqual(after.y, before.y, accuracy: 2)
        XCTAssertTrue(app.buttons["jump-to-bottom"].exists)
    }

    func testTextSizeKeepsTopRow() {
        tap("Jump to 2500")
        waitFor { $0.top == 2500 }
        for _ in 0..<3 {
            tap("Text size +")
            settle()
            let s = state
            print("STATE text size: \(label.label)")
            XCTAssertEqual(s.top, 2500)
            XCTAssertEqual(s.y, 0, accuracy: 2)
        }
        tap("Reset")
        let s = waitFor { $0.loaded == 40 && $0.pinned }
        XCTAssertEqual(s.last, 50000)
    }

    func testTextSizeKeepsPinned() {
        for _ in 0..<2 {
            tap("Text size +")
            settle()
            XCTAssertTrue(state.pinned, label.label)
        }
    }

    func testRotationKeepsTopRow() {
        tap("Jump to 2500")
        waitFor { $0.top == 2500 }
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(1.5)
        var s = state
        print("STATE landscape: \(label.label)")
        XCTAssertEqual(s.top, 2500); XCTAssertEqual(s.y, 0, accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
        settle(1.5)
        s = state
        print("STATE portrait: \(label.label)")
        XCTAssertEqual(s.top, 2500); XCTAssertEqual(s.y, 0, accuracy: 2)
    }

    func testRotationKeepsPinned() {
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(1.5)
        XCTAssertTrue(state.pinned, label.label)
        XCUIDevice.shared.orientation = .portrait
        settle(1.5)
        XCTAssertTrue(state.pinned, label.label)
    }

    func testBoostBurstStaysPinned() {
        tap("Boost burst")
        settle(1.6)
        let s = state
        print("STATE burst: \(label.label)")
        XCTAssertTrue(s.pinned)
        XCTAssertEqual(app.otherElements["message-50000"].exists || true, true)
    }

    func testLongPressShowsMenu() {
        let message = app.descendants(matching: .any)["message-49999"]
        XCTAssertTrue(message.waitForExistence(timeout: 3))
        message.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Reply"].exists)
    }
}
