import UIKit
import CampfireKit

/// Everything a message cell draws, with frames already computed. Frames are relative to the row,
/// except where noted (inside the bubble or inside a pill).
struct RowLayout {
    struct Separator {
        var lineFrame: CGRect
        var pillFrame: CGRect
        var labelFrame: CGRect      // inside the pill
        var text: NSAttributedString
    }

    struct Pill {
        var frame: CGRect           // inside the bubble
        var avatarFrame: CGRect     // inside the pill
        var contentFrame: CGRect    // inside the pill
        var content: NSAttributedString
        var initial: String
        var color: UIColor
        var initialFont: UIFont
    }

    struct File {
        var iconFrame: CGRect       // inside the bubble
        var nameFrame: CGRect
        var name: NSAttributedString
        var downloadFrame: CGRect
        var shareFrame: CGRect
    }

    enum BubbleStyle { case plain, mentioned, transparent }

    var id: MessageID
    var height: CGFloat
    var gapBefore: CGFloat
    var isMine: Bool
    var separator: Separator?
    var avatarFrame: CGRect?        // outer frame, ring included
    var avatarInitial = ""
    var avatarColor = UIColor.gray
    var bubbleFrame: CGRect
    var bubbleStyle: BubbleStyle
    var headerFrame: CGRect         // inside the bubble
    var header: NSAttributedString
    var dotsFrame: CGRect           // inside the bubble
    var textFrame: CGRect?          // inside the bubble
    var text: NSAttributedString?
    var codeBoxFrame: CGRect?       // inside the bubble
    var codeTextFrame: CGRect?      // inside the code box
    var code: NSAttributedString?
    var imageFrame: CGRect?         // inside the bubble
    var imageColor: UIColor?
    var file: File?
    var pills: [Pill] = []
    var addBoostFrame: CGRect?      // inside the bubble
    var copyText: String
}

/// A row layout held by reference: the room layout reads every row's height on each change, and reading
/// through a reference copies nothing.
final class RowBox {
    let row: RowLayout
    init(_ row: RowLayout) { self.row = row }
}

/// TextKit 1 measuring stack. The cells show text in TextKit 1 text views with the same settings,
/// so measured and drawn line breaks are identical.
final class TextMeasurer {
    static let shared = TextMeasurer()
    private let storage = NSTextStorage()
    private let manager = NSLayoutManager()
    private let container = NSTextContainer(size: .zero)

    init() {
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
    }

    func size(of text: NSAttributedString, width: CGFloat) -> CGSize {
        container.size = CGSize(width: width, height: 1_000_000)
        storage.setAttributedString(text)
        manager.ensureLayout(for: container)
        let used = manager.usedRect(for: container)
        return CGSize(width: Self.ceilPixel(used.width), height: Self.ceilPixel(used.height))
    }

    /// Width of a single line of text.
    static func lineWidth(_ text: NSAttributedString) -> CGFloat {
        ceilPixel(text.boundingRect(with: CGSize(width: 100_000, height: 1000), options: [.usesLineFragmentOrigin], context: nil).width)
    }

    static func ceilPixel(_ value: CGFloat) -> CGFloat { (value * 3).rounded(.up) / 3 }
}

enum Formatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "h:mm a"
        return f
    }()

    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()
}

/// Small round avatar images for mentions, cached per user and size.
enum AvatarImages {
    private static var cache: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func image(initial: String, color: UIColor, diameter: CGFloat, leftPad: CGFloat, rightPad: CGFloat, font: UIFont) -> UIImage {
        let key = "\(initial)|\(diameter)|\(leftPad)|\(rightPad)|\(font.pointSize)|\(color.hashValue)"
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let size = CGSize(width: diameter + leftPad + rightPad, height: diameter)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let circle = CGRect(x: leftPad, y: 0, width: diameter, height: diameter)
            color.setFill()
            UIBezierPath(ovalIn: circle).fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let text = initial as NSString
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: circle.midX - textSize.width / 2, y: circle.midY - textSize.height / 2), withAttributes: attrs)
        }
        cache[key] = image
        return image
    }
}

/// Builds many rows at once on several threads. Each worker has its own measurer; everything else a
/// builder reads (the store, fonts, formatters, the locked avatar cache) is safe to read concurrently.
/// Called from the main thread only, so a measurer is never used by two calls at once.
enum ParallelRowLayout {
    private static let workers = max(1, min(8, ProcessInfo.processInfo.activeProcessorCount))
    private static let measurers = (0..<workers).map { i in i == 0 ? TextMeasurer.shared : TextMeasurer() }

