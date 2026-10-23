import XCTest
@testable import CampfireKit
@testable import Campfire

@MainActor
final class RowHeightIndexTests: XCTestCase {
    func testMixedEditsPreservePositions() {
        var seed: UInt64 = 987654321
        func random(_ limit: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1
            return Int(seed >> 32) % limit
        }
        var index = RowHeightIndex()
        var reference: [CGFloat] = []
        for _ in 0..<5_000 {
            let values = (0..<random(9)).map { _ in CGFloat(random(1000) + 1) / 3 }
            switch random(6) {
            case 0: index.append(values); reference.append(contentsOf: values)
            case 1: index.prepend(values); reference.insert(contentsOf: values, at: 0)
            case 2:
                let count = random(reference.count + 1)
                index.removeFirst(count); reference.removeFirst(count)
            case 3:
                let count = random(reference.count + 1)
                index.removeLast(count); reference.removeLast(count)
            case 4 where !reference.isEmpty:
                let position = random(reference.count), value = CGFloat(random(1000) + 1) / 3
                index.setHeight(value, at: position); reference[position] = value
            default: index.reset(values); reference = values
            }
            XCTAssertEqual(index.count, reference.count)
            XCTAssertEqual(index.total, reference.reduce(0, +), accuracy: 0.001)
            if !reference.isEmpty {
                let position = random(reference.count)
                let offset = reference.prefix(position).reduce(0, +)
                XCTAssertEqual(index.offset(at: position), offset, accuracy: 0.001)
                XCTAssertEqual(index.firstRow(endingAfter: offset + reference[position] / 2), position)
            }
        }
    }

    func testLongSlidingWindowAndOlderPages() {
        var index = RowHeightIndex()
        var reference = Array(repeating: CGFloat(80), count: 5_000)
        index.reset(reference)
        for step in 0..<12_000 {
            let height = CGFloat(40 + step % 200)
            index.append([height]); reference.append(height)
            index.removeFirst(1); reference.removeFirst()
            if step % 100 == 0 {
                XCTAssertEqual(index.total, reference.reduce(0, +), accuracy: 0.001)
                XCTAssertEqual(index.offset(at: 2_500), reference.prefix(2_500).reduce(0, +), accuracy: 0.001)
            }
        }
        for _ in 0..<125 {
            let page = Array(repeating: CGFloat(91.2), count: 40)
            index.prepend(page); reference.insert(contentsOf: page, at: 0)
        }
        XCTAssertEqual(index.count, 10_000)
        XCTAssertEqual(index.total, reference.reduce(0, +), accuracy: 0.001)
        XCTAssertEqual(index.offset(at: 7_500), reference.prefix(7_500).reduce(0, +), accuracy: 0.001)
    }
}

@MainActor
final class MessageLayoutTests: XCTestCase {
    func testShowcaseGeometryAndWrappedBoosts() {
        let data = FakeData.generate(size: .k1)
        let users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        let page = Array(Windowing.lastPage(data.messages))
        var sawImage = false, sawCode = false, sawFile = false, sawWrapping = false
        for (index, m) in page.enumerated() {
            let row = MessageLayout(message: m, previous: data.messages[m.id - 2],
                                    next: index + 1 < page.count ? page[index + 1] : nil,
                                    users: users, width: 393, scale: 1)
            XCTAssertEqual(row.bubble.minX, row.presentation.isMine ? 393 - 40.8 - row.bubble.width : 40.8, accuracy: 0.01)
            XCTAssertLessThanOrEqual(row.bubble.maxX, 379.01)
            XCTAssertGreaterThan(row.height, 0)
            XCTAssertEqual(row.presentation.isThreaded, Grouping.presentation(of: m, after: data.messages[m.id - 2], currentUserID: 1).isThreaded)
            for frame in row.boostFrames {
                XCTAssertGreaterThanOrEqual(frame.minX, 10.5)
                XCTAssertLessThanOrEqual(frame.maxX, row.bubble.width - 10.5 + 0.1)
                XCTAssertLessThanOrEqual(frame.maxY, row.bubble.height)
            }
            if case .image(let width, let height, _)? = m.attachment {
                sawImage = true
                XCTAssertEqual(row.bubble.width, 300, accuracy: 0.1)
                XCTAssertEqual(row.image.width / row.image.height, CGFloat(width) / CGFloat(height), accuracy: 0.001)
            }
            if row.pieces.contains(where: \.code) { sawCode = true }
            if row.fileName != nil { sawFile = true }
            if Set(row.boostFrames.map(\.minY)).count > 1 { sawWrapping = true }
            let larger = MessageLayout(message: m, previous: data.messages[m.id - 2], next: nil,
                                       users: users, width: 393, scale: 1.5)
            XCTAssertGreaterThanOrEqual(larger.pieces.reduce(0) { $0 + $1.frame.height }, row.pieces.reduce(0) { $0 + $1.frame.height })
            for piece in larger.pieces where !piece.code {
                let textView = SelectableMessageText()
                textView.attributedText = piece.text
                let actual = textView.sizeThatFits(CGSize(width: piece.frame.width, height: .greatestFiniteMagnitude))
                XCTAssertLessThanOrEqual(actual.height, piece.frame.height + 2, "Text should not clip: \(m.id)")
            }
        }
        XCTAssertTrue(sawImage && sawCode && sawFile && sawWrapping)
    }
    func testThemeColorsMatchFixture() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        XCTAssertEqual(Theme.bubble.resolvedColor(with: light), UIColor(hex: 0xF3F2EE))
        XCTAssertEqual(Theme.bubble.resolvedColor(with: dark), UIColor(hex: 0x222222))
        XCTAssertEqual(Theme.avatar(1), UIColor(hex: 0xBF7C2A))
        XCTAssertEqual(Theme.avatar(2), UIColor(hex: 0x698F9C))
    }
}

