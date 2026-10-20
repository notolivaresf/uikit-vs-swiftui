import SwiftUI

/// One message: optional day separator, then the bubble with the avatar overlapping its corner.
struct MessageRow: View, Equatable {
    nonisolated static let contentSpace = "room-content"

    let row: RowModel
    let palette: Palette
    let scale: CGFloat
    let selection: MessageSelection?
    let model: RoomModel

    /// Where the bubble starts inside the row (below the day separator, if any).
    private var bubbleTop: CGFloat {
        guard row.daySeparator != nil else { return Metrics.bubbleTopMargin }
        return 2 * Metrics.separatorMarginY + 2 * Metrics.separatorPadY + FontSize.separatorLine * scale + Metrics.bubbleTopMargin
    }

    nonisolated static func == (a: MessageRow, b: MessageRow) -> Bool {
        a.row == b.row && a.palette == b.palette && a.scale == b.scale && a.selection == b.selection
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: row.isThreaded ? 0 : Metrics.rowGap)
            RowContent(row: row, palette: palette, scale: scale, selection: selection, model: model)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityText)
                .accessibilityIdentifier("message-\(row.id)")
                .overlay(alignment: row.isMine ? .topTrailing : .topLeading) {
                    // Outside the row's accessibility element so its buttons stay reachable.
                    if selection != nil {
                        SelectionMenu(palette: palette, onCopy: { model.copySelection() }, onReply: { model.clearSelection() })
                            .padding(.horizontal, row.isMine ? Metrics.bubbleLeft : Metrics.bubbleLeft + 4)
                            .offset(y: bubbleTop - 48)
                    }
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.contentSpace)) } action: { frame in
                    model.rowFrameChanged(row.id, frame)
                }
        }
    }
}

struct RowContent: View {
    let row: RowModel
    let palette: Palette
    let scale: CGFloat
    var selection: MessageSelection? = nil
    var model: RoomModel? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let day = row.daySeparator {
                DaySeparator(text: day, palette: palette, scale: scale)
                    .padding(.vertical, Metrics.separatorMarginY)
            }
            ZStack(alignment: row.isMine ? .topTrailing : .topLeading) {
                MessageBubble(row: row, palette: palette, scale: scale, selection: selection, model: model)
                    .padding(.leading, row.isMine ? Metrics.mineMinLeft - Metrics.screenPaddingX
                                                  : Metrics.bubbleLeft - Metrics.screenPaddingX)
                    .padding(.trailing, row.isMine ? Metrics.bubbleLeft - Metrics.screenPaddingX : 0)
                    .frame(maxWidth: .infinity, alignment: row.isMine ? .trailing : .leading)
                if !row.isThreaded {
                    Avatar(person: row.author, size: Metrics.avatarSize, fontSize: 16)
                        .background(Circle().fill(palette.background).padding(-Metrics.avatarRing))
                }
            }
            .padding(.top, row.isThreaded ? Metrics.threadedTopMargin : Metrics.bubbleTopMargin)
            .padding(.bottom, Metrics.bubbleBottomMargin)
        }
        .padding(.horizontal, Metrics.screenPaddingX)
    }
}

struct MessageBubble: View {
    let row: RowModel
    let palette: Palette
    let scale: CGFloat
    let selection: MessageSelection?
    let model: RoomModel?

    private var hasImage: Bool {
        if case .image = row.attachment { true } else { false }
    }

    private var fill: Color {
        if row.isEmojiOnly { return .clear }
        return row.mentionsMe ? palette.mentioned : palette.bubble
    }

