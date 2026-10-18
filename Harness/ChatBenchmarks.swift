import XCTest

/// Reusable benchmark suite. Add this folder to a UI test target of either app. The app under test must
/// follow docs/spec.md (identifiers, debug panel, signposts). 5 iterations per measure block.
/// Launch arguments: `-uvsBenchmark YES -uvsDataset 50k`.
final class ChatBenchmarks: XCTestCase {
    static let iterations = 5
    static let datasetArg = "50k"

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES", "-uvsDataset", Self.datasetArg]
    }

    private var options: XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = Self.iterations
        return o
    }

    private var list: XCUIElement { app.collectionViews[ChatID.list].exists ? app.collectionViews[ChatID.list] : app.scrollViews[ChatID.list] }
    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private func waitForList() {
        XCTAssertTrue(el(ChatID.list).waitForExistence(timeout: 30), "message list missing")
    }

    private func reset() {
        el(ChatID.debugReset).tap()
        XCTAssertTrue(el(ChatID.debugState).waitForExistence(timeout: 10))
    }

    private func state() -> (first: Int, last: Int, loaded: Int, bottom: Bool) {
        var out = (0, 0, 0, false)
        for part in (el(ChatID.debugState).label).split(separator: " ") {
            let kv = part.split(separator: "=")
            guard kv.count == 2, let v = Int(kv[1]) else { continue }
            switch kv[0] { case "first": out.0 = v; case "last": out.1 = v; case "loaded": out.2 = v; default: out.3 = v == 1 }
        }
        return out
    }

    // MARK: cold start

    func testLaunchToFirstContent() {
        measure(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric(),
                          XCTOSSignpostMetric(subsystem: ChatSignpost.subsystem, category: ChatSignpost.category, name: ChatSignpost.initialLoad)],
                options: options) {
            app.launch()
            waitForList()
            app.terminate()
        }
    }

    // MARK: 1. open a room with 50,000 messages, 2. fling-scroll top to bottom

    func testFlingScrollTopToBottom() {
        app.launch(); waitForList()
        let scroll = XCTOSSignpostMetric.scrollDecelerationMetric
        let drag = XCTOSSignpostMetric.scrollDraggingMetric
        measure(metrics: [scroll, drag, XCTClockMetric(), XCTMemoryMetric(application: app), XCTCPUMetric(application: app)],
                options: options) {
            reset()
            // Up: fast flings until the oldest loaded page; the app keeps loading older pages as needed.
            for _ in 0..<40 { list.swipeDown(velocity: .fast) }
            for _ in 0..<40 { list.swipeUp(velocity: .fast) }
        }
    }

    // MARK: 3. jump to an old message

    func testJumpToOldMessage() {
        app.launch(); waitForList()
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app),
                          XCTOSSignpostMetric(subsystem: ChatSignpost.subsystem, category: ChatSignpost.category, name: ChatSignpost.jumpToMessage)],
                options: options) {
            reset()
            el(ChatID.debugJumpToOld).tap()
            XCTAssertTrue(el(ChatID.message(2_500)).waitForExistence(timeout: 10), "target row not shown")
        }
    }

    // MARK: 4. prepend 500 older messages while keeping position

    func testPrependKeepsPosition() {
        app.launch(); waitForList()
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app),
                          XCTOSSignpostMetric(subsystem: ChatSignpost.subsystem, category: ChatSignpost.category, name: ChatSignpost.prepend)],
                options: options) {
            reset()
            el(ChatID.debugJumpToOld).tap()
            XCTAssertTrue(el(ChatID.message(2_500)).waitForExistence(timeout: 10))
            let before = el(ChatID.message(2_500)).frame.minY
            let firstBefore = state().first
            el(ChatID.debugPrepend500).tap()
            XCTAssertTrue(waitUntil { self.state().first < firstBefore })
            let after = el(ChatID.message(2_500)).frame.minY
            XCTAssertEqual(before, after, accuracy: 2, "visible message moved after prepend")
        }
    }

    // MARK: 5. live burst: 20 incoming messages per second for 30 s

    func testLiveBurst() {
        app.launch(); waitForList()
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric(),
                          XCTOSSignpostMetric.scrollDraggingMetric,
                          XCTOSSignpostMetric(subsystem: ChatSignpost.subsystem, category: ChatSignpost.category, name: ChatSignpost.burstInsert)],
                options: options) {
            reset()
            el(ChatID.debugStartBurst).tap()
            XCTAssertTrue(el(ChatID.debugBurstDone).waitForExistence(timeout: 45))
            XCTAssertTrue(state().bottom, "list should still be pinned to the bottom after the burst")
        }
    }

    // MARK: Behaviour checks (not measured): run once, fail fast

    func testJumpToBottomButton() {
        app.launch(); waitForList()
        reset()
        XCTAssertFalse(el(ChatID.jumpToBottom).exists)
        for _ in 0..<5 { list.swipeDown(velocity: .fast) }
        XCTAssertTrue(el(ChatID.jumpToBottom).waitForExistence(timeout: 5))
        el(ChatID.jumpToBottom).tap()
        XCTAssertTrue(waitUntil { self.state().bottom })
    }

    func testComposerSendsMessageAtBottom() {
        app.launch(); waitForList()
        reset()
        let input = el(ChatID.composerInput)
        input.tap(); input.typeText("benchmark hello")
        el(ChatID.composerSend).tap()
        XCTAssertTrue(app.staticTexts["benchmark hello"].waitForExistence(timeout: 5))
        XCTAssertTrue(state().bottom)
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