// These test-only rows reproduce the reference conversation. Production reads only FakeData.
@MainActor
final class ReferenceRowTests: XCTestCase {
    func testReferenceRowsWithinTwoPoints() {
        let people = [(1,"Fernando"),(2,"Ana"),(3,"Ben"),(4,"Cleo"),(5,"Dan"),(6,"Eve"),(7,"Frank")]
        let users = Dictionary(uniqueKeysWithValues: people.map { id, name in
            (id, User(id: id, name: name, avatar: RGB(r: 0, g: 0, b: 0)))
        })
        let base = ISO8601DateFormatter().date(from: "2026-10-15T09:00:00Z")!
        func message(_ id: Int, _ creator: Int, _ seconds: Double, _ blocks: [Block], attachment: Attachment? = nil,
                     boosts: [Boost] = []) -> Message {
            Message(id: id, creatorID: creator, createdAt: base.addingTimeInterval(seconds), blocks: blocks,
                    attachment: attachment, boosts: boosts, clientMessageID: "reference-\(id)")
        }
        let first = message(1, 2, 0, [.text("Morning everyone, kicking off the week.")])
        let threaded = message(2, 2, 120, [.text("First thing: the new designs are in the shared folder.")])
        let long = message(3, 3, 600, [.text("Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")])
        let mine = message(4, 1, 720, [.text("Sounds good, let's do it after lunch.")])
        let mention = message(5, 4, 1200, [.mention(1), .text(" can you review the PR before then?")])
        let image = message(6, 5, 90000, [], attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 200)),
                            boosts: [Boost(id: 1, boosterID: 2, content: "👍"),Boost(id: 2, boosterID: 3, content: "🔥"),Boost(id: 3, boosterID: 4, content: "❤️")])
        let code = message(7, 5, 90060, [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")])
        let file = message(8, 6, 90300, [], attachment: .file(name: "Quarterly-report.pdf", bytes: 245000))
        let emoji = message(9, 7, 90600, [.text("🎉🔥")])
        let boosts = message(10, 6, 90840, [.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")], boosts: [Boost(id: 4, boosterID: 1, content: "Agreed!")])
        let cases: [(String, Message, Message?, CGRect)] = [
            ("day-separator",first,nil,CGRect(x: 40.8,y: 70.4,width: 318.83,height: 65.48)),
            ("threaded",threaded,first,CGRect(x: 40.8,y: 1.59,width: 338.2,height: 87.88)),
            ("long-text",long,threaded,CGRect(x: 40.8,y: 1.59,width: 338.2,height: 222.22)),
            ("mine",mine,long,CGRect(x: 64.23,y: 1.59,width: 287.97,height: 65.48)),
            ("mention",mention,mine,CGRect(x: 40.8,y: 1.59,width: 338.2,height: 87.88)),
            ("image-boosts",image,mention,CGRect(x: 40.8,y: 70.41,width: 300,height: 283.73)),
            ("code",code,image,CGRect(x: 40.8,y: 1.59,width: 242.8,height: 124.41)),
            ("file",file,code,CGRect(x: 40.8,y: 1.59,width: 283.11,height: 77)),
            ("emoji-only",emoji,file,CGRect(x: 40.8,y: 1.59,width: 168.53,height: 96.86)),
            ("long-boosts",boosts,emoji,CGRect(x: 40.8,y: 1.59,width: 338.2,height: 187.69))]
        for (name, m, prev, expected) in cases {
            let row = MessageLayout(message: m, previous: prev, next: nil, users: users, width: 393, scale: 1)
            print("REFERENCE \(name): \(row.bubble) natural \(row.pieces.map { $0.text.size() })")
            XCTAssertEqual(row.bubble.minX, expected.minX, accuracy: 2, name + " x")
            XCTAssertEqual(row.bubble.minY, expected.minY, accuracy: 2, name + " y")
            XCTAssertEqual(row.bubble.width, expected.width, accuracy: 2, name + " width")
            XCTAssertEqual(row.bubble.height, expected.height, accuracy: 2, name + " height")
            for dark in [false, true] {
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 393, height: row.messageHeight)
                window.overrideUserInterfaceStyle = dark ? .dark : .light
                let controller = UIViewController()
                window.rootViewController = controller
                let cell = MessageCell(frame: window.bounds)
                controller.view.addSubview(cell)
                window.isHidden = false
                cell.backgroundColor = Theme.background
                cell.show(row, users: users)
                window.layoutIfNeeded(); cell.layoutIfNeeded()
                XCTAssertEqual(cell.traitCollection.userInterfaceStyle, dark ? .dark : .light)
                let renderer = UIGraphicsImageRenderer(size: cell.bounds.size)
                var capture: UIImage!
                cell.traitCollection.performAsCurrent {
                    capture = renderer.image { cell.layer.render(in: $0.cgContext) }
                }
                window.isHidden = true
                let attachment = XCTAttachment(image: capture); attachment.name = name + (dark ? "-dark" : "")
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}
