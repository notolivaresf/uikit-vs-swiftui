import SwiftUI
import CampfireKit
import UIKit // UIPasteboard only. All views, layout, scrolling, and text selection are SwiftUI.

struct MessageRow: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.width == rhs.width
    }
    let row: RoomRow
    let users: [Int: User]
    let width: CGFloat
    @Environment(\.colorScheme) private var scheme
    @State private var selectingText = false
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @ScaledMetric(relativeTo: .caption) private var metaSize = 12.8
    @ScaledMetric(relativeTo: .body) private var emojiSize = 38.4

    private var colors: RoomColors { RoomColors(scheme) }
    private var mine: Bool { row.presentation.isMine }
    private var author: User? { users[row.message.creatorID] }
    private var maximumBubbleWidth: CGFloat {
        let available = width - CampfireStyle.screenPadding * 2 - CampfireStyle.bubbleInset
            - (mine ? CampfireStyle.bubbleInset : 0)
        return isImage ? min(300, available) : available
    }

    var body: some View {
        VStack(spacing: 0) {
            if row.presentation.isFirstOfDay { DaySeparator(date: row.message.createdAt) }
            HStack(spacing: 0) {
                if mine { Spacer(minLength: 0) }
                bubble
                    .overlay(alignment: mine ? .topTrailing : .topLeading) {
                        if !row.presentation.isThreaded, let author {
                            InitialAvatar(user: author)
                                .background(Circle().fill(colors.background).padding(-2.4))
                                .offset(x: mine ? CampfireStyle.bubbleInset : -CampfireStyle.bubbleInset)
                        }
                    }
                if !mine { Spacer(minLength: 0) }
            }
            .padding(.leading, CampfireStyle.screenPadding + (mine ? 0 : CampfireStyle.bubbleInset))
            .padding(.trailing, CampfireStyle.screenPadding + (mine ? CampfireStyle.bubbleInset : 0))
            .padding(.top, 1.6)
            .padding(.bottom, row.message.isEmojiOnly ? 0 : isImage ? 5.12 : 1.6)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = copyText }
            Button("Reply", systemImage: "arrowshape.turn.up.left") {}
            if !copyText.isEmpty {
                Button("Select text", systemImage: "text.cursor") { selectingText = true }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("message-\(row.id)")
    }

    private var bubble: some View {
        BubbleFit {
            VStack(alignment: .leading, spacing: 0) {
                metadata
                    .padding(.leading, mine ? 25 : 0)
                    .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                    .padding(.horizontal, CampfireStyle.bubbleX)
                    .padding(.top, CampfireStyle.bubbleY)
                    .padding(.bottom, isImage ? 13.78 : 2.76)
                if !row.message.blocks.isEmpty {
                    if row.message.isEmojiOnly {
                        Text(row.message.plainText)
                            .font(.system(size: emojiSize))
                            .tracking(-emojiSize * 5 / 38.4)
                            .offset(x: -emojiSize * 2 / 38.4)
                            .frame(minHeight: emojiSize * 1.4)
                            .overlay {
                                if selectingText {
                                    RangeSelectionOverlay(text: copyText, fontSize: bodySize, done: { selectingText = false })
                                }
                            }
                            .padding(.horizontal, CampfireStyle.bubbleX)
                    } else {
                        MessageBody(message: row.message, users: users, fontSize: bodySize)
                            .overlay(alignment: .topLeading) {
                                if selectingText {
                                    RangeSelectionOverlay(text: copyText, fontSize: bodySize, done: { selectingText = false })
                                }
                            }
                            .padding(.horizontal, CampfireStyle.bubbleX)
                    }
                }
                if let attachment = row.message.attachment {
                    switch attachment {
                    case .image(let w, let h, let color):
                        // Equivalent drawing is explicitly supported by CampfireKit.Placeholder.
                        Color(rgb: color)
                            .frame(width: min(300, maximumBubbleWidth),
                                   height: min(300, maximumBubbleWidth) * CGFloat(h) / CGFloat(w))
                            .anchorPreference(key: HeaderImageAnchorsKey.self, value: .bounds) { anchor in
                            [row.id: HeaderImageAnchor(bounds: anchor, color: color)]
                        }
                        .accessibilityLabel("Image, \(w) by \(h)")
                    case .file(let name, let bytes):
                        file(name: name, bytes: bytes)
                            .overlay {
                                if selectingText {
                                    RangeSelectionOverlay(text: copyText, fontSize: bodySize, done: { selectingText = false })
                                }
                            }
                            .padding(.horizontal, CampfireStyle.bubbleX)
                    }
                }
                if !row.message.boosts.isEmpty {
                    BoostFlow {
                        ForEach(row.boosts) { item in
                            if let user = users[item.boost.boosterID] { BoostPill(boost: item.boost, user: user) }
                        }
                        AddBoostButton()
                    }
                    .padding(.top, isImage ? 5.2 : 4)
                    .padding(.horizontal, isImage ? 10.56 : CampfireStyle.bubbleX)
                }
            }
            .padding(.bottom, isImage ? (row.message.boosts.isEmpty ? 0 : 6.35) : CampfireStyle.bubbleY)
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        }
        .background(row.message.isEmojiOnly ? Color.clear : row.presentation.mentionsMe ? colors.mention : colors.bubble,
                    in: RoundedRectangle(cornerRadius: CampfireStyle.bubbleRadius))
        .clipShape(RoundedRectangle(cornerRadius: CampfireStyle.bubbleRadius))
        .frame(maxWidth: maximumBubbleWidth, alignment: mine ? .trailing : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var isImage: Bool {
        if case .image? = row.message.attachment { true } else { false }
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            if mine { more }
            if !mine && !row.presentation.isThreaded { Text(author?.name ?? "").bold() }
            Text(row.message.createdAt.formatted(Self.timeFormat)).opacity(0.5)
            if mine && !row.presentation.isThreaded { Text(author?.name ?? "").bold() }
            if !mine { more }
        }
        .font(.system(size: metaSize))
        .frame(minHeight: metaSize * 1.5)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var more: some View {
        Button {} label: {
            CampfireGlyph(kind: .more)
                .frame(width: 32, height: metaSize * 1.5)
                .padding(.leading, mine ? 0 : 1.6)
                .padding(.trailing, mine ? 1.6 : 0)
                .opacity(0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Message options")
    }

    private func file(name: String, bytes: Int) -> some View {
        HStack(spacing: 8) {
            CampfireGlyph(kind: .document).frame(width: 18, height: 22).frame(width: 20)
            Text(name).font(.system(size: bodySize)).lineLimit(1)
            Button {} label: { CampfireGlyph(kind: .download).frame(width: 16, height: 17).frame(width: 28) }
                .accessibilityLabel("Download \(name)")
            Button {} label: { CampfireGlyph(kind: .share).frame(width: 12, height: 18).frame(width: 34.5) }
                .accessibilityLabel("Share \(name)")
        }
        .buttonStyle(.plain)
        .frame(minHeight: max(33.92, bodySize * 1.8))
        .offset(y: 1.5)
        .accessibilityLabel("\(name), \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))")
    }

    private var copyText: String {
        var text = ""
        for block in row.message.blocks {
            switch block {
            case .text(let value): text += value
            case .mention(let id): text += users[id]?.name ?? "@"
            case .code(_, let source): text += (text.isEmpty ? "" : "\n") + source
            }
        }
        if text.isEmpty, case .file(let name, _)? = row.message.attachment { return name }
        return text
    }

    private static let timeFormat = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "en_US"), calendar: Grouping.calendar, timeZone: TimeZone(secondsFromGMT: 0)!)
        .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)

}

private struct MessageBody: View {
    let message: Message
    let users: [Int: User]
    let fontSize: CGFloat
    @Environment(\.displayScale) private var displayScale

    private struct Part: Identifiable {
        // Blocks are immutable for the life of a message; this key identifies the original block run.
        let id: Int
        let blocks: [Block]
    }
    private var parts: [Part] {
        var result: [Part] = []
        var run: [Block] = []
        var key = 0
        for (index, block) in message.blocks.enumerated() {
            if case .code = block {
                if !run.isEmpty { result.append(Part(id: key, blocks: run)); run = [] }
                result.append(Part(id: index, blocks: [block]))
                key = index + 1
            } else {
                if run.isEmpty { key = index }
                run.append(block)
            }
        }
        if !run.isEmpty { result.append(Part(id: key, blocks: run)) }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parts) { part in
                if case .code(_, let source)? = part.blocks.first {
                    CodeBlock(source: source, fontSize: fontSize * 0.8)
                } else {
                    inlineText(part.blocks)
                        .font(.system(size: fontSize))
                        .lineSpacing(fontSize * (part.blocks.contains { if case .mention = $0 { true } else { false } } ? 0.1125 : 0.20625))
                        .padding(.vertical, fontSize * (part.blocks.contains { if case .mention = $0 { true } else { false } } ? 0.003125 : 0.103125))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    private func inlineText(_ blocks: [Block]) -> Text {
        blocks.reduce(Text("")) { text, block in
            switch block {
            case .text(let string): return text + Text(string)
            case .mention(let id):
                guard let user = users[id] else { return text }
                let renderer = ImageRenderer(content: InitialAvatar(user: user, size: fontSize * 1.1))
                renderer.scale = displayScale
                let icon: Text
                if let cgImage = renderer.cgImage {
                    icon = Text(Image(decorative: cgImage, scale: displayScale)).baselineOffset(-fontSize * 0.14)
                } else { icon = Text("@") }
                return text + icon + Text(" " + user.name).fontWeight(.semibold)
            case .code: return text
            }
        }
    }
}

private struct CodeBlock: View {
    let source: String
    let fontSize: CGFloat
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(highlighted)
            .font(.system(size: fontSize, design: .monospaced))
            .tracking(-fontSize / 100)
            .lineSpacing(fontSize * 0.2)
            .padding(12.8)
            .background(RoomColors(scheme).background, in: RoundedRectangle(cornerRadius: 6.4))
            .padding(.top, 1.72)
            .padding(.bottom, 3)
    }
    private var highlighted: AttributedString {
        var value = AttributedString(source)
        let rules: [(String, UInt32, UInt32)] = [
            (#"\b(def|end|let|var|SELECT|FROM|ORDER BY|DESC|LIMIT)\b"#, 0xD73A49, 0xFF7B72),
            (#"\b(greet|print)\b"#, 0x6F42C1, 0xD2A8FF),
            (#"\"[^\"]*\""#, 0x032F62, 0x79C0FF)
        ]
        for (pattern, light, dark) in rules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let range = Range(match.range, in: source),
                      let start = AttributedString.Index(range.lowerBound, within: value),
                      let end = AttributedString.Index(range.upperBound, within: value) else { continue }
                value[start..<end].foregroundColor = Color(hex: scheme == .dark ? dark : light)
            }
        }
        return value
    }
}

private struct BoostPill: View {
    private var isText: Bool { boost.content.contains { $0.isLetter || $0.isNumber || $0 == "+" } }
    let boost: Boost
    let user: User
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .body) private var size = 16.0
    var body: some View {
        HStack(spacing: 4) {
            InitialAvatar(user: user, size: 22.4)
            Text(boost.content).font(.system(size: isText ? size * 5 / 6 : size * 1.1))
        }
        .padding(.leading, 2.6)
        .padding(.trailing, 4.2)
        .frame(minHeight: max(28.64, size * 1.79))
        .background(RoomColors(scheme).background, in: Capsule())
        .overlay(Capsule().strokeBorder(RoomColors(scheme).border, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(user.name) boosted \(boost.content)")
    }
}

struct DaySeparator: View {
    let date: Date
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption) private var size = 12.8
    var body: some View {
        Text(date.formatted(Self.format).uppercased())
            .font(.system(size: size, weight: .semibold))
            .frame(minHeight: size * 1.4)
            .padding(.horizontal, 20.3)
            .padding(.vertical, 8.5)
            .background(RoomColors(scheme).bubble, in: Capsule())
            .frame(maxWidth: .infinity)
            .background { Rectangle().fill(RoomColors(scheme).bubble).frame(height: 2) }
            .padding(.horizontal, CampfireStyle.screenPadding)
            .padding(.top, 17.02)
            .padding(.bottom, 17.02)
    }
    private static let format = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: Grouping.calendar, timeZone: TimeZone(secondsFromGMT: 0)!).month(.wide).day().year()

}
