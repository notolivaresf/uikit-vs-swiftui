import SwiftUI

/// File icon, name, and the download and share buttons (which do nothing).
struct FileAttachmentView: View {
    let name: String
    let bytes: Int
    @Environment(\.metrics) private var metrics

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.plaintext.fill")
                .font(.system(size: 22))
                .foregroundStyle(Palette.ink)
                .frame(width: 19)
                .padding(.trailing, 7)
            Text(verbatim: name)
                .font(.system(size: metrics.bodySize))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .padding(.trailing, 6)
            Button {} label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: Metrics.fileButton, height: Metrics.fileButton)
            }
            .accessibilityLabel("Download \(name)")
            Button {} label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: Metrics.fileButton, height: Metrics.fileButton)
            }
            .padding(.leading, 5)
            .accessibilityLabel("Share \(name)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
        .frame(height: Metrics.fileRowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name), \(Formatters.fileSize(bytes))")
    }
}
