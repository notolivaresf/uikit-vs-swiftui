import CampfireKit
import os
import SwiftUI

/// Keeps the room where the reader left it. Rows report their frames in content coordinates and the scroll
/// view reports its geometry; after any change in layout (new rows, older pages, boosts, Dynamic Type,
/// rotation) the scroller puts the anchor row back where it was, or keeps the room pinned to the bottom.
@MainActor
@Observable
final class RoomScroller {
    enum Anchor: Equatable {
        case bottom
        /// A row id and where its top sits, measured down from the bottom edge of the header.
        case row(MessageID, CGFloat)
    }

    /// How close to the bottom (in points) still counts as pinned.
    static let pinDistance: CGFloat = 100
    /// Start loading another page when the visible edge gets this close to the end of the content.
    static let loadDistance: CGFloat = 400

    private(set) var position = ScrollPosition(edge: .bottom)
    private(set) var isPinned = true

    /// For `.scrollPosition`. SwiftUI writes the position back as it scrolls; only real changes are stored,
    /// so the write-back cannot loop through observation.
    var positionBinding: Binding<ScrollPosition> {
        Binding { self.position } set: { new in
            if new != self.position { self.position = new }
        }
    }

    @ObservationIgnored weak var store: RoomStore?
    @ObservationIgnored var onSettled: (() -> Void)?
    @ObservationIgnored private(set) var anchor = Anchor.bottom
    @ObservationIgnored private var frames: [MessageID: CGRect] = [:]
    /// Rows the scroll view reports as on screen. Lazy rows kept alive off screen can hold stale frames,
    /// so only these count when reading the top row.
    @ObservationIgnored private var visible: Set<MessageID> = []
    @ObservationIgnored private var ids: [MessageID] = []
    @ObservationIgnored private var windowAtEnd = true
    @ObservationIgnored private var windowAtStart = false
    @ObservationIgnored private var geometry: ScrollGeometry?
    @ObservationIgnored private var phase = ScrollPhase.idle
    /// Set by a content change until the anchor is back in place.
    @ObservationIgnored private var restoring = true
    @ObservationIgnored private var lastRequestedOffset: CGFloat?
    @ObservationIgnored private var loadScheduled = false
    @ObservationIgnored private(set) var layoutTick = 0

    // MARK: Reading the layout

    var topRow: (id: MessageID, y: CGFloat)? {
        guard let geometry else { return nil }
        let headerBottom = Self.headerBottom(geometry)
        var best: (id: MessageID, y: CGFloat)?
        for id in visible {
            guard let frame = frames[id] else { continue }
            // A row's last 1.6 pt is empty margin that the next (threaded) row may overlap.
            guard frame.maxY - Metrics.rowBottomInset > headerBottom + 0.01 else { continue }
            let y = frame.minY - headerBottom
            if best == nil || y < best!.y { best = (id, y) }
        }
        return best
    }

    /// The row is laid out and on screen.
    func hasFrame(for id: MessageID) -> Bool { frames[id] != nil && visible.contains(id) }

    var isUserScrolling: Bool { phase == .interacting || phase == .decelerating || phase == .tracking }

    private static func headerBottom(_ g: ScrollGeometry) -> CGFloat {
        g.contentOffset.y + g.contentInsets.top
    }

    private static func minOffset(_ g: ScrollGeometry) -> CGFloat { -g.contentInsets.top }

    // `containerSize` is the area between the insets; the offset is the content y at the scroll view's top
    // edge, which sits `contentInsets.top` above the header bottom.
    private static func maxOffset(_ g: ScrollGeometry) -> CGFloat {
        max(minOffset(g), g.contentSize.height - g.containerSize.height - g.contentInsets.top)
    }

    private func distanceToBottom(_ g: ScrollGeometry) -> CGFloat {
        let visibleBottom = g.contentOffset.y + g.contentInsets.top + g.containerSize.height
        let lastBottom = ids.last.flatMap { visible.contains($0) ? frames[$0]?.maxY : nil } ?? g.contentSize.height
        return lastBottom - visibleBottom
    }

