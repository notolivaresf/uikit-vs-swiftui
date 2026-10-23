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
    private static var timeLabels = [String?](repeating: nil, count: 24 * 60)
    private static func timeLabel(for date: Date) -> String {
        let seconds = Int(date.timeIntervalSince1970.rounded(.down))
        let minute = (((seconds % 86_400) + 86_400) % 86_400) / 60
        if let cached = timeLabels[minute] { return cached }
        let label = timeFormatter.string(from: date)
        timeLabels[minute] = label
        return label
    }
    private static let syntaxRules: [(NSRegularExpression, UIColor)] = {
        let tokens: [(String, UInt32, UInt32)] = [
            (#"\b(def|end|let|var|func|return|SELECT|FROM|ORDER BY|LIMIT)\b"#, 0xD73A49, 0xFF7B72),
            (#"\b(greet|print)\b"#, 0x6F42C1, 0xD2A8FF),
            (#"\"[^\"]*\"|https?://\S+"#, 0x032F62, 0x79C0FF)
        ]
        return tokens.compactMap { pattern, light, dark in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? dark : light) })
        }
    }()

    init(message: Message, previous: Message?, next: Message?, users: [Int: User], width: CGFloat, scale: CGFloat, extraBoosts: [RoomBoost] = []) {
        self.id = message.id; self.message = message; self.scale = scale
        let emojiOnly = message.isEmojiOnly
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
        let time = Self.timeLabel(for: message.createdAt)
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
            style.minimumLineHeight = (emojiOnly ? 53.76 : 22.4) * scale
            style.maximumLineHeight = style.minimumLineHeight
            text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
            let bounds = Self.measure(text, width: innerMax + 0.1)
            let line = (emojiOnly ? 53.76 : 22.4) * scale
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
                text.append(Theme.attributed(value, size: emojiOnly ? 38.4 : 16,
                                             line: emojiOnly ? 53.76 : 22.4, scale: scale))
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
        var bubbleWidth = min(maxWidth, contentWidth + px * 2 + (emojiOnly ? 15.12 : 0))
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

    mutating func updateFollowing(_ next: Message?) {
        let threaded = next.map { Grouping.presentation(of: $0, after: message, currentUserID: 1).isThreaded } ?? false
        height = messageHeight + (next == nil ? 0 : threaded ? -1.2 : 21.28)
    }

    static func highlight(_ source: String, scale: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: Theme.attributed(source, size: 12.8, line: 17.92, scale: scale, mono: true))
        for (regex, color) in syntaxRules {
            for match in regex.matches(in: source, range: NSRange(location: 0, length: result.length)) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        return result
    }
}

import Foundation

/// Prefix heights with logarithmic point changes and offset searches. Leading
/// storage permits older pages to be inserted without shifting every height.
struct RowHeightIndex {
    // One-based Fenwick sums; start marks the first active row in the storage.
    private var values: [CGFloat] = []
    private var sums: [CGFloat] = [0]
    private var start = 0
    private var base: CGFloat = 0
    var count: Int { values.count - start }
    var total: CGFloat { prefix(values.count) - base }

    mutating func reset(_ heights: [CGFloat]) { rebuild(heights, leading: 64) }

    private mutating func rebuild(_ heights: [CGFloat], leading: Int) {
        start = leading
        values = Array(repeating: 0, count: leading) + heights
        sums = [0] + values
        for i in 1..<sums.count {
            let parent = i + (i & -i)
            if parent < sums.count { sums[parent] += sums[i] }
        }
        base = 0
    }

    mutating func append(_ heights: [CGFloat]) {
        for height in heights {
            values.append(height)
            let index = values.count
            let lower = index - (index & -index)
            var sum = height
            var previous = index - 1
            while previous > lower {
                sum += sums[previous]
                previous -= previous & -previous
            }
            sums.append(sum)
        }
    }

    mutating func prepend(_ heights: [CGFloat]) {
        guard !heights.isEmpty else { return }
        if start < heights.count {
            rebuild(Array(values[start...]), leading: max(64, max(heights.count, count / 2)))
        }
        start -= heights.count
        for (i, height) in heights.enumerated() { setPhysical(start + i, height: height) }
        base = prefix(start)
    }

