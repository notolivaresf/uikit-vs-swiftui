import SwiftUI

struct CodeBlockView: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption) private var fontSize = 12.8
    let source: String

    var body: some View {
        SelectableMessageText(text: Text(highlightedSource), plainText: source)
            .font(.system(size: fontSize, design: .monospaced))
            .lineSpacing(fontSize * 0.20625)
            .padding(.vertical, fontSize * 0.103125 + 1.2)
            .padding(12.8)
            .background(CampfireStyle.background(scheme), in: .rect(cornerRadius: 6.4))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var highlightedSource: AttributedString {
        var result = AttributedString(source)
        let keywords = ["def", "end", "let", "var", "func", "return", "SELECT", "FROM", "ORDER", "BY", "DESC", "LIMIT"]
        for word in keywords {
            for range in source.ranges(of: word) {
                guard let start = AttributedString.Index(range.lowerBound, within: result),
                      let end = AttributedString.Index(range.upperBound, within: result) else { continue }
                result[start..<end].foregroundColor = CampfireStyle.color(scheme == .dark ? 0xFF7B72 : 0xD73A49)
            }
        }
        if let range = source.range(of: "greet"),
           let start = AttributedString.Index(range.lowerBound, within: result),
           let end = AttributedString.Index(range.upperBound, within: result) {
            result[start..<end].foregroundColor = CampfireStyle.color(scheme == .dark ? 0xD2A8FF : 0x6F42C1)
        }
        if let start = source.firstIndex(of: "\""), let end = source.lastIndex(of: "\""), start != end,
           let a = AttributedString.Index(start, within: result),
           let b = AttributedString.Index(source.index(after: end), within: result) {
            result[a..<b].foregroundColor = CampfireStyle.color(scheme == .dark ? 0x79C0FF : 0x032F62)
        }
        return result
    }
}
