import CampfireKit
import Observation
import SwiftUI

@MainActor @Observable
final class MessageItem: Identifiable {
    let id: MessageID
    var message: Message
    let presentation: MessagePresentation
    let author: User
    let users: [UserID: User]
    let prose: String
    let proseText: Text
    let copyText: String

    init(message: Message, previous: Message?, users: [UserID: User], currentUserID: UserID) {
        self.id = message.id
        self.message = message
        self.presentation = Grouping.presentation(of: message, after: previous, currentUserID: currentUserID)
        self.users = users
        // The package guarantees that every creator is in its user list.
        guard let author = users[message.creatorID] else { preconditionFailure("Missing message author") }
        self.author = author
        var prose = ""
        var text = Text("")
        var copy = ""
        for block in message.blocks {
            switch block {
            case .text(let value):
                prose += value; copy += value
                text = Text("\(text)\(Text(value))")
            case .mention(let id):
                guard let user = users[id] else { continue }
                let renderer = ImageRenderer(content: AvatarView(user: user, size: 17.6))
                renderer.scale = 3
                if let image = renderer.cgImage {
                    let avatar = Text(Image(decorative: image, scale: 3)).baselineOffset(2.5)
                    text = Text("\(text)\(avatar) ")
                    prose += "\u{FFFC} "
                }
                let name = Text(user.name).fontWeight(.semibold)
                text = Text("\(text)\(name)")
                prose += user.name
                copy += user.name
            case .code(_, let source):
                if !copy.isEmpty { copy += "\n" }
                copy += source
            }
        }
        if case .file(let name, _) = message.attachment {
            if !copy.isEmpty { copy += "\n" }
            copy += name
        }
        self.prose = prose
        self.proseText = text
        self.copyText = copy
    }
}
