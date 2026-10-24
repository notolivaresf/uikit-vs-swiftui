import CampfireKit
import SwiftUI

/// Monospaced, highlighted code in a box of the page background colour.
struct CodeBlockView: View {
    let messageID: MessageID
    let block: Int
    let language: String?
    let source: String
    @Environment(\.metrics) private var metrics

    var body: some View {
        SelectableText(messageID: messageID, block: block, text: highlighted, plain: source,
                       fontSize: metrics.codeSize, lineHeight: metrics.codeLine, ratio: FontRatio.mono)
            .padding(Metrics.codePadding)
            .background(RoundedRectangle(cornerRadius: Metrics.codeRadius).fill(Palette.background))
    }

    private var highlighted: Text {
        var text = Text(verbatim: "")
        for (string, kind) in CodeHighlighter.tokens(source, language: language) {
            let token = Text(verbatim: string).foregroundStyle(CodeHighlighter.color(for: kind))
            text = Text("\(text)\(token)")
        }
        return text.font(.system(size: metrics.codeSize, design: .monospaced))
    }
}
