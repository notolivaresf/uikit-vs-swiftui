import SwiftUI
import Observation

@MainActor @Observable
final class RoomScrollState {
    var position = ScrollPosition(idType: Int.self)
    private(set) var pinned = true
    private(set) var debugLabel = "first 49961 last 50000 loaded 40 pinned yes top 0 y 0.0 ms 0"
    private(set) var ready = false

    @ObservationIgnored private(set) var frames: [Int: CGRect] = [:]
    @ObservationIgnored private(set) var offset = 0.0
    @ObservationIgnored private var viewportSize = CGSize.zero
    @ObservationIgnored private var stableAnchor: ScrollAnchor = .bottom
    @ObservationIgnored private var pending: ScrollAnchor? = .bottom
    @ObservationIgnored private var layoutTask: Task<Void, Never>?
    @ObservationIgnored private var tapStarted: ContinuousClock.Instant?
    @ObservationIgnored private var milliseconds = 0
    @ObservationIgnored private var firstID = 49_961
    @ObservationIgnored private var lastID = 50_000
    @ObservationIgnored private var count = 40
    @ObservationIgnored var userScrolling = false

    init(launchedAt: ContinuousClock.Instant) { tapStarted = launchedAt }

    var topID: Int? {
        frames.filter { $0.value.maxY - 1.6 > 0.1 && $0.value.minY + 1.6 < viewportSize.height }
            .min { $0.value.minY < $1.value.minY }?.key
    }

    var restoring: Bool { pending != nil }

    func measureTap() { tapStarted = .now }

    func preserve() {
        if pending == nil { pending = pinned ? .bottom : stableAnchor }
    }

    func request(_ anchor: ScrollAnchor) {
        layoutTask?.cancel()
        pending = anchor
        if case .bottom = anchor { pinned = true } else { pinned = false }
    }

    func updateWindow(_ items: [MessageItem]) {
        firstID = items.first?.id ?? 0
        lastID = items.last?.id ?? 0
        count = items.count
        scheduleLayout()
    }

    func layoutChanged(_ newFrames: [Int: CGRect]) {
        guard !newFrames.isEmpty else { return }
        frames = newFrames
        if pending == nil && ready && !userScrolling {
            pending = pinned ? .bottom : stableAnchor
        }
        if pending != nil { scheduleLayout() }
        else {
            if userScrolling { refreshAnchor() }
            updateLabel()
        }
    }

    func geometryChanged(_ metrics: ViewportMetrics) {
        if viewportSize != .zero && viewportSize != metrics.size && pending == nil {
            pending = pinned ? .bottom : stableAnchor
        }
        viewportSize = metrics.size
        offset = metrics.offset
        if pending != nil {
            scheduleLayout()
        } else if ready && !userScrolling {
            // Lazy rows can refine estimates after a programmatic scroll finishes.
            // Keep the last reading anchor until the person actually scrolls.
            pending = pinned ? .bottom : stableAnchor
            scheduleLayout()
        } else {
            refreshAnchor()
            updateLabel()
        }
    }

    func scrollPhaseChanged(_ phase: ScrollPhase) {
        let wasUserScrolling = userScrolling
        userScrolling = phase == .interacting || phase == .decelerating
        if phase == .interacting {
            layoutTask?.cancel()
            pending = nil
        }
        if pending == nil && (userScrolling || wasUserScrolling) { refreshAnchor(); updateLabel() }
    }

    func scheduleLayout() {
        layoutTask?.cancel()
        layoutTask = Task { [weak self] in
            // Defer to the next display pass so the geometry belongs to the changed
            // rows, including a new Dynamic Type environment or container width.
            do { try await Task.sleep(for: .milliseconds(12)) } catch { return }
            guard let self else { return }
            self.restoreAfterLayout()
        }
    }

    private func restoreAfterLayout() {
        guard !frames.isEmpty, viewportSize.height > 0 else { return }
        guard let pending else { finishMeasurement(); updateLabel(); return }
        let target: Double
        switch pending {
        case .bottom:
            if frames[lastID] == nil {
                position.scrollTo(edge: .bottom)
                scheduleLayout()
                return
            }
            target = max(0, offset + Double(frames[lastID]?.maxY ?? 0) + 16 - viewportSize.height)
        case .row(let id, let y):
            guard let frame = frames[id] else {
                position.scrollTo(id: id, anchor: .top)
                scheduleLayout()
                return
            }
            target = max(0, offset + frame.minY - y)
        }
        if abs(offset - target) > 0.5 { position.scrollTo(y: target) }
        layoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
            self?.completeIfPositioned()
        }
    }

    private func completeIfPositioned() {
        // Geometry confirms that the requested result is on screen before timing it.
        let error: Double
        switch pending {
        case .bottom:
            guard let frame = frames[lastID] else { scheduleLayout(); return }
            error = frame.maxY + 16 - viewportSize.height
        case .row(let id, let y):
            guard let frame = frames[id] else { scheduleLayout(); return }
            error = frame.minY - y
        case nil:
            return
        }
        guard abs(error) <= 1 else {
            scheduleLayout()
            return
        }
        pending = nil
        ready = true
        refreshAnchor()
        finishMeasurement()
        updateLabel()
    }

    private func finishMeasurement() {
        if let tapStarted {
            let duration = tapStarted.duration(to: .now)
            milliseconds = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
            self.tapStarted = nil
        }
    }

    private func refreshAnchor() {
        if let last = frames[lastID] {
            pinned = max(0, last.maxY + 16 - viewportSize.height) <= 100
        } else { pinned = false }
        if let id = topID, let frame = frames[id] {
            stableAnchor = .row(id: id, y: frame.minY)
        }
    }

    private func updateLabel() {
        let id = topID ?? firstID
        let y = frames[id].map { Double($0.minY) } ?? 0
        let formattedY = y.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(1)).grouping(.never))
        let value = "first \(firstID) last \(lastID) loaded \(count) pinned \(pinned ? "yes" : "no") top \(id) y \(formattedY) ms \(milliseconds)"
        if debugLabel != value { debugLabel = value }
    }
}
