import UIKit
import CampfireKit

enum TextLayout {
    static func measure(_ text: NSAttributedString, width: CGFloat) -> CGSize {
        guard text.length > 0 else { return .zero }
        let storage = NSTextStorage(attributedString: text)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container); storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        return manager.usedRect(for: container).size
    }

    static func attributes(font: UIFont, lineHeight: CGFloat, color: UIColor = Style.text) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight; paragraph.maximumLineHeight = lineHeight
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }

    static func code(_ source: String, category: UIContentSizeCategory) -> NSAttributedString {
        let scale = Style.scale(category)
        let font = UIFont(name: "Menlo-Regular", size: 12.8 * scale) ?? UIFont.monospacedSystemFont(ofSize: 12.8 * scale, weight: .regular)
        let result = NSMutableAttributedString(string: source, attributes: attributes(font: font, lineHeight: 17.92 * scale))
        // Highlight the structured code field only. Message bodies are never parsed.
        let patterns: [(String, UIColor)] = [
            (#"\b(def|end|let|var|func|return|SELECT|FROM|ORDER|BY|DESC|LIMIT)\b"#, Style.color(0xD73A49, 0xFF7B72)),
            (#"\b(greet|print)\b"#, Style.color(0x6F42C1, 0xD2A8FF)),
            (#"\"[^\"\n]*\""#, Style.color(0x032F62, 0x79C0FF)),
            (#"https?://\S+"#, Style.color(0x032F62, 0x79C0FF))
        ]
        for (pattern, color) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for match in regex.matches(in: source, range: NSRange(location: 0, length: (source as NSString).length)) {
                    result.addAttribute(.foregroundColor, value: color, range: match.range)
                }
            }
        }
        return result
    }

    static func mention(_ user: User?, id: Int, category: UIContentSizeCategory) -> NSAttributedString {
        let scale = Style.scale(category)
        let diameter = 17.6 * scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter + 3.7 * scale, height: diameter))
        let attachment = NSTextAttachment()
        attachment.image = renderer.image { _ in
            Style.avatarColor(id).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).fill()
            let font = UIFont.systemFont(ofSize: 10.2 * scale, weight: .bold)
            let text = String(user?.name.prefix(1) ?? "?")
            let size = text.size(withAttributes: [.font: font])
            text.draw(at: CGPoint(x: (diameter-size.width)/2, y: (diameter-size.height)/2), withAttributes: [.font: font, .foregroundColor: UIColor.white])
        }
        attachment.bounds = CGRect(x: 0, y: -3 * scale, width: diameter + 3.7 * scale, height: diameter)
        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes(attributes(font: Style.font(16, weight: .semibold, category: category), lineHeight: 22.4 * scale), range: NSRange(location: 0, length: result.length))
        var mentionAttributes = attributes(font: Style.font(16, weight: .semibold, category: category), lineHeight: 22.4 * scale)
        mentionAttributes[.kern] = 0.1 * scale
        result.append(NSAttributedString(string: user?.name ?? "Unknown", attributes: mentionAttributes))
        return result
    }
}

struct MessageMetrics {
    enum Content {
        case text(NSAttributedString)
        case code(NSAttributedString)
        case image(RGB)
        case file(String, Int)
    }
    struct Part { let content: Content; let frame: CGRect }
    let message: Message
    let presentation: MessagePresentation
    let category: UIContentSizeCategory
    let bubble: CGRect
    let avatar: CGRect
    let day: CGRect?
    let header: CGRect
    let parts: [Part]
    let boostFrames: [CGRect]
    let boosts: [DisplayBoost]
    let addBoostFrame: CGRect?
    let height: CGFloat