    static func layouts(for ids: [MessageID], store: RoomStore, width: CGFloat, scale: TypeScale) -> [RowLayout?] {
        var results = [RowLayout?](repeating: nil, count: ids.count)
        let n = min(workers, ids.count)
        results.withUnsafeMutableBufferPointer { out in
            DispatchQueue.concurrentPerform(iterations: n) { w in
                let builder = RowLayoutBuilder(store: store, width: width, scale: scale, measurer: measurers[w])
                var i = w
                while i < ids.count {
                    out[i] = builder.layout(for: ids[i])
                    i += n
                }
            }
        }
        return results
    }
}

/// Builds `RowLayout`s. Pure: the same message, width and text size always give the same frames.
struct RowLayoutBuilder {
    let store: RoomStore
    let width: CGFloat
    let scale: TypeScale
    /// Not thread-safe: a builder used off the main thread brings its own.
    var measurer: TextMeasurer = .shared

    private var textLeft: CGFloat { Metrics.bubblePadX }
    private var maxBubbleWidth: CGFloat { max(120, width - Metrics.bubbleX - Metrics.bubbleRightInset) }
    private var maxTextWidth: CGFloat { maxBubbleWidth - 2 * Metrics.bubblePadX }

    static func initial(of name: String) -> String { name.first.map { String($0).uppercased() } ?? "?" }

