import XCTest
@testable import Campfire
import CampfireKit

@MainActor
final class RoomStoreTests: XCTestCase {
    func testHistoryWindowAndJump() async {
        let store = RoomStore()
        await store.load()
        XCTAssertEqual(store.rows.map(\.id), Array(49961...50000))
        XCTAssertTrue(store.loadOlder())
        XCTAssertEqual(store.rows.map(\.id), Array(49921...50000))
        store.jump(to: 2500)
        XCTAssertEqual(store.rows.first?.id, 2460)
        XCTAssertEqual(store.rows.last?.id, 2540)
        XCTAssertTrue(store.rows.contains { $0.id == 2500 })
        for _ in 0..<10 { store.loadOlder() }
        XCTAssertLessThanOrEqual(store.rows.count, 320)
        store.reset()
        XCTAssertEqual(store.rows.count, 40)
        XCTAssertEqual(store.rows.last?.id, 50000)
    }

    func testBoostBurstUsesRequiredPackageBoosts() async throws {
        let store = RoomStore()
        await store.load()
        let count = try XCTUnwrap(store.rows.last).message.boosts.count
        store.boostBurst()
        try await Task.sleep(for: .milliseconds(1250))
        let boosts = try XCTUnwrap(store.rows.last).message.boosts.suffix(5)
        XCTAssertEqual(store.rows.last?.message.boosts.count, count + 5)
        XCTAssertEqual(boosts.map(\.boosterID), [2, 3, 4, 5, 6])
        XCTAssertEqual(boosts.map(\.content), ["👍", "🎉", "🔥", "❤️", "😂"])
    }
}
