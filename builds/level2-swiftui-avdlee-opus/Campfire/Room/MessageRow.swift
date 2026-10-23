import SwiftUI
import CampfireKit

extension EnvironmentValues {
    @Entry var palette: Palette = .light
}

/// Long-press menu for a message: Copy (the message text) and Reply (drawn only).
struct MessageMenu: ViewModifier {
    let text: String
    let shape: RoundedRectangle
    @Environment(\.selectTextAction) private var selectText

    func body(content: Content) -> some View {
        content
            .contentShape(.contextMenuPreview, shape)
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(text) }
                Button("Reply", systemImage: "arrowshape.turn.up.left") {}
                if let selectText, !text.isEmpty {
                    Button("Select Text", systemImage: "selection.pin.in.out") { selectText.handler(text) }
                }
            }
    }
}

/// Opens a message's text for range selection. A class so the environment value keeps one identity.
@MainActor
final class SelectTextAction {
    var handler: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    @Entry var selectTextAction: SelectTextAction? = nil
}

/// One message: optional day separator, then the bubble with avatar, meta line, body and boosts.
struct MessageRow: View, Equatable {
    let row: RowData

    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    nonisolated static func == (a: MessageRow, b: MessageRow) -> Bool { a.row == b.row }

    var body: some View {
        let ts = TypeScale(dynamicTypeSize)
        VStack(spacing: 0) {
            if let day = row.day {
                DaySeparator(text: day, ts: ts)
            }
            bubbleLine(ts: ts)
                .padding(.top, Metrics.bubbleTopInRow)
                .padding(.bottom, Metrics.bubbleBottomMargin)
        }
        .padding(.horizontal, Metrics.screenPaddingX)
    }

    private func bubbleLine(ts: TypeScale) -> some View {
        let inset = Metrics.bubbleLeft - Metrics.screenPaddingX
        return HStack(spacing: 0) {
            if row.isMine { Spacer(minLength: 0) }
            MessageBubble(row: row, ts: ts)
            if !row.isMine { Spacer(minLength: 0) }
        }
        .padding(row.isMine ? .trailing : .leading, inset)
        .padding(row.isMine ? .leading : .trailing, Metrics.bubbleRightInset - Metrics.screenPaddingX)
        .overlay(alignment: row.isMine ? .topTrailing : .topLeading) {
            if !row.isThreaded {
                Avatar(userID: row.authorID, initial: row.authorInitial, size: Metrics.avatarSize, fontSize: 16)
                    .background(Circle().fill(palette.background).padding(-Metrics.avatarRing))
                    .accessibilityHidden(true)
            }
        }
    }
}

struct Avatar: View {
    let userID: UserID
    let initial: String
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Circle()
            .fill(Palette.avatarColor(for: userID))
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: initial)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

struct DaySeparator: View {
    let text: String
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: ts(12.8), weight: .semibold))
            .foregroundStyle(palette.text)
            .cssLineHeight(fontSize: ts(12.8), lineHeight: ts(17.92), raise: 0.8)
            .padding(.vertical, 8.5)
            .padding(.horizontal, 23.5)
            .background(Capsule().fill(palette.bubble))
            .frame(maxWidth: .infinity)
            .background {
                Rectangle().fill(palette.bubble).frame(height: 2)
            }
            .padding(.vertical, 17.02)
            .accessibilityAddTraits(.isHeader)
    }
}

struct MessageBubble: View {
    let row: RowData
    let ts: TypeScale
    @Environment(\.palette) private var palette

