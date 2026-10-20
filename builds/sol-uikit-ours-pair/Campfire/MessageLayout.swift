import UIKit
import CampfireKit

struct RoomBoost: Hashable {
    let id: Int
    let boosterID: Int
    let content: String
    var textSize: CGFloat { content.contains { $0.isLetter || $0.isNumber || $0 == "+" } ? 16 : 17.6 }
}

struct TextPiece {
    let text: NSAttributedString
    var frame: CGRect
    let code: Bool
}

@MainActor
struct MessageLayout {
    let id: Int
    let message: Message
    let presentation: MessagePresentation
    let boosts: [RoomBoost]
    let author: User
    let scale: CGFloat
    var height: CGFloat = 0
    var messageHeight: CGFloat = 0
    var bubble = CGRect.zero
    var avatar = CGRect.zero
    var header = CGRect.zero
    var headerText = NSAttributedString()
    var day = CGRect.zero
    var dayText = ""
    var pieces: [TextPiece] = []
    var image = CGRect.zero
    var imageColor: UIColor?
    var file = CGRect.zero
    var fileName: String?
    var fileSize = ""
    var boostFrames: [CGRect] = []
    var addBoost = CGRect.zero

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "h:mm a"; return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "MMMM d, yyyy"; return f
    }()

    init(message: Message, previous: Message?, next: Message?, users: [Int: User], width: CGFloat, scale: CGFloat, extraBoosts: [RoomBoost] = []) {
        self.id = message.id; self.message = message; self.scale = scale
        boosts = message.boosts.map { RoomBoost(id: $0.id, boosterID: $0.boosterID, content: $0.content) } + extraBoosts
        let p = Grouping.presentation(of: message, after: previous, currentUserID: 1)
        presentation = p
        author = users[message.creatorID]!
        let px: CGFloat = 15.12, py: CGFloat = 10.56
        let metaLine = 19.2 * scale
        let maxWidth = max(100, width - (p.isMine ? 105.03 : 54.8))
        let innerMax = maxWidth - 2 * px
        let dayHeight: CGFloat = p.isFirstOfDay ? 68.8 + max(0, scale - 1) * 18 : 0
        if p.isFirstOfDay {
            day = CGRect(x: 14.01, y: 17.02, width: width - 28.02, height: 34.92 + max(0, scale - 1) * 18)
            dayText = Self.dayFormatter.string(from: message.createdAt).uppercased()
        }
        let time = Self.timeFormatter.string(from: message.createdAt)
        let meta = NSMutableAttributedString(string: "")
        func append(_ value: String, bold: Bool = false, muted: Bool = false) {
            meta.append(Theme.attributed(value, size: 12.8, line: 19.2, scale: scale,
                                         weight: bold ? .bold : .regular, color: muted ? Theme.text.withAlphaComponent(0.5) : nil))
        }
        if p.isMine {
            append("•••   ", bold: true, muted: true); append(time + (p.isThreaded ? "" : " "), muted: true)
            if !p.isThreaded { append(author.name, bold: true) }
        } else {
            if !p.isThreaded { append(author.name + " ", bold: true) }
            append(time, muted: true); append("   •••", bold: true, muted: true)
        }
        headerText = meta
        var contentWidth = min(innerMax, ceil(meta.size().width))
        let metaHeight = max(metaLine, Self.measure(meta, width: innerMax).height)
        var y = py + metaHeight + 2.76 * scale
        let text = NSMutableAttributedString(string: "")
        func flushText() {
            guard text.length > 0 else { return }
            let style = NSMutableParagraphStyle()
            style.minimumLineHeight = (message.isEmojiOnly ? 53.76 : 22.4) * scale
            style.maximumLineHeight = style.minimumLineHeight
            text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
            let bounds = Self.measure(text, width: innerMax + 0.1)
            let line = (message.isEmojiOnly ? 53.76 : 22.4) * scale
            let textHeight = max(line, bounds.height)
            pieces.append(TextPiece(text: NSAttributedString(attributedString: text),
                                    frame: CGRect(x: px, y: y, width: innerMax, height: textHeight), code: false))
            contentWidth = max(contentWidth, min(innerMax, ceil(text.size().width * 3) / 3))
            y += textHeight
            text.setAttributedString(NSAttributedString(string: ""))
        }
        for block in message.blocks {
            switch block {
            case .text(let value):
                text.append(Theme.attributed(value, size: message.isEmojiOnly ? 38.4 : 16,
                                             line: message.isEmojiOnly ? 53.76 : 22.4, scale: scale))
            case .mention(let userID):
                guard let user = users[userID] else { continue }
                let size = 17.6 * scale
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let img = renderer.image { context in
                    Theme.avatar(userID).setFill()
                    context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                    let name = String(user.name.prefix(1)) as NSString
                    let attributes: [NSAttributedString.Key: Any] = [.font: Theme.font(11, weight: .bold, scale: scale), .foregroundColor: UIColor.white]
                    let s = name.size(withAttributes: attributes)
                    name.draw(at: CGPoint(x: (size - s.width) / 2, y: (size - s.height) / 2), withAttributes: attributes)
                }
                let attachment = NSTextAttachment(); attachment.image = img
                attachment.bounds = CGRect(x: 0, y: -3 * scale, width: size, height: size)
                text.append(NSAttributedString(attachment: attachment))
                text.append(Theme.attributed(" " + user.name, size: 16, line: 22.4, scale: scale, weight: .semibold))
            case .code(_, let source):
                flushText()
                if !pieces.isEmpty { y += 8 * scale }
                let code = Self.highlight(source, scale: scale)
                let codeMax = max(40, innerMax - 25.6)
                let measured = Self.measure(code, width: codeMax)
                let codeWidth = min(innerMax, measured.width + 25.6)
                let codeHeight = measured.height + 25.6
                pieces.append(TextPiece(text: code, frame: CGRect(x: px + 1, y: y, width: codeWidth, height: codeHeight), code: true))
                contentWidth = max(contentWidth, codeWidth + 1)
                y += codeHeight
            }
        }
        flushText()
        var bubbleWidth = min(maxWidth, contentWidth + px * 2 + (message.isEmojiOnly ? 15.12 : 0))
        if let attachment = message.attachment {
            switch attachment {
            case .image(let w, let h, let color):
                bubbleWidth = min(300, maxWidth)
                if !pieces.isEmpty { y += 8 }
                y += 12
                let imageWidth = bubbleWidth - 2.4
                image = CGRect(x: 1.2, y: y, width: imageWidth, height: imageWidth * CGFloat(h) / CGFloat(w))
                imageColor = UIColor(rgb: color)
                y += image.height
            case .file(let name, let bytes):
                fileName = name
                fileSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
                let nameWidth = (name as NSString).size(withAttributes: [.font: Theme.font(16, scale: scale)]).width
                bubbleWidth = min(maxWidth, max(contentWidth, nameWidth + 105 * scale) + px * 2)
                file = CGRect(x: px, y: y + 2.4, width: bubbleWidth - px * 2, height: 31.32 * scale)
                y += 34.72 * scale
            }
        }
        if !boosts.isEmpty {
            y += 4
            let boostHeight = 28.64 * max(1, scale * 0.85)
            let boostX: CGFloat = imageColor != nil ? 10.56 : px
            let boostMax = bubbleWidth - 2 * boostX
            var bx = boostX
            for boost in boosts {
                let labelWidth = (boost.content as NSString).size(withAttributes: [.font: Theme.font(boost.textSize, scale: scale)]).width
                let pillWidth = min(boostMax, 29 * max(1, scale * 0.85) + labelWidth + 7)
                if bx > boostX, bx + pillWidth > bubbleWidth - boostX + 0.1 { bx = boostX; y += boostHeight + 5 }
                boostFrames.append(CGRect(x: bx, y: y, width: pillWidth, height: boostHeight))
                bx += pillWidth + 4.8
            }
            if bx + boostHeight > bubbleWidth - boostX { bx = boostX; y += boostHeight + 5 }
            addBoost = CGRect(x: bx, y: y, width: boostHeight, height: boostHeight)
            y += boostHeight
        }
        y += imageColor == nil ? py : py - 2.4
        let x = p.isMine ? width - 40.8 - bubbleWidth : 40.8
        bubble = CGRect(x: x, y: dayHeight + 1.6, width: bubbleWidth, height: y)
        header = CGRect(x: px, y: py, width: bubbleWidth - px * 2, height: metaHeight)
        avatar = CGRect(x: p.isMine ? width - 49.28 : 14.01, y: dayHeight + 1.6, width: 35.27, height: 35.27)
        for i in pieces.indices where !pieces[i].code {
            pieces[i].frame.size.width = bubbleWidth - px * 2 + 0.1
        }
        messageHeight = bubble.maxY + 1.6
        // Campfire removes the regular grid gap between messages in a thread.
        let nextThreaded = next.map { Grouping.presentation(of: $0, after: message, currentUserID: 1).isThreaded } ?? false
        height = messageHeight + (next == nil ? 0 : nextThreaded ? -1.2 : 21.28)
    }

    static func measure(_ text: NSAttributedString, width: CGFloat) -> CGSize {
        let rect = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: min(width, ceil(rect.width * 3) / 3), height: ceil(rect.height * 3) / 3)
    }

    static func highlight(_ source: String, scale: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: Theme.attributed(source, size: 12.8, line: 17.92, scale: scale, mono: true))
        let tokens: [(String, UInt32, UInt32)] = [
            (#"\b(def|end|let|var|func|return|SELECT|FROM|ORDER BY|LIMIT)\b"#, 0xD73A49, 0xFF7B72),
            (#"\b(greet|print)\b"#, 0x6F42C1, 0xD2A8FF),
            (#"\"[^\"]*\"|https?://\S+"#, 0x032F62, 0x79C0FF)
        ]
        for (pattern, light, dark) in tokens {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let color = UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? dark : light) }
            for match in regex.matches(in: source, range: NSRange(location: 0, length: result.length)) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        return result
    }
}
