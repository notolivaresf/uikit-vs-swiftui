import XCTest

/// Shared helpers: finds things only by what the user sees (the debug bar in PROMPT.md).
class BenchCase: XCTestCase {
    static let iterations = 5
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Bar.bundleID)
        app.launchArguments = ["-uvsBenchmark", "YES"]
    }

    var options: XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = Self.iterations
        return o
    }

    var list: XCUIElement {
        let table = app.tables.firstMatch
        if table.exists { return table }
        let collection = app.collectionViews.firstMatch
        return collection.exists ? collection : app.scrollViews.firstMatch
    }

    func button(_ title: String) -> XCUIElement { app.buttons[title].firstMatch }
    /// PROMPT.md: the state label shows first id, last id, loaded count and pinned, in that order. It is found by
    /// the word "pinned"; the numbers are read in order, so "first 41, last 50, loaded 40, pinned yes" and
    /// "41 / 50 / 40 / pinned: true" both work.
    var stateLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'pinned'")).firstMatch
    }

    func waitForBar() {
        XCTAssertTrue(button(Bar.reset).waitForExistence(timeout: 30), "debug bar missing")
    }

    func reset() {
        button(Bar.reset).tap()
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 10))
    }

    /// Scroll metrics, plus hitches on iOS 26 and later (the device runs iOS 26; older systems only get fps).
    func scrollMetrics(deceleration: Bool) -> [XCTMetric] {
        var m: [XCTMetric] = deceleration
            ? [XCTOSSignpostMetric.scrollDecelerationMetric, XCTOSSignpostMetric.scrollDraggingMetric]
            : [XCTOSSignpostMetric.scrollDraggingMetric]
        if #available(iOS 26, *) { m.append(XCTHitchMetric(application: app)) }
        return m
    }

    /// Reads the state label: the first three integers are first id, last id, loaded count; pinned is
    /// whatever follows the word "pinned" (yes, true, 1 or on = pinned).
    func state() -> (first: Int, last: Int, loaded: Int, pinned: Bool) {
        let text = stateLabel.label.lowercased()
        let pinnedRange = text.range(of: "pinned")
        // Numbers before the word "pinned" if it comes last; otherwise numbers after it are ignored for the ids.
        var numbers: [Int] = []
        var current = ""
        for ch in text + " " {
            if ch.isNumber { current.append(ch) } else { if let n = Int(current) { numbers.append(n) }; current = "" }
        }
        var pinned = false
        if let r = pinnedRange {
            let rest = text[r.upperBound...].drop { $0 == ":" || $0 == "=" || $0 == " " }
            pinned = ["yes", "true", "1", "on"].contains { rest.hasPrefix($0) }
        }
        return (numbers.count > 0 ? numbers[0] : 0, numbers.count > 1 ? numbers[1] : 0,
                numbers.count > 2 ? numbers[2] : 0, pinned)
    }

    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
