import SwiftUI

struct SelectionGlyph: Identifiable {
    let id: Int
    let range: Range<Int>
    let rect: CGRect
}
