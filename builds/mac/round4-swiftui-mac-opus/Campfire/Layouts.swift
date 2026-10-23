import SwiftUI

/// CSS `width: fit-content` with a maximum: short content hugs its ideal width, content that has to wrap
/// takes the whole available width (as a browser does), and nothing exceeds `maxWidth`.
struct FitContentLayout: Layout {
    var maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let limit = max(0, min(maxWidth, proposal.width ?? maxWidth))
        let ideal = child.sizeThatFits(.unspecified)
        let width = ideal.width <= limit + 0.01 ? ideal.width : limit
        let size = child.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// Lays children out left to right and wraps them onto new lines, like inline-flex pills.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    private func lines(_ maxWidth: CGFloat, _ subviews: Subviews) -> [[(Int, CGSize)]] {
        var lines: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let size = v.sizeThatFits(.unspecified)
            if !lines[lines.count - 1].isEmpty, x + size.width > maxWidth + 0.01 {
                lines.append([])
                x = 0
            }
            lines[lines.count - 1].append((i, size))
            x += size.width + spacing
        }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let ls = lines(maxWidth, subviews)
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (n, line) in ls.enumerated() {
            let w = line.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, line.count - 1))
            width = max(width, w)
            height += (line.map(\.1.height).max() ?? 0) + (n > 0 ? lineSpacing : 0)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(bounds.width, subviews) {
            var x = bounds.minX
            let h = line.map(\.1.height).max() ?? 0
            for (i, size) in line {
                subviews[i].place(at: CGPoint(x: x, y: y + (h - size.height) / 2), anchor: .topLeading,
                                  proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += h + lineSpacing
        }
    }
}
