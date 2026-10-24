import CampfireKit
import SwiftUI

/// The placeholder image, edge to edge in a 300 pt bubble, aspect kept. Its colour shows at once and the
/// decoded placeholder PNG replaces it when ready (same pixels).
struct ImageAttachmentView: View {
    let width: Int
    let height: Int
    let color: RGB
    let roundsBottom: Bool

    @State private var image: CGImage?

    private var key: PlaceholderImages.Key {
        PlaceholderImages.Key(width: width, height: height, r: color.r, g: color.g, b: color.b)
    }

    var body: some View {
        let displayWidth = Metrics.imageWidth - 2 * Metrics.imageInset
        let displayHeight = displayWidth * CGFloat(height) / CGFloat(max(1, width))
        let radius = roundsBottom ? Metrics.bubbleRadius - Metrics.imageInset : 0
        Rectangle()
            .fill(Color(.sRGB, red: Double(color.r) / 255, green: Double(color.g) / 255, blue: Double(color.b) / 255))
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1).resizable()
                }
            }
            .frame(width: displayWidth, height: displayHeight)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius))
            .padding(.horizontal, Metrics.imageInset)
            .task(id: key) {
                let key = key
                image = await Task.detached(priority: .utility) {
                    await PlaceholderImages.shared.image(for: key)
                }.value
            }
            .accessibilityElement()
            .accessibilityLabel("Image")
    }
}
