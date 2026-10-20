import SwiftUI

/// Development aid: `-uvsReferenceRow <name>` draws one of the ten reference rows from
/// Fixtures/constants.json (typed in by hand) at the top of the screen, for pixel comparison with
/// screenshots/row-<name>.png.
struct ReferenceGallery: View {
    let name: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if name == "room-top" {
            roomTop
        } else {
            singleRow
        }
    }

    /// The top of the room as in screenshots/room-top.png.
    private var roomTop: some View {
        let palette = Palette.forScheme(colorScheme)
        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        WelcomeCard(palette: palette, scale: 1)
                        ForEach(["day-separator", "threaded", "long-text"], id: \.self) { key in
                            let row = Self.rows[key]!
                            Color.clear.frame(height: row.isThreaded ? 0 : Metrics.rowGap)
                            RowContent(row: row, palette: palette, scale: 1)
                        }
                    }
                }
                RoomHeader(palette: palette)
            }
            Composer(palette: palette)
                .padding(.top, Metrics.composerGap)
        }
        .background(palette.background)
    }

    private var singleRow: some View {
        let palette = Palette.forScheme(colorScheme)
        return VStack(spacing: 0) {
            if let row = Self.rows[name] {
                RowContent(row: row, palette: palette, scale: 1)
                    .padding(.top, row.isThreaded ? 1.2 : 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    private static let ana = Person(id: 2, name: "Ana")
    private static let ben = Person(id: 3, name: "Ben")
    private static let cleo = Person(id: 4, name: "Cleo")
    private static let dan = Person(id: 5, name: "Dan")
    private static let eve = Person(id: 6, name: "Eve")
    private static let frank = Person(id: 7, name: "Frank")
    private static let me = Person(id: 1, name: "Fernando")

    private static func row(_ id: Int, _ author: Person, _ time: String, day: String? = nil, threaded: Bool = false,
                            mine: Bool = false, mention: Bool = false, emoji: Bool = false, parts: [BodyPart] = [],
                            attachment: AttachmentItem? = nil, boosts: [(Person, String)] = []) -> RowModel {
        RowModel(id: id, author: author, time: time, daySeparator: day, isThreaded: threaded, isMine: mine,
                 mentionsMe: mention, isEmojiOnly: emoji, parts: parts, attachment: attachment,
                 boosts: boosts.enumerated().map { BoostItem(id: "r\($0.offset)", booster: $0.element.0, content: $0.element.1) },
                 copyText: "")
    }

    private static func text(_ s: String) -> [BodyPart] { [.paragraph([.text(s)])] }

    static let rows: [String: RowModel] = [
        "day-separator": row(1, ana, "9:00 AM", day: "OCTOBER 15, 2026", parts: text("Morning everyone, kicking off the week.")),
        "threaded": row(2, ana, "9:02 AM", threaded: true, parts: text("First thing: the new designs are in the shared folder.")),
        "long-text": row(3, ben, "9:10 AM", parts: text(
            "Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")),
        "mine": row(4, me, "9:12 AM", mine: true, parts: text("Sounds good, let's do it after lunch.")),
        "mention": row(5, cleo, "9:20 AM", mention: true, parts: [.paragraph([.mention(me), .text(" can you review the PR before then?")])]),
        "image-boosts": row(6, dan, "10:00 AM", day: "OCTOBER 16, 2026",
                            attachment: .image(width: 600, height: 400, red: 0x3C, green: 0x78, blue: 0xC8),
                            boosts: [(ana, "👍"), (ben, "🔥"), (cleo, "❤️")]),
        "code": row(7, dan, "10:01 AM", threaded: true,
                    parts: [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")]),
        "file": row(8, eve, "10:05 AM", attachment: .file(name: "Quarterly-report.pdf", size: "245 KB")),
        "emoji-only": row(9, frank, "10:10 AM", emoji: true, parts: text("🎉🔥")),
        "long-boosts": row(10, eve, "10:14 AM", parts: text(
            "One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight."),
                           boosts: [(me, "Agreed!")]),
    ]
}
