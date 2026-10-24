import CampfireKit
import CoreGraphics
import ImageIO
import SwiftUI

/// Decodes CampfireKit's placeholder PNGs off the main thread and keeps the recent ones.
actor PlaceholderImages {
    static let shared = PlaceholderImages()

    struct Key: Hashable, Sendable {
        let width: Int
        let height: Int
        let r: UInt8, g: UInt8, b: UInt8
    }

    private var cache: [Key: CGImage] = [:]
    private var order: [Key] = []
    private let limit = 24

    func image(for key: Key) -> CGImage? {
        if let image = cache[key] { return image }
        let data = Placeholder.pngData(width: key.width, height: key.height, color: RGB(r: key.r, g: key.g, b: key.b))
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[key] = image
        order.append(key)
        if order.count > limit { cache[order.removeFirst()] = nil }
        return image
    }
}
