import XCTest

/// Drives the debug bar and checks the room keeps its place. Prints the state label at each step.
final class RoomBehaviourTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        _ = state.waitForExistence(timeout: 10)
        settle()
    }

    private var state: XCUIElement { app.staticTexts["debug.state"] }

    private func settle(_ seconds: TimeInterval = 0.8) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func label(_ step: String) -> State {
        let text = state.label
        print("STATE [\(name) \(step)] \(text)")
        return State(text)
    }

    private func tap(_ title: String) {
        app.buttons["debug.\(title)"].tap()
        settle()
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/cfm/ui-\(name).png"))
    }

    struct State {
        var fields: [String: String] = [:]
        init(_ text: String) {
            let parts = text.split(separator: " ").map(String.init)
            var i = 0
            while i + 1 < parts.count { fields[parts[i]] = parts[i + 1]; i += 2 }
        }
        var top: String { fields["top"] ?? "" }
        var y: Double { Double(fields["y"] ?? "") ?? .nan }
        var pinned: String { fields["pinned"] ?? "" }
        var loaded: Int { Int(fields["loaded"] ?? "") ?? -1 }
    }

    func testLaunch() {
        let s = label("launch")
        XCTAssertEqual(s.pinned, "yes")
        XCTAssertEqual(s.loaded, 40)
        shot("launch")
    }

    func testLoadOlderKeepsPlace() {
        let before = label("before")
        tap("Load older")
        let after = label("after")
        XCTAssertEqual(after.loaded, 80)
        XCTAssertEqual(before.top, after.top)
        XCTAssertEqual(before.y, after.y, accuracy: 2)
        // Scroll up then load older.
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        settle(1.5)
        let mid = label("scrolled")
        tap("Load older")
        let mid2 = label("loaded again")
        XCTAssertEqual(mid.top, mid2.top)
        XCTAssertEqual(mid.y, mid2.y, accuracy: 2)
    }

    func testJump() {
        tap("Jump to 2500")
        let s = label("jump")
        XCTAssertEqual(s.top, "2500")
        XCTAssertEqual(s.y, 0, accuracy: 2)
        shot("jump")
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        settle(1.5)
        let a = label("scrolled up")
        app.scrollViews.firstMatch.swipeDown(velocity: .fast)
        settle(2)
        let b = label("scrolled up more")
        _ = (a, b)
        app.scrollViews.firstMatch.swipeUp(velocity: .fast)
        app.scrollViews.firstMatch.swipeUp(velocity: .fast)
        app.scrollViews.firstMatch.swipeUp(velocity: .fast)
        settle(2)
        _ = label("scrolled down")
    }

    func testTextSize() {
        tap("Text size +")
        var s = label("size+1 pinned")
        XCTAssertEqual(s.pinned, "yes")
        shot("textsize1")
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        settle(1.5)
        let before = label("scrolled")
        tap("Text size +")
        s = label("size+2")
        XCTAssertEqual(before.top, s.top)
        XCTAssertEqual(before.y, s.y, accuracy: 2)
        for i in 0..<10 { tap("Text size +"); _ = label("size step \(i)") }
        shot("textsize-big")
        tap("Reset")
        _ = label("reset")
    }

    func testRotation() {
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        settle(1.5)
        let before = label("portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(2)
        let after = label("landscape")
        shot("landscape")
        XCTAssertEqual(before.top, after.top)
        XCTAssertEqual(before.y, after.y, accuracy: 2)
        XCUIDevice.shared.orientation = .portrait
        settle(2)
        let back = label("portrait again")
        XCTAssertEqual(before.top, back.top)
        tap("Reset")
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(2)
        XCTAssertEqual(label("landscape pinned").pinned, "yes")
        XCUIDevice.shared.orientation = .portrait
        settle(1)
    }

    func testStreamPinned() {
        tap("Start stream")
        settle(5)
        let s = label("streaming")
        XCTAssertEqual(s.pinned, "yes")
        shot("stream")
        XCTAssertTrue(app.staticTexts["Stream done"].waitForExistence(timeout: 40))
        let done = label("done")
        XCTAssertEqual(done.pinned, "yes")
        XCTAssertEqual(done.fields["last"], "50600")
    }

    func testStreamUnpinned() {
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        settle(1.5)
        let before = label("scrolled")
        tap("Start stream")
        settle(4)
        let during = label("streaming")
        XCTAssertEqual(during.pinned, "no")
        XCTAssertEqual(before.top, during.top)
        XCTAssertEqual(before.y, during.y, accuracy: 2)
        XCTAssertTrue(app.buttons["jumpToBottom"].exists)
        app.buttons["jumpToBottom"].tap()
        settle(1)
        XCTAssertEqual(label("jumped").pinned, "yes")
    }

    func testBoostBurst() {
        tap("Boost burst")
        settle(1.5)
        let s = label("burst")
        XCTAssertEqual(s.pinned, "yes")
        shot("burst")
    }

    func testLongPress() {
        let text = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'cut the build'")).firstMatch
        let target = text.exists ? text : app.scrollViews.firstMatch
        target.press(forDuration: 1.0)
        settle(0.5)
        shot("longpress")
        XCTAssertTrue(app.buttons["Copy"].exists)
        XCTAssertTrue(app.buttons["Reply"].exists)
        app.buttons["Copy"].tap()
        settle(0.3)
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        settle(1)
        _ = label("after scroll")
    }
}
