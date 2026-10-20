import SwiftUI
import CampfireKit

struct BoostStrip: View {
    let boosts: [Boost]
    let users: [Int: User]
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .body) private var size = 16.0

    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        FlowLayout(spacing: 4.5) {
            ForEach(identifiedBoosts) { item in
                let boost = item.boost
                HStack(spacing: 4) {
                    Avatar(id: boost.boosterID, initial: String((users[boost.boosterID]?.name ?? "").prefix(1)), size: 22.4)
                    Text(boost.content).font(.system(size: size))
                }
                .padding(.leading, 1.6)
                .padding(.trailing, 5)
                .frame(minHeight: 28.64)
                .background(colors.background, in: Capsule())
                .overlay(Capsule().strokeBorder(colors.border, lineWidth: 1))
            }
            Button {} label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 17))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "plus").font(.system(size: 8, weight: .heavy))
                            .background(colors.background).offset(x: 3, y: 1)
                    }
                    .frame(width: 28.64, height: 28.64)
                    .background(colors.background, in: Circle())
                    .overlay(Circle().strokeBorder(colors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add boost")
        }
    }
    private var identifiedBoosts: [BoostOccurrence] {
        var occurrences: [Int: Int] = [:]
        return boosts.map { boost in
            let occurrence = occurrences[boost.id, default: 0]
            occurrences[boost.id] = occurrence + 1
            return BoostOccurrence(id: "\(boost.id):\(occurrence)", boost: boost)
        }
    }

}

private struct BoostOccurrence: Identifiable { let id: String; let boost: Boost }

struct FlowLayout: Layout {
    let spacing: CGFloat
    struct Placement { let origin: CGPoint; let size: CGSize }

    private func arrange(_ views: Subviews, width: CGFloat) -> (CGSize, [Placement]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        var placements: [Placement] = []
        for view in views {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            placements.append(Placement(origin: CGPoint(x: x, y: y), size: size))
            maxX = max(maxX, x + size.width)
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxX, height: y + lineHeight), placements)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .greatestFiniteMagnitude).0
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, placements) = arrange(subviews, width: bounds.width)
        for (view, placement) in zip(subviews, placements) {
            view.place(at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                       proposal: ProposedViewSize(placement.size))
        }
    }
}
