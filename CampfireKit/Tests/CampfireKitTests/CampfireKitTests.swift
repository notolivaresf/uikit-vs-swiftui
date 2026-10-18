import Testing
let goldenSum = 323580392
import Foundation
@testable import CampfireKit

@Suite struct DeterminismTests {
    @Test func sameSeedSameData() {
        #expect(FakeData.generate(size: .k1).messages == FakeData.generate(size: .k1).messages)
    }

    @Test func differentSeedDiffers() {
        #expect(FakeData.generate(count: 200, seed: 1).messages != FakeData.generate(count: 200, seed: 2).messages)
    }

    @Test func prefixStable() {
        // A bigger dataset starts with the smaller one, so 1k results are comparable to 50k results.
        let small = FakeData.generate(count: 1_000).messages
        let big = FakeData.generate(count: 3_000).messages
        #expect(Array(big.prefix(1_000)) == small)
    }

    @Test func goldenFingerprint() {
        // Locks the generator: if this changes, every stored benchmark number is void.
        let m = FakeData.generate(count: 1_000).messages
        let sum = m.reduce(0) { ($0 &* 31 &+ $1.creatorID &+ $1.plainText.utf8.count) % 1_000_000_007 }
        #expect(sum == goldenSum)
    }

    @Test func shape() {
        let d = FakeData.generate(size: .k10)
        #expect(d.users.count == 50)
        #expect(d.messages.count == 10_000)
        #expect(zip(d.messages, d.messages.dropFirst()).allSatisfy { $0.id < $1.id && $0.createdAt <= $1.createdAt })
        #expect(d.messages.contains { $0.attachment != nil })
        #expect(d.messages.contains { !$0.boosts.isEmpty })
        #expect(d.messages.contains { !$0.mentionedUserIDs.isEmpty })
        #expect(d.messages.contains { $0.isEmojiOnly })
        #expect(d.messages.contains { $0.blocks.contains { if case .code = $0 { true } else { false } } })
        #expect(d.messages.allSatisfy { $0.creatorID >= 1 && $0.creatorID <= 50 })
    }

    @Test func fiftyKSize() {
        #expect(FakeData.generate(size: .k50).messages.count == 50_000)
    }

    @Test func placeholderPNG() {
        let png = Placeholder.pngData(width: 4, height: 3, color: RGB(r: 1, g: 2, b: 3))
        #expect(Array(png.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(Placeholder.pngData(width: 4, height: 3, color: RGB(r: 1, g: 2, b: 3)) == png)
    }
}

@Suite struct GroupingTests {
    @Test func threadingAndDays() {
        let d = FakeData.generate(count: 2_000)
        let p = Grouping.presentations(of: d.messages, currentUserID: 1)
        #expect(p[0].isFirstOfDay && !p[0].isThreaded)
        #expect(p.contains { $0.isThreaded })
        #expect(p.filter(\.isFirstOfDay).count > 3)
        for i in 1..<d.messages.count where p[i].isThreaded {
            #expect(d.messages[i].creatorID == d.messages[i - 1].creatorID)
            #expect(!p[i].isFirstOfDay)
        }
    }

    @Test func pages() {
        let all = FakeData.generate(count: 500).messages
        #expect(Windowing.lastPage(all).last?.id == 500)
        #expect(Windowing.page(before: 100, in: all).map(\.id) == Array(60..<100))
        #expect(Windowing.page(before: 10, in: all).count == 9)
        #expect(Windowing.around(250, in: all).count == 81)
    }
}

@Suite struct LiveFeedTests {
    @Test func scriptDeterministicAndRated() {
        let d = FakeData.generate(count: 100)
        let a = FakeLiveFeed(dataset: d), b = FakeLiveFeed(dataset: d)
        #expect(a.script == b.script)
        let msgs = a.script.compactMap { e -> Message? in if case .message(let m) = e.event { m } else { nil } }
        #expect(msgs.count == 600)
        #expect(msgs.first?.id == 101)
        #expect(msgs.last?.id == 700)
        #expect(msgs.allSatisfy { $0.creatorID != d.currentUserID })
        #expect(a.script.last!.at <= 30.1)
        #expect(zip(a.script, a.script.dropFirst()).allSatisfy { $0.at <= $1.at })
    }

    @Test func playYieldsEvents() async {
        let d = FakeData.generate(count: 10)
        let feed = FakeLiveFeed(dataset: d, messagesPerSecond: 100, duration: 0.2)
        var n = 0
        for await e in feed.play() { if case .message = e { n += 1 } }
        #expect(n == 20)
    }
}

@Suite struct ScaleTests {
    @Test func fiftyKTimingAndMix() {
        let start = ContinuousClock.now
        let d = FakeData.generate(size: .k50)
        let elapsed = ContinuousClock.now - start
        print("CampfireKit: generated \(d.messages.count) messages in \(elapsed)")
        let n = Double(d.messages.count)
        func pct(_ f: (Message) -> Bool) -> Double { Double(d.messages.filter(f).count) / n * 100 }
        let long = pct { $0.plainText.utf8.count > 200 }
        let image = pct { if case .image? = $0.attachment { true } else { false } }
        let code = pct { $0.blocks.contains { if case .code = $0 { true } else { false } } }
        let mention = pct { !$0.mentionedUserIDs.isEmpty }
        let boosts = pct { !$0.boosts.isEmpty }
        print("mix %: long \(long) image \(image) code \(code) mention \(mention) boosts \(boosts)")
        #expect(d.messages.count == 50_000 && d.users.count == 50)
        #expect(abs(image - 6) < 1 && abs(code - 3) < 1 && abs(mention - 5) < 1 && abs(boosts - 8) < 1)
        #expect(long > 4 && long < 12)
        #expect(d.messages[0].createdAt >= FakeData.epoch)
        #expect(Windowing.pageSize == 40)
        #expect(Grouping.threadWindow == 300)
        let feed = FakeLiveFeed(dataset: d)
        #expect(feed.messagesPerSecond == 20 && feed.duration == 30)
    }
}
