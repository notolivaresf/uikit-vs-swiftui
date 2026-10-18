import XCTest

/// One pass of each scenario, for Instruments. `Harness/record.sh` starts one of these tests, attaches `xctrace`
/// to the app while the test waits (`attachWindow` seconds after the debug bar shows), and stops the trace when the
/// scenario is over. They measure nothing themselves; the numbers come from the trace.
final class TraceScenarios: BenchCase {
    /// Time given to `xctrace` to attach before the scenario starts.
    static let attachWindow: TimeInterval = 25

    private func launchAndWaitForAttach() {
        app.launch()
        waitForBar()
        print("UVS_APP_UP")
        Thread.sleep(forTimeInterval: Self.attachWindow)
        reset()
    }

    func testTraceFling() {
        launchAndWaitForAttach()
        for _ in 0..<40 { list.swipeDown(velocity: .fast) }
        for _ in 0..<40 { list.swipeUp(velocity: .fast) }
        print("UVS_SCENARIO_DONE")
    }

    func testTraceStream() {
        launchAndWaitForAttach()
        button(Bar.start).tap()
        XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
        print("UVS_SCENARIO_DONE")
    }

    /// Memory: load a lot of rows (jump, older pages, a fling) so peak memory has something to show.
    func testTraceMemory() {
        launchAndWaitForAttach()
        button(Bar.jump).tap()
        _ = waitUntil { let s = self.state(); return s.first <= 2_500 && s.last >= 2_500 }
        for _ in 0..<10 { button(Bar.older).tap() }
        for _ in 0..<20 { list.swipeDown(velocity: .fast) }
        print("UVS_SCENARIO_DONE")
    }
}
