import Foundation

/// How a message is presented relative to the one before it. Both builds must use this, not their own rule
/// (Campfire: same author and at most 5 minutes apart is "threaded"; a new calendar day shows a day separator).
public struct MessagePresentation: Equatable, Sendable {
    /// Hide avatar and name; show only the body.
    public let isThreaded: Bool
    public let isFirstOfDay: Bool
    public let isMine: Bool
    public let mentionsMe: Bool
}

public enum Grouping {
    public static let threadWindow: TimeInterval = 5 * 60

    /// Days are cut in UTC so the same data reads the same on every machine.
    public static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    public static func presentation(of message: Message, after previous: Message?, currentUserID: UserID) -> MessagePresentation {
        let threaded: Bool
        let firstOfDay: Bool
        if let p = previous {
            threaded = p.creatorID == message.creatorID
                && abs(message.createdAt.timeIntervalSince(p.createdAt)) <= threadWindow
            firstOfDay = !calendar.isDate(p.createdAt, inSameDayAs: message.createdAt)
        } else {
            threaded = false
            firstOfDay = true
        }
        return MessagePresentation(isThreaded: threaded && !firstOfDay, isFirstOfDay: firstOfDay,
                                   isMine: message.creatorID == currentUserID,
                                   mentionsMe: message.mentionedUserIDs.contains(currentUserID))
    }

    /// Presentation for a whole slice. `previous` is the message just before the slice, if any
    /// (needed when older messages are prepended: re-run for the first old-slice item's successor).
    public static func presentations(of messages: [Message], previous: Message? = nil, currentUserID: UserID) -> [MessagePresentation] {
        var prev = previous
        return messages.map { m in
            defer { prev = m }
            return presentation(of: m, after: prev, currentUserID: currentUserID)
        }
    }
}

public enum Windowing {
    /// Campfire loads 40 messages per page and keeps at most 300 in memory (trims 20+ over).
    public static let pageSize = 40
    public static let maxLoaded = 300

    /// The newest page, a page before an id, a page around an id.
    public static func lastPage(_ all: [Message], size: Int = pageSize) -> ArraySlice<Message> { all.suffix(size) }

    public static func page(before id: MessageID, in all: [Message], size: Int = pageSize) -> ArraySlice<Message> {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return [] }
        return all[max(0, i - size)..<i]
    }

    public static func page(after id: MessageID, in all: [Message], size: Int = pageSize) -> ArraySlice<Message> {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return [] }
        return all[(i + 1)..<min(all.count, i + 1 + size)]
    }

    public static func around(_ id: MessageID, in all: [Message], size: Int = pageSize) -> ArraySlice<Message> {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return [] }
        return all[max(0, i - size)..<min(all.count, i + size + 1)]
    }
}
