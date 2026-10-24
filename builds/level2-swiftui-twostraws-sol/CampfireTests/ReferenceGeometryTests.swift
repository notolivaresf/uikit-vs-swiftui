import SwiftUI
import Testing
@testable import CampfireKit
@testable import Campfire

@MainActor struct ReferenceGeometryTests {
    @Test func referenceBubbleMeasurements() throws {
        let names = [1: "Fernando", 2: "Ana", 3: "Ben", 4: "Cleo", 5: "Dan", 6: "Eve", 7: "Frank"]
        let users = Dictionary(uniqueKeysWithValues: names.map {
            ($0.key, User(id: $0.key, name: $0.value, avatar: RGB(r: 0, g: 0, b: 0)))
        })
        let date = Date(timeIntervalSince1970: 1_792_054_800)
        let references: [(String, Int, [Block], CampfireKit.Attachment?, [Boost], Double, Double)] = [
            ("day-separator", 2, [.text("Morning everyone, kicking off the week.")], nil, [], 318.83, 65.48),
            ("threaded", 2, [.text("First thing: the new designs are in the shared folder.")], nil, [], 338.2, 87.88),
            ("long-text", 3, [.text("Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")], nil, [], 338.2, 222.22),
            ("mine", 1, [.text("Sounds good, let's do it after lunch.")], nil, [], 287.97, 65.48),
            ("mention", 4, [.mention(1), .text(" can you review the PR before then?")], nil, [], 338.2, 87.88),
            ("image-boosts", 5, [], .image(width: 600, height: 400, color: RGB(r: 70, g: 130, b: 180)),
             [Boost(id: 1, boosterID: 2, content: "👍"), Boost(id: 2, boosterID: 3, content: "🔥"), Boost(id: 3, boosterID: 4, content: "❤️")], 300, 283.73),
            ("code", 5, [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")], nil, [], 242.8, 124.41),
            ("file", 6, [], .file(name: "Quarterly-report.pdf", bytes: 245_000), [], 283.11, 77),
            ("emoji-only", 7, [.text("🎉🔥")], nil, [], 168.53, 96.86),
            ("long-boosts", 6, [.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")], nil,
             [Boost(id: 4, boosterID: 1, content: "Agreed!")], 338.2, 187.69)
        ]
        for (name, author, blocks, attachment, boosts, width, height) in references {
            let message = Message(id: 2, creatorID: author, createdAt: date, blocks: blocks, attachment: attachment,
                                  boosts: boosts, clientMessageID: "fixture")
            let previous = Message(id: 1, creatorID: ["threaded", "code"].contains(name) ? author : 50,
                                   createdAt: date.addingTimeInterval(-60), blocks: [], attachment: nil, boosts: [], clientMessageID: "previous")
            let item = MessageItem(message: message, previous: previous, users: users, currentUserID: 1)
            for scheme in [ColorScheme.light, .dark] {
                let renderer = ImageRenderer(content: MessageBubble(item: item)
                    .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large))
                renderer.proposedSize = ProposedViewSize(width: author == 1 ? 288.3 : 338.2, height: nil)
                renderer.scale = 3
                let image = try #require(renderer.cgImage)
                let actualWidth = Double(image.width) / 3, actualHeight = Double(image.height) / 3
                print("REFERENCE \(name) \(scheme): \(actualWidth) x \(actualHeight), expected \(width) x \(height)")
                #expect(abs(actualWidth - width) <= 2, "\(name) width")
                #expect(abs(actualHeight - height) <= 2, "\(name) height")
            }
        }
    }
}
