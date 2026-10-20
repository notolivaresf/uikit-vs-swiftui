import Foundation
import CampfireKit

// Objective-C-facing copies of the CampfireKit value types. Every class is immutable and built from the
// Swift value in one go, so wrapping cost is paid once per object, when a page is requested.

@objc public enum CFKBlockKind: Int, Sendable {
    case text = 0, mention, code
}

@objc public enum CFKAttachmentKind: Int, Sendable {
    case image = 0, file
}

@objc public enum CFKFeedEventKind: Int, Sendable {
    case message = 0, boost, typingStarted, typingStopped
}

@objc public final class CFKUser: NSObject, @unchecked Sendable {
    @objc public let userID: Int
    @objc public let name: String
    /// Avatar background colour, 0...255 per channel.
    @objc public let red: Int
    @objc public let green: Int
    @objc public let blue: Int

    init(_ u: User) {
        userID = u.id; name = u.name
        red = Int(u.avatar.r); green = Int(u.avatar.g); blue = Int(u.avatar.b)
    }
}

@objc public final class CFKBoost: NSObject, @unchecked Sendable {
    @objc public let boostID: Int
    @objc public let boosterID: Int
    @objc public let content: String

    init(_ b: Boost) { boostID = b.id; boosterID = b.boosterID; content = b.content }
}

@objc public final class CFKBlock: NSObject, @unchecked Sendable {
    @objc public let kind: CFKBlockKind
    /// Text of a `.text` block; source of a `.code` block; nil for a mention.
    @objc public let text: String?
    /// User id of a `.mention` block; 0 otherwise.
    @objc public let mentionedUserID: Int
    /// Language of a `.code` block; nil otherwise or when none.
    @objc public let language: String?

    init(_ b: Block) {
        switch b {
        case .text(let t): kind = .text; text = t; mentionedUserID = 0; language = nil
        case .mention(let id): kind = .mention; text = nil; mentionedUserID = id; language = nil
        case .code(let lang, let source): kind = .code; text = source; mentionedUserID = 0; language = lang
        }
    }
}

@objc public final class CFKAttachment: NSObject, @unchecked Sendable {
    @objc public let kind: CFKAttachmentKind
    /// Image: pixel size and colour (0...255). Zero for files.
    @objc public let width: Int
    @objc public let height: Int
    @objc public let red: Int
    @objc public let green: Int
    @objc public let blue: Int
    /// File: name and size in bytes. nil / 0 for images.
    @objc public let name: String?
    @objc public let bytes: Int

    init(_ a: Attachment) {
        switch a {
        case .image(let w, let h, let c):
            kind = .image; width = w; height = h; red = Int(c.r); green = Int(c.g); blue = Int(c.b)
            name = nil; bytes = 0
        case .file(let n, let b):
            kind = .file; width = 0; height = 0; red = 0; green = 0; blue = 0; name = n; bytes = b
        }
    }

    /// PNG bytes of an image attachment's solid-colour placeholder; nil for files.
    @objc public var placeholderPNGData: Data? {
        kind == .image ? CFKPlaceholder.pngData(width: width, height: height, red: red, green: green, blue: blue) : nil
    }
}

@objc public final class CFKMessage: NSObject, @unchecked Sendable {
    @objc public let messageID: Int
    @objc public let creatorID: Int
    @objc public let createdAt: Date
    @objc public let blocks: [CFKBlock]
    @objc public let attachment: CFKAttachment?
    @objc public let boosts: [CFKBoost]
    @objc public let clientMessageID: String
    /// User ids mentioned in the blocks, as NSNumber, in order.
    @objc public let mentionedUserIDs: [NSNumber]
    @objc public let plainText: String
    @objc public let isEmojiOnly: Bool
    /// The Swift value this object was made from (not visible to Objective-C).
    let swift: Message

    init(_ m: Message) {
        swift = m
        messageID = m.id; creatorID = m.creatorID; createdAt = m.createdAt
        blocks = m.blocks.map(CFKBlock.init)
        attachment = m.attachment.map(CFKAttachment.init)
        boosts = m.boosts.map(CFKBoost.init)
        clientMessageID = m.clientMessageID
        mentionedUserIDs = m.mentionedUserIDs.map { NSNumber(value: $0) }
        plainText = m.plainText
        isEmojiOnly = m.isEmojiOnly
    }
}

@objc public final class CFKPresentation: NSObject, @unchecked Sendable {
    @objc public let isThreaded: Bool
    @objc public let isFirstOfDay: Bool
    @objc public let isMine: Bool
    @objc public let mentionsMe: Bool

    init(_ p: MessagePresentation) {
        isThreaded = p.isThreaded; isFirstOfDay = p.isFirstOfDay; isMine = p.isMine; mentionsMe = p.mentionsMe
    }
}

/// A page of messages with the presentation of each (same index), computed against the message before the page.
@objc public final class CFKPage: NSObject, @unchecked Sendable {
    @objc public let messages: [CFKMessage]
    @objc public let presentations: [CFKPresentation]

    init(messages: [CFKMessage], presentations: [CFKPresentation]) {
        self.messages = messages; self.presentations = presentations
    }
}

@objc public final class CFKFeedEvent: NSObject, @unchecked Sendable {
    @objc public let kind: CFKFeedEventKind
    /// kind == .message
    @objc public let message: CFKMessage?
    /// kind == .boost: the message boosted; boost is the new boost.
    @objc public let messageID: Int
    @objc public let boost: CFKBoost?
    /// kind == .typingStarted / .typingStopped
    @objc public let userID: Int

    init(_ e: FeedEvent) {
        switch e {
        case .message(let m): kind = .message; message = CFKMessage(m); messageID = m.id; boost = nil; userID = 0
        case .boost(let id, let b): kind = .boost; message = nil; messageID = id; boost = CFKBoost(b); userID = 0
        case .typingStarted(let u): kind = .typingStarted; message = nil; messageID = 0; boost = nil; userID = u
        case .typingStopped(let u): kind = .typingStopped; message = nil; messageID = 0; boost = nil; userID = u
        }
    }
}