    var isSettledAtAnchor: Bool {
        guard let geometry else { return false }
        switch anchor {
        case .bottom:
            return abs(Self.maxOffset(geometry) - geometry.contentOffset.y) <= 0.5
        case .row(let id, let y):
            guard let frame = frames[id] else { return false }
            let current = frame.minY - Self.headerBottom(geometry)
            if abs(current - y) <= 0.5 { return true }
            // An anchor that cannot be reached (near an end of the content) counts as settled.
            let target = clampedOffset(for: frame, y: y, in: geometry)
            return abs(target - geometry.contentOffset.y) <= 0.5
        }
    }

    // MARK: Content changes (from the store)

    /// Called before rows change, so a change that lands mid-scroll keeps what the reader sees.
    func willMutate() {
        if isUserScrolling { captureAnchor() }
        restoring = true
    }

    /// Called before the window is replaced (reset, jump), with where the new content should sit.
    func willReplaceContent(anchor newAnchor: Anchor) {
        anchor = newAnchor
        restoring = true
        lastRequestedOffset = nil
        switch newAnchor {
        case .bottom:
            scrollToBottom()
        case .row(let id, _):
            position.scrollTo(id: id, anchor: .top)
        }
        setPinned(newAnchor == .bottom)
    }

    func didMutate(ids newIDs: [MessageID], windowAtEnd atEnd: Bool, windowAtStart atStart: Bool) {
        ids = newIDs
        windowAtEnd = atEnd
        windowAtStart = atStart
        if anchor == .bottom {
            if atEnd {
                // Resolved during layout, so the new rows are drawn already at the bottom.
                scrollToBottom()
            } else {
                captureAnchor()
            }
        }
        // The layout callbacks that follow settle the rest; the geometry known now is stale.
    }

    @ObservationIgnored private var bottomRequested = false

    private func scrollToBottom() {
        bottomRequested = true
        lastRequestedOffset = nil
        position.scrollTo(edge: .bottom)
    }

    // MARK: Layout callbacks (from the views)

    func rowFrameChanged(_ id: MessageID, _ frame: CGRect) {
        frames[id] = frame
        layoutTick &+= 1
        scheduleSettle()
    }

    func rowRemoved(_ id: MessageID) {
        frames[id] = nil
        visible.remove(id)
    }

    func rowVisibilityChanged(_ id: MessageID, _ isVisible: Bool) {
        if isVisible { visible.insert(id) } else { visible.remove(id) }
        if isVisible && (restoring || lastRequestedOffset != nil) { scheduleSettle() }
    }

    func geometryChanged(_ new: ScrollGeometry) {
        let old = geometry
        geometry = new
        log("geometry offset \(new.contentOffset.y) size \(new.contentSize.height) insets \(new.contentInsets.top)/\(new.contentInsets.bottom) container \(new.containerSize.height) phase \(phase)")
        let layoutChanged = old == nil || old!.contentSize != new.contentSize
            || old!.containerSize != new.containerSize || old!.contentInsets != new.contentInsets
        if layoutChanged {
            layoutTick &+= 1
            scheduleSettle()
        } else if restoring || lastRequestedOffset != nil || bottomRequested {
            scheduleSettle()
        } else if isUserScrolling {
            captureAnchor()
        }
        checkLoadEdges(new)
    }

    func phaseChanged(to newPhase: ScrollPhase) {
        let wasScrolling = isUserScrolling
        phase = newPhase
        if newPhase == .interacting || newPhase == .tracking {
            // The reader took over: drop any programmatic target.
            lastRequestedOffset = nil
            bottomRequested = false
            restoring = false
        }
        if wasScrolling && newPhase == .idle {
            captureAnchor()
            restoring = false
            onSettled?()
            if let geometry { checkLoadEdges(geometry) }
        }
    }

    // MARK: Restoring

    private func captureAnchor() {
        guard let geometry else { return }
        if windowAtEnd && distanceToBottom(geometry) <= Self.pinDistance {
            anchor = .bottom
            setPinned(true)
        } else if let top = topRow {
            anchor = .row(top.id, top.y)
            setPinned(false)
        }
    }

