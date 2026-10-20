import XCTest
import UIKit
@testable import CampfireKit
@testable import Campfire

/// The ten hand-measured rows supplied with the task, kept in the test target only.
/// Production messages always come from FakeData and FakeLiveFeed.
final class ReferenceRowsTests: XCTestCase {
    @MainActor func testReferenceGeometryAndRenderBothAppearances() {
        let names = ["Fernando", "Ana", "Ben", "Cleo", "Dan", "Eve", "Frank"]
        let people = names.enumerated().map { User(id: $0.offset+1, name: $0.element, avatar: RGB(r: 0,g: 0,b: 0)) }
        let users = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let date = ISO8601DateFormatter().date(from: "2026-10-15T09:00:00Z")!
        func message(_ id: Int, _ by: Int, _ minutes: Double, _ blocks: [Block], attachment: Attachment? = nil, boosts: [Boost] = []) -> Message {
            Message(id: id, creatorID: by, createdAt: date.addingTimeInterval(minutes*60), blocks: blocks, attachment: attachment, boosts: boosts, clientMessageID: "test-\(id)")
        }
        let rows: [(String, Message, Double, Double, Double)] = [
            ("day-separator", message(1,2,0,[.text("Morning everyone, kicking off the week.")]),318.83,65.48,137.48),
            ("threaded", message(2,2,2,[.text("First thing: the new designs are in the shared folder.")]),338.2,87.88,91.06),
            ("long-text", message(3,3,10,[.text("Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")]),338.2,222.22,225.41),
            ("mine", message(4,1,12,[.text("Sounds good, let's do it after lunch.")]),287.97,65.48,68.67),
            ("mention", message(5,4,20,[.mention(1),.text(" can you review the PR before then?")]),338.2,87.88,91.06),
            ("image-boosts", message(6,5,1500,[],attachment: .image(width: 600,height: 400,color: RGB(r: 59,g: 120,b: 196)), boosts: [Boost(id: 1,boosterID: 2,content: "👍"),Boost(id: 2,boosterID: 3,content: "🔥"),Boost(id: 3,boosterID: 4,content: "❤️")]),300,283.73,359.41),
            ("code", message(7,5,1501,[.code(language: "ruby",source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")]),242.8,124.41,127.59),
            ("file", message(8,6,1505,[],attachment: .file(name: "Quarterly-report.pdf",bytes: 250880)),283.11,77,80.19),
            ("emoji-only", message(9,7,1510,[.text("🎉🔥")]),168.53,96.86,98.45),
            ("long-boosts", message(10,6,1514,[.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")], boosts: [Boost(id: 4,boosterID: 1,content: "Agreed!")]),338.2,187.69,190.88)
        ]
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
            window.overrideUserInterfaceStyle = appearance
            let host = UIViewController(); window.rootViewController = host
            window.makeKeyAndVisible(); host.view.layoutIfNeeded()
            var previous: Message?
            for (name, message, width, height, rowHeight) in rows {
                let metric = MessageMetrics.make(message: message, previous: previous, users: users, width: 393, category: .large, boosts: message.boosts.map(DisplayBoost.init))
                print("REFERENCE \(name) actual \(metric.bubble.width) x \(metric.bubble.height) row \(metric.height)")
                XCTAssertEqual(metric.bubble.width, width, accuracy: 2, name)
                XCTAssertEqual(metric.bubble.height, height, accuracy: 2, name)
                XCTAssertEqual(metric.height, rowHeight, accuracy: 2, name)
                if name == "mention", case .text(let text) = metric.parts[0].content {
                    let storage = NSTextStorage(attributedString: text)
                    let layout = NSLayoutManager()
                    let container = NSTextContainer(size: CGSize(width: metric.parts[0].frame.width, height: 1000))
                    container.lineFragmentPadding = 0; layout.addTextContainer(container); storage.addLayoutManager(layout)
                    layout.ensureLayout(for: container)
                    var glyphs = NSRange()
                    _ = layout.lineFragmentUsedRect(forGlyphAt: 0, effectiveRange: &glyphs)
                    let chars = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
                    let firstLine = (text.string as NSString).substring(with: chars).trimmingCharacters(in: .whitespacesAndNewlines)
                    XCTAssertTrue(firstLine.hasSuffix("PR"), "Mention should wrap before 'before then?': \(firstLine)")
                }
                let cell = MessageCell(frame: CGRect(x: 0, y: 0, width: 393, height: metric.height))
                cell.overrideUserInterfaceStyle = appearance
                cell.backgroundColor = Style.background
                host.view.addSubview(cell)
                cell.configure(metric, users: users); cell.layoutIfNeeded()
                for subview in cell.contentView.subviews { subview.layoutIfNeeded(); for child in subview.subviews { child.layoutIfNeeded() } }
                let image = UIGraphicsImageRenderer(size: cell.bounds.size).image { ctx in cell.layer.render(in: ctx.cgContext) }
                var pixel = [UInt8](repeating: 0, count: 4)
                pixel.withUnsafeMutableBytes { buffer in
                    let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(image.cgImage!.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1))!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
                XCTAssertEqual(pixel[0], appearance == .dark ? 0 : 255, "Reference background must follow appearance")
                let attachment = XCTAttachment(image: image)
                attachment.name = name + (appearance == .dark ? "-dark" : "")
                attachment.lifetime = .keepAlways; add(attachment)
                cell.removeFromSuperview()
                previous = message
            }
            let data = Dataset(seed: 0, currentUserID: 1, users: people, room: Room(name: "General", messageCount: rows.count), messages: rows.map { $0.1 })
            let room = RoomViewController(dataset: data)
            window.rootViewController = room; window.makeKeyAndVisible()
            room.view.frame = window.bounds; room.view.setNeedsLayout(); room.view.layoutIfNeeded()
            for atTop in [true, false] {
                room.collection.contentOffset.y = atTop ? 0 : room.bottomOffset
                room.collection.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(size: room.view.bounds.size).image { context in room.view.layer.render(in: context.cgContext) }
                let attachment = XCTAttachment(image: image)
                attachment.name = (atTop ? "room-top" : "room-bottom") + (appearance == .dark ? "-dark" : "")
                attachment.lifetime = .keepAlways; add(attachment)
            }
            window.isHidden = true
        }
    }
}
