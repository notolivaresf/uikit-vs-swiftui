import SwiftUI

struct RowFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ContentLayout: Equatable {
    var size: CGSize = .zero
    var revision = 0
}
struct ContentLayoutKey: PreferenceKey {
    static let defaultValue = ContentLayout()
    static func reduce(value: inout ContentLayout, nextValue: () -> ContentLayout) { value = nextValue() }
}
struct RoomMetrics: Equatable {
    let offset: CGFloat
    let height: CGFloat
    let contentHeight: CGFloat
}

/// ScrollPosition and content-coordinate row measurements are the only scrolling
/// mechanisms. There is no access to the scroll view's AppKit implementation.
@MainActor @Observable
final class RoomScroll {
    struct Anchor {
        var pinned: Bool
        var id: Int
        var y: CGFloat
    }
    var position = ScrollPosition(idType: Int.self, edge: .bottom)
    var pinned = true
    var topID = 0
    var topY: CGFloat = 0
    var milliseconds = 0
    var ready = false
    @ObservationIgnored var frames: [Int: CGRect] = [:]
    @ObservationIgnored var metrics = RoomMetrics(offset: 0, height: 0, contentHeight: 0)
    @ObservationIgnored private var layout = ContentLayout()
    @ObservationIgnored private var anchor = Anchor(pinned: true, id: 0, y: 0)
    @ObservationIgnored private var pending: Anchor? = Anchor(pinned: true, id: 0, y: 0)
    @ObservationIgnored private var measuredFrom: ContinuousClock.Instant?
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored var userScrolling = false
    @ObservationIgnored var loadOlder: (() -> Void)?
    @ObservationIgnored var loadNewer: (() -> Void)?
    @ObservationIgnored private var paging = false

    init(launchTime: ContinuousClock.Instant) { measuredFrom = launchTime }

    func click() { measuredFrom = .now }
    func preserve() {
        if pending == nil { pending = anchor }
    }
    func requestBottom() {
        pending = Anchor(pinned: true, id: 0, y: 0)
        pinned = true
    }
    func requestJump(_ id: Int) {
        pending = Anchor(pinned: false, id: id, y: 0)
        pinned = false
    }
    func preserveForForwardPage() {
        pending = Anchor(pinned: false, id: topID, y: topY)
    }
    func receiveFrames(_ newFrames: [Int: CGRect]) {
        guard !newFrames.isEmpty else { return }
        if frames != newFrames {
            // Width changes arrive here before the outer geometry on some OS
            // versions. Use the last settled anchor, never the reflowed frames.
            if ready && pending == nil && !userScrolling { pending = anchor }
            frames = newFrames
            scheduleSettlement()
        }
    }
    func receiveLayout(_ newLayout: ContentLayout) {
        guard newLayout != layout else { return }
        if ready && pending == nil { pending = anchor }
        layout = newLayout
        scheduleSettlement()
    }
    func receiveMetrics(_ newMetrics: RoomMetrics) {
        let resized = metrics.height > 0 && abs(metrics.height - newMetrics.height) > 0.01
        if resized && ready && pending == nil { pending = anchor }
        metrics = newMetrics
        if pending != nil {
            scheduleSettlement()
        } else {
            updateVisible()
            if userScrolling && !paging {
                if newMetrics.offset <= 1 {
                    paging = true
                    loadOlder?()
                    Task { try? await Task.sleep(for: .milliseconds(150)); self.paging = false }
                } else if newMetrics.contentHeight - newMetrics.height - newMetrics.offset <= 1 {
                    loadNewer?()
                }
            }
        }
    }
    func phaseChanged(_ phase: ScrollPhase) {
        userScrolling = phase.isScrolling
        if phase == .idle {
            if pending != nil { scheduleSettlement() } else { updateVisible() }
        }
    }
    func finishUnchangedClick() { scheduleSettlement() }
    private func scheduleSettlement() {
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            // Preference delivery is after layout; yield once so ScrollPosition
            // sees the new content extent before restoring the point.
            await Task.yield()
            guard !Task.isCancelled, let self, !self.frames.isEmpty, self.metrics.height > 0 else { return }
            var desiredOffset: CGFloat?
            if let target = self.pending {
                let wanted: CGFloat
                if target.pinned {
                    wanted = max(0, self.layout.size.height - self.metrics.height)
                } else if let frame = self.frames[target.id] {
                    wanted = min(max(0, self.layout.size.height - self.metrics.height), max(0, frame.minY - target.y))
                } else { return }
                desiredOffset = wanted
                if abs(self.metrics.offset - wanted) > 0.1 {
                    self.position.scrollTo(y: wanted)
                }
            }
            // Wait for the resulting geometry transaction, including text reflow.
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            if let desiredOffset, abs(self.metrics.offset - desiredOffset) > 0.5 {
                // Do not publish the result or stop timing until the actual
                // scroll geometry confirms that the restoration took effect.
                self.scheduleSettlement()
                return
            }
            self.pending = nil
            self.ready = true
            self.updateVisible()
            if let start = self.measuredFrom {
                let duration = start.duration(to: .now).components
                self.milliseconds = Int(duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000)
                self.measuredFrom = nil
            }
        }
    }
    private func updateVisible() {
        let visible = frames.filter { $0.value.maxY > metrics.offset + 0.05 &&
            $0.value.minY < metrics.offset + metrics.height }.min { $0.key < $1.key }
        if let visible {
            topID = visible.key
            topY = visible.value.minY - metrics.offset
        }
        pinned = layout.size.height - metrics.offset - metrics.height <= 100
        anchor = Anchor(pinned: pinned, id: topID, y: topY)
    }
}
