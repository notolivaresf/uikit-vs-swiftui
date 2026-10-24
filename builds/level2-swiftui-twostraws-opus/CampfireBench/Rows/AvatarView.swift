import CampfireKit
import SwiftUI

/// Round avatar in the user's palette colour with a white initial.
struct AvatarView: View {
    let userID: UserID
    let name: String
    var size: CGFloat = Metrics.avatarSize
    var fontSize: CGFloat = 16

    var body: some View {
        Circle()
            .fill(Palette.avatar(for: userID))
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: Self.initial(of: name))
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    static func initial(of name: String) -> String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}
