import SwiftUI
import CampfireKit

struct AvatarView: View {
    let user: User
    var size: Double = CampfireStyle.avatarSize

    var body: some View {
        Text(String(user.name.prefix(1)))
            .font(.system(size: size * 0.454, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(CampfireStyle.avatarColor(user.id), in: .circle)
            .accessibilityHidden(true)
    }
}
