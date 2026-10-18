import XCTest

/// One pass of each scenario, for Instruments. `Harness/record.sh` starts the app under `xctrace --launch`
/// (so the trace covers the whole process), then runs one of these tests, which takes over the running app with
/// `activate()` instead of launching it, plays the scenario and ends. They measure nothing themselves; the
/// numbers come from the trace. Each scenario starts and ends with a few idle seconds so the trace's frames
/// split cleanly into the scenario and the rest.
final class TraceScenarios: BenchCase {
    static let idle: TimeInterval = 3

    private func takeOver() {
        app.activate()
        waitForBar()
        reset()
        RunLoop.current.run(until: Date().addingTimeInterval(Self.idle))
        print("UVS_SCENARIO_START")
    }

    private func done() {
        RunLoop.current.run(until: Date().addingTimeInterval(Self.idle))
        print("UVS_SCENARIO_DONE")
    }

    func testTraceFling() {
        takeOver()
        for _ in 0..<40 { list.swipeDown(velocity: .fast) }
        for _ in 0..<40 { list.swipeUp(velocity: .fast) }
        done()
    }

    func testTraceStream() {
        takeOver()
        button(Bar.start).tap()
        XCTAssertTrue(app.staticTexts[Bar.streamDone].waitForExistence(timeout: 60), "stream never finished")
        done()
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
