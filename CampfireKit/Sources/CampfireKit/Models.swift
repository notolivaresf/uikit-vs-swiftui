import Foundation

public typealias UserID = Int
public typealias MessageID = Int

public struct User: Hashable, Sendable, Identifiable {
    public let id: UserID
    public let name: String
    /// Avatar background colour, red/green/blue 0...255 (the apps draw initials on it).
    public let avatar: RGB
}

public struct RGB: Hashable, Sendable {
    public let r: UInt8, g: UInt8, b: UInt8
    public init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }
}

public struct Room: Hashable, Sendable {
    public let name: String
    public let messageCount: Int
}

public struct Boost: Hashable, Sendable, Identifiable {
    public let id: Int
    public let boosterID: UserID
    /// Up to 16 characters, usually one emoji.
    public let content: String
}

/// One block of message content. Messages are plain structured data, not HTML.
public enum Block: Hashable, Sendable {
    case text(String)
    /// Inline mention of a person, shown as a pill with the person's name.
    case mention(UserID)
    case code(language: String?, source: String)
}

public enum Attachment: Hashable, Sendable {
    /// Solid-colour placeholder image. Both builds draw exactly this colour at this pixel size.
    case image(width: Int, height: Int, color: RGB)
    case file(name: String, bytes: Int)
}

public struct Message: Hashable, Sendable, Identifiable {
    public let id: MessageID
    public let creatorID: UserID
    public let createdAt: Date
    public let blocks: [Block]
    public let attachment: Attachment?
    public var boosts: [Boost]
    /// Set on messages the current user wrote on this device and have not been confirmed yet.
    public let clientMessageID: String

    public var mentionedUserIDs: [UserID] {
        blocks.compactMap { if case .mention(let id) = $0 { id } else { nil } }
    }

    /// Plain text used for sizing, search and the emoji-only check.
    public var plainText: String {
        var out = ""
        for block in blocks {
            switch block {
            case .text(let t): out += t
            case .mention: out += "@"
            case .code(_, let s): out += s
            }
        }
        return out
    }

    /// Emoji-only messages show their text large and without a bubble (Campfire `message--emoji`).
    public var isEmojiOnly: Bool {
        guard attachment == nil, case .text(let t)? = blocks.first, blocks.count == 1 else { return false }
        let trimmed = t.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.allSatisfy { $0.unicodeScalars.contains { $0.properties.isEmojiPresentation } }
    }
}

/// One chat room: the only room in the comparison.
public struct Dataset: Sendable {
    public let seed: UInt64
    public let currentUserID: UserID
    public let users: [User]
    public let room: Room
    /// Oldest first. Ids are increasing, creation times never decrease.
    public let messages: [Message]

    public func user(_ id: UserID) -> User? { users.first { $0.id == id } }
}
