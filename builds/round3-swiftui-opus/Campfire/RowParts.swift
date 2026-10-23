import SwiftUI

enum Pasteboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}

/// Round palette-coloured avatar with the white initial.
struct Avatar: View {
    let person: Person
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Circle()
            .fill(AvatarPalette.color(for: person.id))
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: person.initial)
                    .font(.system(size: fontSize, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

struct DaySeparator: View {
    let text: String
    let palette: Palette
    let scale: CGFloat

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: FontSize.separator * scale, weight: .semibold))
            .foregroundStyle(palette.text)
            .lineLimit(1)
            .frame(height: FontSize.separatorLine * scale)
            .padding(.vertical, Metrics.separatorPadY)
            .padding(.horizontal, Metrics.separatorPadX)
            .background(palette.bubble, in: Capsule())
            .frame(maxWidth: .infinity)
            .background {
                Rectangle().fill(palette.border).frame(height: Metrics.separatorLine)
            }
            .accessibilityAddTraits(.isHeader)
    }
}

/// Code block: monospaced 12.8 on 17.92, in a box of the background colour, lightly highlighted.
struct CodeBlock: View {
    let language: String?
    let source: String
    let palette: Palette
    let scale: CGFloat
    /// Set while the row is selected.
    var model: RoomModel? = nil

    var body: some View {
        let size = FontSize.code * scale
        let gap = (FontSize.codeLine - TypeScale.naturalLineHeight(FontSize.code)) * scale
        let highlighted = SyntaxHighlighter.highlight(source, language: language, palette: palette)
        let text = Text(highlighted)
        VStack(alignment: .leading, spacing: 0) {
            SelectableBlock(content: text, text: { highlighted }, model: model)
        }
            .font(.system(size: size, design: .monospaced))
            .tracking(-0.2 * scale)
            .foregroundStyle(palette.text)
            .lineSpacing(gap)
            .padding(.vertical, gap / 2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Metrics.codePadding)
            .background(palette.codeBox, in: RoundedRectangle(cornerRadius: Metrics.codeRadius))
            .padding(.bottom, 1)
    }
}

enum SyntaxHighlighter {
    private static let keywords: Set<String> = [
        "def", "end", "class", "module", "if", "else", "elsif", "unless", "do", "return", "while", "puts", "self",
        "let", "var", "func", "import", "struct", "guard", "in", "for", "print",
        "SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT", "AND", "OR", "JOIN", "ON",
    ]
    private static let shellCommands: Set<String> = ["kamal", "curl", "echo", "cd", "git"]
    private static let rubyBuiltins: Set<String> = ["puts", "print"]

    static func highlight(_ source: String, language: String?, palette: Palette) -> AttributedString {
        var out = AttributedString()
        let chars = Array(source)
        var i = 0
        var previousWord = ""
        func emit(_ s: String, _ color: Color?) {
            var a = AttributedString(s)
            if let color { a.foregroundColor = color }
            out += a
        }
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count, chars[j] != c, chars[j] != "\n" { j += 1 }
                j = min(j + 1, chars.count)
                emit(String(chars[i..<j]), palette.codeString)
                i = j
            } else if c == "#" && language != "ruby" || (c == "-" && i + 1 < chars.count && chars[i + 1] == "-") {
                var j = i
                while j < chars.count, chars[j] != "\n" { j += 1 }
                emit(String(chars[i..<j]), palette.codeComment)
                i = j
            } else if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                let word = String(chars[i..<j])
                let color: Color?
                if previousWord == "def" || previousWord == "func" || previousWord == "class" {
                    color = palette.codeEntity
                } else if language == "ruby" && rubyBuiltins.contains(word) {
                    color = nil
                } else if keywords.contains(word) {
                    color = palette.codeKeyword
                } else if language == "sh" && shellCommands.contains(word) && (i == 0 || chars[i - 1] == "\n") {
                    color = palette.codeEntity
                } else {
                    color = nil
                }
                emit(word, color)
                previousWord = word
                i = j
            } else if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
                emit(String(chars[i..<j]), palette.codeConstant)
                i = j
            } else {
                emit(String(c), nil)
                if !c.isWhitespace { previousWord = "" }
                i += 1
            }
        }
        return out
    }
}

/// File attachment: document icon, name, download and share buttons (they do nothing).
struct FileLine: View {
    let name: String
    let size: String
    let palette: Palette
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20 * scale))
                .foregroundStyle(palette.text)
                .frame(width: 18.6 * scale)
                .padding(.trailing, 7)
            Text(verbatim: name)
                .font(.system(size: FontSize.body * scale))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .accessibilityLabel("\(name), \(size)")
            Button {} label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .frame(width: 33.92 * scale, height: 33.92 * scale)
            }
            .accessibilityLabel("Download \(name)")
            .padding(.leading, 6)
            Button {} label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15 * scale, weight: .medium))
                    .frame(width: 33.92 * scale, height: 33.92 * scale)
            }
            .accessibilityLabel("Share \(name)")
            .padding(.leading, 5)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.text)
        .frame(height: 33.92 * scale)
    }
}

/// Boost pills (booster's avatar plus the emoji or short text) that wrap, ending with the add-boost button.
struct BoostStrip: View {
    let boosts: [BoostItem]
    let palette: Palette
    let scale: CGFloat

    var body: some View {
        FlowLayout(spacing: Metrics.boostGap, lineSpacing: Metrics.boostGap) {
            ForEach(boosts) { boost in
                BoostPill(boost: boost, palette: palette, scale: scale)
            }
            Button {} label: {
                AddBoostIcon(palette: palette)
                    .frame(width: Metrics.boostHeight, height: Metrics.boostHeight)
                    .background(palette.background, in: Circle())
                    .overlay(Circle().strokeBorder(palette.borderDark, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a boost")
        }
    }
}

struct BoostPill: View {
    let boost: BoostItem
    let palette: Palette
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 5) {
            Avatar(person: boost.booster, size: Metrics.boostAvatar, fontSize: 11)
            Text(verbatim: boost.content)
                .font(.system(size: FontSize.boost * scale))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 1)
        .padding(.trailing, 8)
        .frame(minHeight: Metrics.boostHeight - 2)
        .padding(1)
        .background(palette.background, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.borderDark, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(boost.booster.name): \(boost.content)")
    }
}

struct AddBoostIcon: View {
    let palette: Palette

    var body: some View {
        Image(systemName: "face.smiling")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(palette.text)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(palette.text)
                    .padding(1)
                    .background(palette.background, in: Circle())
                    .offset(x: 2.5, y: 2.5)
            }
    }
}

extension String {
    /// True when every character is an emoji (shown at emoji size in boost pills).
    var isEmojiOnly: Bool {
        let t = trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.allSatisfy { c in
            guard let first = c.unicodeScalars.first else { return false }
            return first.properties.isEmojiPresentation
                || (first.properties.isEmoji && c.unicodeScalars.count > 1)
        }
    }
}

/// Left-to-right flow that wraps onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, width: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width
            width = max(width, x)
            x += spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX + 0.5 {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