    private var hasImage: Bool { if case .image? = row.attachment { true } else { false } }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .circular)
        FitContentLayout(maxWidth: hasImage ? Metrics.imageMaxWidth : .infinity, fillsWidth: hasImage) {
            content
        }
        .background {
            if row.mentionsMe {
                shape.fill(palette.background)
                shape.fill(palette.mentionedBubble)
            } else if !row.isEmojiOnly {
                shape.fill(palette.bubble)
            }
        }
        .modifier(MessageMenu(text: row.plainText, shape: shape))
        // One element per message with a prepared label: cheap for VoiceOver and UI tests even while streaming.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("message-\(row.id)")
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: row.isMine ? .trailing : .leading, spacing: 0) {
            MetaLine(row: row, ts: ts)
                .padding(.horizontal, Metrics.bubblePaddingX)
                .padding(.top, Metrics.bubblePaddingY + 1.6)
            VStack(alignment: .leading, spacing: 0) {
                body(ts: ts)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 1.16)
            if !row.boosts.isEmpty {
                BoostStrip(boosts: row.boosts, ts: ts)
                    .padding(.horizontal, hasImage ? 10 : Metrics.bubblePaddingX)
                    .padding(.top, hasImage ? 4.33 : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer().frame(height: hasImage && !row.boosts.isEmpty ? 8.33 : Metrics.bubblePaddingY)
        }
    }

    @ViewBuilder private func body(ts: TypeScale) -> some View {
        let textParts = row.parts.filter { if case .code = $0 { false } else { true } }
        if row.isEmojiOnly {
            BodyText(parts: row.parts, ts: ts, emoji: true)
                .padding(.horizontal, Metrics.bubblePaddingX)
        } else {
            if !textParts.isEmpty {
                BodyText(parts: textParts, ts: ts, emoji: false)
                    .padding(.horizontal, Metrics.bubblePaddingX)
            }
            ForEach(Array(row.parts.enumerated()), id: \.offset) { _, part in
                if case .code(let language, let source) = part {
                    CodeBlock(source: source, language: language, ts: ts)
                        .padding(.horizontal, Metrics.bubblePaddingX)
                        .padding(.top, textParts.isEmpty ? 1.43 : 8)
                        .padding(.bottom, 1.67)
                }
            }
            switch row.attachment {
            case .image(let width, let height, let color)?:
                ImageAttachment(width: width, height: height, color: color)
                    .padding(.top, 11.6)
            case .file(let name, let bytes)?:
                FileAttachment(name: name, bytes: bytes, ts: ts)
                    .padding(.horizontal, Metrics.bubblePaddingX)
            case nil:
                EmptyView()
            }
        }
    }
}

struct MetaLine: View {
    let row: RowData
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if row.isMine {
                Spacer().frame(width: 16)
                ActionsButton(ts: ts)
                time
                if !row.isThreaded { Text(verbatim: " ").font(.system(size: ts(12.8))); name }
            } else {
                if !row.isThreaded { name; Text(verbatim: " ").font(.system(size: ts(12.8))) }
                time
                ActionsButton(ts: ts)
            }
        }
        .cssLineHeight(fontSize: ts(12.8), lineHeight: ts(19.2), raise: 0.33)
        .fixedSize()
    }

    private var name: some View {
        Text(verbatim: row.authorName)
            .font(.system(size: ts(12.8), weight: .bold))
            .foregroundStyle(palette.text)
    }

    private var time: some View {
        Text(verbatim: row.time)
            .font(.system(size: ts(12.8)))
            .foregroundStyle(palette.text.opacity(0.5))
    }
}

/// Campfire's "•••" message menu button. Drawn only.
struct ActionsButton: View {
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in Circle().frame(width: 4.33, height: 4.33) }
        }
        .foregroundStyle(palette.text.opacity(0.5))
        .frame(width: 44)
        .offset(x: -1.3)
        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 3.2 }
        .accessibilityHidden(true)
    }
}

/// Paragraph text with inline mention pills.
struct BodyText: View {
    let parts: [RowData.Part]
    let ts: TypeScale
    let emoji: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        let size = emoji ? ts(38.4) : ts(16)
        let line = emoji ? ts(53.76) : ts(22.4)
        composed(size: size)
            .font(.system(size: size))
            .kerning(emoji ? -ts(5) : 0)
            .foregroundStyle(palette.text)
            .overlay(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
                // A mention that opens the message gets its avatar drawn here, over a transparent spacer in the
                // text: an inline image would make SwiftUI grow that line, which Campfire does not.
                if case .mention(let id, let name)? = parts.first {
                    Avatar(userID: id, initial: RowBuilder.initial(name), size: ts(17.3), fontSize: ts(17.3) * 0.45)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                        .offset(x: ts(1.1), y: ts(3.4))
                        .accessibilityHidden(true)
                }
            }
            .cssLineHeight(fontSize: size, lineHeight: line, raise: emoji ? 1 : -0.2)
            .offset(x: emoji ? -2 : 0)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private func composed(size: CGFloat) -> Text {
        var result = Text(verbatim: "")
        for (index, part) in parts.enumerated() {
            switch part {
            case .text(let t):
                result = Text("\(result)\(Text(verbatim: t))")
            case .mention(_, let name):
                let pill: Text
                if index == 0 {
                    // Room for the avatar drawn over the text: a no-break space widened by kerning (about 4.4 pt
                    // wide at 16 pt, so 17.3 more makes the 21.7 pt Campfire leaves before the name).
                    let space = Text(verbatim: "\u{00A0}").kerning(ts(1.1 + 17.3 + 3.3) - ts(4.42))
                    pill = Text("\(space)\(Text(verbatim: name).font(.system(size: size, weight: .semibold)))")
                } else {
                    // CampfireKit only puts mentions first; a later one reads as a bold @name.
                    pill = Text(verbatim: "@" + name).font(.system(size: size, weight: .semibold))
                }
                result = Text("\(result)\(pill)")
            case .code:
                break
            }
        }
        return result
    }
}

