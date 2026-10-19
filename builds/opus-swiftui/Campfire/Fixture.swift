#if DEBUG
import CampfireKit
import Foundation

/// The reference rows from Fixtures/constants.json, typed in by hand, used only to compare this build against
/// the screenshots (`-uvsFixture YES`). Never used by the real room.
enum Fixture {
    static let people = People(names: [1: "Fernando", 2: "Ana", 3: "Ben", 4: "Cleo", 5: "Dan", 6: "Eve", 7: "Frank"])

    static func date(_ day: Int, _ h: Int, _ m: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = day; c.hour = h; c.minute = m
        return Grouping.calendar.date(from: c)!
    }

    static var rows: [RowItem] {
        [
            RowItem(id: 1, creatorID: 2, authorName: "Ana", createdAt: date(15, 9, 0),
                    blocks: [.text("Morning everyone, kicking off the week.")], isFirstOfDay: true),
            RowItem(id: 2, creatorID: 2, authorName: "Ana", createdAt: date(15, 9, 2),
                    blocks: [.text("First thing: the new designs are in the shared folder.")], isThreaded: true),
            RowItem(id: 3, creatorID: 3, authorName: "Ben", createdAt: date(15, 9, 10),
                    blocks: [.text("Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")]),
            RowItem(id: 4, creatorID: 1, authorName: "Fernando", createdAt: date(15, 9, 12),
                    blocks: [.text("Sounds good, let's do it after lunch.")], isMine: true),
            RowItem(id: 5, creatorID: 4, authorName: "Cleo", createdAt: date(15, 9, 20),
                    blocks: [.mention(1), .text(" can you review the PR before then?")], mentionsMe: true),
            RowItem(id: 6, creatorID: 5, authorName: "Dan", createdAt: date(16, 10, 0), blocks: [],
                    attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 200)),
                    boosts: [BoostItem(id: 1, boosterID: 2, content: "👍"), BoostItem(id: 2, boosterID: 3, content: "🔥"),
                             BoostItem(id: 3, boosterID: 4, content: "❤️")], isFirstOfDay: true),
            RowItem(id: 7, creatorID: 5, authorName: "Dan", createdAt: date(16, 10, 1),
                    blocks: [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")], isThreaded: true),
            RowItem(id: 8, creatorID: 6, authorName: "Eve", createdAt: date(16, 10, 5), blocks: [],
                    attachment: .file(name: "Quarterly-report.pdf", bytes: 250_880)),
            RowItem(id: 9, creatorID: 7, authorName: "Frank", createdAt: date(16, 10, 10), blocks: [.text("🎉🔥")], isEmojiOnly: true),
            RowItem(id: 10, creatorID: 1, authorName: "Fernando", createdAt: date(16, 10, 12),
                    blocks: [.text("Nice work, all of you.")], isMine: true),
            RowItem(id: 11, creatorID: 6, authorName: "Eve", createdAt: date(16, 10, 14),
                    blocks: [.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")],
                    boosts: [BoostItem(id: 4, boosterID: 1, content: "Agreed!")]),
        ]
    }
}
#endif
