import SwiftUI

/// CSS `width: fit-content`: as wide as the content's single-line (max-content) width, but never wider
/// than offered; once the content has to wrap it takes the whole offered width, like a browser block does.
struct FitContentLayout: Layout {
    var maxWidth: CGFloat = .infinity
    /// Always take `maxWidth` (or all that is offered, if less): image bubbles.
    var fillsWidth = false

    /// Measuring a bubble is the expensive part of a room layout, so each answer is kept until the content changes.
    struct Cache {
        var idealWidth: CGFloat?
        var heights: [CGFloat: CGFloat] = [:]
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let width = resolvedWidth(proposal: proposal, subview: subview, cache: &cache)
        if let height = cache.heights[width] { return CGSize(width: width, height: height) }
        let height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        cache.heights[width] = height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let subview = subviews.first else { return }
        subview.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }

    private func resolvedWidth(proposal: ProposedViewSize, subview: LayoutSubview, cache: inout Cache) -> CGFloat {
        let available = min(proposal.width ?? .infinity, maxWidth)
        if fillsWidth, available.isFinite { return available }
        let ideal: CGFloat
        if let cached = cache.idealWidth {
            ideal = cached
        } else {
            ideal = subview.sizeThatFits(.unspecified).width
            cache.idealWidth = ideal
        }
        return min(ideal, available)
    }
}

/// Wrapping row of views (boost pills, debug buttons): left to right, new line when full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    struct Line { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    func lines(for width: CGFloat, subviews: Subviews) -> ([Line], [CGSize]) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var lines: [Line] = [Line()]
        for (i, size) in sizes.enumerated() {
            let extra = lines[lines.count - 1].indices.isEmpty ? size.width : spacing + size.width
            if !lines[lines.count - 1].indices.isEmpty, lines[lines.count - 1].width + extra > width + 0.01 {
                lines.append(Line())
            }
            var line = lines[lines.count - 1]
            line.width += line.indices.isEmpty ? size.width : spacing + size.width
            line.height = max(line.height, size.height)
            line.indices.append(i)
            lines[lines.count - 1] = line
        }
        return (lines.filter { !$0.indices.isEmpty }, sizes)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (lines, _) = lines(for: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + CGFloat(max(0, lines.count - 1)) * lineSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (lines, sizes) = lines(for: bounds.width, subviews: subviews)
        var y = bounds.minY
        for line in lines {
            var x = bounds.minX
            if alignment == .trailing { x = bounds.maxX - line.width }
            if alignment == .center { x = bounds.minX + (bounds.width - line.width) / 2 }
            for i in line.indices {
                let size = sizes[i]
                subviews[i].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                  proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }
}
