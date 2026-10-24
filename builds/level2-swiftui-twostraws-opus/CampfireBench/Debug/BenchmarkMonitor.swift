import SwiftUI

/// Builds the debug bar's state label and times each debug-bar tap until its result is laid out on screen.
@MainActor
@Observable
final class BenchmarkMonitor {
    private struct Pending {
        let start: ContinuousClock.Instant
        let layoutTick: Int
        let needsLayout: Bool
        let isDone: @MainActor () -> Bool
    }

    private(set) var label = ""

    @ObservationIgnored private let store: RoomStore
    @ObservationIgnored private var milliseconds = 0
    @ObservationIgnored private var pending: Pending?

    init(store: RoomStore) {
        self.store = store
        // At launch: from the app's first line of code until the first rows are on screen.
        pending = Pending(start: LaunchClock.start, layoutTick: -1, needsLayout: false) { [unowned store] in
            guard let last = store.rows.last?.id else { return false }
            return store.scroller.hasFrame(for: last)
        }
        store.scroller.onSettled = { [weak self] in self?.update() }
    }

    /// Starts timing a tap. `isDone` says when the tap's result is in place.
    func begin(needsLayout: Bool = false, isDone: @escaping @MainActor () -> Bool = { true }) {
        pending = Pending(start: .now, layoutTick: store.scroller.layoutTick, needsLayout: needsLayout, isDone: isDone)
        Task { @MainActor [weak self] in
            // A tap whose result needs no layout pass still reports once the run loop turns.
            try? await Task.sleep(for: .milliseconds(16))
            self?.update()
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.update(force: true)
        }
    }

    func update(force: Bool = false) {
        let scroller = store.scroller
        if let pending {
            let laidOut = !pending.needsLayout || scroller.layoutTick != pending.layoutTick
            if force || (laidOut && scroller.isSettledAtAnchor && pending.isDone()) {
                milliseconds = LaunchClock.milliseconds(since: pending.start)
                self.pending = nil
            } else {
                return
            }
        }
        if scroller.isUserScrolling { return }
        let text = makeLabel()
        if text != label {
            label = text
            #if DEBUG
            scroller.dumpVisible(text)
            #endif
        }
    }

    private func makeLabel() -> String {
        let rows = store.rows
        let first = rows.first.map { String($0.id) } ?? "-"
        let last = rows.last.map { String($0.id) } ?? "-"
        let pinned = store.scroller.isPinned ? "yes" : "no"
        var top = "-"
        var y = "-"
        if let row = store.scroller.topRow {
            top = String(row.id)
            let rounded = (row.y * 10).rounded() / 10
            y = String(format: "%.1f", rounded == 0 ? 0 : rounded)
        }
        return "first \(first) last \(last) loaded \(rows.count) pinned \(pinned) top \(top) y \(y) ms \(milliseconds)"
    }
}
