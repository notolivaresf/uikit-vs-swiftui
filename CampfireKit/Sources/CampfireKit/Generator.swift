import Foundation

public enum DatasetSize: Int, Sendable, CaseIterable {
    case k1 = 1_000, k10 = 10_000, k50 = 50_000
}

public enum FakeData {
    /// The fixed seed every benchmark uses. Changing it changes every number, so do not.
    public static let defaultSeed: UInt64 = 0xCAF3_F12E
    /// 2025-01-06 00:00:00 UTC: the first message of every dataset.
    public static let epoch = Date(timeIntervalSince1970: 1_736_121_600)
    public static let userCount = 50
    public static let currentUserID = 1

    public static func users(seed: UInt64 = defaultSeed) -> [User] {
        var rng = SeededRandom(seed: seed ^ 0x55)
        return (1...userCount).map { id in
            let name = "\(Corpus.first[(id - 1) % Corpus.first.count]) \(Corpus.last[rng.int(0...(Corpus.last.count - 1))])"
            return User(id: id, name: name,
                        avatar: RGB(r: UInt8(rng.int(40...200)), g: UInt8(rng.int(40...200)), b: UInt8(rng.int(40...200))))
        }
    }

    public static func generate(size: DatasetSize, seed: UInt64 = defaultSeed) -> Dataset {
        generate(count: size.rawValue, seed: seed)
    }

    public static func generate(count: Int, seed: UInt64 = defaultSeed) -> Dataset {
        let users = users(seed: seed)
        var rng = SeededRandom(seed: seed)
        var messages: [Message] = []
        messages.reserveCapacity(count)
        var time = epoch
        var author = pickAuthor(&rng)
        var boostID = 1
        for i in 0..<count {
            // Runs of one author (threaded messages) with short gaps, then a new author after a longer pause.
            if rng.chance(0.35) {
                author = pickAuthor(&rng)
                time = time.addingTimeInterval(Double(rng.int(60...1800)))
            } else {
                time = time.addingTimeInterval(Double(rng.int(2...240)))
            }
            // Occasional long silence so that day separators appear (about one per 60 messages).
            if rng.chance(1.0 / 60) { time = time.addingTimeInterval(Double(rng.int(6...20)) * 3600) }
            let m = makeMessage(id: i + 1, creator: author, at: time, rng: &rng, boostID: &boostID)
            messages.append(m)
        }
        if count >= showcaseCount {
            applyShowcase(to: &messages, seed: seed, boostID: &boostID)
        }
        return Dataset(seed: seed, currentUserID: currentUserID, users: users,
                       room: Room(name: "General", messageCount: count), messages: messages)
    }

    /// Builds one message; shared by the history generator and the live feed.
    static func makeMessage(id: Int, creator: UserID, at time: Date, rng: inout SeededRandom, boostID: inout Int) -> Message {
        var blocks: [Block] = []
        var attachment: Attachment?
        let roll = rng.int(0...99)
        switch roll {
        case 0..<3:
            blocks = [.text(rng.pick(Corpus.emoji) + (rng.chance(0.3) ? rng.pick(Corpus.emoji) : ""))]
        case 3..<9:
            attachment = .image(width: rng.pick([320, 480, 640, 800, 1200]), height: rng.pick([240, 360, 480, 600, 900]),
                                color: RGB(r: UInt8(rng.int(0...255)), g: UInt8(rng.int(0...255)), b: UInt8(rng.int(0...255))))
            if rng.chance(0.3) { blocks = [.text(sentence(&rng, words: rng.int(2...8)))] }
        case 9..<11:
            attachment = .file(name: rng.pick(Corpus.fileNames), bytes: rng.int(2_000...9_000_000))
        case 11..<14:
            let (lang, src) = rng.pick(Corpus.codeSnippets)
            blocks = [.text(sentence(&rng, words: rng.int(3...9))), .code(language: lang, source: src)]
        case 14..<19:
            blocks = [.mention(rng.chance(0.4) ? currentUserID : rng.int(2...userCount)), .text(" " + sentence(&rng, words: rng.int(2...10)))]
        case 19..<27:
            blocks = [.text(paragraphs(&rng))]  // long: 3-5 sentences, up to two paragraphs
        default:
            blocks = [.text(sentence(&rng, words: rng.chance(0.6) ? rng.int(1...8) : rng.int(9...24)))]
        }
        var boosts: [Boost] = []
        if rng.chance(0.08) {
            for _ in 0..<rng.int(1...3) {
                boosts.append(Boost(id: boostID, boosterID: rng.int(1...userCount), content: boostContent(&rng)))
                boostID += 1
            }
        }
        return Message(id: id, creatorID: creator, createdAt: time, blocks: blocks, attachment: attachment,
                       boosts: boosts, clientMessageID: "m\(id)")
    }

    /// About 1 boost in 5 is short text ("Nice!") rather than an emoji.
    static func boostContent(_ rng: inout SeededRandom) -> String {
        rng.chance(0.2) ? rng.pick(Corpus.textBoosts) : rng.pick(Corpus.reactions)
    }

