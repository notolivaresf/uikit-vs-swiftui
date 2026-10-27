import UIKit
import CampfireKit

struct BodyPart {
    enum Kind { case text, code, image(RGB), file(String, Int) }
    let kind: Kind
    var frame: CGRect
    let text: NSAttributedString?
}
struct BoostGeometry {
    let boost: Boost?
    let frame: CGRect
    let name: String
}
struct MessageGeometry {
    let id: Int
    let presentation: MessagePresentation
    let height: CGFloat
    let bubble: CGRect
    let avatar: CGRect
    let header: NSAttributedString
    let headerFrame: CGRect
    let day: String?
    let dayFrame: CGRect
    let parts: [BodyPart]
    let boosts: [BoostGeometry]
    let plainText: String
    let emojiOnly: Bool
}

/// The same TextKit 1 settings are used here and in each selectable message view.
final class MessageMeasurer {
    private let storage = NSTextStorage()
    private let manager = NSLayoutManager()
    private let container = NSTextContainer(size: .zero)
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "h:mm a"; return f
    }()
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "MMMM d, yyyy"; return f
    }()
    private var times: [Int: String] = [:]
    private var mentionAvatars: [Int: NSTextAttachment] = [:]
    private(set) var cache: [Int: MessageGeometry] = [:]
    var width: CGFloat = 393
    var scale: CGFloat = 1
    var users: [Int: User] = [:]
    init() {
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
    }
    func clear() { cache.removeAll(keepingCapacity: true); mentionAvatars.removeAll(keepingCapacity: true) }
    func discard(_ id: Int) { cache.removeValue(forKey: id) }
    func retain(_ ids: Set<Int>) { cache = cache.filter { ids.contains($0.key) } }
    private func measure(_ text: NSAttributedString, width: CGFloat) -> CGSize {
        container.size = CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
        storage.setAttributedString(text)
        manager.ensureLayout(for: container)
        let r = manager.usedRect(for: container)
        return CGSize(width: ceil(r.width), height: ceil(r.height * 3) / 3)
    }
    private func bodyText(_ blocks: [Block], emoji: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let size: CGFloat = emoji ? 38.4 : 16
        let attributes: [NSAttributedString.Key: Any] = [.font: Style.font(size, scale: scale), .foregroundColor: Style.text, .paragraphStyle: Style.paragraph(emoji ? 53.76 : 22.4, scale: scale)]
        for block in blocks {
            switch block {
            case .text(let string): result.append(NSAttributedString(string: string, attributes: attributes))
            case .mention(let id):
                let attachment: NSTextAttachment
                if let saved = mentionAvatars[id] { attachment = saved }
                else {
                    let size = CGSize(width: 18*scale, height: 18*scale)
                    let image = UIGraphicsImageRenderer(size: size).image { _ in
                        Style.avatar(id).setFill()
                        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                        let initial = String((users[id]?.name ?? "?").prefix(1)) as NSString
                        let a: [NSAttributedString.Key: Any] = [.font: Style.font(10.4, .bold, scale: scale), .foregroundColor: UIColor.white]
                        let s = initial.size(withAttributes: a)
                        initial.draw(at: CGPoint(x: (size.width-s.width)/2, y: (size.height-s.height)/2), withAttributes: a)
                    }
                    attachment = NSTextAttachment()
                    attachment.image = image
                    attachment.bounds = CGRect(x: 0, y: -3*scale, width: 18*scale, height: 18*scale)
                    mentionAvatars[id] = attachment
                }
                result.append(NSAttributedString(attachment: attachment))
                var a = attributes
                a[.font] = Style.font(16, .bold, scale: scale)
                result.append(NSAttributedString(string: " " + (users[id]?.name ?? "User \(id)"), attributes: a))
            case .code: break
            }
        }
        return result
    }
    private func codeText(_ source: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: 12.8 * scale, weight: .regular)
        let out = NSMutableAttributedString(string: source, attributes: [.font: font, .foregroundColor: Style.text, .paragraphStyle: Style.paragraph(17.92, scale: scale)])
        // Syntax spans are presentation only. Content and block boundaries come from CampfireKit.
        let ns = source as NSString
        for word in ["def", "end", "let", "SELECT", "FROM", "ORDER", "BY", "DESC", "LIMIT"] {
            let range = ns.range(of: word)
            if range.location != NSNotFound { out.addAttribute(.foregroundColor, value: Style.adaptive(0xD73A49, 0xFF7B72), range: range) }
        }
        let greet = ns.range(of: "greet")
        if greet.location != NSNotFound { out.addAttribute(.foregroundColor, value: Style.adaptive(0x6F42C1, 0xD2A8FF), range: greet) }
        if let start = source.firstIndex(of: "\""), let end = source.lastIndex(of: "\""), start < end {
            out.addAttribute(.foregroundColor, value: Style.adaptive(0x032F62, 0x79C0FF), range: NSRange(start...end, in: source))
        }
        return out
    }
    func geometry(_ message: Message, previous: Message?) -> MessageGeometry {
        if let saved = cache[message.id] { return saved }
        let presentation = Grouping.presentation(of: message, after: previous, currentUserID: 1)
        let rowMaxWidth = max(100, width - (presentation.isMine ? 105.03 : 54.8))
        let maxWidth: CGFloat
        if case .image? = message.attachment { maxWidth = min(300, rowMaxWidth) } else { maxWidth = rowMaxWidth }
        let padding: CGFloat = 15.12
        let dayHeight: CGFloat = presentation.isFirstOfDay ? 68.81 * scale : 0
        let top = dayHeight + 1.59
        let headerFont = Style.font(12.8, scale: scale)
        let minute = Int(message.createdAt.timeIntervalSince1970 / 60)
        let timestamp: String
        if let saved = times[minute] { timestamp = saved } else {
            timestamp = timeFormatter.string(from: message.createdAt)
            if times.count > 512 { times.removeAll(keepingCapacity: true) }
            times[minute] = timestamp
        }
        let name = presentation.isThreaded ? "" : (users[message.creatorID]?.name ?? "")
        let header = NSMutableAttributedString()
        let regular: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: Style.text.withAlphaComponent(0.5)]
        let bold: [NSAttributedString.Key: Any] = [.font: Style.font(12.8, .bold, scale: scale), .foregroundColor: Style.text]
        if presentation.isMine {
            header.append(NSAttributedString(string: "•••   \(timestamp)", attributes: regular))
            if !name.isEmpty { header.append(NSAttributedString(string: " \(name)", attributes: bold)) }
        } else {
            if !name.isEmpty { header.append(NSAttributedString(string: name + " ", attributes: bold)) }
            header.append(NSAttributedString(string: "\(timestamp)   •••", attributes: regular))
        }
        #if CHEAP_HEADER
        // Spike arm: the header is one line, so its size comes from the string itself, not a layout manager pass.
        let headerLine = header.size()
        let headerSize = CGSize(width: ceil(min(headerLine.width, maxWidth - padding*2)), height: ceil(headerLine.height * 3) / 3)
        #else
        let headerSize = measure(header, width: maxWidth - padding*2)
        #endif
        var bodyParts: [BodyPart] = []
        let headerHeight = max(19.2 * scale, headerSize.height)
        let headerExtra = headerHeight - 19.2 * scale
        var localY = 33.08 * scale + headerExtra
        var contentWidth = headerSize.width
        let text = bodyText(message.blocks, emoji: message.isEmojiOnly)
        if text.length > 0 {
            let size = measure(text, width: maxWidth - padding*2)
            contentWidth = max(contentWidth, size.width)
            bodyParts.append(BodyPart(kind: .text, frame: CGRect(x: padding, y: localY, width: size.width, height: size.height), text: text))
            localY += size.height
        }
        for block in message.blocks {
            if case .code(_, let source) = block {
                if !bodyParts.isEmpty { localY += 8 * scale }
                let attributed = codeText(source)
                let size = measure(attributed, width: maxWidth - 2*padding - 25.6*scale)
                let boxWidth = min(maxWidth - 2*padding, size.width + 25.6*scale)
                bodyParts.append(BodyPart(kind: .code, frame: CGRect(x: padding, y: localY, width: boxWidth, height: size.height + 25.6*scale), text: attributed))
                contentWidth = max(contentWidth, boxWidth)
                localY += size.height + 25.6*scale
            }
        }
        var bubbleWidth = min(maxWidth, max(contentWidth + padding*2, 80))
        var imageMessage = false
        if let attachment = message.attachment {
            switch attachment {
            case .image(let w, let h, let color):
                imageMessage = true
                bubbleWidth = min(300, maxWidth)
                localY = bodyParts.isEmpty ? 44 * scale + headerExtra : localY + 10.56
                let imageHeight = (bubbleWidth - 2) * CGFloat(h)/CGFloat(w)
                bodyParts.append(BodyPart(kind: .image(color), frame: CGRect(x: 1, y: localY, width: bubbleWidth - 2, height: imageHeight), text: nil))
                localY += imageHeight
            case .file(let filename, let bytes):
                let size = measure(NSAttributedString(string: filename, attributes: [.font: Style.font(16, scale: scale)]), width: maxWidth - 110)
                bubbleWidth = min(maxWidth, max(headerSize.width + padding*2, size.width + 110))
                bodyParts.append(BodyPart(kind: .file(filename, bytes), frame: CGRect(x: padding, y: localY, width: bubbleWidth - padding*2, height: 33.36*scale), text: nil))
                localY += 33.36 * scale
            }
        }
        var boostFrames: [BoostGeometry] = []
        if !message.boosts.isEmpty {
            localY += 4
            var x = padding
            var y = localY
            let available = maxWidth - padding*2
            for boost in message.boosts {
                let emojiSize = (boost.content as NSString).size(withAttributes: [.font: Style.font(17.6, scale: scale)])
                let pillWidth = 29 + ceil(emojiSize.width) + 6
                if x > padding && x + pillWidth > padding + available { x = padding; y += 32.64 * scale }
                boostFrames.append(BoostGeometry(boost: boost, frame: CGRect(x: x, y: y, width: pillWidth, height: 28.64 * scale), name: users[boost.boosterID]?.name ?? "?"))
                x += pillWidth + 5
                bubbleWidth = max(bubbleWidth, min(maxWidth, x + padding - 5))
            }
            let addWidth = 28.64 * scale
            if x + addWidth > maxWidth - padding { x = padding; y += 32.64 * scale }
            boostFrames.append(BoostGeometry(boost: nil, frame: CGRect(x: x, y: y, width: addWidth, height: addWidth), name: "Add boost"))
            bubbleWidth = min(maxWidth, max(bubbleWidth, x + addWidth + padding))
            localY = y + addWidth
        }
        let bubbleHeight = localY + (imageMessage ? 8.42 : 10.56 * scale)
        let bubbleX = presentation.isMine ? width - 40.8 - bubbleWidth : 40.8
        let bubble = CGRect(x: bubbleX, y: top, width: bubbleWidth, height: bubbleHeight)
        let avatar = CGRect(x: presentation.isMine ? width - 49.27 : 14.01, y: top, width: 35.27, height: 35.27)
        let headerX = presentation.isMine ? bubbleWidth - padding - headerSize.width : padding
        let geometry = MessageGeometry(id: message.id, presentation: presentation,
            height: top + bubbleHeight + 1.6,
            bubble: bubble, avatar: avatar, header: header,
            headerFrame: CGRect(x: headerX, y: 10.56*scale, width: headerSize.width, height: headerHeight),
            day: presentation.isFirstOfDay ? dayFormatter.string(from: message.createdAt).uppercased() : nil,
            dayFrame: CGRect(x: 14.01, y: 17.02*scale, width: width - 28.02, height: 35*scale),
            parts: bodyParts, boosts: boostFrames,
            plainText: message.blocks.map { block in
                switch block { case .text(let t): return t; case .mention(let id): return users[id]?.name ?? ""; case .code(_, let source): return source }
            }.joined(), emojiOnly: message.isEmojiOnly)
        cache[message.id] = geometry
        return geometry
    }
}
