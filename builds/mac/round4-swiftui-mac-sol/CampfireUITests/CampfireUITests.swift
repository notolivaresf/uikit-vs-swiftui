import XCTest
import AppKit
import ApplicationServices

@MainActor final class CampfireUITests: XCTestCase {
    private var app: XCUIApplication!
    struct State {
        let first: Int
        let last: Int
        let loaded: Int
        let pinned: Bool
        let top: Int
        let y: Double
        let ms: Int
    }
    override func setUp() async throws {
        continueAfterFailure = false
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        if session?["CGSSessionScreenIsLocked"] as? Bool == true {
            throw XCTSkip("These interaction checks require an unlocked desktop.")
        }
        app = XCUIApplication()
        app.launchArguments = ["-uvsBenchmark", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["benchmark-state"].waitForExistence(timeout: 5))
        waitFor { self.state()?.top ?? 0 > 0 }
    }
    override func tearDown() async throws { app?.terminate() }

    func testLaunchJumpPagingAndTextReflow() throws {
        let start = try XCTUnwrap(state())
        XCTAssertEqual(start.first, 49961)
        XCTAssertEqual(start.last, 50000)
        XCTAssertEqual(start.loaded, 40)
        XCTAssertTrue(start.pinned)
        XCTAssertLessThan(start.ms, 1000)
        XCTAssertEqual(app.windows.firstMatch.frame.width, 393, accuracy: 2)
        XCTAssertEqual(app.windows.firstMatch.frame.height, 852, accuracy: 2)
        app.buttons["Jump to 2500"].click()
        waitFor { self.state()?.top == 2500 && abs(self.state()?.y ?? 100) <= 2 }
        let anchor = try XCTUnwrap(state())
        let messageTop = app.otherElements["message-2500"].frame.minY
        let headerBottom = app.buttons["Menu"].frame.maxY + 10
        XCTAssertEqual(messageTop, headerBottom, accuracy: 2)
        XCTAssertFalse(anchor.pinned)
        app.buttons["Load older"].click()
        waitFor { self.state()?.first == 2420 }
        for _ in 0..<5 {
            app.buttons["Text size +"].click()
            waitFor { self.state()?.top == anchor.top && abs((self.state()?.y ?? 100) - anchor.y) <= 2 }
            XCTAssertEqual(try XCTUnwrap(state()).top, anchor.top)
        }
        app.buttons["Reset"].click()
        waitFor { self.state()?.loaded == 40 && self.state()?.pinned == true }
    }
    func testResizePreservesAnchor() throws {
        app.buttons["Jump to 2500"].click()
        waitFor { self.state()?.top == 2500 }
        let anchor = try XCTUnwrap(state())
        let running = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "campfire.bench").last { $0.isFinishedLaunching })
        let ax = AXUIElementCreateApplication(running.processIdentifier)
        var windows: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows), .success)
        let window = try XCTUnwrap((windows as? [AXUIElement])?.first)
        for width: CGFloat in [600, 1200, 393] {
            var size = CGSize(width: width, height: 852)
            let value = try XCTUnwrap(AXValueCreate(.cgSize, &size))
            XCTAssertEqual(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value), .success)
            waitFor { abs(self.app.windows.firstMatch.frame.width - width) < 2 && self.state()?.top == anchor.top && abs((self.state()?.y ?? 100) - anchor.y) <= 2 }
        }
    }
    func testBoostsAndLiveFeedWhileUnpinned() throws {
        app.buttons["Jump to 2500"].click()
        waitFor { self.state()?.top == 2500 }
        app.buttons["Boost burst"].click()
        app.buttons["Start stream"].click()
        XCTAssertTrue(app.staticTexts["Stream done"].waitForExistence(timeout: 35))
        let state = try XCTUnwrap(state())
        XCTAssertEqual(state.top, 2500)
        XCTAssertEqual(state.y, 0, accuracy: 2)
        XCTAssertFalse(state.pinned)
        app.buttons["Jump to bottom"].click()
        waitFor { self.state()?.last == 50600 && self.state()?.pinned == true }
    }
    func testSelectableMessageAndContextCopy() throws {
        let room = app.scrollViews["room-scroll"]
        XCTAssertTrue(room.exists)
        app.buttons["Jump to 2500"].click()
        waitFor { self.state()?.top == 2500 }
        let row = app.otherElements["message-2500"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        let point = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        point.rightClick()
        XCTAssertTrue(app.menuItems["Copy"].waitForExistence(timeout: 2))
        app.menuItems["Copy"].click()
        let copied = try XCTUnwrap(NSPasteboard.general.string(forType: .string))
        XCTAssertFalse(copied.isEmpty)
        let body = row.staticTexts.allElementsBoundByIndex.last
        if let body {
            NSPasteboard.general.clearContents()
            let word = body.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: 12, dy: 10))
            word.doubleClick()
            app.typeKey("c", modifierFlags: .command)
            let selection = try XCTUnwrap(NSPasteboard.general.string(forType: .string))
            XCTAssertFalse(selection.isEmpty)
            XCTAssertTrue(copied.contains(selection))
        } else {
            XCTFail("The message must expose selectable text")
        }
        room.scroll(byDeltaX: 0, deltaY: 200)
        XCTAssertTrue(app.buttons["Reset"].exists)
    }
    private func state() -> State? {
        let label = app.staticTexts["benchmark-state"].label
        let parts = label.split(separator: " ").map(String.init)
        guard parts.count == 14, let first = Int(parts[1]), let last = Int(parts[3]),
              let loaded = Int(parts[5]), let top = Int(parts[9]), let y = Double(parts[11]), let ms = Int(parts[13]) else { return nil }
        return State(first: first, last: last, loaded: loaded, pinned: parts[7] == "yes", top: top, y: y, ms: ms)
    }
    private func waitFor(timeout: TimeInterval = 5, _ condition: @escaping @MainActor () -> Bool) {
        let predicate = NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }
}