struct CodeBlock: View {
    let source: String
    let language: String?
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        Text(CodeHighlighter.attributed(source, language: language, palette: palette))
            .font(.system(size: ts(12.8), design: .monospaced))
            .kerning(-0.13)
            .cssLineHeight(fontSize: ts(12.8), lineHeight: ts(17.92), ratio: FontMetrics.monoLineHeightRatio, raise: 1.0)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(12.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6.4).fill(palette.codeBackground))
    }
}

struct ImageAttachment: View {
    let width: Int
    let height: Int
    let color: RGB

    var body: some View {
        // CampfireKit's Placeholder is a solid PNG of this colour and pixel size; a filled rectangle is the same.
        Rectangle()
            .fill(Color(color))
            .aspectRatio(CGFloat(width) / CGFloat(max(1, height)), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 1)
            .accessibilityLabel("Image")
    }
}

struct FileAttachment: View {
    let name: String
    let bytes: Int
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.plaintext.fill")
                .font(.system(size: ts(21)))
                .frame(width: 20)
            Text(verbatim: name)
                .font(.system(size: ts(16)))
                .padding(.leading, 6)
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: ts(16), weight: .bold))
                .scaleEffect(x: 1.3, y: 1)
                .padding(.leading, 16)
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: ts(14.8), weight: .semibold))
                .scaleEffect(x: 0.85, y: 1)
                .padding(.leading, 21)
        }
        .offset(y: 1)
        .foregroundStyle(palette.text)
        .frame(minHeight: 33.92)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(Formatting.fileSize(bytes))")
    }
}

/// Boost pills (booster avatar + emoji or text) and the add-boost button, wrapping onto new lines.
struct BoostStrip: View {
    let boosts: [RowData.BoostData]
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(boosts) { boost in
                BoostPill(boost: boost, ts: ts)
            }
            AddBoostButton(ts: ts)
        }
    }
}

struct BoostPill: View {
    let boost: RowData.BoostData
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        let isEmoji = boost.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
        HStack(spacing: 0) {
            Avatar(userID: boost.boosterID, initial: boost.initial, size: 23, fontSize: 11.5)
            Text(verbatim: boost.content)
                .font(.system(size: isEmoji ? ts(14.4) : ts(13.2)))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .padding(.leading, 4.3)
                .padding(.trailing, 7)
        }
        .padding(.leading, 2.6)
        .frame(minHeight: 28.64)
        .background(Capsule().fill(palette.boostBackground))
        .overlay(Capsule().strokeBorder(palette.borderDark, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boost \(boost.content)")
    }
}

struct AddBoostButton: View {
    let ts: TypeScale
    @Environment(\.palette) private var palette

    var body: some View {
        SmileyPlusIcon()
            .stroke(palette.text, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            .frame(width: 15.5, height: 15.5)
            .offset(x: 0.7, y: 1)
            .frame(width: 28.64, height: 28.64)
            .background(Circle().fill(palette.boostBackground))
            .overlay(Circle().strokeBorder(palette.borderDark, lineWidth: 1))
            .accessibilityElement()
            .accessibilityLabel("Add boost")
    }
}

/// Campfire's add-boost glyph: an open smiley with a plus tucked into its lower right.
struct SmileyPlusIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let c = CGPoint(x: rect.minX + s * 0.46, y: rect.minY + s * 0.46)
        let r = s * 0.42
        var p = Path()
        // Face outline, open towards the plus.
        p.addArc(center: c, radius: r, startAngle: .degrees(80), endAngle: .degrees(10), clockwise: false)
        // Eyes.
        for dx in [-0.15, 0.15] {
            let e = CGPoint(x: c.x + s * dx, y: c.y - s * 0.1)
            p.move(to: e)
            p.addLine(to: CGPoint(x: e.x, y: e.y + s * 0.05))
        }
        // Smile.
        let m = CGPoint(x: c.x, y: c.y + s * 0.02)
        let mr = s * 0.2
        p.move(to: CGPoint(x: m.x + mr * cos(.pi / 6), y: m.y + mr * sin(.pi / 6)))
        p.addArc(center: m, radius: mr, startAngle: .degrees(30), endAngle: .degrees(150), clockwise: false)
        // Plus.
        let q = CGPoint(x: rect.minX + s * 0.84, y: rect.minY + s * 0.84)
        let a = s * 0.17
        p.move(to: CGPoint(x: q.x - a, y: q.y)); p.addLine(to: CGPoint(x: q.x + a, y: q.y))
        p.move(to: CGPoint(x: q.x, y: q.y - a)); p.addLine(to: CGPoint(x: q.x, y: q.y + a))
        return p
    }
}

enum Clipboard {
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}

