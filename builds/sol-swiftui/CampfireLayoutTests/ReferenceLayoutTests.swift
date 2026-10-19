import XCTest
import SwiftUI
@testable import Campfire
@testable import CampfireKit

final class ReferenceLayoutTests: XCTestCase {
    @MainActor func testReferenceRowHeightsInBothAppearances() throws {
        let names = ["Fernando", "Ana", "Ben", "Cleo", "Dan", "Eve", "Frank"]
        let users = Dictionary(uniqueKeysWithValues: names.enumerated().map {
            ($0.offset + 1, User(id: $0.offset + 1, name: $0.element, avatar: RGB(r: 0, g: 0, b: 0)))
        })
        struct Reference {
            let name: String
            let by: Int
            let text: String
            let height: CGFloat
            var day = false
            var threaded = false
            var mine = false
            var mention = false
            var attachment: Attachment?
            var code: String?
            var boosts: [(Int, String)] = []
        }
        let cases: [Reference] = [
            Reference(name: "day-separator", by: 2, text: "Morning everyone, kicking off the week.", height: 137.48, day: true),
            Reference(name: "threaded", by: 2, text: "First thing: the new designs are in the shared folder.", height: 91.06, threaded: true),
            Reference(name: "long-text", by: 3, text: "Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.", height: 225.41),
            Reference(name: "mine", by: 1, text: "Sounds good, let's do it after lunch.", height: 68.67, mine: true),
            Reference(name: "mention", by: 4, text: " can you review the PR before then?", height: 91.06, mention: true),
            Reference(name: "image-boosts", by: 5, text: "", height: 359.41, day: true, attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 200)), boosts: [(2, "👍"), (3, "🔥"), (4, "❤️")]),
            Reference(name: "code", by: 5, text: "", height: 127.59, threaded: true, code: "def greet(name)\n  puts \"Hello, #{name}!\"\nend"),
            Reference(name: "file", by: 6, text: "", height: 80.19, attachment: .file(name: "Quarterly-report.pdf", bytes: 245_000)),
            Reference(name: "emoji-only", by: 7, text: "🎉🔥", height: 98.45),
            Reference(name: "long-boosts", by: 6, text: "One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.", height: 190.88, boosts: [(1, "Agreed!")])
        ]
        let bubbles: [String: (x: CGFloat, width: CGFloat, top: CGFloat)] = [
            "day-separator": (40.8, 318.83, 70.4), "threaded": (40.8, 338.2, 1.59),
            "long-text": (40.8, 338.2, 1.59), "mine": (64.23, 287.97, 1.59),
            "mention": (40.8, 338.2, 1.59), "image-boosts": (40.8, 300, 70.41),
            "code": (40.8, 242.8, 1.59), "file": (40.8, 283.11, 1.59),
            "long-boosts": (40.8, 338.2, 1.59)
        ]
        for scheme in [ColorScheme.light, .dark] {
            for reference in cases {
                let blocks: [Block]
                if let code = reference.code { blocks = [.code(language: "ruby", source: code)] }
                else if reference.mention { blocks = [.mention(1), .text(reference.text)] }
                else { blocks = reference.text.isEmpty ? [] : [.text(reference.text)] }
                let message = Message(id: 1, creatorID: reference.by,
                                      createdAt: Date(timeIntervalSince1970: 1_792_054_800),
                                      blocks: blocks, attachment: reference.attachment,
                                      boosts: reference.boosts.enumerated().map { Boost(id: $0.offset, boosterID: $0.element.0, content: $0.element.1) },
                                      clientMessageID: "reference")
                let row = RoomRow(message: message, presentation: MessagePresentation(isThreaded: reference.threaded,
                    isFirstOfDay: reference.day, isMine: reference.mine, mentionsMe: reference.mention))
                let renderer = ImageRenderer(content: MessageRow(row: row, users: users, extraBoosts: [])
                    .padding(.horizontal, 14.01)
                    .frame(width: 393)
                    .environment(\.dynamicTypeSize, .large)
                    .environment(\.colorScheme, scheme)
                    .background(scheme == .dark ? Color.black : Color.white))
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.cgImage)
                let height = CGFloat(image.height) / 3
                print("Reference \(reference.name) \(scheme): \(height), expected \(reference.height)")
                XCTAssertEqual(height, reference.height, accuracy: 2, "\(reference.name), \(scheme)")
                if let bubble = bubbles[reference.name] {
                    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
                    bytes.withUnsafeMutableBytes { buffer in
                        let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                            bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                        let pixels = buffer.bindMemory(to: UInt8.self)
                        let sample = (Int((bubble.top + 3) * 3) * image.width + 600) * 4
                        let y = Int((bubble.top + 38.5) * 3)
                        let matches = (0..<image.width).filter { x in
                            let p = (y * image.width + x) * 4
                            return (0..<3).allSatisfy { abs(Int(pixels[p + $0]) - Int(pixels[sample + $0])) <= 1 }
                        }
                        if let first = matches.first, let last = matches.last {
                            let x = CGFloat(first) / 3, width = CGFloat(last - first + 1) / 3
                            print("Bubble \(reference.name) \(scheme): x \(x), width \(width)")
                            XCTAssertEqual(x, bubble.x, accuracy: 2, "\(reference.name) bubble x")
                            XCTAssertEqual(width, bubble.width, accuracy: 2, "\(reference.name) bubble width")
                        } else { XCTFail("No bubble pixels for \(reference.name)") }
                    }
                }
                let attachment = XCTAttachment(image: UIImage(cgImage: image))
                attachment.name = "\(reference.name)-\(scheme)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
