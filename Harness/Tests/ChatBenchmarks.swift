import XCTest

/// Benchmarks for the installed app `campfire.bench`, launched with `-uvsBenchmark YES`.
/// Five iterations per measure block; run the suite in 3 alternating rounds per build. The tests never differ
/// between the UIKit and SwiftUI builds.
///
/// Times that count come from the app's own state label (`ms`: from the tap until its result is laid out, or
/// at launch from the app's first line of code until 40 rows are on screen); the XCTest clock next to them
/// includes XCUITest's own overhead and is only a sanity bound. Positions (drift in pt) come from `top` and `y`.
final class ChatBenchmarks: BenchCase {
    // Cold launch to the debug bar on screen.
    func testLaunch() {
        measure(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric()], options: options) {
            app.launch()
            waitForBar()
            app.terminate()
        }
    }

    // Cold launch until the first 40 rows are on screen, timed by the app (`ms` at launch).
    func testTimeTo40Rows() {
        measure(metrics: [XCTClockMetric()], options: options) {
            app.launch()
            waitForBar()
            XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
            let s = settled()
            record("testTimeTo40Rows", ["app_ms": s.ms as Any, "loaded": s.loaded])
            app.terminate()
        }
    }

    // 40 fast swipes towards older messages, then 40 back. Frame rate (fps) and hitches come from the scroll
    // metrics, which only count while a scroll is moving.
    func testFling() {
        app.launch(); waitForBar()
        measure(metrics: scrollMetrics(deceleration: true) +
                          [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: manualOptions) {
            reset()
            startMeasuring()
            for _ in 0..<40 { list.swipeDown(velocity: .fast) }
            for _ in 0..<40 { list.swipeUp(velocity: .fast) }
            stopMeasuring()
        }
    }

    // "Jump to 2500": message 2,500's top lands just under the header (y 0). Time from the app, drift = |y|.
    func testJumpTo2500() {
        app.launch(); waitForBar()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: manualOptions) {
            reset()
            startMeasuring()
            button(Bar.jump).tap()
            XCTAssertTrue(waitUntil { let s = self.state(); return s.first <= 2_500 && s.last >= 2_500 },
                          "message 2500 not loaded")
            stopMeasuring()
            let s = settled()
            record("testJumpTo2500", ["app_ms": s.ms as Any, "top": s.top, "y": s.y,
                                      "drift_pt": s.top == 2_500 ? abs(s.y) as Any : NSNull()])
        }
    }

    // "Load older": 40 older messages arrive; the row at the top stays put. Drift = how far it moved.
    func testLoadOlder() {
        app.launch(); waitForBar()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: manualOptions) {
            reset()
            let before = settled()
            startMeasuring()
            button(Bar.older).tap()
            XCTAssertTrue(waitUntil { self.state().first < before.first }, "no older messages loaded")
            stopMeasuring()
            let after = settled()
            record("testLoadOlder", ["app_ms": after.ms as Any, "top_before": before.top, "top_after": after.top,
                                     "drift_pt": drift(before, after) as Any])
        }
    }

    // 20 messages a second for 30 s; ends with the "Stream done" label and the list still pinned.
    func testLiveStream() {
        app.launch(); waitForBar()
        measure(metrics: hitchMetric + [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric()],
                options: manualOptions) {
            reset()
            startMeasuring()
            button(Bar.start).tap()
            XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
            stopMeasuring()
            let s = settled()
            record("testLiveStream", ["pinned": s.pinned, "loaded": s.loaded])
            XCTAssertTrue(s.pinned, "list should stay pinned to the bottom")
        }
    }

    // Memory: physical footprint from a fresh launch through a heavy scenario. "Memory Peak Physical" is the
    // peak footprint during the scenario, "Memory Physical" the growth from its start to its end.
    func testMemory() {
        measure(metrics: [XCTMemoryMetric(application: app), XCTClockMetric()], options: manualOptions) {
            app.launch(); waitForBar()
            XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
            _ = settled()
            startMeasuring()
            tap(Bar.jump)
            for _ in 0..<10 { tap(Bar.older) }
            for _ in 0..<20 { list.swipeDown(velocity: .fast) }
            reset()
            button(Bar.start).tap()
            XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
            for _ in 0..<20 { list.swipeDown(velocity: .fast) }
            _ = settled()
            stopMeasuring()
            app.terminate()
        }
    }
}
