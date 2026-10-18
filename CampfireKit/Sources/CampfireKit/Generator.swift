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
        var author = rng.int(1...userCount)
        var boostID = 1
        for i in 0..<count {
            // Runs of one author (threaded messages) with short gaps, then a new author after a longer pause.
            if rng.chance(0.35) {
                author = rng.int(1...userCount)
                time = time.addingTimeInterval(Double(rng.int(60...1800)))
            } else {
                time = time.addingTimeInterval(Double(rng.int(2...240)))
            }
            // Occasional long silence so that day separators appear (about one per 60 messages).
            if rng.chance(1.0 / 60) { time = time.addingTimeInterval(Double(rng.int(6...20)) * 3600) }
            let m = makeMessage(id: i + 1, creator: author, at: time, rng: &rng, boostID: &boostID)
            messages.append(m)
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
            blocks = [.mention(rng.int(1...userCount)), .text(" " + sentence(&rng, words: rng.int(2...10)))]
        case 19..<27:
            blocks = [.text(paragraphs(&rng))]  // long: 3-5 sentences, up to two paragraphs
        default:
            blocks = [.text(sentence(&rng, words: rng.chance(0.6) ? rng.int(1...8) : rng.int(9...24)))]
        }
        var boosts: [Boost] = []
        if rng.chance(0.08) {
            for _ in 0..<rng.int(1...3) {
                boosts.append(Boost(id: boostID, boosterID: rng.int(1...userCount), content: rng.pick(Corpus.reactions)))
                boostID += 1
            }
        }
        return Message(id: id, creatorID: creator, createdAt: time, blocks: blocks, attachment: attachment,
                       boosts: boosts, clientMessageID: "m\(id)")
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
