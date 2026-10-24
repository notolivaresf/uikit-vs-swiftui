import SwiftUI

struct FileAttachmentView: View {
    @ScaledMetric(relativeTo: .body) private var fontSize = 16.0
    let name: String
    let bytes: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "doc.text.fill").font(.system(size: 22))
            SelectableMessageText(text: Text(name), plainText: name)
                .font(.system(size: fontSize)).lineLimit(2)
            Button("Download \(name)", systemImage: "arrow.down.to.line") {}
                .labelStyle(.iconOnly)
            Button("Share \(name)", systemImage: "square.and.arrow.up") {}
                .labelStyle(.iconOnly)
                .padding(.leading, 8)
                .padding(.trailing, 5.1)
        }
        .buttonStyle(.plain)
        .font(.system(size: 19, weight: .semibold))
        .frame(minHeight: 24)
        .accessibilityValue(bytes.formatted(.byteCount(style: .file)))
    }
}
