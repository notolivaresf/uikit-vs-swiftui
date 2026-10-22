import XCTest

/// One pass of each scenario for Instruments, as on the iPhone (Harness/Tests/TraceScenarios.swift):
/// record-mac.sh starts the app under `xctrace --launch`, then runs one of these tests, which takes over the
/// running app with activate() instead of launching it, plays the scenario and ends.
final class MacTraceScenarios: MacBenchCase {
    static let idle: TimeInterval = 3

    /// The app xctrace launched is running but not frontmost (state runningBackground), and XCUITest needs it
    /// active before it can see the window: take it over, then insist on the foreground.
    private func assertRunning() {
        let ok: [XCUIApplication.State] = [.runningForeground, .runningBackground]
        XCTAssertTrue(ok.contains(app.state),
                      "the app Instruments launched is not running (state \(app.state.rawValue))")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app Instruments launched never came to the front")
    }

    private func takeOver() {
        assertRunning()
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

    /// The cold launch Instruments just made: the app's own time to the first 40 rows, before any click.
    func testLaunchState() {
        assertRunning()
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 30), "state label missing")
        XCTAssertTrue(waitUntil(timeout: 30) { self.state().loaded >= 40 }, "fewer than 40 rows")
        let s = settled()
        record("testLaunchState", ["app_ms": s.ms as Any, "loaded": s.loaded])
        app.terminate()
    }

    // Window: from the first scroll to the last.
    func testTraceFling() {
        takeOver()
        fling(10, older: true)
        fling(10, older: false)
        _ = settled()
        done()
    }

    // Window: from the Start stream click until "Stream done" shows.
    func testTraceStream() {
        takeOver()
        let before = state()
        button(Bar.start).click()
        XCTAssertTrue(streamDone.waitForExistence(timeout: 60), "stream never finished")
        done()
        XCTAssertGreaterThanOrEqual(state().last - before.last, 600, "the stream should add 600 messages")
    }

    // Window: narrow to wide and back, twice, at the bottom.
    func testTraceResize() {
        takeOver()
        for _ in 0..<2 {
            resize(toWidth: Self.wideWidth)
            resize(toWidth: Self.narrow.width)
        }
        done()
    }
}
