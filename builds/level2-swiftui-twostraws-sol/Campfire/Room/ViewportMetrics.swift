import SwiftUI

struct ViewportMetrics: Equatable {
    let offset: Double
    let size: CGSize
    let contentHeight: Double

    init(_ geometry: ScrollGeometry) {
        offset = geometry.contentOffset.y + geometry.contentInsets.top
        size = geometry.containerSize
        contentHeight = geometry.contentSize.height
    }
}
