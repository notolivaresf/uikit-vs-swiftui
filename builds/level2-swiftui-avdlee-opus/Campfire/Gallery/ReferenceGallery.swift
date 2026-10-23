import SwiftUI
import CampfireKit

/// Development aid: renders the ten reference rows from Fixtures/constants.json (hard-coded here, nothing is
/// read from disk) so they can be compared pixel for pixel with Campfire's screenshots.
/// Launch with `-uvsGallery <row name>`, `-uvsGallery room-top` or `-uvsGallery room-bottom`.
struct ReferenceGallery: View {
    let name: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette.of(colorScheme)
        Group {
            if name.hasPrefix("room") {
                GalleryRoom(fromTop: name == "room-top")
            } else {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 100)
                    if let row = Self.rows.first(where: { $0.0 == name })?.1 {
                        MessageRow(row: row)
                    }
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
            }
        }
        .background(palette.background)
        .environment(\.palette, palette)
    }

    static func row(_ id: Int, _ author: UserID, _ name: String, _ time: String, day: String? = nil,
                    threaded: Bool = false, mentionsMe: Bool = false, emoji: Bool = false,
                    _ parts: [RowData.Part] = [], attachment: Attachment? = nil,
                    boosts: [(UserID, String, String)] = []) -> RowData {
        RowData(id: id, authorID: author, authorName: name, authorInitial: String(name.prefix(1)), time: time,
                day: day, isThreaded: threaded, isMine: author == 1, mentionsMe: mentionsMe, isEmojiOnly: emoji,
                parts: parts, attachment: attachment,
                boosts: boosts.enumerated().map { .init(id: $0.offset, boosterID: $0.element.0,
                                                        initial: $0.element.1, content: $0.element.2) })
    }

    static let rows: [(String, RowData)] = [
        ("row-day-separator", row(1, 2, "Ana", "9:00 AM", day: "OCTOBER 15, 2026",
                                  [.text("Morning everyone, kicking off the week.")])),
        ("row-threaded", row(2, 2, "Ana", "9:02 AM", threaded: true,
                             [.text("First thing: the new designs are in the shared folder.")])),
        ("row-long-text", row(3, 3, "Ben", "9:10 AM", [.text(
            "Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")])),
        ("row-mine", row(4, 1, "Fernando", "9:12 AM", [.text("Sounds good, let's do it after lunch.")])),
        ("row-mention", row(5, 4, "Cleo", "9:20 AM", mentionsMe: true,
                            [.mention(1, name: "Fernando"), .text(" can you review the PR before then?")])),
        ("row-image-boosts", row(6, 5, "Dan", "10:00 AM", day: "OCTOBER 16, 2026",
                                 attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 200)),
                                 boosts: [(2, "A", "👍"), (3, "B", "🔥"), (4, "C", "❤️")])),
        ("row-code", row(7, 5, "Dan", "10:01 AM", threaded: true,
                         [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")])),
        ("row-file", row(8, 6, "Eve", "10:05 AM", attachment: .file(name: "Quarterly-report.pdf", bytes: 250_880))),
        ("row-emoji-only", row(9, 7, "Frank", "10:10 AM", emoji: true, [.text("🎉🔥")])),
        ("row-mine-2", row(10, 1, "Fernando", "10:12 AM", [.text("Nice work, all of you.")])),
        ("row-long-boosts", row(11, 6, "Eve", "10:14 AM", [.text(
            "One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")],
                                boosts: [(1, "F", "Agreed!")])),
    ]
}

private struct GalleryRoom: View {
    let fromTop: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        WelcomeCard()
                        ForEach(ReferenceGallery.rows, id: \.1.id) { _, row in
                            MessageRow(row: row)
                                .padding(.top, row.isThreaded ? Metrics.rowGap + Metrics.threadedMarginTop : Metrics.rowGap)
                        }
                    }
                }
                .contentMargins(.top, Metrics.headerHeight, for: .scrollContent)
                .defaultScrollAnchor(fromTop ? .top : .bottom)
                HeaderBar()
            }
            ComposerBar()
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
