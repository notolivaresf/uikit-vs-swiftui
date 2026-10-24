import SwiftUI

/// Uppercase date pill on a line, above the first message of each UTC day.
struct DaySeparator: View {
    let date: Date
    @Environment(\.metrics) private var metrics

    var body: some View {
        Text(verbatim: Formatters.dayString(date))
            .font(.system(size: metrics.separatorSize, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .lineHeight(metrics.separatorLine, fontSize: metrics.separatorSize)
            .lineLimit(1)
            .padding(.horizontal, Metrics.separatorPadX)
            .padding(.vertical, Metrics.separatorPadY)
            .background(Capsule().fill(Palette.bubble))
            .frame(maxWidth: .infinity)
            .background {
                Rectangle()
                    .fill(Palette.bubble)
                    .frame(height: Metrics.separatorLineWidth)
            }
            .padding(.top, Metrics.separatorMarginTop)
            .padding(.bottom, Metrics.separatorMarginBottom)
            .accessibilityAddTraits(.isHeader)
    }
}
