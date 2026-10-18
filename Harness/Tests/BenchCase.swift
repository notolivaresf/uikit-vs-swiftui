import XCTest

/// One reading of the state label (PROMPT.md): `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`.
struct AppState: Equatable {
    var first = 0, last = 0, loaded = 0
    var pinned = false
    var top = 0
    var y = 0.0
    var ms: Int?
    var raw = ""

    /// Keyed parse: each key is followed by its value. Missing keys keep their defaults (ms stays nil).
    init(_ text: String) {
        raw = text
        let words = text.lowercased()
            .replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "=", with: " ")
            .split(separator: " ").map(String.init)
        func value(_ key: String) -> String? {
            guard let i = words.firstIndex(of: key), i + 1 < words.count else { return nil }
            return words[i + 1]
        }
        first = value("first").flatMap { Int($0) } ?? 0
        last = value("last").flatMap { Int($0) } ?? 0
        loaded = value("loaded").flatMap { Int($0) } ?? 0
        pinned = value("pinned").map { ["yes", "true", "1", "on"].contains($0) } ?? false
        top = value("top").flatMap { Int($0) } ?? 0
        y = value("y").flatMap { Double($0) } ?? 0
        ms = value("ms").flatMap { Int($0) }
    }
}

/// Shared helpers: finds things only by what the user sees (the debug bar in PROMPT.md).
class BenchCase: XCTestCase {
    static let iterations = 3
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Bar.bundleID)
        app.launchArguments = ["-uvsBenchmark", "YES"]
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// testFling and testMemory run 1 iteration (plus XCTest's warm-up), every other measured test 3 (Fernando,
    /// 18 Oct: a round of about 1 h was too long; in smoke round 8, at 5 iterations and 40 + 40 swipes,
    /// testMemory took 19 min and testFling 12 min; the fling and stream traces already give the frames and
    /// hitches). Same for every build.
    static let singleIterationTests: Set<String> = ["testFling", "testMemory"]

    var iterationCount: Int {
        let test = name.split(separator: " ").last.map { String($0.dropLast()) } ?? ""
        return Self.singleIterationTests.contains(test) ? 1 : Self.iterations
    }

    var options: XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = iterationCount
        return o
    }

    /// Measure options where the block calls startMeasuring() / stopMeasuring() itself, so set-up (launch,
    /// reset) stays out of the numbers.
    var manualOptions: XCTMeasureOptions {
        let o = options
        o.invocationOptions = [.manuallyStart, .manuallyStop]
        return o
    }

    var list: XCUIElement {
        let table = app.tables.firstMatch
        if table.exists { return table }
        let collection = app.collectionViews.firstMatch
        return collection.exists ? collection : app.scrollViews.firstMatch
    }

    func button(_ title: String) -> XCUIElement { app.buttons[title].firstMatch }

    /// The state label, found by the words "pinned" and "loaded".
    var stateLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'pinned' AND label CONTAINS[c] 'loaded'")).firstMatch
    }

    func waitForBar() {
        XCTAssertTrue(button(Bar.reset).waitForExistence(timeout: 30), "debug bar missing")
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 30), "state label missing")
    }

    func state() -> AppState { AppState(stateLabel.label) }

    /// Taps Reset and waits until the room is back at the bottom and the label has settled.
    func reset() {
        tap(Bar.reset)
        XCTAssertTrue(waitUntil(timeout: 15) { self.state().pinned }, "not pinned after Reset")
        _ = settled()
    }

    /// Whether the label changed after the last tap() (false: it still read the same after `changeWait`, so the
    /// reading may be the previous tap's; tests record it next to the value).
    var lastTapChanged = true

    /// Taps a debug-bar button, waits until the label changes (the app shows this tap's result: a new `ms` at
    /// least), then until it has settled, and returns it. A slow result can't be mistaken for the old one unless
    /// the label stays identical for `changeWait` seconds.
    @discardableResult
    func tap(_ title: String, changeWait: TimeInterval = 10) -> AppState {
        let before = stateLabel.label
        button(title).tap()
        lastTapChanged = waitUntil(timeout: changeWait) { self.stateLabel.label != before }
        return settled()
    }

    /// Waits until the state label has not changed for `quiet` seconds and returns it. Fails the test if it
    /// never settles within `timeout`.
    func settled(quiet: TimeInterval = 0.6, timeout: TimeInterval = 20) -> AppState {
        let end = Date().addingTimeInterval(timeout)
        var last = state()
        var since = Date()
        while Date() < end {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            let now = state()
            if now != last { last = now; since = Date() } else if Date().timeIntervalSince(since) >= quiet { return now }
        }
        XCTFail("state label never settled in \(Int(timeout)) s: \(last.raw)")
        return last
    }

    /// True when the app's window is wider than tall (it really turned to landscape).
    var isLandscape: Bool { let f = app.windows.firstMatch.frame; return f.width > f.height }

    /// Scroll metrics, plus hitches on iOS 26 and later (the device runs iOS 26; older systems only get fps).
    func scrollMetrics(deceleration: Bool) -> [XCTMetric] {
        var m: [XCTMetric] = deceleration
            ? [XCTOSSignpostMetric.scrollDecelerationMetric, XCTOSSignpostMetric.scrollDraggingMetric]
            : [XCTOSSignpostMetric.scrollDraggingMetric]
        m += hitchMetric
        return m
    }

    /// The app's hitches over the measured block (iOS 26 and later; empty before that).
    var hitchMetric: [XCTMetric] {
        if #available(iOS 26, *) { return [XCTHitchMetric(application: app)] }
        return []
    }

    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    /// Rotates the device and waits for the room to settle.
    @discardableResult
    func rotate(_ o: UIDeviceOrientation) -> AppState {
        XCUIDevice.shared.orientation = o
        let wantLandscape = o.isLandscape
        XCTAssertTrue(waitUntil(timeout: 5) { self.isLandscape == wantLandscape },
                      "the app did not turn to \(wantLandscape ? "landscape" : "portrait")")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        return settled(quiet: 0.8)
    }

    /// Prints a wall-clock mark (seconds since 1970, phone clock) that summarize.py lines up with the trace's
    /// start date, so a trace's measured window is the scenario itself, not inferred from drawing.
    func mark(_ name: String) {
        print("UVS_MARK \(name) \(String(format: "%.3f", Date().timeIntervalSince1970))")
    }

    /// One result line per value the harness reads from the app (not from XCTest metrics). summarize.py
    /// collects every `UVS_RESULT` line from the test logs; each is one JSON object.
    func record(_ test: String, _ values: [String: Any]) {
        var v = values
        v["test"] = test
        v["rid"] = UUID().uuidString      // one id per reading, so summarize.py drops only echoed lines
        v["wall"] = Date().timeIntervalSince1970
        if let data = try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys]),
           let line = String(data: data, encoding: .utf8) {
            print("UVS_RESULT \(line)")
        }
    }

    /// How far the row at the top moved between two readings, in points. Nil when a different row is at the top,
    /// which means it moved by at least a row.
    func drift(_ before: AppState, _ after: AppState) -> Double? {
        guard before.top == after.top, before.top != 0 else { return nil }
        return abs(after.y - before.y)
    }
}
