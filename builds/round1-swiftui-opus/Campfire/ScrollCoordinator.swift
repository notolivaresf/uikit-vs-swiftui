import CampfireKit
import SwiftUI

/// Keeps the room where the reader left it.
///
/// The room is either pinned to the bottom or anchored to a row: the topmost row under the header and how far
/// below the header its top sits. Only the reader's own scrolling (or a jump) moves the anchor; every layout change
/// (older page, new message, boost, text size, rotation) is followed by restoring it. Row frames are tracked in the
/// content's coordinate space, so they only change when layout changes, never while scrolling.
@MainActor
final class ScrollCoordinator {
    enum Anchor: Equatable {
        case bottom
        case row(id: MessageID, y: CGFloat)
    }

    weak var store: RoomStore?

    var anchor: Anchor = .bottom {
        didSet {
            let pinned = anchor == .bottom
            if store?.isPinned != pinned { store?.isPinned = pinned }
        }
    }
    /// Distance from the scroll view's top edge (under the status bar) to the header's bottom edge.
    var headerOffset: CGFloat { (geometry?.contentInsets.top ?? 0) + Theme.headerHeight }

    private(set) var frames: [MessageID: CGRect] = [:]
    private(set) var geometry: ScrollGeometry?
    private var phase: ScrollPhase = .idle
    private var layoutVersion = 0
    /// Set when the store is about to change layout: the anchor is frozen until it has been restored.
    private var restoring = false
    private var lastRequestedY: CGFloat?
    private var enforceScheduled = false
    private var edgeLoadPending = false
    private var lastRowRequest: MessageID?

    private var measure: (start: ContinuousClock.Instant, version: Int, expectLayout: Bool, hops: Int)?
    private var lastMs = 0

    static let pinDistance: CGFloat = 100

    private var userScrolling: Bool {
        switch phase {
        case .interacting, .decelerating, .tracking: true
        default: false
        }
    }

    // MARK: Inputs from the view

    func rowFrameChanged(_ id: MessageID, _ frame: CGRect) {
        frames[id] = frame
        layoutVersion &+= 1
        if case .row(let anchorID, _) = anchor, anchorID == id {
            // Geometry may still describe the old content size here, so do not clamp to it.
            enforce(clamped: false)
        }
        scheduleEnforce()
    }

    /// Rows of the lazy stack come and go as they scroll; only laid-out rows have frames.
    func rowDisappeared(_ id: MessageID) {
        frames.removeValue(forKey: id)
    }

    func rowsChanged(_ ids: Set<MessageID>) {
        frames = frames.filter { ids.contains($0.key) }
    }

    func geometryChanged(_ old: ScrollGeometry, _ new: ScrollGeometry) {
        geometry = new
        let layoutChanged = old.contentSize != new.contentSize || old.containerSize != new.containerSize
            || old.contentInsets != new.contentInsets
        if layoutChanged {
            layoutVersion &+= 1
            enforce()
            scheduleEnforce()
        } else if old.contentOffset != new.contentOffset {
            if userScrolling {
                if !restoring {
                    updateAnchor()
                    checkEdges()
                }
            } else {
                // Not the reader: our own restore, or the lazy stack re-estimating rows. Hold the anchor.
                scheduleEnforce()
            }
        }
        if !userScrolling && measure == nil { refreshLabel() }
    }

    func phaseChanged(_ new: ScrollPhase) {
        let wasUser = userScrolling
        phase = new
        if new == .idle {
            if !restoring || (wasUser && anchor == .bottom) {
                restoring = false
                updateAnchor()
                checkEdges()
            }
            refreshLabel()
        } else if new == .interacting {
            restoring = false
            lastRequestedY = nil
        }
    }

    /// The store is about to insert, remove or resize rows.
    func willChangeLayout() {
        // A reader dragging away from the bottom is not pinned any more, whatever the anchor last said.
        if userScrolling && anchor == .bottom { return }
        restoring = true
        scheduleEnforce()
    }

    // MARK: Anchor

    private func minOffset(_ g: ScrollGeometry) -> CGFloat { -g.contentInsets.top }

    /// `containerSize` excludes the insets; the scroll view's bounds are container plus insets.
    private func maxOffset(_ g: ScrollGeometry) -> CGFloat {
        max(minOffset(g), g.contentSize.height - g.containerSize.height - g.contentInsets.top)
    }

    private func clamp(_ y: CGFloat, _ g: ScrollGeometry) -> CGFloat {
        min(max(y, minOffset(g)), maxOffset(g))
    }

    func distanceToBottom() -> CGFloat {
        guard let g = geometry else { return 0 }
        return maxOffset(g) - g.contentOffset.y
    }

    /// The topmost row at least partly visible below the header, and its top relative to the header bottom.
    func topRow() -> (id: MessageID, y: CGFloat)? {
        guard let g = geometry else { return nil }
        let line = g.contentOffset.y + headerOffset
        // Rows are in id order, so the topmost visible row is the lowest id whose bottom is below the line.
        var best: (id: MessageID, y: CGFloat)?
        for (id, f) in frames where f.maxY > line + 0.5 && f.minY < line + g.containerSize.height {
            if best == nil || id < best!.id { best = (id, f.minY - line) }
        }
        return best
    }

