import AppKit
import XCTest

/// One reading of the state label (PROMPT-mac.md): `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`.
/// Same parse as the iPhone harness's AppState (Harness/Tests/BenchCase.swift), copied so the iPhone tests stay as they are.
struct AppState: Equatable {
    var first = 0, last = 0, loaded = 0
    var pinned = false
    var top = 0
    var y = 0.0
    var ms: Int?
    var raw = ""

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

/// Shared helpers for the Mac pass. Finds things only by what the user sees (the debug bar in PROMPT-mac.md).
/// The app under test is the exact .app that record-mac.sh names in UVS_APP_PATH (passed to the runner as
/// TEST_RUNNER_UVS_APP_PATH), so two builds with the same app id never get mixed up.
class MacBenchCase: XCTestCase {
    static let iterations = 3
    static let singleIterationTests: Set<String> = ["testFling", "testMemory"]
    /// Smoke mode (record.sh --mac --fast): one iteration, no warm-up. Never set for the real passes.
    static let fast = ProcessInfo.processInfo.environment["UVS_FAST"] == "1"
    /// The window's content size at launch (PROMPT-mac.md), and the wide size the resize tests drag to.
    static let narrow = CGSize(width: 393, height: 852)
    static let wideWidth: CGFloat = 852

    var app: XCUIApplication!

    static var appURL: URL {
        let path = ProcessInfo.processInfo.environment["UVS_APP_PATH"] ?? ""
        return URL(fileURLWithPath: path)
    }

    override func setUp() {
        continueAfterFailure = false
        let path = ProcessInfo.processInfo.environment["UVS_APP_PATH"] ?? ""
        XCTAssertFalse(path.isEmpty, "UVS_APP_PATH is not set (record-mac.sh sets it)")
        app = XCUIApplication(url: Self.appURL)
        app.launchArguments = ["-uvsBenchmark", "YES", "-ApplePersistenceIgnoreState", "YES"]
    }

    var iterationCount: Int {
        let test = name.split(separator: " ").last.map { String($0.dropLast()) } ?? ""
        if Self.fast { return 1 }
        return Self.singleIterationTests.contains(test) ? 1 : Self.iterations
    }

    func bench(metrics: [XCTMetric], options: XCTMeasureOptions, block: () -> Void) {
        guard Self.fast else { measure(metrics: metrics, options: options, block: block); return }
        let manual = options.invocationOptions.contains(.manuallyStart)
        var warmup = true
        measure(metrics: metrics, options: options) { [self] in
            if warmup {
                warmup = false
                if manual { startMeasuring(); stopMeasuring() }
                return
            }
            block()
        }
    }

    var options: XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = iterationCount
        return o
    }

    var manualOptions: XCTMeasureOptions {
        let o = options
        o.invocationOptions = [.manuallyStart, .manuallyStop]
        return o
    }

    var window: XCUIElement { app.windows.firstMatch }

    /// The message list: a table, an outline, a collection or else the biggest scroll area in the window.
    var list: XCUIElement {
        for q in [app.tables, app.outlines, app.collectionViews] where q.firstMatch.exists { return q.firstMatch }
        let scrolls = app.scrollViews.allElementsBoundByIndex.filter { $0.exists }
        return scrolls.max { $0.frame.height * $0.frame.width < $1.frame.height * $1.frame.width } ?? app.scrollViews.firstMatch
    }

    func button(_ title: String) -> XCUIElement { app.buttons[title].firstMatch }

    /// On the Mac a label's text is its accessibility value; some stacks also give it as the label. Both are searched.
    var stateLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format:
            "(value CONTAINS[c] 'pinned' AND value CONTAINS[c] 'loaded') OR (label CONTAINS[c] 'pinned' AND label CONTAINS[c] 'loaded')")).firstMatch
    }

    var streamDone: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", Bar.streamDone, Bar.streamDone)).firstMatch
    }

    func text(of e: XCUIElement) -> String {
        if let v = e.value as? String, !v.isEmpty { return v }
        return e.label
    }

    func waitForBar() {
        XCTAssertTrue(button(Bar.reset).waitForExistence(timeout: 30), "debug bar missing")
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 30), "state label missing")
    }

    func state() -> AppState { AppState(text(of: stateLabel)) }

    /// Launches the app at its default window size (no saved window state: -ApplePersistenceIgnoreState).
    func launch() {
        app.launch()
        waitForBar()
    }

    func reset() {
        tap(Bar.reset, changeWait: Self.fast ? 2 : 10)
        XCTAssertTrue(waitUntil(timeout: 15) { self.state().pinned }, "not pinned after Reset")
        _ = settled()
    }

    var lastTapChanged = true

    /// Clicks a debug-bar button, waits for the label to change, then to settle.
    @discardableResult
    func tap(_ title: String, changeWait: TimeInterval = 10) -> AppState {
        let before = text(of: stateLabel)
        button(title).click()
        lastTapChanged = waitUntil(timeout: changeWait) { self.text(of: self.stateLabel) != before }
        return settled()
    }

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

    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    /// A fling: `count` fast scroll-wheel gestures over the list (positive dy = towards older messages).
    /// XCUITest posts each as one discrete scroll event, so there is no trackpad momentum after it; the list
    /// moves only as far as the events say.
    func fling(_ count: Int, older: Bool) {
        for _ in 0..<count { list.scroll(byDeltaX: 0, deltaY: older ? 2_000 : -2_000) }
    }

    /// Drags the window's bottom-right corner so its content becomes `width` points wide (height unchanged)
    /// and waits for the room to settle. Returns the reading and the window width it got.
    @discardableResult
    func resize(toWidth width: CGFloat) -> (AppState, CGFloat) {
        let frame = window.frame
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.width - 2, dy: frame.height - 2))
        let target = corner.withOffset(CGVector(dx: width - frame.width, dy: 0))
        corner.press(forDuration: 0.2, thenDragTo: target)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        return (settled(quiet: 0.8), window.frame.width)
    }

    func mark(_ name: String) {
        print("UVS_MARK \(name) \(String(format: "%.3f", Date().timeIntervalSince1970))")
    }

    func record(_ test: String, _ values: [String: Any]) {
        var v = values
        v["test"] = test
        v["rid"] = UUID().uuidString
        v["wall"] = Date().timeIntervalSince1970
        if let data = try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys]),
           let line = String(data: data, encoding: .utf8) {
            print("UVS_RESULT \(line)")
        }
    }

    func drift(_ before: AppState, _ after: AppState) -> Double? {
        guard before.top == after.top, before.top != 0 else { return nil }
        return abs(after.y - before.y)
    }

    /// Hitches over a measured block (macOS 26 and later).
    var hitchMetric: [XCTMetric] {
        if #available(macOS 26, *) { return [XCTHitchMetric(application: app)] }
        return []
    }
}
