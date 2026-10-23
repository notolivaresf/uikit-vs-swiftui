import SwiftUI
import CampfireKit

struct HeaderImage: Equatable {
    let rect: CGRect
    let color: RGB
}

struct HeaderImageAnchor {
    let bounds: Anchor<CGRect>
    let color: RGB
}

struct HeaderImageAnchorsKey: PreferenceKey {
    static var defaultValue: [Int: HeaderImageAnchor] { [:] }
    static func reduce(value: inout [Int: HeaderImageAnchor], nextValue: () -> [Int: HeaderImageAnchor]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct HeaderImagesKey: PreferenceKey {
    static let defaultValue: [Int: HeaderImage] = [:]
    static func reduce(value: inout [Int: HeaderImage], nextValue: () -> [Int: HeaderImage]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct RoomLayout: Equatable {
    var frames: [Int: CGRect] = [:]
    var width: CGFloat = 0
    var height: CGFloat = 0
    var revision: Int = 0
    var textSize: DynamicTypeSize = .large
}

struct RoomLayoutKey: PreferenceKey {
    static let defaultValue = RoomLayout()
    static func reduce(value: inout RoomLayout, nextValue: () -> RoomLayout) {
        let next = nextValue()
        value.frames.merge(next.frames) { _, new in new }
        if next.width > 0 {
            value.width = next.width
            value.height = next.height
            value.revision = next.revision
            value.textSize = next.textSize
        }
    }
}

struct ScrollMeasurement: Equatable {
    let offset: CGFloat
    let height: CGFloat
    let size: CGSize
}

@MainActor @Observable
final class RoomViewport {
    enum Destination {
        case bottom
        case row(Int, CGFloat)
    }
    var position = ScrollPosition(y: 0)
    private(set) var pinned = true
    private(set) var top = 0
    private(set) var topY: CGFloat = 0
    private(set) var milliseconds = 0
    private(set) var hasAppeared = false
    private(set) var isRestoring = true
    private(set) var headerImage: HeaderImage?
    @ObservationIgnored var headerHeight: CGFloat = 58
    @ObservationIgnored private var layout = RoomLayout()
    @ObservationIgnored private var images: [Int: HeaderImage] = [:]
    @ObservationIgnored private var measurement = ScrollMeasurement(offset: 0, height: 0, size: .zero)
    @ObservationIgnored private var pending: Destination? = .bottom
    @ObservationIgnored private var targetOffset: CGFloat?
    @ObservationIgnored private var tapStarted: ContinuousClock.Instant? = CampfireApp.startedAt
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var paginationAllowed = false
    @ObservationIgnored private(set) var userScrolling = false
    @ObservationIgnored private var atNewest = true
    @ObservationIgnored private var lastWidth: CGFloat = 0
    @ObservationIgnored private var frozenAnchor: Destination = .bottom

    var nearTop: Bool { measurement.offset < 40 }
    var nearBottom: Bool { measurement.height - measurement.offset - measurement.size.height < 100 }

    func beginTap() { tapStarted = .now }

    func preserve() {
        guard pending == nil, !userScrolling else { return }
        pending = pinned ? .bottom : .row(top, topY)
        frozenAnchor = pending ?? .bottom
        isRestoring = true
    }

    func go(_ destination: Destination) {
        pending = destination
        frozenAnchor = destination
        isRestoring = true
        if case .bottom = destination { pinned = true } else { pinned = false }
    }

    func changedLayout(_ new: RoomLayout) {
        guard !new.frames.isEmpty, new.width > 0 else { return }
        if lastWidth > 0,
           (abs(lastWidth - new.width) > 0.1 || layout.textSize != new.textSize),
           pending == nil {
            pending = frozenAnchor
            isRestoring = true
        }
        lastWidth = new.width
        layout = new
        if let pending { restore(pending) }
        else { updateVisible() }
    }

    func changedScroll(_ new: ScrollMeasurement) {
        if measurement.size != .zero,
           (abs(new.size.width - measurement.size.width) > 1 || abs(new.size.height - measurement.size.height) > 1),
           pending == nil {
            pending = frozenAnchor
            isRestoring = true
        }
        measurement = new
        if let pending {
            // Geometry can arrive before preferences. Wait for the content's new dimensions.
            if abs(layout.height - new.height) < 1 { restore(pending) }
        } else {
            if userScrolling { pinned = nearBottom && atNewest }
            updateVisible()
        }
    }

    private func restore(_ destination: Destination) {
        guard measurement.size.height > 0, layout.height > 0 else { return }
        let desired: CGFloat
        switch destination {
        case .bottom: desired = max(0, layout.height - measurement.size.height)
        case .row(let id, let y):
            guard let frame = layout.frames[id] else { return }
            desired = min(max(0, frame.minY - y), max(0, layout.height - measurement.size.height))
        }
        if abs(measurement.offset - desired) < 0.5 && abs(measurement.height - layout.height) < 1 {
            completeRestoration()
            return
        }
        if targetOffset != desired || abs(measurement.offset - desired) >= 0.5 {
            position.scrollTo(y: desired)
        }
        targetOffset = desired
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            // Retry after the scroll content commits if SwiftUI initially clamped to its old size.
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled, let self, let destination = self.pending else { return }
            self.restore(destination)
        }
    }

    private func completeRestoration() {
        settleTask?.cancel()
        let wasFollowingBottom: Bool
        if case .bottom? = pending { wasFollowingBottom = true } else { wasFollowingBottom = false }
        pending = nil
        targetOffset = nil
        isRestoring = false
        hasAppeared = true
        pinned = atNewest && (wasFollowingBottom || nearBottom)
        updateVisible()
        finishTiming()
    }

    private func finishTiming() {
        if let tapStarted {
            let elapsed = tapStarted.duration(to: .now).components
            milliseconds = max(0, Int(elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000))
            self.tapStarted = nil
        }
    }

    private func updateVisible() {
        updateHeaderImage()
        let visible = layout.frames.filter {
            $0.value.maxY - 1.6 > measurement.offset + 0.5 && $0.value.minY < measurement.offset + measurement.size.height
        }.min { $0.value.minY < $1.value.minY }
        if let visible {
            top = visible.key
            topY = visible.value.minY - measurement.offset
        }
        frozenAnchor = pinned ? .bottom : .row(top, topY)
    }

    func changedImages(_ images: [Int: HeaderImage]) {
        self.images = images
        updateHeaderImage()
    }

    private func updateHeaderImage() {
        if let image = images.values.first(where: {
            $0.rect.maxY > measurement.offset - headerHeight && $0.rect.minY < measurement.offset
        }) {
            headerImage = HeaderImage(rect: image.rect.offsetBy(dx: 0, dy: headerHeight - measurement.offset), color: image.color)
        } else { headerImage = nil }
    }

    func setAtNewest(_ value: Bool) {
        atNewest = value
        if !value { pinned = false }
        else if case .bottom? = pending { pinned = true }
    }

    func changedPhase(_ phase: ScrollPhase) {
        if phase == .tracking || phase == .interacting {
            userScrolling = true
            paginationAllowed = true
            pending = nil
            targetOffset = nil
            settleTask?.cancel()
            isRestoring = false
        } else if phase == .idle && userScrolling {
            userScrolling = false
            pinned = nearBottom && atNewest
            updateVisible()
        }
    }

    func shouldLoadOlder() -> Bool {
        guard paginationAllowed, !isRestoring, nearTop else { return false }
        paginationAllowed = false
        return true
    }

    func allowNextPagination() { paginationAllowed = true }
}
