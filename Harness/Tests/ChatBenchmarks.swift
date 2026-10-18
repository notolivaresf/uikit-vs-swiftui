import XCTest

/// Benchmarks for the installed app `campfire.bench`, launched with `-uvsBenchmark YES`.
/// Five iterations per measure block; run the suite in 3 alternating rounds per build. The tests never differ between the UIKit and SwiftUI builds.
final class ChatBenchmarks: XCTestCase {
    static let iterations = 5
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Bar.bundleID)
        app.launchArguments = ["-uvsBenchmark", "YES"]
    }

    private var options: XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = Self.iterations
        return o
    }

    private var list: XCUIElement {
        let table = app.tables.firstMatch
        if table.exists { return table }
        let collection = app.collectionViews.firstMatch
        return collection.exists ? collection : app.scrollViews.firstMatch
    }

    private func button(_ title: String) -> XCUIElement { app.buttons[title].firstMatch }
    private var stateLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'first' AND label CONTAINS 'loaded'")).firstMatch
    }

    private func waitForBar() {
        XCTAssertTrue(button(Bar.reset).waitForExistence(timeout: 30), "debug bar missing")
    }

    private func reset() {
        button(Bar.reset).tap()
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 10))
    }

    /// Parses numbers after the words first, last, loaded, pinned (pinned: yes/true/1).
    private func state() -> (first: Int, last: Int, loaded: Int, pinned: Bool) {
        let text = stateLabel.label.lowercased()
        func number(_ key: String) -> Int? {
            guard let r = text.range(of: key) else { return nil }
            let digits = text[r.upperBound...].drop { !$0.isNumber }.prefix { $0.isNumber }
            return Int(digits)
        }
        var pinned = false
        if let r = text.range(of: "pinned") {
            let rest = text[r.upperBound...].drop { $0 == ":" || $0 == "=" || $0 == " " }
            pinned = rest.hasPrefix("yes") || rest.hasPrefix("true") || rest.hasPrefix("1")
        }
        return (number("first") ?? 0, number("last") ?? 0, number("loaded") ?? 0, pinned)
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    // Cold launch to the debug bar on screen.
    func testLaunch() {
        measure(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric(), XCTMemoryMetric(application: app)],
                options: options) {
            app.launch()
            waitForBar()
            app.terminate()
        }
    }

    // 40 fast swipes towards older messages, then 40 back. Frame rate (fps) and hitches come from the scroll metrics.
    func testFling() {
        app.launch(); waitForBar()
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric, XCTOSSignpostMetric.scrollDraggingMetric,
                          XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: options) {
            reset()
            for _ in 0..<40 { list.swipeDown(velocity: .fast) }
            for _ in 0..<40 { list.swipeUp(velocity: .fast) }
        }
    }

    // "Jump to 2500": message 2,500 must be loaded when the state label says so.
    func testJumpTo2500() {
        app.launch(); waitForBar()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: options) {
            reset()
            button(Bar.jump).tap()
            XCTAssertTrue(waitUntil { let s = self.state(); return s.first <= 2_500 && s.last >= 2_500 },
                          "message 2500 not loaded")
        }
    }

    // "Load older": 40 older messages arrive and the first id drops.
    func testLoadOlder() {
        app.launch(); waitForBar()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: options) {
            reset()
            let firstBefore = state().first
            button(Bar.older).tap()
            XCTAssertTrue(waitUntil { self.state().first < firstBefore }, "no older messages loaded")
        }
    }

    // 20 messages a second for 30 s; ends with the "Stream done" label and the list still pinned.
    func testLiveStream() {
        app.launch(); waitForBar()
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric(),
                          XCTOSSignpostMetric.scrollDraggingMetric],
                options: options) {
            reset()
            button(Bar.start).tap()
            XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
            XCTAssertTrue(state().pinned, "list should stay pinned to the bottom")
        }
    }
}
