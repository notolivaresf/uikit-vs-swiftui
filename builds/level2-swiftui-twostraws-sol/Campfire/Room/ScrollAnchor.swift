import Foundation

enum ScrollAnchor: Equatable {
    case bottom
    case row(id: Int, y: Double)
}
