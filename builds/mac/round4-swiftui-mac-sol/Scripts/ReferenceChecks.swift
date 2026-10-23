import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import CampfireKit

@main struct ReferenceChecks {
    struct Reference {
        let name: String
        let message: Message
        let presentation: MessagePresentation
        let expected: CGFloat
    }
    @MainActor static func main() {
        let names = ["Fernando", "Ana", "Ben", "Cleo", "Dan", "Eve", "Frank"]
        let users = Dictionary(uniqueKeysWithValues: names.enumerated().map { index, name in
            (index + 1, User(id: index + 1, name: name, avatar: RGB(r: 0, g: 0, b: 0)))
        })
        var references: [Reference] = []
        func row(_ name: String, by: Int, text: String = "", blocks: [Block]? = nil, attachment: Attachment? = nil,
                 boosts: [Boost] = [], day: Bool = false, threaded: Bool = false, expected: CGFloat) {
            let times = ["day-separator": "09:00", "threaded": "09:02", "long-text": "09:10", "mine": "09:12", "mention": "09:20", "image-boosts": "10:00", "code": "10:01", "file": "10:05", "emoji-only": "10:10", "long-boosts": "10:14"]
            let dayNumber = references.count < 5 ? "15" : "16"
            let date = ISO8601DateFormatter().date(from: "2026-10-\(dayNumber)T\(times[name]!):00Z")!
            let m = Message(id: references.count + 1, creatorID: by, createdAt: date,
                            blocks: blocks ?? (text.isEmpty ? [] : [.text(text)]), attachment: attachment, boosts: boosts, clientMessageID: name)
            let p = MessagePresentation(isThreaded: threaded, isFirstOfDay: day, isMine: by == 1, mentionsMe: m.mentionedUserIDs.contains(1))
            references.append(Reference(name: name, message: m, presentation: p, expected: expected))
        }
        row("day-separator", by: 2, text: "Morning everyone, kicking off the week.", day: true, expected: 137.48)
        row("threaded", by: 2, text: "First thing: the new designs are in the shared folder.", threaded: true, expected: 91.06)
        row("long-text", by: 3, text: "Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.", expected: 225.41)
        row("mine", by: 1, text: "Sounds good, let's do it after lunch.", expected: 68.67)
        row("mention", by: 4, blocks: [.mention(1), .text(" can you review the PR before then?")], expected: 91.06)
        row("image-boosts", by: 5, attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 200)),
            boosts: [Boost(id: 1, boosterID: 2, content: "👍"), Boost(id: 2, boosterID: 3, content: "🔥"), Boost(id: 3, boosterID: 4, content: "❤️")], day: true, expected: 359.41)
        row("code", by: 5, blocks: [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")], threaded: true, expected: 127.59)
        row("file", by: 6, attachment: .file(name: "Quarterly-report.pdf", bytes: 245000), expected: 80.19)
        row("emoji-only", by: 7, text: "🎉🔥", expected: 98.45)
        row("long-boosts", by: 6, text: "One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.",
            boosts: [Boost(id: 4, boosterID: 1, content: "Agreed!")], expected: 190.88)
        var failures = 0
        for dark in [false, true] {
            for ref in references {
                let view = MessageRow(message: ref.message, presentation: ref.presentation, users: users,
                                      theme: RoomTheme(dark: dark), scale: 1, availableWidth: 393)
                    .frame(width: 393).background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                let image = renderer.cgImage!
                let height = CGFloat(image.height) / 3
                let delta = abs(height - ref.expected)
                let okay = delta <= 2
                if !okay { failures += 1 }
                print("\(okay ? "PASS" : "FAIL") \(ref.name) \(dark ? "dark" : "light") height \(height) fixture \(ref.expected) delta \(delta)")
                let path = "runs/reference-\(ref.name)\(dark ? "-dark" : "").png"
                let url = URL(fileURLWithPath: path)
                let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(dest, image, nil)
                CGImageDestinationFinalize(dest)
            }
        }
        for dark in [false, true] {
            let theme = RoomTheme(dark: dark)
            let content = VStack(spacing: 0) {
                WelcomeCard(theme: theme)
                ForEach(Array(references.prefix(3).enumerated()), id: \.offset) { _, ref in
                    MessageRow(message: ref.message, presentation: ref.presentation, users: users,
                               theme: theme, scale: 1, availableWidth: 393)
                        .padding(.top, ref.presentation.spacingBefore)
                }
            }
            let room = VStack(spacing: 0) {
                RoomHeader(name: "General", theme: theme).zIndex(2)
                content.fixedSize(horizontal: false, vertical: true).frame(height: 702, alignment: .top)
                RoomComposer(theme: theme).zIndex(2)
            }
            .frame(width: 393, height: 852).background(theme.background).clipped()
            .environment(\.colorScheme, dark ? .dark : .light)
            let renderer = ImageRenderer(content: room)
            renderer.scale = 3
            let image = renderer.cgImage!
            let path = "runs/reference-room-top\(dark ? "-dark" : "").png"
            let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
        precondition(failures == 0, "\(failures) reference rows exceed the layout tolerance")
    }
}
