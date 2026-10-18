import XCTest

/// Benchmarks for the installed app `campfire.bench`, launched with `-uvsBenchmark YES`.
/// Five iterations per measure block; run the suite in 3 alternating rounds per build. The tests never differ between the UIKit and SwiftUI builds.
final class ChatBenchmarks: BenchCase {
    // Cold launch to the debug bar on screen.
    func testLaunch() {
        measure(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric(), XCTMemoryMetric(application: app)],
                options: options) {
            app.launch()
            waitForBar()
            app.terminate()
        }
    }

    // Cold launch until the first 40 rows are loaded (the state label says "loaded 40" or more).
    func testTimeTo40Rows() {
        measure(metrics: [XCTClockMetric()], options: options) {
            app.launch()
            XCTAssertTrue(button(Bar.reset).waitForExistence(timeout: 30), "debug bar missing")
            XCTAssertTrue(waitUntil(timeout: 30) { self.stateLabel.exists && self.state().loaded >= 40 }, "fewer than 40 rows")
            app.terminate()
        }
    }

    // 40 fast swipes towards older messages, then 40 back. Frame rate (fps) and hitches come from the scroll metrics.
    func testFling() {
        app.launch(); waitForBar()
        measure(metrics: scrollMetrics(deceleration: true) +
                          [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
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
        measure(metrics: scrollMetrics(deceleration: false) +
                          [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric()],
                options: options) {
            reset()
            button(Bar.start).tap()
            XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
            XCTAssertTrue(state().pinned, "list should stay pinned to the bottom")
        }
    }
}
