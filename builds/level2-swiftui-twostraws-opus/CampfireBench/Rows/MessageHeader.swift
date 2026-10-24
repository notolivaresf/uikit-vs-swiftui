import SwiftUI

/// Name, time and the options button. Mine is reversed and right-aligned; threaded rows drop the name.
struct MessageHeader: View {
    let name: String?
    let time: String
    let isMine: Bool
    @Environment(\.metrics) private var metrics

    var body: some View {
        HStack(spacing: 0) {
            if isMine {
                options.padding(.trailing, 12.5)
                timeText
                if let name { nameText(name).padding(.leading, 4) }
            } else {
                if let name { nameText(name).padding(.trailing, 4) }
                timeText
                options.padding(.leading, 12.5)
            }
        }
        .lineLimit(1)
        .frame(height: metrics.headerHeight)
    }

    private func nameText(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.system(size: metrics.metaSize, weight: .bold))
            .foregroundStyle(Palette.ink)
    }

    private var timeText: some View {
        Text(verbatim: time)
            .font(.system(size: metrics.metaSize))
            .foregroundStyle(Palette.ink.opacity(0.5))
    }

    private var options: some View {
        Image(systemName: "ellipsis")
            .resizable()
            .scaledToFit()
            .fontWeight(.black)
            .frame(width: 16.5 * metrics.scale, height: 4.6 * metrics.scale)
            .foregroundStyle(Palette.ink.opacity(0.5))
            .frame(height: metrics.headerHeight)
            .accessibilityLabel("Message options")
    }
}
