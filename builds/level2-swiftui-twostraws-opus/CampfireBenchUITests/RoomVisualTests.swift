import XCTest

/// Screenshots for comparing against `screenshots/`. Written to /tmp/cfm when run on the simulator.
final class RoomVisualTests: XCTestCase {
    func testRoomTop() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsScript", "jump:1"]
        app.launch()
        Thread.sleep(forTimeInterval: 3.5)
        app.scrollViews.firstMatch.swipeDown(velocity: .fast)
        Thread.sleep(forTimeInterval: 2)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/cfm/ui-roomtop.png"))
    }
}

final class RoomFlingTests: XCTestCase {
    func testFlingIntoOlder() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES", "-uvsScrollLog", "YES"]
        app.launch()
        Thread.sleep(forTimeInterval: 2)
        for _ in 0..<9 {
            app.scrollViews.firstMatch.swipeDown(velocity: .fast)
            Thread.sleep(forTimeInterval: 1.2)
            print("STATE fling \(app.staticTexts["debug.state"].label)")
        }
    }
}