    var body: some View {
        BubbleStack(trailingFirst: row.isMine) {
            MetaLine(row: row, palette: palette, scale: scale)
                .padding(.horizontal, Metrics.bubblePaddingX)
                .padding(.top, Metrics.bubblePaddingY)
            if case .image(let w, let h, let r, let g, let b) = row.attachment {
                Rectangle()
                    .fill(Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255))
                    .frame(width: Metrics.imageWidth, height: Metrics.imageWidth * CGFloat(h) / CGFloat(max(w, 1)))
                    .overlay(Rectangle().strokeBorder(fill, lineWidth: 1))
                    .padding(.top, Metrics.bubblePaddingY)
                    .accessibilityLabel("Image")
            }
            ForEach(Array(row.parts.enumerated()), id: \.offset) { i, part in
                BodyPartView(part: part, isEmojiOnly: row.isEmojiOnly, palette: palette, scale: scale,
                             selection: selection?.part == i ? selection : nil, rowID: row.id, index: i, model: model)
                    .padding(.horizontal, Metrics.bubblePaddingX)
                    .padding(.top, (i > 0 || hasImage) ? 4 : 0)
            }
            if case .file(let name, let size) = row.attachment {
                FileLine(name: name, size: size, palette: palette, scale: scale)
                    .padding(.horizontal, Metrics.bubblePaddingX)
            }
            if !row.boosts.isEmpty {
                BoostStrip(boosts: row.boosts, palette: palette, scale: scale)
                    .padding(.horizontal, hasImage && row.parts.isEmpty ? Metrics.imageBoostPaddingX : Metrics.bubblePaddingX)
                    .padding(.top, Metrics.boostMarginTop + (hasImage && row.parts.isEmpty ? 1 : 0))
            }
        }
        .padding(.bottom, bottomPadding)
        .background(fill, in: RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .circular))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .circular))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .circular))
        .onLongPressGesture(minimumDuration: 0.45) {
            model?.beginSelection(rowID: row.id)
        }
    }

    private var bottomPadding: CGFloat {
        if hasImage && row.parts.isEmpty { return row.boosts.isEmpty ? 0 : 8 }
        return Metrics.bubblePaddingY
    }
}

/// A vertical stack whose width fits its widest child; the first child (the meta line) can hug the
/// trailing edge for my own messages while everything else stays leading.
struct BubbleStack: Layout {
    var trailingFirst: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Like a CSS block: a child whose one-line (ideal) width does not fit wraps and makes the
        // bubble take the whole width; otherwise the bubble hugs its widest child.
        var width: CGFloat = 0
        for s in subviews { width = max(width, s.sizeThatFits(.unspecified).width) }
        if let w = proposal.width { width = min(width, w) }
        var height: CGFloat = 0
        for s in subviews { height += s.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (i, s) in subviews.enumerated() {
            let size = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            let x = (i == 0 && trailingFirst) ? bounds.maxX - size.width : bounds.minX
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            y += size.height
        }
    }
}

/// "Name 9:00 AM •••", reversed for my own messages; threaded rows show only the time.
struct MetaLine: View {
    let row: RowModel
    let palette: Palette
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            if row.isMine {
                MoreDots(palette: palette)
                    .padding(.trailing, 13)
                time
                if !row.isThreaded { name.padding(.leading, 4) }
            } else {
                if !row.isThreaded { name.padding(.trailing, 4) }
                time
                MoreDots(palette: palette)
                    .padding(.leading, 13)
            }
        }
        .frame(height: Metrics.headerLineHeight * scale)
    }

    private var name: some View {
        Text(row.author.name)
            .font(.system(size: FontSize.meta * scale, weight: .bold))
            .foregroundStyle(palette.text)
            .lineLimit(1)
    }

    private var time: some View {
        Text(row.time)
            .font(.system(size: FontSize.meta * scale))
            .foregroundStyle(palette.text.opacity(0.5))
            .lineLimit(1)
            .fixedSize()
    }
}

struct MoreDots: View {
    let palette: Palette

    var body: some View {
        HStack(spacing: 1.8) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().frame(width: 4.4, height: 4.4)
            }
        }
        .foregroundStyle(palette.text.opacity(0.5))
        .accessibilityLabel("More")
    }
}

