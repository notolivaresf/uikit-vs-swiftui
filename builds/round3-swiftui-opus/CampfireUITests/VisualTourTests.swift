import XCTest

/// Saves screenshots for eyeballing: landscape and a few screens of history.
final class VisualTourTests: XCTestCase {
    func shot(_ name: String) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/cftools/tour-\(name).png"))
    }

    func testTour() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        _ = app.staticTexts["state"].waitForExistence(timeout: 5)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        shot("landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        for i in 1...4 {
            app.swipeDown(velocity: .slow)
            sleep(1)
            shot("up\(i)")
        }
        app.buttons["Jump to 2500"].tap()
        sleep(1)
        shot("jump")
        app.buttons["Text size +"].tap()
        app.buttons["Text size +"].tap()
        sleep(1)
        shot("bigtext")
    }
}
