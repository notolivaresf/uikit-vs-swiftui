import CampfireKit
import Foundation

// Messages 1...60 (room top, with the welcome card above message 1) and the newest 40 (room bottom and the
// per-row shots), from FakeData.generate(size: .k50) as the builds see them. Every structured field is kept.
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "fixture")
let images = out.appendingPathComponent("images")
try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

let data = FakeData.generate(size: .k50)
let iso = ISO8601DateFormatter()
func rgb(_ c: RGB) -> [String: Int] { ["r": Int(c.r), "g": Int(c.g), "b": Int(c.b)] }

let ranges = [0..<60, (data.messages.count - 40)..<data.messages.count]
var rows: [[String: Any]] = []
for range in ranges {
    let slice = Array(data.messages[range])
    let previous = range.lowerBound > 0 ? data.messages[range.lowerBound - 1] : nil
    let pres = Grouping.presentations(of: slice, previous: previous, currentUserID: data.currentUserID)
    for (m, p) in zip(slice, pres) {
        var row: [String: Any] = [
            "id": m.id, "creator_id": m.creatorID, "created_at": iso.string(from: m.createdAt),
            "emoji_only": m.isEmojiOnly, "threaded": p.isThreaded, "first_of_day": p.isFirstOfDay,
            "mine": p.isMine, "mentions_me": p.mentionsMe,
        ]
        row["blocks"] = m.blocks.map { b -> [String: Any] in
            switch b {
            case .text(let t): return ["type": "text", "text": t]
            case .mention(let id): return ["type": "mention", "user_id": id]
            case .code(let lang, let src): return ["type": "code", "language": lang ?? NSNull(), "source": src]
            }
        }
        switch m.attachment {
        case .image(let w, let h, let c)?:
            let name = "image-\(m.id).png"
            try Placeholder.pngData(width: w, height: h, color: c).write(to: images.appendingPathComponent(name))
            row["attachment"] = ["type": "image", "width": w, "height": h, "color": rgb(c), "file": "images/\(name)"]
        case .file(let name, let bytes)?:
            row["attachment"] = ["type": "file", "name": name, "bytes": bytes]
        case nil: break
        }
        row["boosts"] = m.boosts.map { ["id": $0.id, "booster_id": $0.boosterID, "content": $0.content] }
        rows.append(row)
    }
}
let users = data.users.map { ["id": $0.id, "name": $0.name, "avatar": rgb($0.avatar)] as [String: Any] }
let doc: [String: Any] = ["seed": data.seed, "current_user_id": data.currentUserID, "room": data.room.name,
                          "message_count": data.messages.count, "users": users, "messages": rows]
let json = try JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys])
try json.write(to: out.appendingPathComponent("fixture.json"))
print("\(rows.count) messages, \(users.count) users in \(out.path)")
