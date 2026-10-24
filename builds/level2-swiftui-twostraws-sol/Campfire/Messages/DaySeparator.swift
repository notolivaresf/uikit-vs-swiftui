import SwiftUI

struct DaySeparator: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption) private var fontSize = 12.8
    let date: Date

    var body: some View {
        Text(date.formatted(CampfireStyle.dayFormat).uppercased())
            .font(.system(size: fontSize, weight: .semibold))
            .frame(minHeight: fontSize * 1.4)
            .padding(.vertical, 8.5)
            .padding(.horizontal, 23.5)
            .background(CampfireStyle.bubble(scheme), in: .capsule)
            .frame(maxWidth: .infinity)
            .background {
                Rectangle().fill(CampfireStyle.bubble(scheme)).frame(height: 2)
            }
            .padding(.vertical, 17.02)
            .padding(.horizontal, CampfireStyle.screenPadding)
            .accessibilityAddTraits(.isHeader)
    }
}
