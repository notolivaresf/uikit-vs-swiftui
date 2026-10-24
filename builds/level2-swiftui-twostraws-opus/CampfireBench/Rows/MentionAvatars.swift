import CampfireKit
import SwiftUI

/// Inline mention avatars, rendered once per person and size so they can sit inside a `Text`.
@MainActor
enum MentionAvatars {
    private struct Key: Hashable {
        let userID: UserID
        let size: CGFloat
        let scale: CGFloat
    }

    private static var cache: [Key: Image] = [:]

    static func image(userID: UserID, name: String, size: CGFloat, displayScale: CGFloat) -> Image {
        let key = Key(userID: userID, size: size, scale: displayScale)
        if let image = cache[key] { return image }
        let renderer = ImageRenderer(content:
            AvatarView(userID: userID, name: name, size: size, fontSize: size * 0.5)
                .environment(\.colorScheme, .light))
        renderer.scale = displayScale
        let image = renderer.cgImage.map { Image(decorative: $0, scale: displayScale) } ?? Image(systemName: "person.circle.fill")
        cache[key] = image
        return image
    }
}
