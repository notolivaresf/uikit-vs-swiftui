import Testing
import Foundation
import CampfireKit
@testable import CampfireKitObjC

private let swiftData = FakeData.generate(size: .k50)
private let bridge = CFKDataset()

private func expectEqual(_ c: CFKMessage, _ m: Message) {
    #expect(c.messageID == m.id)
    #expect(c.creatorID == m.creatorID)
    #expect(c.createdAt == m.createdAt)
    #expect(c.clientMessageID == m.clientMessageID)
    #expect(c.plainText == m.plainText)
    #expect(c.isEmojiOnly == m.isEmojiOnly)
    #expect(c.mentionedUserIDs.map(\.intValue) == m.mentionedUserIDs)
    #expect(c.blocks.count == m.blocks.count)
    for (cb, b) in zip(c.blocks, m.blocks) {
        switch b {
        case .text(let t): #expect(cb.kind == .text && cb.text == t && cb.mentionedUserID == 0 && cb.language == nil)
        case .mention(let id): #expect(cb.kind == .mention && cb.mentionedUserID == id && cb.text == nil)
        case .code(let lang, let src): #expect(cb.kind == .code && cb.text == src && cb.language == lang)
        }
    }
    switch m.attachment {
    case nil: #expect(c.attachment == nil)
    case .image(let w, let h, let col)?:
        let a = c.attachment
        #expect(a?.kind == .image && a?.width == w && a?.height == h)
        #expect(a?.red == Int(col.r) && a?.green == Int(col.g) && a?.blue == Int(col.b))
        #expect(a?.placeholderPNGData == Placeholder.pngData(width: w, height: h, color: col))
    case .file(let n, let b)?:
        #expect(c.attachment?.kind == .file && c.attachment?.name == n && c.attachment?.bytes == b)
        #expect(c.attachment?.placeholderPNGData == nil)
    }
    #expect(c.boosts.count == m.boosts.count)
    for (cb, b) in zip(c.boosts, m.boosts) {
        #expect(cb.boostID == b.id && cb.boosterID == b.boosterID && cb.content == b.content)
    }
}

private func samples() -> [Int] {
    var rng = SeededRandom(seed: FakeData.defaultSeed)
    return [1, 50_000, 2_500] + (0..<200).map { _ in rng.int(1...50_000) }
}

@Suite struct BridgeTests {
    @Test func datasetBasics() {
        #expect(bridge.messageCount == swiftData.messages.count)
        #expect(bridge.seed == swiftData.seed)
        #expect(bridge.currentUserID == swiftData.currentUserID)
        #expect(bridge.firstMessageID == 1 && bridge.lastMessageID == 50_000)
        #expect(CFKDataset.pageSize == 40)
        #expect(bridge.users.count == 50)
        for (c, u) in zip(bridge.users, swiftData.users) {
            #expect(c.userID == u.id && c.name == u.name)
            #expect(c.red == Int(u.avatar.r) && c.green == Int(u.avatar.g) && c.blue == Int(u.avatar.b))
        }
        #expect(bridge.user(withID: 7)?.name == swiftData.user(7)?.name)
        #expect(bridge.user(withID: 999) == nil)
    }

    @Test func sampledMessagesMatch() {
        for id in samples() {
            guard let c = bridge.message(withID: id) else { Issue.record("missing \(id)"); continue }
            expectEqual(c, swiftData.messages[id - 1])
        }
        #expect(bridge.message(withID: 0) == nil)
        #expect(bridge.message(withID: 50_001) == nil)
    }

    @Test func pagesMatchWindowing() {
        let all = swiftData.messages
        func check(_ page: CFKPage, _ slice: ArraySlice<Message>) {
            #expect(page.messages.count == slice.count)
            for (c, m) in zip(page.messages, slice) { expectEqual(c, m) }
        }
        check(bridge.lastPage(), Windowing.lastPage(all))
        for id in [1, 2, 40, 41, 2_500, 49_961, 50_000] {
            check(bridge.pageBeforeMessageID(id), Windowing.page(before: id, in: all))
            check(bridge.pageAfterMessageID(id), Windowing.page(after: id, in: all))
            check(bridge.pageAroundMessageID(id), Windowing.around(id, in: all))
        }
        #expect(bridge.pageBeforeMessageID(999_999).messages.isEmpty)
    }

    @Test func groupingMatches() {
        let all = swiftData.messages
        let me = swiftData.currentUserID
        func same(_ c: CFKPresentation, _ p: MessagePresentation) {
            #expect(c.isThreaded == p.isThreaded && c.isFirstOfDay == p.isFirstOfDay)
            #expect(c.isMine == p.isMine && c.mentionsMe == p.mentionsMe)
        }
        for id in samples() {
            let i = id - 1
            let expected = Grouping.presentation(of: all[i], after: i > 0 ? all[i - 1] : nil, currentUserID: me)
            same(bridge.presentation(forMessageID: id)!, expected)
        }
        // Page presentations are computed against the message before the page.
        for id in [1, 41, 2_500, 50_000] {
            let page = bridge.pageBeforeMessageID(id + 1)
            let slice = Windowing.page(before: id + 1, in: all)
            let expected = Grouping.presentations(of: Array(slice), previous: slice.startIndex > 0 ? all[slice.startIndex - 1] : nil, currentUserID: me)
            #expect(page.presentations.count == expected.count)
            for (c, p) in zip(page.presentations, expected) { same(c, p) }
        }
        let a = bridge.message(withID: 100)!, b = bridge.message(withID: 101)!
        same(bridge.presentation(of: b, after: a), Grouping.presentation(of: all[100], after: all[99], currentUserID: me))
        same(bridge.presentation(of: a, after: nil), Grouping.presentation(of: all[99], after: nil, currentUserID: me))
    }

