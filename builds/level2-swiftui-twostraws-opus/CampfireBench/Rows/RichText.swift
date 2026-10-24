import CampfireKit
import SwiftUI

/// A run of text and mention blocks turned into one `Text`, plus the plain string it shows (one U+FFFC per
/// inline image), which text selection maps character indices back into.
struct RichParagraph {
    let text: Text
    let plain: String
}

@MainActor
enum RichText {
    static let attachmentCharacter = "\u{FFFC}"

    static func paragraph(_ blocks: [Block], users: UserDirectory, metrics: Metrics,
                          displayScale: CGFloat) -> RichParagraph {
        var text = Text(verbatim: "")
        var plain = ""
        for block in blocks {
            switch block {
            case .text(let string):
                text = Text("\(text)\(Text(verbatim: string))")
                plain += string
            case .mention(let id):
                let name = users.name(id)
                let size = metrics.mentionAvatarSize
                let avatar = Text(MentionAvatars.image(userID: id, name: name, size: size, displayScale: displayScale))
                    .baselineOffset(-3.2 * metrics.scale)
                let label = Text(verbatim: " " + name).font(.system(size: metrics.bodySize, weight: .semibold))
                text = Text("\(text)\(avatar)\(label)")
                plain += attachmentCharacter + " " + name
            case .code:
                break
            }
        }
        return RichParagraph(text: text.font(.system(size: metrics.bodySize)), plain: plain)
    }

    /// Splits blocks into paragraphs (consecutive text and mentions) and code blocks.
    static func sections(of blocks: [Block]) -> [BodySection] {
        var sections: [BodySection] = []
        var run: [Block] = []
        func flush() {
            if !run.isEmpty { sections.append(.paragraph(run)); run = [] }
        }
        for block in blocks {
            switch block {
            case .text, .mention: run.append(block)
            case .code(let language, let source):
                flush()
                sections.append(.code(language: language, source: source))
            }
        }
        flush()
        return sections
    }
}

enum BodySection {
    case paragraph([Block])
    case code(language: String?, source: String)
}
