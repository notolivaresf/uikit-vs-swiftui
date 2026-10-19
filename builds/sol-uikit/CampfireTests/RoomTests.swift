import XCTest
import UIKit
import CampfireKit
@testable import Campfire

final class RoomTests: XCTestCase {
    @MainActor private func room() -> (UIWindow, RoomViewController) {
        let vc = RoomViewController(dataset: FakeData.generate(size: .k50))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc; window.makeKeyAndVisible()
        vc.view.frame = window.bounds; vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        return (window, vc)
    }

    @MainActor func testLaunchAndResetNewestForty() {
        let (window, vc) = room(); defer { window.isHidden = true }
        XCTAssertEqual(vc.loaded.map(\.id), Array(49961...50000))
        XCTAssertTrue(vc.isPinned)
        let initialAnchor = vc.captureAnchor()
        for _ in 0..<12 { vc.handleDebugAction("Load older") }
        XCTAssertLessThanOrEqual(vc.loaded.count, Windowing.maxLoaded)
        XCTAssertEqual(vc.captureAnchor().messageID, initialAnchor.messageID)
        XCTAssertEqual(vc.captureAnchor().y, initialAnchor.y, accuracy: 0.34)
        vc.handleDebugAction("Jump to 2500")
        vc.handleDebugAction("Text size +")
        vc.handleDebugAction("Reset")
        XCTAssertEqual(vc.loaded.count, 40)
        XCTAssertEqual(vc.loaded.last?.id, 50000)
        XCTAssertTrue(vc.isPinned)
    }

    @MainActor func testJumpAndOlderKeepExactTop() {
        let (window, vc) = room(); defer { window.isHidden = true }
        vc.handleDebugAction("Jump to 2500")
        let before = vc.captureAnchor()
        XCTAssertEqual(before.messageID, 2500)
        XCTAssertEqual(before.y, 0, accuracy: 0.01)
        XCTAssertFalse(before.pinned)
        vc.handleDebugAction("Load older")
        let after = vc.captureAnchor()
        XCTAssertEqual(after.messageID, before.messageID)
        XCTAssertEqual(after.y, before.y, accuracy: 0.34)
        XCTAssertEqual(vc.loaded.first?.id, 2420)
    }

    @MainActor func testDynamicTypeKeepsAnchorIncludingPartialRow() {
        let (window, vc) = room(); defer { window.isHidden = true }
        vc.handleDebugAction("Jump to 2500")
        vc.collection.contentOffset.y += 17.5
        let before = vc.captureAnchor()
        for _ in 0..<8 {
            vc.handleDebugAction("Text size +")
            let after = vc.captureAnchor()
            XCTAssertEqual(after.messageID, before.messageID)
            XCTAssertEqual(after.y, before.y, accuracy: 0.34)
            for metric in vc.roomLayout.metrics {
                XCTAssertTrue(metric.bubble.height.isFinite)
                XCTAssertGreaterThan(metric.bubble.height, 0)
            }
        }
    }

    @MainActor func testStreamingPinnedAndReadingHistory() {
        let (window, vc) = room(); defer { window.isHidden = true }
        let events = FakeLiveFeed(dataset: vc.dataset).script
        for event in events.prefix(70) { vc.receive(event.event) }
        XCTAssertTrue(vc.isPinned)
        XCTAssertGreaterThan(vc.loaded.last!.id, 50000)
        vc.handleDebugAction("Jump to 2500")
        vc.collection.contentOffset.y += 12.5
        let before = vc.captureAnchor()
        for event in events.dropFirst(70).prefix(100) { vc.receive(event.event) }
        let after = vc.captureAnchor()
        XCTAssertEqual(after.messageID, before.messageID)
        XCTAssertEqual(after.y, before.y, accuracy: 0.34)
    }

    @MainActor func testStreamAppendsAndTrimsWithoutMovingReader() {
        let (window, vc) = room(); defer { window.isHidden = true }
        vc.collection.contentOffset.y = vc.bottomOffset - 400
        let before = vc.captureAnchor()
        XCTAssertFalse(before.pinned)
        for event in FakeLiveFeed(dataset: vc.dataset).script { vc.receive(event.event) }
        let after = vc.captureAnchor()
        XCTAssertEqual(after.messageID, before.messageID)
        XCTAssertEqual(after.y, before.y, accuracy: 0.34)
        XCTAssertLessThanOrEqual(vc.loaded.count, Windowing.maxLoaded)
        XCTAssertEqual(vc.all.last?.id, 50600)
    }

    @MainActor func testAllSixHundredStreamMessagesStayPinnedWithBoundedWindow() {
        let (window, vc) = room(); defer { window.isHidden = true }
        for event in FakeLiveFeed(dataset: vc.dataset).script { vc.receive(event.event) }
        XCTAssertEqual(vc.loaded.last?.id, 50600)
        XCTAssertLessThanOrEqual(vc.loaded.count, Windowing.maxLoaded)
        XCTAssertTrue(vc.isPinned)
    }

    @MainActor func testEveryShowcaseKindHasBoundedGeometryAndWrappedBoosts() {
        let data = FakeData.generate(size: .k50)
        let users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        let page = Array(Windowing.lastPage(data.messages))
        let metrics = page.enumerated().map { index, m in
            MessageMetrics.make(message: m, previous: data.messages[m.id-2], users: users, width: 393, category: .large, boosts: m.boosts.map(DisplayBoost.init))
        }
        XCTAssertTrue(metrics[5].presentation.isThreaded)
        XCTAssertTrue(metrics[7].presentation.isMine)
        XCTAssertTrue(metrics[8].presentation.mentionsMe)
        XCTAssertEqual(metrics[9].bubble.width, 300, accuracy: 0.01)
        XCTAssertEqual(metrics[9].parts.last!.frame.height, 225, accuracy: 0.01)
        XCTAssertTrue(page[12].isEmojiOnly)
        let boosted = metrics[13]
        XCTAssertGreaterThan(Set(boosted.boostFrames.map(\.minY)).count, 1)
        for metric in metrics {
            XCTAssertGreaterThanOrEqual(metric.bubble.minX, 14)
            XCTAssertLessThanOrEqual(metric.bubble.maxX, 379.01)
            for f in metric.boostFrames + [metric.addBoostFrame].compactMap({ $0 }) {
                XCTAssertLessThanOrEqual(f.maxX, metric.bubble.width + 0.01)
                XCTAssertLessThanOrEqual(f.maxY, metric.bubble.height)
            }
        }
    }
}
