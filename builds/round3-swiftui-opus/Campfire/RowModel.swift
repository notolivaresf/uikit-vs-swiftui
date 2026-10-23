import CampfireKit
import Foundation

/// A person as rows draw them: name, initial and palette colour index.
struct Person: Hashable, Sendable {
    let id: Int
    let name: String
    let initial: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
        initial = name.first.map { String($0).uppercased() } ?? "?"
    }
}

struct BoostItem: Identifiable, Equatable, Sendable {
    let id: String
    let booster: Person
    let content: String
}

/// One run of inline content inside a paragraph.
enum InlinePart: Equatable, Sendable {
    case text(String)
    case mention(Person)
}

enum BodyPart: Equatable, Sendable {
    case paragraph([InlinePart])
    case code(language: String?, source: String)
}

enum AttachmentItem: Equatable, Sendable {
    case image(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8)
    case file(name: String, size: String)
}

/// Everything one message row draws, built once from structured CampfireKit fields (never parsed text).
struct RowModel: Identifiable, Equatable, Sendable {
    let id: Int
    let author: Person
    let time: String
    /// "OCTOBER 16, 2026" when this is the first message of its UTC day.
    let daySeparator: String?
    let isThreaded: Bool
    let isMine: Bool
    let mentionsMe: Bool
    let isEmojiOnly: Bool
    let parts: [BodyPart]
    let attachment: AttachmentItem?
    var boosts: [BoostItem]
    /// What Copy puts on the pasteboard.
    let copyText: String
}

/// Turns CampfireKit messages into row models.
struct RowBuilder {
    let people: [Int: Person]
    let currentUserID: Int

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    nonisolated(unsafe) private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    func person(_ id: Int) -> Person { people[id] ?? Person(id: id, name: "User \(id)") }

    func row(for message: Message, after previous: Message?, extraBoosts: [BoostItem]) -> RowModel {
        let p = Grouping.presentation(of: message, after: previous, currentUserID: currentUserID)
        var parts: [BodyPart] = []
        var inline: [InlinePart] = []
        var copy: [String] = []
        var inlineCopy = ""
        func flush() {
            if !inline.isEmpty { parts.append(.paragraph(inline)); copy.append(inlineCopy) }
            inline = []
            inlineCopy = ""
        }
        for block in message.blocks {
            switch block {
            case .text(let t):
                inline.append(.text(t))
                inlineCopy += t
            case .mention(let id):
                let who = person(id)
                inline.append(.mention(who))
                inlineCopy += who.name
            case .code(let language, let source):
                flush()
                parts.append(.code(language: language, source: source))
                copy.append(source)
            }
        }
        flush()

        var attachment: AttachmentItem?
        switch message.attachment {
        case .image(let w, let h, let c):
            attachment = .image(width: w, height: h, red: c.r, green: c.g, blue: c.b)
        case .file(let name, let bytes):
            attachment = .file(name: name, size: Self.byteFormatter.string(fromByteCount: Int64(bytes)))
            copy.append(name)
        case nil:
            break
        }

        let boosts = message.boosts.map { BoostItem(id: "b\($0.id)", booster: person($0.boosterID), content: $0.content) }
            + extraBoosts

        return RowModel(
            id: message.id,
            author: person(message.creatorID),
            time: Self.timeFormatter.string(from: message.createdAt),
            daySeparator: p.isFirstOfDay ? Self.dayFormatter.string(from: message.createdAt).uppercased() : nil,
            isThreaded: p.isThreaded,
            isMine: p.isMine,
            mentionsMe: p.mentionsMe,
            isEmojiOnly: message.isEmojiOnly,
            parts: parts,
            attachment: attachment,
            boosts: boosts,
            copyText: copy.joined(separator: "\n"))
    }
}

extension RowModel {
    /// One spoken summary per row keeps the accessibility tree (and UI automation) small.
    var accessibilityText: String {
        var parts: [String] = []
        if let daySeparator { parts.append(daySeparator) }
        parts.append(isThreaded ? time : "\(author.name), \(time)")
        if !copyText.isEmpty { parts.append(copyText) }
        if case .image = attachment { parts.append("Image") }
        if !boosts.isEmpty { parts.append(boosts.map { "\($0.booster.name) \($0.content)" }.joined(separator: ", ")) }
        return parts.joined(separator: ". ")
    }
}
