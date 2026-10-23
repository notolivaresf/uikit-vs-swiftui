import Foundation
import CampfireKit

/// Everything one message row draws, resolved up front so the row view is a pure function of it.
struct RowData: Identifiable, Equatable, Sendable {
    enum Part: Equatable, Sendable {
        case text(String)
        case mention(UserID, name: String)
        case code(language: String?, source: String)
    }

    struct BoostData: Identifiable, Equatable, Sendable {
        let id: Int
        let boosterID: UserID
        let initial: String
        let content: String
    }

    let id: MessageID
    let authorID: UserID
    let authorName: String
    let authorInitial: String
    let time: String
    /// Day separator text when this is the first message of its UTC day.
    let day: String?
    let isThreaded: Bool
    let isMine: Bool
    let mentionsMe: Bool
    let isEmojiOnly: Bool
    let parts: [Part]
    let attachment: Attachment?
    let boosts: [BoostData]

    var accessibilityLabel: String {
        var parts = [authorName, time]
        let text = plainText
        if !text.isEmpty { parts.append(text) }
        switch attachment {
        case .image?: parts.append("Image")
        case .file(let name, let bytes)?: parts.append("File \(name), \(Formatting.fileSize(bytes))")
        case nil: break
        }
        if !boosts.isEmpty { parts.append("Boosts: " + boosts.map(\.content).joined(separator: " ")) }
        return parts.joined(separator: ", ")
    }

    /// Text copied by the context menu's Copy.
    var plainText: String {
        var out = ""
        for part in parts {
            switch part {
            case .text(let t): out += t
            case .mention(_, let name): out += "@" + name
            case .code(_, let source): out += (out.isEmpty ? "" : "\n") + source
            }
        }
        return out
    }
}

/// Builds rows from CampfireKit messages, using CampfireKit's own grouping rule.
struct RowBuilder {
    let users: [UserID: User]
    let currentUserID: UserID

    init(dataset: Dataset) {
        users = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
        currentUserID = dataset.currentUserID
    }

    func name(_ id: UserID) -> String { users[id]?.name ?? "Someone" }

    static func initial(_ name: String) -> String { name.first.map { String($0).uppercased() } ?? "?" }

    func row(for message: Message, after previous: Message?, extraBoosts: [RowData.BoostData] = []) -> RowData {
        let p = Grouping.presentation(of: message, after: previous, currentUserID: currentUserID)
        let author = name(message.creatorID)
        let parts: [RowData.Part] = message.blocks.map { block in
            switch block {
            case .text(let t): .text(t)
            case .mention(let id): .mention(id, name: name(id))
            case .code(let language, let source): .code(language: language, source: source)
            }
        }
        return RowData(
            id: message.id, authorID: message.creatorID, authorName: author, authorInitial: Self.initial(author),
            time: Formatting.timeString(message.createdAt),
            day: p.isFirstOfDay ? Formatting.dayString(message.createdAt) : nil,
            isThreaded: p.isThreaded, isMine: p.isMine, mentionsMe: p.mentionsMe, isEmojiOnly: message.isEmojiOnly,
            parts: parts, attachment: message.attachment,
            boosts: message.boosts.map { b in
                RowData.BoostData(id: b.id, boosterID: b.boosterID, initial: Self.initial(name(b.boosterID)), content: b.content)
            } + extraBoosts)
    }
}
