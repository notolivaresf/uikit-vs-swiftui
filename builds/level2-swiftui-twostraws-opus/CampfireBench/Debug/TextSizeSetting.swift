import SwiftUI

/// The debug bar's "Text size +" override of the system Dynamic Type size.
@MainActor
@Observable
final class TextSizeSetting {
    var override: DynamicTypeSize?

    /// One step larger, back to the default after the largest.
    func step(from current: DynamicTypeSize) {
        let all = DynamicTypeSize.allCases
        guard let index = all.firstIndex(of: current), index + 1 < all.count else {
            override = .large
            return
        }
        override = all[index + 1]
    }
}