struct BodyPartView: View {
    let part: BodyPart
    let isEmojiOnly: Bool
    let palette: Palette
    let scale: CGFloat
    let selection: MessageSelection?
    let rowID: Int
    let index: Int
    let model: RoomModel?

    var body: some View {
        switch part {
        case .paragraph(let inline):
            if isEmojiOnly {
                Text(inline.plainText)
                    .font(.system(size: FontSize.emojiOnly * scale))
                    .frame(height: FontSize.emojiOnlyLine * scale)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                RichText(parts: inline, palette: palette, scale: scale, selection: selection?.range, rowID: rowID,
                         index: index, model: model)
            }
        case .code(let language, let source):
            CodeBlock(language: language, source: source, palette: palette, scale: scale, selection: selection?.range,
                      rowID: rowID, index: index, model: model)
        }
    }
}

extension [InlinePart] {
    var plainText: String {
        map {
            switch $0 {
            case .text(let t): t
            case .mention(let p): p.name
            }
        }.joined()
    }
}

/// Body text with inline mentions (avatar + bold name), 16 pt on a 22.4 pt line.
struct RichText: View {
    let parts: [InlinePart]
    let palette: Palette
    let scale: CGFloat
    var selection: NSRange? = nil
    var rowID = 0
    var index = 0
    var model: RoomModel? = nil

    var body: some View {
        let gap = (FontSize.bodyLine - TypeScale.naturalLineHeight(FontSize.body)) * scale
        VStack(alignment: .leading, spacing: 0) {
            if let model, selection != nil {
                SelectableText(text: rendered, characters: parts.layoutCharacters, selection: selection, rowID: rowID,
                               part: index, palette: palette, model: model)
                    .coordinateSpace(.named(SelectionHandles.space))
            } else {
                rendered
            }
        }
        .font(.system(size: FontSize.body * scale))
        .foregroundStyle(palette.text)
        .lineSpacing(gap)
        .padding(.vertical, gap / 2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var hasMention: Bool { parts.contains { if case .mention = $0 { true } else { false } } }

    /// Mentions need the renderer that draws their avatars; plain paragraphs skip it.
    @ViewBuilder private var rendered: some View {
        if hasMention {
            text.textRenderer(MentionRenderer(scale: scale))
        } else {
            text
        }
    }

    private var text: Text {
        var result = Text(verbatim: "")
        for part in parts {
            switch part {
            case .text(let t):
                result = Text("\(result)\(Text(verbatim: t))")
            case .mention(let person):
                // A transparent placeholder short enough not to grow the line; MentionRenderer draws the
                // avatar over it, reaching below the baseline like Campfire's.
                let slot = Text(MentionRenderer.placeholder(scale: scale)).customAttribute(MentionAvatar(person: person))
                let name = Text(verbatim: person.name).fontWeight(.semibold)
                result = Text("\(result)\(slot)\(name)")
            }
        }
        return result
    }
}

struct MentionAvatar: TextAttribute {
    let person: Person
}

struct MentionRenderer: TextRenderer {
    let scale: CGFloat
    static let diameter: CGFloat = 17
    static let gap: CGFloat = 2.7
    static let belowBaseline: CGFloat = 4

    static func placeholder(scale: CGFloat) -> Image {
        Image(size: CGSize(width: (diameter + gap) * scale, height: 10 * scale)) { _ in }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let mention = run[MentionAvatar.self] else {
                    ctx.draw(run)
                    continue
                }
                let bounds = run.typographicBounds
                let d = Self.diameter * scale
                let rect = CGRect(x: bounds.rect.minX, y: bounds.origin.y + Self.belowBaseline * scale - d, width: d, height: d)
                ctx.fill(Path(ellipseIn: rect), with: .color(AvatarPalette.color(for: mention.person.id)))
                ctx.draw(Text(verbatim: mention.person.initial)
                            .font(.system(size: 8.5 * scale, weight: .heavy))
                            .foregroundStyle(.white),
                         at: CGPoint(x: rect.midX, y: rect.midY))
            }
        }
    }
}
