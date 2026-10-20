import XCTest

/// Drives the debug bar the way the benchmark does and checks the state label.
final class RoomBehaviourTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES", "-uvsVerbose", "YES"]
        app.launch()
        XCTAssertTrue(label.waitForExistence(timeout: 5))
    }

    var label: XCUIElement { app.staticTexts["debugState"] }

    /// Parsed `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`.
    struct State: CustomStringConvertible {
        var first = 0, last = 0, loaded = 0, top = 0, ms = 0
        var pinned = false
        var y: Double = 0
        var description: String { "first \(first) last \(last) loaded \(loaded) pinned \(pinned) top \(top) y \(y) ms \(ms)" }
    }

    func state(settle: TimeInterval = 0.8) -> State {
        if settle > 0 { Thread.sleep(forTimeInterval: settle) }
        let parts = label.label.split(separator: " ").map(String.init)
        var s = State()
        var i = 0
        while i + 1 < parts.count {
            let k = parts[i], v = parts[i + 1]
            switch k {
            case "first": s.first = Int(v) ?? -1
            case "last": s.last = Int(v) ?? -1
            case "loaded": s.loaded = Int(v) ?? -1
            case "pinned": s.pinned = v == "yes"
            case "top": s.top = Int(v) ?? -1
            case "y": s.y = Double(v) ?? .nan
            case "ms": s.ms = Int(v) ?? -1
            default: break
            }
            i += 2
        }
        print("STATE \(label.label)")
        return s
    }

    func tap(_ name: String) { app.buttons[name].firstMatch.tap() }

    func testLaunchAndJump() {
        let s0 = state()
        XCTAssertEqual(s0.first, 49961)
        XCTAssertEqual(s0.last, 50000)
        XCTAssertEqual(s0.loaded, 40)
        XCTAssertTrue(s0.pinned)
        XCTAssertLessThan(s0.ms, 1000)

        tap("Jump to 2500")
        let s1 = state()
        XCTAssertEqual(s1.top, 2500)
        XCTAssertEqual(s1.y, 0, accuracy: 2)
        XCTAssertFalse(s1.pinned)

        tap("Load older")
        let s2 = state()
        XCTAssertEqual(s2.first, s1.first - 40)
        XCTAssertEqual(s2.top, 2500)
        XCTAssertEqual(s2.y, 0, accuracy: 2)

        tap("Reset")
        let s3 = state()
        XCTAssertEqual(s3.last, 50000)
        XCTAssertTrue(s3.pinned)
    }

    func testScrollToTopLoadsOlder() {
        let s0 = state()
        let list = app.scrollViews.firstMatch
        for _ in 0..<12 { list.swipeDown(velocity: .fast) }
        let s1 = state(settle: 1.5)
        XCTAssertGreaterThan(s1.loaded, 40)
        XCTAssertLessThan(s1.first, s0.first)
        // Position must hold still once settled.
        let s2 = state(settle: 1.0)
        XCTAssertEqual(s1.top, s2.top)
        XCTAssertEqual(s1.y, s2.y, accuracy: 2)
    }

    func testTextSizeKeepsTopRow() {
        tap("Jump to 2500")
        let s0 = state()
        tap("Text size +")
        let s1 = state()
        XCTAssertEqual(s1.top, s0.top)
        XCTAssertEqual(s1.y, s0.y, accuracy: 2)
        tap("Text size +")
        let s2 = state()
        XCTAssertEqual(s2.top, s0.top)
        XCTAssertEqual(s2.y, s0.y, accuracy: 2)
        tap("Reset")
        tap("Text size +")
        let s3 = state()
        XCTAssertTrue(s3.pinned)
        XCTAssertEqual(s3.last, 50000)
    }

    func testRotationKeepsTopRow() {
        tap("Jump to 2500")
        let s0 = state()
        XCUIDevice.shared.orientation = .landscapeLeft
        let s1 = state(settle: 1.5)
        XCTAssertEqual(s1.top, s0.top)
        XCTAssertEqual(s1.y, s0.y, accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
        let s2 = state(settle: 1.5)
        XCTAssertEqual(s2.top, s0.top)
        XCTAssertEqual(s2.y, s0.y, accuracy: 2)
        tap("Reset")
        XCUIDevice.shared.orientation = .landscapeLeft
        let s3 = state(settle: 1.5)
        XCTAssertTrue(s3.pinned)
        XCUIDevice.shared.orientation = .portrait
        let s4 = state(settle: 1.5)
        XCTAssertTrue(s4.pinned)
    }

    func testStreamPinnedAndUnpinned() {
        tap("Start stream")
        let s1 = state(settle: 3)
        XCTAssertTrue(s1.pinned)
        XCTAssertGreaterThan(s1.last, 50000)
        let list = app.scrollViews.firstMatch
        list.swipeDown(velocity: .slow)
        let s2 = state(settle: 1.5)
        XCTAssertFalse(s2.pinned)
        let s3 = state(settle: 2)
        XCTAssertEqual(s3.top, s2.top)
        XCTAssertEqual(s3.y, s2.y, accuracy: 2)
        XCTAssertTrue(app.buttons["Jump to bottom"].exists)
        XCTAssertTrue(app.staticTexts["streamDone"].waitForExistence(timeout: 40))
    }

    func testBoostBurstKeepsPinned() {
        tap("Boost burst")
        let s1 = state(settle: 2)
        XCTAssertTrue(s1.pinned)
        XCTAssertGreaterThan(s1.top, 0)
    }

    func testLongPressSelectsAndShowsMenu() {
        let row = app.descendants(matching: .any)["message-49999"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Reply"].exists)
        Thread.sleep(forTimeInterval: 2)
        // Drag the end handle back towards the start: the selection shrinks to a range.
        let frame = row.frame
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.maxX - 30, dy: frame.maxY - 14))
        let target = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.maxY - 14))
        end.press(forDuration: 0.05, thenDragTo: target)
        Thread.sleep(forTimeInterval: 3)
        app.buttons["Copy"].tap()
        XCTAssertFalse(app.buttons["Reply"].waitForExistence(timeout: 1))
        // Scrolling still works afterwards.
        let before = state()
        app.scrollViews.firstMatch.swipeDown()
        let after = state(settle: 1.5)
        XCTAssertNotEqual(before.top, after.top)
    }
}