    static func isEmoji(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.unicodeScalars.contains { $0.properties.isEmojiPresentation } }
    }

    func layout(for id: MessageID) -> RowLayout? {
        guard let message = store.message(id), let presentation = store.presentation(of: id) else { return nil }
        let author = store.user(message.creatorID)
        let authorName = author?.name ?? "Unknown"
        let mine = presentation.isMine
        let threaded = presentation.isThreaded

        // Day separator.
        var separator: RowLayout.Separator?
        var bubbleTop = Metrics.rowTopPad
        if presentation.isFirstOfDay {
            let text = NSAttributedString(string: Formatters.day.string(from: message.createdAt).uppercased(),
                                          attributes: [.font: scale.separator, .foregroundColor: Palette.text])
            let textWidth = TextMeasurer.lineWidth(text)
            let pillHeight = scale.separatorLine + 2 * Metrics.separatorPillPadY
            let pillWidth = textWidth + 2 * Metrics.separatorPillPadX
            let pill = CGRect(x: ((width - pillWidth) / 2).rounded(), y: Metrics.separatorPillTop, width: pillWidth, height: pillHeight)
            let line = CGRect(x: Metrics.screenPaddingX, y: pill.midY - Metrics.separatorLine / 2,
                              width: width - 2 * Metrics.screenPaddingX, height: Metrics.separatorLine)
            separator = .init(lineFrame: line, pillFrame: pill,
                              labelFrame: CGRect(x: Metrics.separatorPillPadX, y: Metrics.separatorPillPadY, width: textWidth, height: scale.separatorLine),
                              text: text)
            bubbleTop = pill.maxY + Metrics.separatorMarginBottom + Metrics.rowTopPad
        }

        // Header: name and time (reversed for mine), then the actions dots.
        let header = NSMutableAttributedString()
        let nameText = NSAttributedString(string: authorName, attributes: [.font: scale.metaBold, .foregroundColor: Palette.text])
        let timeText = NSAttributedString(string: Formatters.time.string(from: message.createdAt),
                                          attributes: [.font: scale.meta, .foregroundColor: Palette.textHalf])
        let space = NSAttributedString(string: " ", attributes: [.font: scale.meta])
        if threaded {
            header.append(timeText)
        } else if mine {
            header.append(timeText); header.append(space); header.append(nameText)
        } else {
            header.append(nameText); header.append(space); header.append(timeText)
        }
        let headerTextWidth = TextMeasurer.lineWidth(header)
        let headerWidth = headerTextWidth + Metrics.timeToDotsGap + Metrics.dotsWidth
        let headerLineTop = Metrics.headerTop
        let contentTop = headerLineTop + scale.metaLine

        // Body: text and mentions in one attributed string; code blocks below it.
        let emojiOnly = message.isEmojiOnly
        var body: NSAttributedString?
        var code: NSAttributedString?
        var copyParts: [String] = []
        do {
            let font = emojiOnly ? scale.emoji : scale.body
            let line = emojiOnly ? scale.emojiLine : scale.bodyLine
            let attrs = LineBox.attributes(font: font, lineHeight: line, color: Palette.text)
            let s = NSMutableAttributedString()
            var codeSources: [(String?, String)] = []
            for block in message.blocks {
                switch block {
                case .text(let t):
                    s.append(NSAttributedString(string: t, attributes: attrs))
                    copyParts.append(t)
                case .mention(let uid):
                    let user = store.user(uid)
                    let name = user?.name ?? "someone"
                    let attachment = NSTextAttachment()
                    let diameter = scale.size(Metrics.mentionAvatar)
                    attachment.image = AvatarImages.image(initial: Self.initial(of: name), color: Palette.avatarColor(for: uid),
                                                          diameter: diameter, leftPad: 2, rightPad: 4,
                                                          font: .systemFont(ofSize: scale.size(7.5), weight: .bold))
                    attachment.bounds = CGRect(x: 0, y: (-diameter * 0.19).rounded(), width: diameter + 6, height: diameter)
                    s.append(NSAttributedString(attachment: attachment))
                    s.addAttributes(attrs, range: NSRange(location: s.length - 1, length: 1))
                    var nameAttrs = attrs
                    nameAttrs[.font] = scale.mention
                    s.append(NSAttributedString(string: name, attributes: nameAttrs))
                    copyParts.append(name)
                case .code(let language, let source):
                    codeSources.append((language, source))
                }
            }
            if s.length > 0 { body = s }
            if !codeSources.isEmpty {
                code = CodeHighlighter.highlight(codeSources, scale: scale)
                if !copyParts.isEmpty { copyParts.append("\n") }
                copyParts.append(codeSources.map(\.1).joined(separator: "\n\n"))
            }
        }

        // Widths (CSS shrink-to-fit: min(max-content, available)).
        var contentWidth = headerWidth
        var bodyNatural: CGSize = .zero
        if let body {
            bodyNatural = measurer.size(of: body, width: 100_000)
            contentWidth = max(contentWidth, bodyNatural.width)
        }
        var codeNatural: CGSize = .zero
        if let code {
            codeNatural = measurer.size(of: code, width: 100_000)
            contentWidth = max(contentWidth, codeNatural.width + 2 * Metrics.codePad + 2 * (Metrics.codeBoxInsetX - Metrics.bubblePadX))
        }
        var fileInfo: (name: NSAttributedString, nameWidth: CGFloat)?
        if case .file(let name, _)? = message.attachment {
            let n = NSAttributedString(string: name, attributes: [.font: scale.body, .foregroundColor: Palette.text])
            let w = min(TextMeasurer.lineWidth(n), maxTextWidth - 28.08 - 70)
            fileInfo = (n, w)
            contentWidth = max(contentWidth, 28.08 + w + 22.3 + 39 + 32 - Metrics.bubblePadX)
        }
        let pillSpecs = makePills(store.boosts(of: id))
        if !pillSpecs.isEmpty {
            let line = pillSpecs.reduce(0) { $0 + $1.width + Metrics.boostGap } + pillHeight
            contentWidth = max(contentWidth, line)
        }

        var image: (w: Int, h: Int, color: RGB)?
        if case .image(let w, let h, let color)? = message.attachment { image = (w, h, color) }

        let bubbleWidth: CGFloat
        if image != nil {
            bubbleWidth = min(Metrics.imageWidth, maxBubbleWidth)
        } else {
            bubbleWidth = min(TextMeasurer.ceilPixel(contentWidth + 2 * Metrics.bubblePadX), maxBubbleWidth)
        }
        let innerWidth = bubbleWidth - 2 * Metrics.bubblePadX

        // Vertical stacking inside the bubble.
        var y = contentTop
        var textFrame: CGRect?
        var codeBoxFrame: CGRect?
        var codeTextFrame: CGRect?
        var imageFrame: CGRect?
        var file: RowLayout.File?
        var bottomPad = Metrics.bubbleBottomPad
        var pillsInset = Metrics.bubblePadX

        if let image {
            y = contentTop + Metrics.imageTopGap
            let w = bubbleWidth - 2 * Metrics.imageInset
            let h = (w * CGFloat(image.h) / CGFloat(max(1, image.w)) * 3).rounded() / 3
            imageFrame = CGRect(x: Metrics.imageInset, y: y, width: w, height: h)
            y += h
            if body == nil {
                if pillSpecs.isEmpty {
                    bottomPad = Metrics.imageInset
                } else {
                    y += 5 - Metrics.boostMarginTop
                    bottomPad = Metrics.imageBoostBottomPad
                    pillsInset = Metrics.imageBoostInsetX
                }
            } else {
                y += Metrics.bubblePadX * 0.7
            }
        }
        if let body {
            // Text no wider than the bubble breaks only where its natural lines do, so it measures the same.
            let size = bodyNatural.width <= innerWidth ? bodyNatural : measurer.size(of: body, width: innerWidth)
            let font = emojiOnly ? scale.emoji : scale.body
            let shift = LineBox.glyphShift(font: font, lineHeight: emojiOnly ? scale.emojiLine : scale.bodyLine)
            textFrame = CGRect(x: textLeft, y: y - shift + Metrics.glyphNudge, width: innerWidth, height: size.height)
            y += size.height
        }
        if let code {
            let boxInner = min(codeNatural.width, bubbleWidth - 2 * Metrics.codeBoxInsetX - 2 * Metrics.codePad)
            let size = boxInner >= codeNatural.width && boxInner >= 40 ? codeNatural : measurer.size(of: code, width: max(boxInner, 40))
            y += Metrics.codeBoxGapTop
            let boxWidth = boxInner + 2 * Metrics.codePad
            codeBoxFrame = CGRect(x: Metrics.codeBoxInsetX, y: y, width: boxWidth, height: size.height + 2 * Metrics.codePad)
            let shift = LineBox.glyphShift(font: scale.code, lineHeight: scale.codeLine)
            codeTextFrame = CGRect(x: Metrics.codePad, y: Metrics.codePad - shift + Metrics.glyphNudge, width: boxInner, height: size.height)
            y = codeBoxFrame!.maxY
            if pillSpecs.isEmpty { bottomPad = Metrics.codeBoxBottomPad }
        }
        if let fileInfo {
            let mid = y + Metrics.fileBlockHeight / 2
            let nameHeight = scale.bodyLine
            let nameFrame = CGRect(x: textLeft + 28.08, y: mid - nameHeight / 2, width: fileInfo.nameWidth, height: nameHeight)
            let downloadMid = nameFrame.maxX + 22.3
            let shareMid = downloadMid + 39
            file = .init(iconFrame: CGRect(x: textLeft + 2.08, y: mid - 11, width: 18, height: 22),
                         nameFrame: nameFrame, name: fileInfo.name,
                         downloadFrame: CGRect(x: downloadMid - 11, y: mid - 11, width: 22, height: 22),
                         shareFrame: CGRect(x: shareMid - 11, y: mid - 11, width: 22, height: 22))
            y += Metrics.fileBlockHeight
            if pillSpecs.isEmpty { bottomPad = Metrics.fileBottomPad }
        }

        var pills: [RowLayout.Pill] = []
        var addBoostFrame: CGRect?
        if !pillSpecs.isEmpty {
            y += Metrics.boostMarginTop
            let maxX = bubbleWidth - pillsInset
            var x = pillsInset
            var rowTop = y
            let h = pillHeight
            for spec in pillSpecs {
                if x > pillsInset && x + spec.width > maxX + 0.5 {
                    x = pillsInset
                    rowTop += h + Metrics.boostRowGap
                }
                var pill = spec.pill
                pill.frame = CGRect(x: x, y: rowTop, width: spec.width, height: h)
                pills.append(pill)
                x += spec.width + Metrics.boostGap
            }
            if x > pillsInset && x + h > maxX + 0.5 {
                x = pillsInset
                rowTop += h + Metrics.boostRowGap
            }
            addBoostFrame = CGRect(x: x, y: rowTop, width: h, height: h)
            y = rowTop + h
        }

        let bubbleHeight = y + bottomPad
        let bubbleX = mine ? width - Metrics.bubbleX - bubbleWidth : Metrics.bubbleX
        let bubbleFrame = CGRect(x: bubbleX, y: bubbleTop, width: bubbleWidth, height: bubbleHeight)

        // Header frames inside the bubble.
        let headerLabelWidth = min(headerTextWidth, innerWidth - Metrics.timeToDotsGap - Metrics.dotsWidth)
        let headerFrame: CGRect
        let dotsFrame: CGRect
        let dotsY = headerLineTop + (scale.metaLine - Metrics.dotSize) / 2
        if mine {
            headerFrame = CGRect(x: bubbleWidth - Metrics.bubblePadX - headerLabelWidth, y: headerLineTop,
                                 width: headerLabelWidth, height: scale.metaLine)
            dotsFrame = CGRect(x: headerFrame.minX - Metrics.timeToDotsGap - Metrics.dotsWidth, y: dotsY,
                               width: Metrics.dotsWidth, height: Metrics.dotSize)
        } else {
            headerFrame = CGRect(x: textLeft, y: headerLineTop, width: headerLabelWidth, height: scale.metaLine)
            dotsFrame = CGRect(x: headerFrame.maxX + Metrics.timeToDotsGap, y: dotsY, width: Metrics.dotsWidth, height: Metrics.dotSize)
        }

        var avatarFrame: CGRect?
        if !threaded {
            let outer = Metrics.avatarSize + 2 * Metrics.avatarRing
            let x = mine ? width - Metrics.screenPaddingX - Metrics.avatarSize - Metrics.avatarRing
                         : Metrics.screenPaddingX - Metrics.avatarRing
            avatarFrame = CGRect(x: x, y: bubbleTop - Metrics.avatarRing, width: outer, height: outer)
        }

        var row = RowLayout(
            id: id,
            height: bubbleFrame.maxY + Metrics.rowBottomPad,
            gapBefore: threaded ? Metrics.rowGap + Metrics.threadedRowMarginTop : Metrics.rowGap,
            isMine: mine,
            separator: separator,
            avatarFrame: avatarFrame,
            bubbleFrame: bubbleFrame,
            bubbleStyle: emojiOnly ? .transparent : (presentation.mentionsMe ? .mentioned : .plain),
            headerFrame: headerFrame,
            header: header,
            dotsFrame: dotsFrame,
            textFrame: textFrame,
            text: body,
            codeBoxFrame: codeBoxFrame,
            codeTextFrame: codeTextFrame,
            code: code,
            imageFrame: imageFrame,
            imageColor: image.map { UIColor(red: CGFloat($0.color.r) / 255, green: CGFloat($0.color.g) / 255, blue: CGFloat($0.color.b) / 255, alpha: 1) },
            file: file,
            pills: pills,
            addBoostFrame: addBoostFrame,
            copyText: copyParts.joined())
        row.avatarInitial = Self.initial(of: authorName)
        row.avatarColor = Palette.avatarColor(for: message.creatorID)
        if case .file(let name, _)? = message.attachment, row.copyText.isEmpty { row.copyText = name }
        return row
    }

    // MARK: Boost pills

    private var pillHeight: CGFloat { max(Metrics.boostHeight, (scale.boostEmoji.lineHeight + 8).rounded()) }

    private func makePills(_ boosts: [BoostItem]) -> [(pill: RowLayout.Pill, width: CGFloat)] {
        let h = pillHeight
        return boosts.map { boost in
            let emoji = Self.isEmoji(boost.content)
            let content = NSAttributedString(string: boost.content, attributes: [
                .font: emoji ? scale.boostEmoji : scale.boostText, .foregroundColor: Palette.text,
            ])
            let contentWidth = TextMeasurer.lineWidth(content)
            let name = store.user(boost.boosterID)?.name ?? "?"
            let avatarX = 1 + Metrics.boostPadLeft
            let avatar = CGRect(x: avatarX, y: (h - Metrics.boostAvatar) / 2, width: Metrics.boostAvatar, height: Metrics.boostAvatar)
            // An emoji's advance is wider than its ink; Campfire's pills hug the ink more closely.
            let inset: (lead: CGFloat, trail: CGFloat) = emoji ? (2.4, 3.3) : (0, 0)
            let contentFrame = CGRect(x: avatar.maxX + Metrics.boostAvatarGap - inset.lead, y: 0, width: contentWidth, height: h)
            let width = contentFrame.maxX + Metrics.boostPadRight + 1 - inset.trail
            let pill = RowLayout.Pill(frame: .zero, avatarFrame: avatar, contentFrame: contentFrame, content: content,
                                      initial: Self.initial(of: name), color: Palette.avatarColor(for: boost.boosterID),
                                      initialFont: .systemFont(ofSize: 10.5, weight: .bold))
            return (pill, width)
        }
    }
}
