import SwiftUI
import ImageIO
import AppKit.NSPasteboard
import CampfireKit

enum Clipboard {
    @MainActor static func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}

/// Decodes CampfireKit's placeholder PNGs off the main thread. Until one is ready, its exact colour is drawn
/// instead, which looks the same. Building a PNG is costly (it checksums every byte), so only images that
/// stay on screen for a moment are built, and ones scrolled away before their turn are skipped.
@MainActor
final class PlaceholderImages {
    static let shared = PlaceholderImages()
    private var images: [String: CGImage] = [:]
    private var pending: Set<String> = []
    private var waiting: [String: [@MainActor (CGImage) -> Void]] = [:]
    private let queue = DispatchQueue(label: "campfire.placeholders", qos: .utility)
    private let wanted = WantedSet()

    static func key(_ w: Int, _ h: Int, _ c: RGB) -> String { "\(w)x\(h)-\(c.r)-\(c.g)-\(c.b)" }

    func image(width: Int, height: Int, color: RGB) -> CGImage? { images[Self.key(width, height, color)] }

    func request(width: Int, height: Int, color: RGB, done: @escaping @MainActor (CGImage) -> Void) {
        let key = Self.key(width, height, color)
        if let hit = images[key] { done(hit); return }
        waiting[key, default: []].append(done)
        wanted.add(key)
        guard !pending.contains(key) else { return }
        pending.insert(key)
        let wanted = self.wanted
        queue.asyncAfter(deadline: .now() + 0.3) {
            var image: CGImage?
            if wanted.contains(key) {
                let data = Placeholder.pngData(width: width, height: height, color: color) as CFData
                image = CGImageSourceCreateWithData(data, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            }
            let box = UncheckedBox(image)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let shared = PlaceholderImages.shared
                    shared.pending.remove(key)
                    let callbacks = shared.waiting.removeValue(forKey: key) ?? []
                    if let image = box.value {
                        shared.images[key] = image
                        callbacks.forEach { $0(image) }
                    }
                }
            }
        }
    }

    func cancel(width: Int, height: Int, color: RGB) {
        let key = Self.key(width, height, color)
        wanted.remove(key)
        waiting[key] = nil
    }
}

/// Keys of images on screen, readable from the decoding queue.
private final class WantedSet: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    func add(_ k: String) { lock.lock(); counts[k, default: 0] += 1; lock.unlock() }
    func remove(_ k: String) {
        lock.lock(); let n = (counts[k] ?? 0) - 1; counts[k] = n > 0 ? n : nil; lock.unlock()
    }
    func contains(_ k: String) -> Bool { lock.lock(); defer { lock.unlock() }; return counts[k] != nil }
}

private struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

struct PlaceholderImage: View {
    let width: Int
    let height: Int
    let color: RGB
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.sRGB, red: Double(color.r) / 255, green: Double(color.g) / 255,
                                   blue: Double(color.b) / 255))
            if let image = image ?? PlaceholderImages.shared.image(width: width, height: height, color: color) {
                Image(decorative: image, scale: 1).resizable()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Image")
        .onAppear {
            guard image == nil else { return }
            PlaceholderImages.shared.request(width: width, height: height, color: color) { image = $0 }
        }
        .onDisappear {
            if image == nil { PlaceholderImages.shared.cancel(width: width, height: height, color: color) }
        }
    }
}
