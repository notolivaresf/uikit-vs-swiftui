import XCTest

/// One pass of each scenario, for Instruments. `Harness/record.sh` starts the app under `xctrace --launch`
/// (so the trace covers the whole process), then runs one of these tests, which takes over the running app with
/// `activate()` instead of launching it, plays the scenario and ends. They measure nothing themselves; the
/// numbers come from the trace. Each scenario starts and ends with a few idle seconds so the trace's frames
/// split cleanly into the scenario and the rest.
final class TraceScenarios: BenchCase {
    static let idle: TimeInterval = 3

    private func takeOver() {
        XCTAssertEqual(app.state, .runningForeground, "the app Instruments launched is not running")
        app.activate()
        waitForBar()
        reset()
        RunLoop.current.run(until: Date().addingTimeInterval(Self.idle))
        mark("start")
    }

    private func done() {
        mark("end")
        RunLoop.current.run(until: Date().addingTimeInterval(Self.idle))
    }

    /// Does nothing. record.sh runs it right before every recording: starting a UI test wakes the phone, and
    /// xctrace on a phone whose screen has gone dark stops with "Timed out waiting for device to boot".
    func testWake() {
        XCTAssertTrue(true)
    }

    /// The cold launch Instruments just made (record.sh: freshly installed, phone idle 30 s): the app's own time
    /// to the first 40 rows, from the label as it is before any tap.
    func testLaunchState() {
        XCTAssertEqual(app.state, .runningForeground, "the app Instruments launched is not running")
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 30), "state label missing")
        XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
        let s = settled()
        record("testLaunchState", ["app_ms": s.ms as Any, "loaded": s.loaded])
    }

    // Window: from the first swipe to the last; fps counts only while the app is drawing (summarize.py).
    func testTraceFling() {
        takeOver()
        for _ in 0..<40 { list.swipeDown(velocity: .fast) }
        for _ in 0..<40 { list.swipeUp(velocity: .fast) }
        _ = settled()
        done()
    }

    // Window: from the Start stream tap until "Stream done" shows, however the drawing went.
    func testTraceStream() {
        takeOver()
        let before = state()
        button(Bar.start).tap()
        XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
        done()
        XCTAssertGreaterThanOrEqual(state().last - before.last, 600, "the stream should add 600 messages")
    }

    /// Memory: load a lot of rows (jump, older pages, a fling, the stream) so the heap has something to show.
    func testTraceMemory() {
        takeOver()
        tap(Bar.jump)
        for _ in 0..<10 { tap(Bar.older) }
        for _ in 0..<20 { list.swipeDown(velocity: .fast) }
        reset()
        button(Bar.start).tap()
        XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
        done()
    }
}
