import Foundation
import CoreText
import CampfireKit

/// Estimates a row's height without building its views, from the same metrics the views use and Core Text
/// line breaking. Rows far from the viewport are drawn as spacers of this height until they are first shown
/// and measured; the room then keeps what the reader sees in place, so an estimate only needs to be close.
@MainActor
final class HeightEstimator {
    private var cache: [Key: CGFloat] = [:]
    private struct Key: Hashable { let id: MessageID; let scale: CGFloat; let width: CGFloat; let boosts: Int; let pres: Int }

    func height(of row: RowModel, isFirst: Bool, metrics m: Metrics, width: CGFloat, store: ChatStore) -> CGFloat {
        let p = row.presentation
        let presBits = (p.isThreaded ? 1 : 0) | (p.isFirstOfDay ? 2 : 0) | (isFirst ? 4 : 0)
        let key = Key(id: row.id, scale: m.s, width: width, boosts: row.message.boosts.count, pres: presBits)
        if let hit = cache[key] { return hit }
        let h = MessageRow.gap(for: row, isFirst: isFirst, metrics: m) + rowHeight(row, m: m, width: width, store: store)
        cache[key] = h
        if cache.count > 20_000 { cache.removeAll(keepingCapacity: true) }
        return h
    }

    private func rowHeight(_ row: RowModel, m: Metrics, width: CGFloat, store: ChatStore) -> CGFloat {
        let message = row.message
        let p = row.presentation
        var h = m.bubbleTop + m.bubbleBottom + (p.isFirstOfDay ? 68.81 * m.s : 0)
        let bubbleMax = p.isMine
            ? width - (m.screenPaddingX + m.bubbleInsetFromAvatar) - m.mineLeftLimit
            : width - (m.screenPaddingX + m.bubbleInsetFromAvatar) - m.screenPaddingX
        let textWidth = max(40, bubbleMax - 2 * m.bubblePadX)

        if case .image(let w, let ih, _)? = message.attachment {
            let bw = min(m.imageMaxWidth, bubbleMax)
            h += m.imageTop + (bw - 2) * CGFloat(ih) / CGFloat(max(1, w))
            let caption = message.blocks.filter { if case .code = $0 { false } else { true } }
            if !caption.isEmpty {
                h += 6 * m.s + paragraphHeight(caption, width: bw - 2 * m.bubblePadX, m: m, store: store)
                if message.boosts.isEmpty { h += m.bubblePadY }
            }
            if !message.boosts.isEmpty {
                h += 5 * m.s + boostsHeight(message.boosts, width: bw - 10 * m.s - m.bubblePadX, m: m) + 7.8 * m.s
            } else if caption.isEmpty {
                h += 1
            }
            return h
        }
        h += m.bodyTop + m.bubblePadY
        if message.isEmojiOnly { return h + m.emojiLine }
        var run: [Block] = []
        var n = 0
        func flush() {
            if !run.isEmpty { h += paragraphHeight(run, width: textWidth, m: m, store: store); run = []; n += 1 }
        }
        for block in message.blocks {
            if case .code(_, let source) = block {
                flush()
                let lines = source.split(separator: "\n", omittingEmptySubsequences: false).count
                h += CGFloat(lines) * m.codeLine + 2 * m.codePadding + m.codeBottomExtra + (n > 0 ? 4 * m.s : 0)
                n += 1
            } else {
                run.append(block)
            }
        }
        flush()
        if case .file? = message.attachment { h += 33.92 * m.s }
        if !message.boosts.isEmpty { h += m.boostMarginTop + boostsHeight(message.boosts, width: textWidth, m: m) }
        return h
    }

    private func paragraphHeight(_ blocks: [Block], width: CGFloat, m: Metrics, store: ChatStore) -> CGFloat {
        var text = ""
        for block in blocks {
            switch block {
            case .text(let t): text += t
            case .mention(let id): text += "\u{2003}" + (store.user(id)?.name ?? "")
            case .code(_, let s): text += s
            }
        }
        return CGFloat(lineCount(text, size: m.bodySize, width: width)) * m.bodyLine
    }

    private func boostsHeight(_ boosts: [Boost], width: CGFloat, m: Metrics) -> CGFloat {
        var widths = boosts.map { b -> CGFloat in
            let isEmoji = b.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
            let content = isEmoji ? 19.2 * m.s : textWidth(b.content, size: m.boostTextSize)
            return 2 + m.boostPadLeft + m.boostAvatar + m.boostInnerGap + content + m.boostPadRight
        }
        widths.append(m.boostHeight)
        var lines = 1
        var x: CGFloat = 0
        for w in widths {
            if x > 0 && x + w > width { lines += 1; x = 0 }
            x += w + m.boostGap
        }
        return CGFloat(lines) * m.boostHeight + CGFloat(lines - 1) * m.boostGap
    }

    // MARK: Core Text

    private var fonts: [CGFloat: CTFont] = [:]

    private func font(_ size: CGFloat) -> CTFont {
        if let f = fonts[size] { return f }
        let f = CTFontCreateUIFontForLanguage(.system, size, nil)!
        fonts[size] = f
        return f
    }

    private func lineCount(_ text: String, size: CGFloat, width: CGFloat) -> Int {
        guard !text.isEmpty else { return 1 }
        let attributed = CFAttributedStringCreate(nil, text as CFString,
                                                  [kCTFontAttributeName: font(size)] as CFDictionary)!
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        return max(1, lines.count + (text.hasSuffix("\n") ? 1 : 0))
    }

    private func textWidth(_ text: String, size: CGFloat) -> CGFloat {
        let attributed = CFAttributedStringCreate(nil, text as CFString,
                                                  [kCTFontAttributeName: font(size)] as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributed)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
}
