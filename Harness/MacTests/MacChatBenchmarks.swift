import XCTest

/// The Mac twin of Harness/Tests/ChatBenchmarks.swift: same scenarios, same numbers, a window instead of a phone.
/// Times that count come from the app's own state label; the XCTest clock is only a sanity bound.
final class MacChatBenchmarks: MacBenchCase {
    // Repeated launch until the first 40 rows are on screen, timed by the app.
    func testTimeTo40Rows() {
        bench(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric()], options: options) {
            launch()
            XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
            let s = settled()
            record("testTimeTo40Rows", ["app_ms": s.ms as Any, "loaded": s.loaded])
            app.terminate()
        }
    }

    // 10 fast scroll-wheel flings towards older messages, then 10 back.
    func testFling() {
        launch()
        bench(metrics: hitchMetric + [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
              options: manualOptions) {
            reset()
            startMeasuring()
            fling(10, older: true)
            fling(10, older: false)
            stopMeasuring()
        }
    }

    // "Jump to 2500": message 2,500's top lands just under the header (y 0). Drift = |y|.
    func testJumpTo2500() {
        launch()
        bench(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
              options: manualOptions) {
            reset()
            startMeasuring()
            button(Bar.jump).click()
            XCTAssertTrue(waitUntil { let s = self.state(); return s.first <= 2_500 && s.last >= 2_500 },
                          "message 2500 not loaded")
            stopMeasuring()
            let s = settled()
            record("testJumpTo2500", ["app_ms": s.ms as Any, "top": s.top, "y": s.y,
                                      "drift_pt": s.top == 2_500 ? abs(s.y) as Any : NSNull()])
        }
    }

    // "Load older": 40 older messages arrive; the row at the top stays put.
    func testLoadOlder() {
        launch()
        bench(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
              options: manualOptions) {
            reset()
            let before = settled()
            startMeasuring()
            button(Bar.older).click()
            XCTAssertTrue(waitUntil { self.state().first < before.first }, "no older messages loaded")
            stopMeasuring()
            let after = settled()
            record("testLoadOlder", ["app_ms": after.ms as Any, "top_before": before.top, "top_after": after.top,
                                     "drift_pt": drift(before, after) as Any])
        }
    }

    // 20 messages a second for 30 s; ends with "Stream done" and the room still pinned. One play per launch.
    func testLiveStream() {
        bench(metrics: hitchMetric + [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric()],
              options: manualOptions) {
            launch()
            XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
            reset()
            let before = state()
            startMeasuring()
            button(Bar.start).click()
            XCTAssertTrue(streamDone.waitForExistence(timeout: 60), "stream never finished")
            stopMeasuring()
            let s = settled()
            record("testLiveStream", ["pinned": s.pinned, "loaded": s.loaded, "added": s.last - before.last])
            XCTAssertGreaterThanOrEqual(s.last - before.last, 600, "the stream should add 600 messages")
            XCTAssertTrue(s.pinned, "list should stay pinned to the bottom")
            app.terminate()
        }
    }

    // Memory: peak physical footprint through the heavy scenario (jump, 2 older pages, flings, reset, stream, flings).
    func testMemory() {
        bench(metrics: [XCTMemoryMetric(application: app), XCTClockMetric()], options: manualOptions) {
            launch()
            XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
            _ = settled()
            startMeasuring()
            tap(Bar.jump)
            for _ in 0..<2 { tap(Bar.older) }
            fling(5, older: true)
            reset()
            let before = state()
            button(Bar.start).click()
            XCTAssertTrue(streamDone.waitForExistence(timeout: 60), "stream never finished")
            XCTAssertGreaterThanOrEqual(state().last - before.last, 600, "the stream should add 600 messages")
            fling(5, older: true)
            _ = settled()
            stopMeasuring()
            app.terminate()
        }
    }
}
