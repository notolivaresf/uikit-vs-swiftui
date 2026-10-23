// Standalone visual-test app, compiled with the original package sources in one module so its
// internal memberwise initializers can build reference fixtures. Never linked into Campfire.app.
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

@main
struct ReferenceProbe: App {
    var body: some Scene {
        WindowGroup {
            Text("Rendering reference rows…").task { capture() }
        }
    }

    @MainActor private func capture() {
        let people = [1: "Fernando", 2: "Ana", 3: "Ben", 4: "Cleo", 5: "Dan", 6: "Eve", 7: "Frank"]
            .mapValues { name in name }
        let users = Dictionary(uniqueKeysWithValues: people.map { id, name in
            (id, User(id: id, name: name, avatar: RGB(r: 0, g: 0, b: 0)))
        })
        func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            Grouping.calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        func message(_ id: Int, _ creator: Int, _ date: Date, _ blocks: [Block],
                     attachment: Attachment? = nil, boosts: [(Int, String)] = []) -> Message {
            Message(id: id, creatorID: creator, createdAt: date, blocks: blocks, attachment: attachment,
                    boosts: boosts.enumerated().map { Boost(id: id * 100 + $0.offset, boosterID: $0.element.0, content: $0.element.1) }, clientMessageID: "reference-\(id)")
        }
        let messages = [
            message(1, 2, date(15, 9, 0), [.text("Morning everyone, kicking off the week.")]),
            message(2, 2, date(15, 9, 2), [.text("First thing: the new designs are in the shared folder.")]),
            message(3, 3, date(15, 9, 10), [.text("Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")]),
            message(4, 1, date(15, 9, 12), [.text("Sounds good, let's do it after lunch.")]),
            message(5, 4, date(15, 9, 20), [.mention(1), .text(" can you review the PR before then?")]),
            message(6, 5, date(16, 10, 0), [], attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 195)), boosts: [(2, "👍"), (3, "🔥"), (4, "❤️")]),
            message(7, 5, date(16, 10, 1), [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")]),
            message(8, 6, date(16, 10, 5), [], attachment: .file(name: "Quarterly-report.pdf", bytes: 245000)),
            message(9, 7, date(16, 10, 10), [.text("🎉🔥")]),
            message(10, 1, date(16, 10, 12), [.text("Nice work, all of you.")]),
            message(11, 6, date(16, 10, 14), [.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")], boosts: [(1, "Agreed!")])
        ]
        let presentations = Grouping.presentations(of: messages, currentUserID: 1)
        let rows = zip(messages, presentations).map { RoomRow(message: $0, presentation: $1) }
        let names = ["day-separator", "threaded", "long-text", "mine", "mention", "image-boosts", "code", "file", "emoji-only", "mine-extra", "long-boosts"]
        let directory = URL.documentsDirectory.appending(path: "ReferenceRenders", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var heights: [String: Double] = [:]
        for dark in [false, true] {
            let colors = RoomColors(dark ? .dark : .light)
            for (row, name) in zip(rows, names) {
                let view = MessageRow(row: row, users: users, width: 393)
                    .frame(width: 393)
                    .foregroundStyle(colors.text)
                    .background(colors.background)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.dynamicTypeSize, .large)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                guard let image = renderer.cgImage else { fatalError("Could not render \(name)") }
                let filename = "row-\(name)\(dark ? "-dark" : "").png"
                let target = directory.appending(path: filename)
                let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
                heights[filename] = Double(image.height) / 3
            }
        }
        for dark in [false, true] {
            for bottom in [false, true] {
                let colors = RoomColors(dark ? .dark : .light)
                let content = ReferenceRoom(rows: rows, users: users, bottom: bottom)
                    .foregroundStyle(colors.text).background(colors.background)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.dynamicTypeSize, .large)
                let renderer = ImageRenderer(content: content); renderer.scale = 3
                guard let image = renderer.cgImage else { fatalError("Could not render room") }
                let filename = "room-\(bottom ? "bottom" : "top")\(dark ? "-dark" : "").png"
                let destination = CGImageDestinationCreateWithURL(directory.appending(path: filename) as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, image, nil); CGImageDestinationFinalize(destination)
            }
        }
        let data = try! JSONSerialization.data(withJSONObject: heights, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: directory.appending(path: "heights.json"))
    }
}

private struct ReferenceRoom: View {
    let rows: [RoomRow]
    let users: [Int: User]
    let bottom: Bool
    var body: some View {
        VStack(spacing: 0) {
            RoomHeader(name: "General")
                .background(alignment: .leading) {
                    if bottom { Color(rgb: RGB(r: 60, g: 120, b: 195)).frame(width: 300).offset(x: 40.8) }
                }
                .zIndex(1)
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    WelcomeCard()
                    ForEach(rows) { row in
                        MessageRow(row: row, users: users, width: 393)
                            .padding(.top, row.id == 1 ? 0 : row.presentation.isThreaded ? -1.2 : CampfireStyle.rowGap)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 393, height: geometry.size.height, alignment: bottom ? .bottom : .top)
                .clipped()
            }
            RoomComposer().zIndex(1)
        }
        .frame(width: 393, height: 852)
    }
}