    private func updateAnchor() {
        guard let store, geometry != nil else { return }
        if distanceToBottom() <= Self.pinDistance && store.hasNewest {
            anchor = .bottom
        } else if let top = topRow() {
            anchor = .row(id: top.id, y: top.y)
        }
        store.setJumpToBottomVisible(anchor != .bottom)
    }

    private func targetOffset(_ g: ScrollGeometry, clamped: Bool) -> CGFloat? {
        switch anchor {
        case .bottom:
            return maxOffset(g)
        case .row(let id, let y):
            guard let f = frames[id] else { return nil }
            let y = f.minY - headerOffset - y
            return clamped ? clamp(y, g) : y
        }
    }

    /// Moves the content back to the anchor if layout moved it. Returns true when nothing had to move.
    @discardableResult
    func enforce(clamped: Bool = true) -> Bool {
        guard let g = geometry, let store, store.isLoaded else { return false }
        // While the reader's finger (or momentum) moves the list, it wins: never pull it back to the bottom,
        // only compensate rows inserted or resized above the anchored row.
        if userScrolling && (!restoring || anchor == .bottom) { return true }
        if anchor == .bottom {
            // The lazy stack's height estimates move the end around; let the scroll view resolve "the end".
            if distanceToBottom() <= 0.5 { restoring = false; return true }
            store.requestScrollToBottom()
            return false
        }
        guard let target = targetOffset(g, clamped: clamped) else {
            // The anchored row is not laid out (lazy stack, after a jump): scroll it into view first.
            if case .row(let id, _) = anchor, store.rows.contains(where: { $0.id == id }), lastRowRequest != id {
                lastRowRequest = id
                store.requestScroll(toRow: id)
            }
            return false
        }
        lastRowRequest = nil
        if abs(target - g.contentOffset.y) <= 0.25 {
            restoring = false
            return true
        }
        scroll(to: target)
        return false
    }

    private func scroll(to y: CGFloat) {
        guard let store else { return }
        dlog("scroll to \(y) from \(geometry?.contentOffset.y ?? -1) anchor \(anchor)")
        lastRequestedY = y
        // ScrollPosition measures y from the inset-adjusted top, ScrollGeometry's contentOffset from the bounds top.
        let inset = geometry?.contentInsets.top ?? 0
        store.requestScroll(toY: y + inset)
    }

    private func scheduleEnforce() {
        guard !enforceScheduled else { return }
        enforceScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.enforceScheduled = false
            self.enforce()
        }
    }

    /// Reaching the top loads older messages; reaching the bottom of an older window loads newer ones.
    private func checkEdges() {
        guard let store, let g = geometry, store.isLoaded else { return }
        guard !edgeLoadPending else { return }
        let visibleTop = g.contentOffset.y + headerOffset
        if visibleTop < 400, !store.atOldest {
            edgeLoadPending = true
            DispatchQueue.main.async { [weak self] in self?.edgeLoadPending = false; store.loadOlder() }
        } else if !store.hasNewest, distanceToBottom() < 400 {
            edgeLoadPending = true
            DispatchQueue.main.async { [weak self] in self?.edgeLoadPending = false; store.loadNewer() }
        }
    }

    // MARK: Debug label

    /// Starts timing a debug-bar action (or the launch); the label shows the result once layout has settled.
    func beginMeasure(from start: ContinuousClock.Instant = .now, expectLayout: Bool) {
        measure = (start, layoutVersion, expectLayout, 0)
        scheduleSettleCheck()
    }

    private func scheduleSettleCheck() {
        DispatchQueue.main.async { [weak self] in self?.settleCheck() }
    }

    private func settleCheck() {
        guard var m = measure else { return }
        if m.hops % 50 == 0, let g = geometry { dlog("settle hops \(m.hops) off \(g.contentOffset.y) size \(g.contentSize) cont \(g.containerSize) ins \(g.contentInsets) vis \(g.visibleRect) target \(String(describing: targetOffset(g, clamped: true))) anchor \(anchor)") }
        m.hops += 1
        measure = m
        let laidOut = m.version != layoutVersion || !m.expectLayout
        let settled = enforce()
        let hasTop = topRow() != nil || store?.rows.isEmpty == true
        if m.hops >= 2, laidOut, settled, hasTop {
            lastMs = Int((ContinuousClock.now - m.start) / .milliseconds(1))
            dlog("settled after \(m.hops) hops: \(lastMs) ms")
            measure = nil
            if !userScrolling { updateAnchorAfterProgrammaticMove() }
            refreshLabel()
        } else if m.hops > 2000 {
            measure = nil
            refreshLabel()
        } else {
            scheduleSettleCheck()
        }
    }

    private func updateAnchorAfterProgrammaticMove() {
        guard let store else { return }
        store.setJumpToBottomVisible(anchor != .bottom)
    }

    func refreshLabel() {
        guard let store else { return }
        let pinned = anchor == .bottom
        var text = store.labelPrefix() + " pinned \(pinned ? "yes" : "no")"
        if let top = topRow() {
            var y = (top.y * 10).rounded() / 10
            if y == 0 { y = 0 }
            text += " top \(top.id) y \(String(format: "%.1f", y))"
        } else {
            text += " top 0 y 0.0"
        }
        text += " ms \(lastMs)"
        if store.debugLabel != text { store.debugLabel = text }
    }
}

func dlog(_ s: @autoclosure () -> String) {
    if Launch.verbose { NSLog("[cf] %@", s()) }
}