    @Test func scriptedEventsMatchSwiftFeed() {
        let swiftFeed = FakeLiveFeed(dataset: swiftData)
        let feed = CFKLiveFeed(dataset: bridge)
        let events = feed.scriptedEvents()
        #expect(feed.eventCount == swiftFeed.script.count && events.count == swiftFeed.script.count)
        for (c, s) in zip(events, swiftFeed.script) {
            switch s.event {
            case .message(let m): #expect(c.kind == .message); expectEqual(c.message!, m)
            case .boost(let id, let b):
                #expect(c.kind == .boost && c.messageID == id)
                #expect(c.boost?.boostID == b.id && c.boost?.boosterID == b.boosterID && c.boost?.content == b.content)
            case .typingStarted(let u): #expect(c.kind == .typingStarted && c.userID == u)
            case .typingStopped(let u): #expect(c.kind == .typingStopped && c.userID == u)
            }
        }
    }

    /// Plays a short real feed through the Objective-C style callbacks and checks sequence, queue and completion.
    @Test @MainActor func liveFeedDeliversSameSequenceOnMain() async {
        let rate = 100.0, secs = 0.5
        let swiftFeed = FakeLiveFeed(dataset: swiftData, messagesPerSecond: rate, duration: secs)
        let feed = CFKLiveFeed(dataset: bridge, messagesPerSecond: rate, duration: secs)
        let box = Box()
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
            _ = feed.start(onEvent: { e in
                MainActor.assumeIsolated { box.onMain = box.onMain && Thread.isMainThread; box.events.append(e) }
            }, completion: {
                MainActor.assumeIsolated { box.completed += 1; k.resume() }
            })
        }
        #expect(box.completed == 1 && box.onMain)
        #expect(box.events.count == swiftFeed.script.count)
        for (c, s) in zip(box.events, swiftFeed.script) {
            switch s.event {
            case .message(let m): #expect(c.kind == .message && c.message?.messageID == m.id && c.message?.plainText == m.plainText)
            case .boost(let id, let b): #expect(c.kind == .boost && c.messageID == id && c.boost?.boostID == b.id)
            case .typingStarted(let u): #expect(c.kind == .typingStarted && c.userID == u)
            case .typingStopped(let u): #expect(c.kind == .typingStopped && c.userID == u)
            }
        }
    }

    @Test @MainActor func cancelStopsCallbacks() async throws {
        let feed = CFKLiveFeed(dataset: bridge, messagesPerSecond: 50, duration: 5)
        let box = Box()
        let handle = feed.start(onEvent: { _ in MainActor.assumeIsolated { box.count += 1 } },
                                completion: { MainActor.assumeIsolated { box.completed += 1 } })
        try await Task.sleep(for: .milliseconds(300))
        handle.cancel()
        try await Task.sleep(for: .milliseconds(100))
        let seen = box.count
        try await Task.sleep(for: .milliseconds(400))
        #expect(seen > 0 && box.count == seen && box.completed == 0)
    }

    @Test func placeholderPNG() {
        let d = CFKPlaceholder.pngData(width: 4, height: 3, red: 10, green: 20, blue: 30)
        #expect(d == Placeholder.pngData(width: 4, height: 3, color: RGB(r: 10, g: 20, b: 30)))
        #expect(d.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }
}

@MainActor private final class Box {
    var events: [CFKFeedEvent] = []
    var completed = 0
    var count = 0
    var onMain = true
}

@Suite struct WrappingCostBenchmark {
    /// Median wall time to wrap one page of 40 (messages plus presentations), many runs, printed.
    @Test func wrapOnePageOf40() {
        let all = swiftData.messages
        let starts = stride(from: 100, to: 49_000, by: 997).map { $0 }
        _ = bridge.pageBeforeMessageID(2_000) // warm up
        func median(_ run: (Int) -> Void) -> Double {
            var t: [Double] = []
            for round in 0..<20 { for s in starts {
                let a = ContinuousClock.now
                run(s + round)
                let d = ContinuousClock.now - a
                t.append(Double(d.components.seconds) * 1e3 + Double(d.components.attoseconds) / 1e15)
            } }
            return t.sorted()[t.count / 2]
        }
        // Pre-sliced pages, so the id lookup in Windowing (a linear scan) is not part of the number.
        let slices = starts.map { Array(all[($0 - 40)..<$0]) }
        let wrapOnly = median { s in
            let page = slices[s % slices.count]
            blackHole(page.map(CFKMessage.init).count)
        }
        let pageCall = median { s in blackHole(bridge.pageBeforeMessageID(s).messages.count) }
        let swiftOnly = median { s in
            let page = slices[s % slices.count]
            blackHole(Grouping.presentations(of: page, previous: nil, currentUserID: 1).count)
        }
        func f(_ x: Double) -> String { String(format: "%.4f", x) }
        print("CFK wrapping cost, one page of 40, median of \(20 * starts.count) runs: wrap 40 messages \(f(wrapOnly)) ms; Swift grouping alone \(f(swiftOnly)) ms; full bridge page call (id lookup, slice, grouping, wrap) \(f(pageCall)) ms")
        #expect(wrapOnly < 50)
    }
}

@inline(never) private func blackHole(_ x: Int) { if x == -1 { print(x) } }
