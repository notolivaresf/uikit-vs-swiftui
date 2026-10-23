import SwiftUI
import CampfireKit

@main struct BehaviorChecks {
    @MainActor static func main() async throws {
        let begin = ContinuousClock.now
        let store = RoomStore()
        let generated = begin.duration(to: .now)
        check(store.messages.count == 40 && store.messages.first?.id == 49961 && store.messages.last?.id == 50000, "Newest page is exactly 40 messages")
        print("Data generation:", generated)
        store.jumpTo2500()
        check(store.messages.first?.id == 2460 && store.messages.last?.id == 2540, "Jump window includes message 2500")
        check(store.loadOlder(topID: 2500) && store.messages.first?.id == 2420 && store.messages.count == 121, "Load older prepends a package page")
        for expected in [1, 2, 3, 4, 0] { store.increaseTextSize(); check(store.textStep == expected, "Text size step \(expected)") }
        store.reset()
        check(store.messages.count == 40 && store.textStep == 0, "Reset restores default page and text")

        let scroll = RoomScroll(launchTime: .now)
        let original = Dictionary(uniqueKeysWithValues: (1...10).map { ($0, CGRect(x: 0, y: ($0 - 1) * 100, width: 393, height: 100)) })
        scroll.receiveFrames(original)
        scroll.receiveLayout(ContentLayout(size: CGSize(width: 393, height: 1000), revision: 0))
        scroll.receiveMetrics(RoomMetrics(offset: 600, height: 400, contentHeight: 1000))
        try await Task.sleep(for: .milliseconds(40))
        check(scroll.pinned && scroll.topID == 7 && abs(scroll.topY) < 0.1, "Initial bottom anchoring reports actual visible row")
        scroll.receiveMetrics(RoomMetrics(offset: 250, height: 400, contentHeight: 1000))
        check(!scroll.pinned && scroll.topID == 3 && scroll.topY == -50, "Partly visible top row is measured")
        scroll.preserve()
        var prepended = original.mapValues { $0.offsetBy(dx: 0, dy: 400) }
        for id in -3...0 { prepended[id] = CGRect(x: 0, y: (id + 3) * 100, width: 393, height: 100) }
        scroll.receiveFrames(prepended)
        scroll.receiveLayout(ContentLayout(size: CGSize(width: 393, height: 1400), revision: 1))
        scroll.receiveMetrics(RoomMetrics(offset: 250, height: 400, contentHeight: 1400))
        try await Task.sleep(for: .milliseconds(40))
        check(abs((scroll.position.y ?? -1) - 650) < 0.1, "Prepending restores row 3 at y -50 exactly")
        scroll.receiveMetrics(RoomMetrics(offset: 650, height: 400, contentHeight: 1400))
        try await Task.sleep(for: .milliseconds(30))
        scroll.preserve()
        let reflowed = prepended.mapValues { CGRect(x: $0.minX, y: $0.minY * 1.25, width: 600, height: 125) }
        scroll.receiveFrames(reflowed)
        scroll.receiveLayout(ContentLayout(size: CGSize(width: 600, height: 1750), revision: 2))
        scroll.receiveMetrics(RoomMetrics(offset: 650, height: 400, contentHeight: 1750))
        try await Task.sleep(for: .milliseconds(40))
        check(abs((scroll.position.y ?? -1) - 800) < 0.1, "Text/width reflow retains the partially visible row exactly")
        scroll.receiveMetrics(RoomMetrics(offset: 800, height: 400, contentHeight: 1750))
        try await Task.sleep(for: .milliseconds(30))
        check(scroll.topID == 3 && abs(scroll.topY + 50) < 0.1, "Reflow settles to the same top id and offset")

        let newest = store.messages.last!
        store.boostBurst(scroll: scroll)
        try await Task.sleep(for: .milliseconds(1150))
        let added = Array(store.messages.last!.boosts.dropFirst(newest.boosts.count))
        check(added.map(\.boosterID) == [2, 3, 4, 5, 6], "Boost burst uses the five requested people")
        check(added.map(\.content) == ["👍", "🎉", "🔥", "❤️", "😂"], "Boost burst uses the five requested reactions")
        store.reset()
        store.startStream(scroll: scroll)
        try await Task.sleep(for: .milliseconds(30700))
        check(store.streamDone && !store.streamRunning, "Live stream reaches completion")
        check(store.history.count == 50600 && store.history.last?.id == 50600, "Only the live feed adds the 600 new messages")
        check(store.hasNewMessages, "Stream while unpinned exposes jump to bottom")
        store.newest()
        check(store.messages.first?.id == 50561 && store.messages.count == 40, "Jump to bottom loads the newest live page")
        print("All behavior checks passed.")
    }
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
        print("PASS:", message)
    }
}
