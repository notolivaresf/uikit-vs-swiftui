import XCTest

/// Drives the debug bar (`-uvsBenchmark YES`) and checks the state label after each action.
final class RoomBehaviourTests: XCTestCase {
    struct State: CustomStringConvertible {
        let first, last, loaded: Int
        let pinned: Bool
        let top: Int
        let y: Double
        let ms: Int
        let raw: String
        var description: String { raw }
    }

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launchEnvironment["CF_TRACE"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["state"].waitForExistence(timeout: 5))
        _ = waitFor { $0.loaded > 0 }
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func state() -> State {
        let raw = app.staticTexts["state"].label
        let p = raw.split(separator: " ").map(String.init)
        func v(_ key: String) -> String { p[p.firstIndex(of: key)! + 1] }
        return State(first: Int(v("first"))!, last: Int(v("last"))!, loaded: Int(v("loaded"))!,
                     pinned: v("pinned") == "yes", top: Int(v("top"))!, y: Double(v("y"))!, ms: Int(v("ms"))!, raw: raw)
    }

    @discardableResult
    func waitFor(_ timeout: TimeInterval = 5, _ condition: (State) -> Bool) -> State {
        let end = Date().addingTimeInterval(timeout)
        var s = state()
        while Date() < end {
            s = state()
            if condition(s) { return s }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return s
    }

    /// Waits until the label stops changing.
    func settled() -> State {
        var last = state().raw
        var stable = 0
        for _ in 0..<60 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            let now = state().raw
            if now == last { stable += 1; if stable >= 3 { break } } else { stable = 0; last = now }
        }
        return state()
    }

    func tap(_ title: String) { app.buttons[title].firstMatch.tap() }

    func testLaunch() {
        let s = settled()
        print("LAUNCH", s)
        XCTAssertEqual(s.first, 49961)
        XCTAssertEqual(s.last, 50000)
        XCTAssertEqual(s.loaded, 40)
        XCTAssertTrue(s.pinned)
        XCTAssertLessThan(s.ms, 1000)
    }

    func testLoadOlderKeepsPosition() {
        let before = settled()
        tap("Load older")
        let after = waitFor { $0.loaded == 80 }
        let s = settled()
        print("LOAD OLDER", before, "->", s)
        XCTAssertEqual(after.first, 49921)
        XCTAssertEqual(s.top, before.top)
        XCTAssertEqual(s.y, before.y, accuracy: 2)
    }

    func testJumpAndTextSize() {
        tap("Jump to 2500")
        var s = waitFor { $0.top == 2500 }
        s = settled()
        print("JUMP", s)
        XCTAssertEqual(s.top, 2500)
        XCTAssertEqual(s.y, 0, accuracy: 2)
        XCTAssertFalse(s.pinned)
        for i in 0..<4 {
            tap("Text size +")
            let t = settled()
            print("TEXT+", i, t)
            XCTAssertEqual(t.top, 2500)
            XCTAssertEqual(t.y, 0, accuracy: 2)
        }
        tap("Reset")
        let r = settled()
        print("RESET", r)
        XCTAssertEqual(r.loaded, 40)
        XCTAssertTrue(r.pinned)
    }

    func testTextSizeWhilePinned() {
        for i in 0..<3 {
            tap("Text size +")
            let t = settled()
            print("PINNED TEXT+", i, t)
            XCTAssertTrue(t.pinned)
        }
    }

    func testRotation() {
        tap("Jump to 2500")
        _ = waitFor { $0.top == 2500 }
        let s = settled()
        XCUIDevice.shared.orientation = .landscapeLeft
        let l = settled()
        print("ROTATE", s, "->", l)
        XCTAssertEqual(l.top, s.top)
        XCTAssertEqual(l.y, s.y, accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
        let p = settled()
        print("ROTATE BACK", p)
        XCTAssertEqual(p.top, s.top)
        XCTAssertEqual(p.y, s.y, accuracy: 2)
    }

    func testRotationPinned() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let l = settled()
        print("ROTATE PINNED", l)
        XCTAssertTrue(l.pinned)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(settled().pinned)
    }

    func testStreamPinnedThenScrolledUp() {
        tap("Start stream")
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        let a = state()
        print("STREAM pinned", a)
        XCTAssertTrue(a.pinned)
        XCTAssertGreaterThan(a.last, 50000)
        app.swipeDown(velocity: .slow)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let b = state()
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        let c = state()
        print("STREAM unpinned", b, "->", c)
        XCTAssertFalse(c.pinned)
        XCTAssertEqual(b.top, c.top)
        XCTAssertEqual(b.y, c.y, accuracy: 2)
        XCTAssertTrue(app.buttons["Jump to bottom"].exists)
        XCTAssertTrue(app.staticTexts["stream-done"].waitForExistence(timeout: 35))
        let d = settled()
        print("STREAM done", d)
    }

    func testJumpToBottomButton() {
        app.swipeDown(velocity: .slow)
        let up = settled()
        XCTAssertFalse(up.pinned)
        app.buttons["Jump to bottom"].tap()
        let s = settled()
        print("JUMP TO BOTTOM", up, "->", s)
        XCTAssertTrue(s.pinned)
        XCTAssertFalse(app.buttons["Jump to bottom"].exists)
    }

    func testBoostBurstPinned() {
        tap("Boost burst")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let s = settled()
        print("BURST", s)
        XCTAssertTrue(s.pinned)
    }

    func testScrollToTopLoadsOlder() {
        let start = settled()
        for _ in 0..<12 { app.swipeDown(velocity: .fast) }
        let s = settled()
        print("SCROLLED", start, "->", s)
        XCTAssertGreaterThan(s.loaded, 40)
    }
}

final class QueryTimingTests: XCTestCase {
    func testQueryTiming() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        _ = app.staticTexts["state"].waitForExistence(timeout: 5)
        let t = Date()
        for _ in 0..<5 { _ = app.staticTexts["state"].label }
        print("QUERY x5", Date().timeIntervalSince(t))
        let t2 = Date()
        print("TREE", app.debugDescription.count, Date().timeIntervalSince(t2))
    }
}