    /// User 1 (the current user) writes about 10% of messages.
    static func pickAuthor(_ rng: inout SeededRandom) -> UserID {
        rng.chance(0.10) ? currentUserID : rng.int(2...userCount)
    }

    /// The newest page (what the app opens on) always holds one of every kind of row.
    public static let showcaseCount = 40

    static func applyShowcase(to messages: inout [Message], seed: UInt64, boostID: inout Int) {
        let start = messages.count - showcaseCount
        var rng = SeededRandom(seed: seed ^ 0x77)
        var time = start > 0 ? messages[start - 1].createdAt : epoch
        func boost(_ id: Int, _ by: UserID, _ text: String) -> Boost {
            defer { boostID += 1 }
            return Boost(id: boostID, boosterID: by, content: text)
        }
        func put(_ slot: Int, by creator: UserID, gap: Double, blocks: [Block], attachment: Attachment? = nil,
                 boosts: [(UserID, String)] = []) {
            time = time.addingTimeInterval(gap)
            let id = start + slot + 1
            messages[start + slot] = Message(
                id: id, creatorID: creator, createdAt: time, blocks: blocks, attachment: attachment,
                boosts: boosts.map { boost(id, $0.0, $0.1) }, clientMessageID: "m\(id)")
        }
        put(0, by: 2, gap: 90, blocks: [.text("Morning all. Standup in five.")])
        put(1, by: 3, gap: 120, blocks: [.text(
            "Quick summary of where the release stands: the build is green, the notes are drafted and the store listing is ready for review.\n\nOne more thing worth saying: the release notes are waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")])
        put(2, by: 4, gap: 75, blocks: [.mention(7), .text(" can you look at the flaky test before lunch?")])
        put(3, by: 5, gap: 60, blocks: [.text("Deploying now.")], boosts: [(8, "On it"), (9, "👍")])
        put(4, by: 6, gap: 150, blocks: [.text("Found the cause.")])
        put(5, by: 6, gap: 40, blocks: [.text("It was the cache key.")])
        put(6, by: 6, gap: 35, blocks: [.text("Patch is up for review.")])
        put(7, by: 1, gap: 100, blocks: [.text("Thanks, I will review it after lunch.")])
        put(8, by: 8, gap: 80, blocks: [.mention(currentUserID), .text(" the demo is moved to Friday, is that ok?")])
        put(9, by: 9, gap: 200, blocks: [], attachment: .image(width: 800, height: 600, color: RGB(r: 70, g: 130, b: 180)),
            boosts: [(10, "🔥"), (11, "Nice!")])
        put(10, by: 10, gap: 120, blocks: [.text("This is the query I used."), .code(language: "sh", source: "kamal deploy\ncurl -I https://example.test/up")])
        put(11, by: 11, gap: 90, blocks: [], attachment: .file(name: "budget.xlsx", bytes: 482_113))
        put(12, by: 12, gap: 60, blocks: [.text("🎉🎉")])
        put(13, by: 13, gap: 45, blocks: [.text("Shipped! Thank you everybody for the help this week, it really was a team effort.")],
            boosts: [(14, "🎉"), (15, "agreed"), (16, "👏"), (17, "lol"), (18, "❤️"), (19, "+1"), (20, "🔥"),
                     (21, "Nice!"), (22, "👍"), (23, "On it"), (24, "💪"), (25, "Agreed!")])
        var author = 14
        for slot in 14..<showcaseCount {
            var gap = Double(rng.int(20...200))
            if slot == 18 { gap = 26 * 3600 }  // more than a day: a day separator inside the window
            if rng.chance(0.35) { author = rng.int(2...userCount) }
            var m = makeMessage(id: start + slot + 1, creator: author, at: time, rng: &rng, boostID: &boostID)
            time = time.addingTimeInterval(gap)
            m = Message(id: m.id, creatorID: slot == 26 ? currentUserID : author, createdAt: time,
                        blocks: slot == 31 ? [.mention(currentUserID), .text(" ping")] : m.blocks,
                        attachment: m.attachment, boosts: m.boosts, clientMessageID: m.clientMessageID)
            messages[start + slot] = m
        }
    }

    static func sentence(_ rng: inout SeededRandom, words n: Int) -> String {
        var parts: [String] = []
        for _ in 0..<n { parts.append(rng.pick(Corpus.words)) }
        var s = parts.joined(separator: " ")
        s = s.prefix(1).uppercased() + s.dropFirst()
        return s + (rng.chance(0.15) ? "?" : ".")
    }

    static func paragraphs(_ rng: inout SeededRandom) -> String {
        let count = rng.int(3...5)
        var out = ""
        for i in 0..<count {
            out += sentence(&rng, words: rng.int(8...22))
            if i < count - 1 { out += i == 1 && rng.chance(0.5) ? "\n\n" : " " }
        }
        return out
    }
}
