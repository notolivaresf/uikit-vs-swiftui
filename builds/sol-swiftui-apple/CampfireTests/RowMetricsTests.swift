import XCTest
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import Campfire
@testable import CampfireKit

@MainActor
final class RowMetricsTests: XCTestCase {
    func testReferenceGeometry() throws {
        let users = [1: User(id: 1, name: "Fernando", avatar: RGB(r: 0,g: 0,b: 0)),
                     2: User(id: 2, name: "Ana", avatar: RGB(r: 0,g: 0,b: 0)),
                     3: User(id: 3, name: "Dan", avatar: RGB(r: 0,g: 0,b: 0)),
                     4: User(id: 4, name: "Eve", avatar: RGB(r: 0,g: 0,b: 0))]
        let time = Date(timeIntervalSince1970: 1792141200)
        func message(_ id: Int, _ by: Int, _ text: String, attachment: Attachment? = nil) -> Message {
            Message(id: id, creatorID: by, createdAt: time.addingTimeInterval(Double(id * 60)),
                    blocks: text.isEmpty ? [] : [.text(text)], attachment: attachment, boosts: [], clientMessageID: "m\(id)")
        }
        let previous = message(1, 2, "Previous")
        let fixtures: [(String, Message, Double)] = [
            ("long-text", message(11, 4, "Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you."), 225.41),
            ("mention", Message(id: 8, creatorID: 3, createdAt: time.addingTimeInterval(400), blocks: [.mention(1), .text(" can you review the PR before then?")], attachment: nil, boosts: [], clientMessageID: "m8"), 91.06),
            ("image-boosts", Message(id: 9, creatorID: 3, createdAt: time.addingTimeInterval(86400), blocks: [], attachment: .image(width: 600, height: 400, color: RGB(r: 60, g: 122, b: 196)), boosts: [Boost(id: 2, boosterID: 2, content: "👍"), Boost(id: 3, boosterID: 3, content: "🔥"), Boost(id: 4, boosterID: 4, content: "❤️")], clientMessageID: "m9"), 359.41),
            ("day-separator", Message(id: 10, creatorID: 2, createdAt: time.addingTimeInterval(86400), blocks: [.text("Morning everyone, kicking off the week.")], attachment: nil, boosts: [], clientMessageID: "m10"), 137.48),
            ("threaded", message(2, 2, "First thing: the new designs are in the shared folder."), 91.06),
            ("mine", message(3, 1, "Sounds good, let's do it after lunch."), 68.67),
            ("file", message(4, 4, "", attachment: .file(name: "Quarterly-report.pdf", bytes: 245000)), 80.19),
            ("emoji", message(5, 3, "🎉🔥"), 98.45),
            ("code", Message(id: 6, creatorID: 2, createdAt: time.addingTimeInterval(120), blocks: [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")], attachment: nil, boosts: [], clientMessageID: "m6"), 127.59),
            ("long-boosts", Message(id: 7, creatorID: 4, createdAt: time.addingTimeInterval(300), blocks: [.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")], attachment: nil, boosts: [Boost(id: 1, boosterID: 1, content: "Agreed!")], clientMessageID: "m7"), 190.88)
        ]
        for dark in [false, true] {
        for (name, message, expected) in fixtures {
            let row = ChatRow(message: message, previous: previous, users: users)
            let renderer = ImageRenderer(content: MessageRow(row: row, users: users)
                .frame(width: 393).background(dark ? .black : .white).environment(\.dynamicTypeSize, .large).environment(\.colorScheme, dark ? .dark : .light))
            renderer.scale = 3
            let cgImage = try XCTUnwrap(renderer.cgImage)
            let url = URL(fileURLWithPath: "/tmp/campfire-row-\(name)\(dark ? "-dark" : "").png")
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, cgImage, nil)
            CGImageDestinationFinalize(destination)
            print("ROW METRIC", name, Double(cgImage.height) / 3, "expected", expected)
            XCTAssertEqual(Double(cgImage.height) / 3, expected, accuracy: 2, name)
            if name != "emoji" {
                let span = try bubbleSpan(cgImage, dark: dark)
                let expectedX = name == "mine" ? 64.23 : 40.8
                let expectedWidth: Double = switch name {
                case "mine": 287.97
                case "file": 283.11
                case "code": 242.8
                case "image-boosts": 300
                case "day-separator": 318.83
                default: 338.2
                }
                print("ROW SPAN", name, span)
                XCTAssertEqual(span.lowerBound, expectedX, accuracy: 2, name)
                XCTAssertEqual(span.upperBound - span.lowerBound, expectedWidth, accuracy: 2, name)
            }
        }
        }
    }

    private func bubbleSpan(_ image: CGImage, dark: Bool) throws -> ClosedRange<Double> {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let scan = height - 60
        let background: UInt8 = dark ? 0 : 255
        let columns = (0..<width).filter { x in
            let offset = (scan * width + x) * 4
            return abs(Int(bytes[offset]) - Int(background)) > 5
                || abs(Int(bytes[offset + 1]) - Int(background)) > 5
                || abs(Int(bytes[offset + 2]) - Int(background)) > 5
        }
        return Double(try XCTUnwrap(columns.first)) / 3 ... Double(try XCTUnwrap(columns.last) + 1) / 3
    }
}
