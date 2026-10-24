import Testing
import SwiftUI
import CampfireKit
@testable import Campfire

@MainActor struct RoomStoreTests {
    @Test func initialPageAndPagingUsePackageWindows() async {
        let store = RoomStore()
        await store.load()
        #expect(store.all.count == 50_000)
        #expect(store.items.map(\.id) == Array(49_961...50_000))
        let file = store.items.first { if case .file = $0.message.attachment { true } else { false } }
        #expect(file?.copyText == "budget.xlsx")
        let retained = store.items[20]
        store.loadOlder(preserving: retained.id)
        #expect(store.items.map(\.id) == Array(49_921...50_000))
        #expect(store.items.first { $0.id == retained.id } === retained)
        store.jumpTo2500()
        #expect(store.items.map(\.id) == Array(2460...2540))
        let message = store.all[2499]
        #expect(store.items.first { $0.id == 2500 }?.presentation ==
                Grouping.presentation(of: message, after: store.all[2498], currentUserID: 1))
        store.reset()
        #expect(store.items.count == 40)
        #expect(store.isAtNewestPage)
    }

    @Test func textSizeCyclesAndResetRestoresDefault() {
        let store = RoomStore()
        store.increaseTextSize(from: .large)
        #expect(store.textSize == .xLarge)
        store.increaseTextSize(from: .accessibility5)
        #expect(store.textSize == .large)
        #expect(store.overrideTextSize)
    }

    @Test func boostBurstReusesPackageValuesInRequestedOrder() async throws {
        let store = RoomStore()
        await store.load()
        let original = store.items.last?.message.boosts.count ?? 0
        store.boostBurst()
        try await Task.sleep(for: .milliseconds(1300))
        let added = Array((store.items.last?.message.boosts ?? []).dropFirst(original))
        #expect(added.map(\.boosterID) == [2, 3, 4, 5, 6])
        #expect(added.map(\.content) == ["👍", "🎉", "🔥", "❤️", "😂"])
        #expect(Set(added.map(\.id)).count == 5)
    }

    @Test func selectionUsesWholeGraphemes() {
        let value = "Hi 👨‍👩‍👧‍👦 café!"
        let boundaries = TextSelectionGeometry.utf16Boundaries(value)
        #expect(boundaries.count == value.count + 1)
        #expect(TextSelectionGeometry.substring(value, range: 3..<4) == "👨‍👩‍👧‍👦")
        #expect(TextSelectionGeometry.substring("Morning everyone", range: 0..<7) == "Morning")
    }
}