    mutating func removeFirst(_ number: Int) {
        precondition(number <= count)
        start += number
        base = prefix(start)
        if start > 4096, start > count * 2 { rebuild(Array(values[start...]), leading: 64) }
    }

    mutating func removeLast(_ number: Int) {
        precondition(number <= count)
        values.removeLast(number)
        sums.removeLast(number)
    }

    mutating func setHeight(_ height: CGFloat, at index: Int) {
        precondition(index >= 0 && index < count)
        setPhysical(start + index, height: height)
    }

    private mutating func setPhysical(_ physical: Int, height: CGFloat) {
        let delta = height - values[physical]
        guard delta != 0 else { return }
        values[physical] = height
        var i = physical + 1
        while i < sums.count {
            sums[i] += delta
            i += i & -i
        }
    }

    func height(at index: Int) -> CGFloat { values[start + index] }
    func offset(at index: Int) -> CGFloat { prefix(start + index) - base }

    func firstRow(endingAfter offset: CGFloat) -> Int {
        let target = offset + base
        var physical = 0
        var sum: CGFloat = 0
        var step = 1
        while step < sums.count { step <<= 1 }
        while step > 0 {
            let next = physical + step
            if next < sums.count, sum + sums[next] <= target {
                physical = next
                sum += sums[next]
            }
            step >>= 1
        }
        return min(count, max(0, physical - start))
    }

    private func prefix(_ end: Int) -> CGFloat {
        var i = end
        var result: CGFloat = 0
        while i > 0 {
            result += sums[i]
            i -= i & -i
        }
        return result
    }
}
import UIKit

/// Message heights are indexed separately from reusable cells. A point update
/// changes a logarithmic number of sums, and viewport queries visit visible rows.
@MainActor
final class RoomRowsLayout: UICollectionViewLayout {
    private var heights = RowHeightIndex()
    private var rowWidth: CGFloat = 0
    private var pixelScale: CGFloat { max(1, collectionView?.traitCollection.displayScale ?? 1) }

    func setRows(heights: [CGFloat], width: CGFloat) {
        self.heights.reset(heights)
        finishUpdates(width: width)
    }
    func appendRows(_ values: [CGFloat]) { heights.append(values) }
    func prependRows(_ values: [CGFloat]) { heights.prepend(values) }
    func removeFirstRows(_ count: Int) { heights.removeFirst(count) }
    func removeLastRows(_ count: Int) { heights.removeLast(count) }
    func setHeight(_ height: CGFloat, at index: Int) { heights.setHeight(height, at: index) }
    func finishUpdates(width: CGFloat) {
        rowWidth = width
        invalidateLayout()
    }

    private func aligned(_ value: CGFloat) -> CGFloat { (value * pixelScale).rounded() / pixelScale }
    override var collectionViewContentSize: CGSize { CGSize(width: rowWidth, height: aligned(heights.total)) }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != collectionView?.bounds.width
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let row = indexPath.item
        guard indexPath.section == 0, row >= 0, row < heights.count else { return nil }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let top = aligned(heights.offset(at: row))
        let bottom = aligned(heights.offset(at: row + 1))
        attributes.frame = CGRect(x: 0, y: top, width: rowWidth, height: bottom - top)
        return attributes
    }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let collectionView, collectionView.numberOfSections > 0 else { return [] }
        let count = min(heights.count, collectionView.numberOfItems(inSection: 0))
        guard count > 0 else { return [] }
        var result: [UICollectionViewLayoutAttributes] = []
        var row = heights.firstRow(endingAfter: rect.minY - 1 / pixelScale)
        while row < count {
            guard let attributes = layoutAttributesForItem(at: IndexPath(item: row, section: 0)), attributes.frame.minY < rect.maxY else { break }
            if attributes.frame.maxY > rect.minY { result.append(attributes) }
            row += 1
        }
        return result
    }
}