    private func setPinned(_ pinned: Bool) {
        if isPinned != pinned { isPinned = pinned }
    }

    private func clampedOffset(for frame: CGRect, y: CGFloat, in g: ScrollGeometry) -> CGFloat {
        let target = frame.minY - y - g.contentInsets.top
        return min(max(target, Self.minOffset(g)), Self.maxOffset(g))
    }

    @ObservationIgnored private var settleScheduled = false

    /// Layout reports arrive one view at a time; settle once they are all in, so a half-updated set of
    /// frames never drives a scroll.
    private func scheduleSettle() {
        guard !settleScheduled else { return }
        settleScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.settleScheduled = false
            self.settle()
        }
    }

    /// Puts the anchor back after a layout change. Idempotent: does nothing when already in place.
    private func settle() {
        guard let geometry else { return }
        if phase == .interacting || phase == .tracking { return }
        if isUserScrolling && !restoring { return }
        switch anchor {
        case .bottom:
            guard windowAtEnd else { break }
            let target = Self.maxOffset(geometry)
            if abs(target - geometry.contentOffset.y) > 0.5 {
                if !bottomRequested {
                    log("bottom from \(geometry.contentOffset.y) to \(target)")
                    scrollToBottom()
                }
                return
            }
            bottomRequested = false
        case .row(let id, let y):
            guard let frame = frames[id] else { return }
            let target = clampedOffset(for: frame, y: y, in: geometry)
            if abs(target - geometry.contentOffset.y) > 0.5 {
                request(offset: target)
                return
            }
        }
        lastRequestedOffset = nil
        restoring = false
        onSettled?()
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        if Self.verbose {
            let text = message()
            Self.logger.debug("SCROLL \(text, privacy: .public)")
        }
        #endif
    }

    #if DEBUG
    static let verbose = UserDefaults.standard.bool(forKey: "uvsScrollLog")
    static let logger = Logger(subsystem: "campfire.bench", category: "scroll")

    func dumpVisible(_ tag: String) {
        guard let geometry else { return }
        let hb = Self.headerBottom(geometry)
        let list = visible.sorted().map { id in "\(id):\(frames[id].map { "\(Int($0.minY - hb))..\(Int($0.maxY - hb))" } ?? "nil")" }
        log("DUMP \(tag) offset \(geometry.contentOffset.y) visible \(list.joined(separator: " "))")
    }
    #endif

    private func request(offset: CGFloat) {
        bottomRequested = false
        log("request \(offset) current \(geometry!.contentOffset.y) insets \(geometry!.contentInsets.top) anchor \(anchor) size \(geometry!.contentSize.height) container \(geometry!.containerSize.height)")
        if let last = lastRequestedOffset, abs(last - offset) <= 0.25, abs(geometry!.contentOffset.y - offset) > 0.5 {
            // Already asked for this; wait for the scroll view to get there.
            return
        }
        lastRequestedOffset = offset
        position.scrollTo(y: offset + (geometry?.contentInsets.top ?? 0))
    }

    // MARK: Paging

    private func checkLoadEdges(_ g: ScrollGeometry) {
        // Paging mid-fling would fight the deceleration (SwiftUI keeps decelerating from the old offset),
        // so pages load once the scroll comes to rest; the edge check reruns then.
        guard !loadScheduled, !isUserScrolling, let store else { return }
        let fromTop = g.contentOffset.y - Self.minOffset(g)
        let fromBottom = Self.maxOffset(g) - g.contentOffset.y
        if !windowAtStart && fromTop < Self.loadDistance && hasFrame(for: ids.first ?? -1) {
            loadScheduled = true
            Task { @MainActor in
                store.loadOlder()
                self.loadScheduled = false
            }
        } else if !windowAtEnd && fromBottom < Self.loadDistance && hasFrame(for: ids.last ?? -1) {
            loadScheduled = true
            Task { @MainActor in
                store.loadNewer()
                self.loadScheduled = false
            }
        }
    }
}
