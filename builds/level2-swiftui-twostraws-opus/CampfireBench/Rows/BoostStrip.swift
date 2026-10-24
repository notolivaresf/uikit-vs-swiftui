import SwiftUI

/// Boost pills (booster's avatar plus the emoji or short text), ending with the add-boost button. Wraps.
struct BoostStrip: View {
    let boosts: [BoostItem]
    @Environment(\.metrics) private var metrics
    @Environment(\.users) private var users

    var body: some View {
        FlowLayout(spacing: Metrics.boostSpacing, lineSpacing: Metrics.boostSpacing) {
            ForEach(boosts) { boost in
                pill(boost)
            }
            Button {} label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 15, weight: .semibold))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "plus")
                            .font(.system(size: 7, weight: .black))
                            .padding(1)
                            .background(Circle().fill(Palette.background))
                            .offset(x: 3, y: 2)
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(width: Metrics.boostHeight, height: Metrics.boostHeight)
                    .background(Circle().fill(Palette.background))
                    .overlay(Circle().strokeBorder(Palette.borderDark, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a boost")
        }
    }

    private func pill(_ boost: BoostItem) -> some View {
        let name = users.name(boost.boosterID)
        let isEmoji = boost.content.allSatisfy { $0.unicodeScalars.contains { $0.properties.isEmojiPresentation } }
        return HStack(spacing: 5) {
            AvatarView(userID: boost.boosterID, name: name, size: Metrics.boostAvatar, fontSize: 12)
            Text(verbatim: boost.content)
                .font(.system(size: isEmoji ? metrics.boostEmojiSize : metrics.boostTextSize))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
        }
        .padding(.leading, 2.3)
        .padding(.trailing, isEmoji ? 7 : 9)
        .frame(minHeight: Metrics.boostHeight)
        .background(Capsule().fill(Palette.background))
        .overlay(Capsule().strokeBorder(Palette.borderDark, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) boosted \(boost.content)")
    }
}
