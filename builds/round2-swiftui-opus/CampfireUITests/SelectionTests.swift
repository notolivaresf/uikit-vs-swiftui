import XCTest

final class SelectionTests: XCTestCase {
    func shot(_ name: String) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/cftools/sel-\(name).png"))
    }

    func testLongPressSelectAndCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launchEnvironment["CF_TRACE"] = "1"
        app.launch()
        let row = app.otherElements["message-50000"].exists ? app.otherElements["message-50000"] : app.descendants(matching: .any)["message-50000"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.8)
        sleep(1)
        shot("1-pressed")
        XCTAssertTrue(app.buttons["Copy"].exists)
        XCTAssertTrue(app.buttons["Reply"].exists)
        let end = app.descendants(matching: .any)["Selection end"]
        if end.exists {
            let from = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let to = from.withOffset(CGVector(dx: -120, dy: -60))
            from.press(forDuration: 0.05, thenDragTo: to)
            sleep(1)
            shot("2-dragged")
        } else {
            print("NO END HANDLE")
        }
        app.buttons["Copy"].tap()
        sleep(1)
        shot("3-copied")
        XCTAssertFalse(app.buttons["Copy"].exists)
        // Scrolling over messages still works.
        let before = app.staticTexts["state"].label
        app.swipeDown(velocity: .slow)
        sleep(2)
        let after = app.staticTexts["state"].label
        print("SCROLL", before, "->", after)
        XCTAssertNotEqual(before, after)
    }
}
