import SwiftUI
import CampfireKit

struct BoostStrip: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .body) private var textSize = 16.0
    let boosts: [Boost]
    let users: [UserID: User]

    var body: some View {
        BoostFlowLayout {
            ForEach(boosts) { boost in
                HStack(spacing: 4) {
                    if let user = users[boost.boosterID] { AvatarView(user: user, size: 23) }
                    Text(boost.content).font(.system(size: textSize))
                }
                .padding(.leading, 1.6)
                .padding(.trailing, 7)
                .padding(.vertical, 2.8)
                .background(CampfireStyle.background(scheme), in: .capsule)
                .overlay(Capsule().strokeBorder(CampfireStyle.pillBorder(scheme), lineWidth: 1))
                .accessibilityLabel("\(users[boost.boosterID]?.name ?? "Someone") boosted \(boost.content)")
            }
            CircleControl(title: "Add boost", symbol: "face.smiling", size: 28.64)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus").font(.system(size: 8, weight: .bold))
                        .padding(4).accessibilityHidden(true)
                }
        }
        .padding(.top, 4)
    }
}
