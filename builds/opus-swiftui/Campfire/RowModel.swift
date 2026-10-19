import CampfireKit
import Foundation

/// A boost as the row draws it.
struct BoostItem: Hashable, Identifiable {
    let id: Int
    let boosterID: UserID
    let content: String
}

/// Everything one message row needs to draw itself. Value type so unchanged rows are skipped on update.
struct RowItem: Hashable, Identifiable {
    let id: MessageID
    let creatorID: UserID
    let authorName: String
    let createdAt: Date
    let blocks: [Block]
    let attachment: Attachment?
    let boosts: [BoostItem]
    let isThreaded: Bool
    let isFirstOfDay: Bool
    let isMine: Bool
    let mentionsMe: Bool
    let isEmojiOnly: Bool

    init(message m: Message, presentation p: MessagePresentation, authorName: String, extraBoosts: [BoostItem] = []) {
        id = m.id
        creatorID = m.creatorID
        self.authorName = authorName
        createdAt = m.createdAt
        blocks = m.blocks
        attachment = m.attachment
        boosts = m.boosts.map { BoostItem(id: $0.id, boosterID: $0.boosterID, content: $0.content) } + extraBoosts
        isThreaded = p.isThreaded
        isFirstOfDay = p.isFirstOfDay
        isMine = p.isMine
        mentionsMe = p.mentionsMe
        isEmojiOnly = m.isEmojiOnly
    }

    init(id: MessageID, creatorID: UserID, authorName: String, createdAt: Date, blocks: [Block],
         attachment: Attachment? = nil, boosts: [BoostItem] = [], isThreaded: Bool = false,
         isFirstOfDay: Bool = false, isMine: Bool = false, mentionsMe: Bool = false, isEmojiOnly: Bool = false) {
        self.id = id
        self.creatorID = creatorID
        self.authorName = authorName
        self.createdAt = createdAt
        self.blocks = blocks
        self.attachment = attachment
        self.boosts = boosts
        self.isThreaded = isThreaded
        self.isFirstOfDay = isFirstOfDay
        self.isMine = isMine
        self.mentionsMe = mentionsMe
        self.isEmojiOnly = isEmojiOnly
    }

    /// Text a Copy puts on the pasteboard.
    var copyText: String {
        var out = ""
        for b in blocks {
            switch b {
            case .text(let t): out += t
            case .mention: out += "@"
            case .code(_, let s): out += (out.isEmpty ? "" : "\n") + s
            }
        }
        if case .file(let name, _)? = attachment { out += name }
        return out
    }
}

/// Names for ids (authors, mentions, boosters).
struct People: Equatable {
    var names: [UserID: String]
    func name(_ id: UserID) -> String { names[id] ?? "Someone" }
    func firstName(_ id: UserID) -> String { String(name(id).split(separator: " ").first ?? "") }
    func initial(_ id: UserID) -> String { String(name(id).prefix(1)).uppercased() }
}

enum Format {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "h:mm a"
        return f
    }()

    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    static func fileSize(_ bytes: Int) -> String {
        // Rails number_to_human_size: 1024 based, three significant digits.
        let units = ["Bytes", "KB", "MB", "GB"]
        var v = Double(bytes), i = 0
        while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
        if i == 0 { return "\(bytes) Bytes" }
        let digits = v >= 100 ? 0 : v >= 10 ? 1 : 2
        var s = String(format: "%.\(digits)f", v)
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        return "\(s) \(units[i])"
    }
}