    static func make(message: Message, previous: Message?, users: [Int: User], width: CGFloat, category: UIContentSizeCategory, boosts: [DisplayBoost]) -> MessageMetrics {
        let p = Grouping.presentation(of: message, after: previous, currentUserID: 1)
        let scale = Style.scale(category)
        let maxBubble = max(80, width - 54.8)
        let headerHeight = 19.2 * scale
        let gap = 2.76 * scale
        let author = p.isThreaded ? "" : (users[message.creatorID]?.name ?? "Unknown")
        let meta = author + " " + Style.time.string(from: message.createdAt) + "    •••"
        let metaWidth = (meta as NSString).size(withAttributes: [.font: Style.font(12.8, category: category)]).width
        var content: [Content] = []
        var text = NSMutableAttributedString()
        func flush() {
            if text.length > 0 { content.append(.text(text.copy() as! NSAttributedString)); text = NSMutableAttributedString() }
        }
        for block in message.blocks {
            switch block {
            case .text(let value):
                text.append(NSAttributedString(string: value, attributes: TextLayout.attributes(font: Style.font(message.isEmojiOnly ? 38.4 : 16, category: category), lineHeight: (message.isEmojiOnly ? 53.76 : 22.4) * scale)))
            case .mention(let id): text.append(TextLayout.mention(users[id], id: id, category: category))
            case .code(_, let source): flush(); content.append(.code(TextLayout.code(source, category: category)))
            }
        }
        flush()
        if let attachment = message.attachment {
            switch attachment {
            case .image(_, _, let color): content.append(.image(color))
            case .file(let name, let bytes): content.append(.file(name, bytes))
            }
        }
        var natural = metaWidth
        var hasImage = false
        for part in content {
            switch part {
            case .text(let value): natural = max(natural, TextLayout.measure(value, width: 100_000).width)
            case .code(let value): natural = max(natural, TextLayout.measure(value, width: 100_000).width + 27.6)
            case .file(let name, _): natural = max(natural, (name as NSString).size(withAttributes: [.font: Style.font(16, category: category)]).width + 104.51)
            case .image: hasImage = true
            }
        }
        if message.isEmojiOnly { natural += 12.8 * scale }
        let bubbleWidth = hasImage ? min(300, maxBubble) : min(maxBubble, ceil(natural + 30.24))
        let textWidth = bubbleWidth - 30.24
        let separatorHeight = 17.92 * scale + 17
        let dayHeight = p.isFirstOfDay ? separatorHeight + 34.04 : 0
        let bubbleX = p.isMine ? width - 40.8 - bubbleWidth : 40.8
        let bubbleY = 1.59 + dayHeight
        var y = 10.56 + headerHeight + gap
        var parts: [Part] = []
        for part in content {
            if !parts.isEmpty { y += 8 * scale }
            switch part {
            case .text(let value):
                let size = TextLayout.measure(value, width: textWidth)
                let h = max(message.isEmojiOnly ? 53.76 * scale : 22.4 * scale, size.height)
                parts.append(Part(content: part, frame: CGRect(x: 15.12, y: y - 1, width: textWidth, height: h)))
                y += h
            case .code(let value):
                let h = TextLayout.measure(value, width: max(1, textWidth - 27.6)).height + 27.6
                parts.append(Part(content: part, frame: CGRect(x: 15.12, y: y, width: textWidth, height: h)))
                y += h
            case .image:
                if parts.isEmpty { y = 44.59 + (headerHeight - 19.2) }
                var ratio: CGFloat = 2/3
                if case .image(let w, let h, _)? = message.attachment { ratio = CGFloat(h) / CGFloat(w) }
                let h = bubbleWidth * ratio
                parts.append(Part(content: part, frame: CGRect(x: 0, y: y, width: bubbleWidth, height: h)))
                y += h
            case .file:
                let h = max(33.92, 27.4 * scale)
                parts.append(Part(content: part, frame: CGRect(x: 15.12, y: y, width: textWidth, height: h)))
                y += h
            }
        }
        var frames: [CGRect] = []
        var add: CGRect?
        if !boosts.isEmpty {
            let inset: CGFloat = hasImage ? 10.56 : 15.12
            let available = bubbleWidth - inset * 2
            let pillHeight: CGFloat = 28.64 * max(1, scale * 0.85)
            var x = inset
            y += 4
            for boost in boosts {
                let emoji = boost.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
                let boostFont = Style.font(emoji ? 17.6 : 12.8, category: category)
                let textWidth = (boost.content as NSString).size(withAttributes: [.font: boostFont]).width
                let w = min(available, max(46, textWidth + (emoji ? 35.2 : 39.8)))
                if x > inset && x + w > bubbleWidth - inset + 0.01 { x = inset; y += pillHeight + 4 }
                frames.append(CGRect(x: x, y: y, width: w, height: pillHeight))
                x += w + 4.8
            }
            if x + pillHeight > bubbleWidth - inset + 0.01 { x = inset; y += pillHeight + 4 }
            add = CGRect(x: x, y: y, width: pillHeight, height: pillHeight)
            y += pillHeight
        }
        y += hasImage && !boosts.isEmpty ? 6.5 : 10.56
        let bubble = CGRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: y)
        return MessageMetrics(message: message, presentation: p, category: category, bubble: bubble,
                              avatar: CGRect(x: p.isMine ? width-49.27 : 14, y: bubbleY, width: 35.27, height: 35.27),
                              day: p.isFirstOfDay ? CGRect(x: 14, y: 17.02, width: width - 28, height: separatorHeight) : nil,
                              header: CGRect(x: 15.12, y: 10.56, width: textWidth, height: headerHeight),
                              parts: parts, boostFrames: frames, boosts: boosts, addBoostFrame: add, height: bubble.maxY + (hasImage ? 5.27 : message.isEmojiOnly ? 0 : 1.6))
    }
}

/// Every row has its final height before collection updates. No estimated-height corrections can
/// move the viewport after the anchor has been restored.
final class RoomLayout: UICollectionViewLayout {
    var metrics: [MessageMetrics] = []
    var attributes: [UICollectionViewLayoutAttributes] = []
    var showsWelcome = false
    var welcomeHeight: CGFloat = 0
    var width: CGFloat = 0
    private var size = CGSize.zero

    func rebuild(metrics: [MessageMetrics], width: CGFloat, welcomeHeight: CGFloat) {
        self.metrics = metrics; self.width = width; self.welcomeHeight = welcomeHeight
        showsWelcome = welcomeHeight > 0
        var y: CGFloat = 0
        var result: [UICollectionViewLayoutAttributes] = []
        if showsWelcome {
            let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
            a.frame = CGRect(x: 0, y: 0, width: width, height: welcomeHeight)
            result.append(a); y = welcomeHeight
        }
        for (i, metric) in metrics.enumerated() {
            if i > 0 { y += metric.presentation.isThreaded ? -1.2 : 21.28 }
            // UIScrollView offsets are quantized to display pixels. Use the same grid for row
            // origins so jumping to a row cannot leave a fractional sliver of its predecessor.
            let displayScale = collectionView?.traitCollection.displayScale ?? 3
            y = (y * displayScale).rounded() / displayScale
            let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: result.count, section: 0))
            a.frame = CGRect(x: 0, y: y, width: width, height: metric.height)
            result.append(a); y += metric.height
        }
        attributes = result
        size = CGSize(width: width, height: y + 2)
        invalidateLayout()
    }
    override var collectionViewContentSize: CGSize { size }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let count = collectionView?.numberOfItems(inSection: 0) ?? attributes.count
        return attributes.filter { $0.indexPath.item < count && $0.frame.intersects(rect) }
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributes.indices.contains(indexPath.item) ? attributes[indexPath.item] : nil
    }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { false }
    func frame(forMessageAt index: Int) -> CGRect { attributes[index + (showsWelcome ? 1 : 0)].frame }
}
