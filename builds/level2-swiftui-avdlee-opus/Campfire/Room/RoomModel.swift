import SwiftUI
import CampfireKit
import os

/// Scroll geometry the room cares about, in the content's coordinate space.
struct ScrollSnapshot: Equatable {
    /// Content y of the scroll view's top edge.
    var visibleMinY: CGFloat = 0
    var visibleHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
    var containerWidth: CGFloat = 0
    var rawOffsetY: CGFloat = 0
    var insetTop: CGFloat = 0
    var insetBottom: CGFloat = 0

    var visibleMaxY: CGFloat { visibleMinY + visibleHeight }
    /// Header's bottom edge and the list's bottom edge in the `.scrollView` coordinate space, whose origin is
    /// the inner edge of the content insets (the header's bottom).
    var viewportHeaderBottom: CGFloat { 0 }
    var viewportBottom: CGFloat { visibleHeight - Metrics.headerHeight }
    /// Content y of the header's bottom edge (the header floats over the top of the scroll view).
    var headerBottomY: CGFloat { visibleMinY + Metrics.headerHeight }
    var distanceFromBottom: CGFloat { contentHeight - visibleMaxY }
}

/// The room: which messages are loaded, where the reader is, the live stream and the debug bar's numbers.
@Observable @MainActor
final class RoomModel {
    static let log = Logger(subsystem: "campfire.bench", category: "room")

    struct RowFrame {
        var frame: CGRect
        var gapBelow: CGFloat
        var minY: CGFloat { frame.minY }
        /// Bottom of what is drawn (the bubble), without the transparent margin and gap below it.
        var visibleMaxY: CGFloat { frame.maxY - gapBelow - Metrics.bubbleBottomMargin }
    }

    struct Anchor: Equatable {
        let id: MessageID
        /// Row top relative to the header's bottom edge.
        let y: CGFloat
        /// Height of the row's scroll target (row plus the gap below it).
        let height: CGFloat
    }

    let benchmark: Bool
    static let verbose = ProcessInfo.processInfo.arguments.contains("-uvsVerbose")

    // MARK: Data

    @ObservationIgnored private var dataset: Dataset?
    @ObservationIgnored private var builder: RowBuilder?
    /// Every message, oldest first; ids are 1...count, so a message's index is id - 1.
    @ObservationIgnored private var all: [Message] = []
    @ObservationIgnored private var rowCache: [MessageID: RowData] = [:]
    @ObservationIgnored private var extraBoosts: [MessageID: [RowData.BoostData]] = [:]
    /// Indices into `all` of the loaded slice.
    @ObservationIgnored private var window: Range<Int> = 0..<0

    private(set) var rows: [RowData] = []
    private(set) var isLoaded = false
    private(set) var atBeginning = false
    private(set) var atNewest = true

    // MARK: Scrolling

    /// Not observed: SwiftUI writes the reader's position back on every scroll, and observing that would
    /// re-render the list in a loop. Programmatic scrolls go through `scroll(_:)`, which bumps `scrollRevision`.
    @ObservationIgnored var position = ScrollPosition(idType: MessageID.self)
    private(set) var scrollRevision = 0
    /// Set just before a change that only adds or removes content above the reader: when the new content
    /// height arrives, the offset moves by the same amount inside that layout pass, so nothing visibly jumps.
    @ObservationIgnored private var heldPosition: (headerBottomY: CGFloat, contentHeight: CGFloat)?
    /// A programmatic scroll has been requested and not yet confirmed by a settle pass.
    @ObservationIgnored private var requestInFlight = false
    @ObservationIgnored private var deferredUserPosition: ScrollPosition?
    private(set) var pinned = true
    private(set) var unseenCount = 0
    @ObservationIgnored private(set) var snapshot = ScrollSnapshot()
    /// Each realized row's frame in the scroll view's coordinates, including the gap below it.
    @ObservationIgnored private var rowFrames: [MessageID: RowFrame] = [:]
    @ObservationIgnored private var phase: ScrollPhase = .idle
    @ObservationIgnored private var isPaging = false
    /// Set by a change that moved content above the reader; resolved once the new layout is known.
    @ObservationIgnored private var pendingAnchor: Anchor?
    @ObservationIgnored private var pendingPin = false
    @ObservationIgnored private var settleToken = 0
    /// Bumped by every geometry callback; settling waits for it to go quiet.
    @ObservationIgnored private var layoutGeneration = 0
    /// Last known reading position, refreshed while the room is at rest.
    @ObservationIgnored private var restingAnchor: Anchor?

    // MARK: Text size

    private(set) var textSizeOverride: DynamicTypeSize?
    @ObservationIgnored var systemTextSize: DynamicTypeSize = .large

    // MARK: Live stream

    enum StreamState { case idle, running, done }
    private(set) var streamState: StreamState = .idle
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var burstTask: Task<Void, Never>?
    @ObservationIgnored private var nextBoostID = 5_000_000

    // MARK: Debug label

    private(set) var stateLabel = "loading"
    @ObservationIgnored private var lastMS = 0
    @ObservationIgnored private var measureStart: ContinuousClock.Instant?

    init(benchmark: Bool) {
        self.benchmark = benchmark
        measureStart = LaunchClock.start
    }

    // MARK: Loading

    func load() async {
        guard dataset == nil else { return }
        if Self.verbose { Self.log.notice("launch: load start t=\((ContinuousClock.now - LaunchClock.start).milliseconds, privacy: .public)") }
        let data = await DataPreload.dataset()
        if Self.verbose { Self.log.notice("launch: data ready t=\((ContinuousClock.now - LaunchClock.start).milliseconds, privacy: .public)") }
        dataset = data
        builder = RowBuilder(dataset: data)
        all = data.messages
        setWindow(Windowing.lastPage(all))
        isLoaded = true
        pinned = true
        scroll { $0.scrollTo(edge: .bottom) }
        settle(pin: true)
    }

    private func setWindow(_ slice: ArraySlice<Message>) {
        window = slice.startIndex..<slice.endIndex
        rebuildRows()
    }

    private func rebuildRows() {
        guard let builder else { return }
        var out: [RowData] = []
        out.reserveCapacity(window.count)
        for i in window {
            let m = all[i]
            if let cached = rowCache[m.id] {
                out.append(cached)
            } else {
                let row = builder.row(for: m, after: i > 0 ? all[i - 1] : nil, extraBoosts: extraBoosts[m.id] ?? [])
                rowCache[m.id] = row
                out.append(row)
            }
        }
        rows = out
        if let first = out.first?.id, let last = out.last?.id {
            rowFrames = rowFrames.filter { $0.key >= first && $0.key <= last }
        }
        atBeginning = window.lowerBound == 0
        atNewest = window.upperBound == all.count
        if atNewest, pinned { unseenCount = 0 }
    }

    private func refreshRow(_ id: MessageID) {
        guard let builder, id >= 1, id <= all.count else { return }
        let i = id - 1
        let row = builder.row(for: all[i], after: i > 0 ? all[i - 1] : nil, extraBoosts: extraBoosts[id] ?? [])
        rowCache[id] = row
        if window.contains(i) {
            rows[i - window.lowerBound] = row
        }
    }

    // MARK: Debug bar actions

    func reset() {
        beginMeasure()
        stopBurst()
        textSizeOverride = nil
        setWindow(Windowing.lastPage(all))
        pinned = true
        unseenCount = 0
        scroll { $0.scrollTo(edge: .bottom) }
        settle(pin: true)
    }

    func jump(to id: MessageID) {
        guard id >= 1, id <= all.count else { return }
        beginMeasure()
        setWindow(Windowing.around(id, in: all))
        if Self.verbose, let st = measureStart { Self.log.notice("jump rebuilt t=\((ContinuousClock.now - st).milliseconds, privacy: .public)") }
        pinned = false
        let anchor = Anchor(id: id, y: 0, height: 0)
        scroll { $0.scrollTo(id: id, anchor: .top) }
        settle(anchor: anchor)
    }

    func loadOlderTapped() {
        beginMeasure()
        if !loadOlder() { settle() }
    }

    func textSizeUp() {
        beginMeasure()
        let current = textSizeOverride ?? systemTextSize
        let all = DynamicTypeSize.allCases
        if let i = all.firstIndex(of: current), i + 1 < all.count {
            changeTextSize(to: all[i + 1])
        } else {
            changeTextSize(to: nil)
        }
    }

    private func changeTextSize(to size: DynamicTypeSize?) {
        let anchor = currentAnchor()
        let wasPinned = pinned
        textSizeOverride = size
        if wasPinned {
            scroll { $0.scrollTo(edge: .bottom) }
            settle(pin: true)
        } else {
            settle(anchor: anchor)
        }
    }

    /// The system text size changed under us (Settings / Control Center).
    func systemTextSizeChanged(to size: DynamicTypeSize, from old: DynamicTypeSize) {
        systemTextSize = size
        guard textSizeOverride == nil else { return }
        relayout(using: restingAnchor)
    }

    /// Rotation or any other container change: keep the top row (or the pin) once the new layout lands.
    func containerChanged() {
        relayout(using: restingAnchor)
    }

    private func relayout(using anchor: Anchor?) {
        if pinned {
            scroll { $0.scrollTo(edge: .bottom) }
            settle(pin: true, measure: false)
        } else if let anchor {
            settle(anchor: anchor, measure: false)
        }
    }

    func boostBurst() {
        guard isLoaded, let target = all.last?.id else { return }
        stopBurst()
        let people: [(UserID, String)] = [(2, "👍"), (3, "🎉"), (4, "🔥"), (5, "❤️"), (6, "😂")]
        burstTask = Task { [weak self] in
            for (index, item) in people.enumerated() {
                if index > 0 { try? await Task.sleep(for: .milliseconds(200)) }
                guard let self, !Task.isCancelled else { return }
                self.addBoost(to: target, id: self.nextBoostID, boosterID: item.0, content: item.1)
                self.nextBoostID += 1
            }
        }
    }

    private func stopBurst() {
        burstTask?.cancel()
        burstTask = nil
    }

    func startStream() {
        guard isLoaded, streamState == .idle, let dataset else { return }
        streamState = .running
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard let self else { return }
                self.apply(event)
            }
            self?.streamState = .done
            self?.updateLabel()
        }
    }

    func jumpToBottom() {
        if atNewest {
            pinned = true
            unseenCount = 0
            scroll { $0.scrollTo(edge: .bottom) }
            settle(pin: true, measure: false)
        } else {
            reset()
        }
    }

    // MARK: Live events

    private func apply(_ event: FeedEvent) {
        switch event {
        case .message(let message):
            guard message.id == all.count + 1 else { return }
            all.append(message)
            guard atNewest else { unseenCount += 1; return }
            if pinned, phase == .idle || phase == .animating {
                window = window.lowerBound..<all.count
                // Campfire keeps at most 300 and trims once it is 20+ over, not one row per message.
                if window.count > Windowing.maxLoaded + Self.trimSlack {
                    window = (all.count - Windowing.maxLoaded)..<all.count
                }
                rebuildRows()
                scroll { $0.scrollTo(edge: .bottom) }
                settle(pin: true, measure: false)
            } else if window.count < Windowing.maxLoaded + Self.trimSlack {
                // Below the reader: nothing on screen moves.
                window = window.lowerBound..<all.count
                rebuildRows()
                unseenCount += pinned ? 0 : 1
                settle(measure: false)
            } else {
                // Window is full and the reader is up in the history: leave it, count it.
                atNewest = false
                unseenCount += 1
            }
        case .boost(let messageID, let boost):
            addBoost(to: messageID, id: boost.id, boosterID: boost.boosterID, content: boost.content)
        case .typingStarted, .typingStopped:
            break
        }
    }

    /// CampfireKit's Boost has no public initializer, so boosts that arrive after load live here.
    private func addBoost(to id: MessageID, id boostID: Int, boosterID: UserID, content: String) {
        guard id >= 1, id <= all.count, let builder else { return }
        let anchor = currentAnchor()
        let aboveReader = anchor.map { id < $0.id } ?? false
        // Only a row that is laid out can change the content height now; an unrealized one is just an estimate.
        if aboveReader, !(pinned && atNewest), rowFrames[id] != nil { holdPositionAcrossChangeAbove() }
        extraBoosts[id, default: []].append(RowData.BoostData(
            id: boostID, boosterID: boosterID, initial: RowBuilder.initial(builder.name(boosterID)), content: content))
        refreshRow(id)
        guard window.contains(id - 1) else { return }
        if pinned, atNewest {
            scroll { $0.scrollTo(edge: .bottom) }
            settle(pin: true, measure: false)
        } else if let anchor, aboveReader {
            preserve(anchor)
        } else {
            settle(measure: false)
        }
    }

    // MARK: Paging

    /// Prepends the 40 messages before the first loaded one. Returns false at the very beginning.
    @discardableResult
    private func loadOlder() -> Bool {
        guard isLoaded, window.lowerBound > 0, let first = rows.first?.id else { return false }
        let anchor = currentAnchor()
        let page = Windowing.page(before: first, in: all)
        guard !page.isEmpty else { return false }
        // Prepend with the bottom edge fixed; trimming the far (bottom) end waits for the next settle so the
        // two changes never move content on both sides of the reader in one layout.
        holdPositionAcrossChangeAbove()
        window = page.startIndex..<window.upperBound
        rebuildRows()
        if let anchor { preserve(anchor) } else { settle() }
        return true
    }

    /// Appends the 40 messages after the last loaded one (only when the window is not at the newest).
    @discardableResult
    private func loadNewer() -> Bool {
        guard isLoaded, !atNewest, let last = rows.last?.id else { return false }
        let anchor = currentAnchor()
        let page = Windowing.page(after: last, in: all)
        guard !page.isEmpty else { return false }
        window = window.lowerBound..<page.endIndex
        rebuildRows()
        if let anchor { preserve(anchor) } else { settle(measure: false) }
        return true
    }

    /// Swaps SwiftUI's "positioned by user" state (left by a drag or fling) for the equivalent position anchored
    /// to the top row. Left as "positioned by user", the lazy stack could loop forever re-placing rows once
    /// messages were appended below it; anchored to a row, it also keeps that row in place by itself.
    private func anchorUserPosition() -> Bool {
        guard phase == .idle, position.isPositionedByUser else { return false }
        recomputePinned()
        guard !pinned, let a = currentAnchor() else { return false }
        let visible = snapshot.visibleHeight - Metrics.headerHeight
        // The unit anchor also works for rows taller than the screen (it goes negative).
        guard abs(visible - a.height) > 1 else { return false }
        scroll { $0.scrollTo(id: a.id, anchor: UnitPoint(x: 0, y: a.y / (visible - a.height))) }
        settle(anchor: a, measure: false)
        return true
    }

    /// Keeps at most `Windowing.maxLoaded` rows, dropping from the end farther from the reader.
    private func trimWindowIfNeeded() -> Bool {
        guard window.count > Windowing.maxLoaded + Self.trimSlack, phase == .idle else { return false }
        let anchor = currentAnchor()
        let readerIndex = anchor.flatMap { a in rows.firstIndex { $0.id == a.id } } ?? rows.count / 2
        if readerIndex < rows.count / 2 {
            window = window.lowerBound..<(window.lowerBound + Windowing.maxLoaded)
        } else {
            if !(pinned && atNewest) { holdPositionAcrossChangeAbove() }
            window = (window.upperBound - Windowing.maxLoaded)..<window.upperBound
        }
        rebuildRows()
        if pinned, atNewest { settle(pin: true, measure: false) } else if let anchor { settle(anchor: anchor, measure: false) }
        return true
    }

    // MARK: Anchoring

    /// The topmost row at least partly visible below the header.
    /// A row counts as on screen once at least this much of it shows below the header (threaded rows overlap
    /// the previous row by a fraction of a point, which must not make that row the top one).
    static let visibleSliver: CGFloat = 1
    static let trimSlack = 20

    func currentAnchor() -> Anchor? {
        let top = snapshot.viewportHeaderBottom
        let bottom = snapshot.viewportBottom
        // The stack is lazy: only realized rows report frames, and a row it keeps around off screen can hold a
        // stale one. So take rows whose frames overlap the screen, keep the longest run of consecutive rows
        // whose frames meet edge to edge (stale frames don't), and pick its first row below the header.
        let candidates = rowFrames
            .filter { $0.value.visibleMaxY > top + Self.visibleSliver && $0.value.minY < bottom }
            .sorted { $0.key < $1.key }
        guard !candidates.isEmpty else { return nil }
        var bestRun: ArraySlice<(key: MessageID, value: RowFrame)> = candidates[0..<1]
        var runStart = 0
        for i in 1..<max(1, candidates.count) {
            let prev = candidates[i - 1], cur = candidates[i]
            let chained = cur.key == prev.key + 1 && abs(cur.value.minY - prev.value.frame.maxY) < 1.5
            if !chained { runStart = i }
            if i - runStart + 1 > bestRun.count { bestRun = candidates[runStart...i] }
        }
        let first = bestRun.first!
        return Anchor(id: first.key, y: first.value.minY - top, height: first.value.frame.height)
    }

    /// Keeps `anchor` at the same height on screen after a change above it.
    private func preserve(_ anchor: Anchor) {
        // Everything that changed is above the reader: keeping the bottom edge fixed keeps the reader in place
        // in the same frame. The settle pass checks the result and corrects it if needed.
        settle(anchor: anchor)
    }

    /// SwiftUI reports the reader's position back through the binding. Right after a content change it reports
    /// "positioned by user" before our own request has been applied; taking that would cancel the request.
    func positionWritten(_ value: ScrollPosition) {
        if Self.verbose { Self.log.notice("position written \(String(describing: value), privacy: .public) inFlight=\(self.requestInFlight)") }
        if requestInFlight, value.isPositionedByUser {
            deferredUserPosition = value
            return
        }
        deferredUserPosition = nil
        position = value
    }

    /// Once our request has landed (or the reader takes over), the binding must hold SwiftUI's own value again;
    /// a stale request left in it would be re-applied on every later render.
    private func endScrollRequest() {
        requestInFlight = false
        if let value = deferredUserPosition {
            position = value
            deferredUserPosition = nil
        }
    }

    private func holdPositionAcrossChangeAbove() {
        heldPosition = (snapshot.headerBottomY, snapshot.contentHeight)
    }

    /// After the next layout: fix the reading position, refresh the label and finish timing.
    private func settle(anchor: Anchor? = nil, pin: Bool = false, measure: Bool = true) {
        if let anchor { pendingAnchor = anchor; pendingPin = false }
        if pin { pendingPin = true; pendingAnchor = nil }
        settleToken += 1
        let token = settleToken
        scheduleSettle(token: token, pass: 0)
    }

    private func scheduleSettle(token: Int, pass: Int) {
        let startGeneration = layoutGeneration
        Task { @MainActor [weak self] in
            // Wait for SwiftUI to lay out and report geometry: at least one geometry callback after the change,
            // then a frame with no further callbacks (so a slow or busy device is not read mid-layout).
            var seen = startGeneration
            var quiet = 0
            for _ in 0..<60 {
                try? await Task.sleep(for: .milliseconds(8))
                guard let self, token == self.settleToken else { return }
                if self.layoutGeneration != seen {
                    seen = self.layoutGeneration
                    quiet = 0
                } else if seen != startGeneration || quiet >= 3 {
                    quiet += 1
                    if quiet >= 2 { break }
                } else {
                    quiet += 1
                }
            }
            self?.finishSettle(token: token, pass: pass)
        }
    }

    private func finishSettle(token: Int, pass: Int) {
        guard token == settleToken else { return }
        var corrected = false
        if pendingPin {
            if snapshot.distanceFromBottom > 0.5 {
                scroll { $0.scrollTo(edge: .bottom) }
                corrected = true
            }
        } else if let anchor = pendingAnchor, rowFrames[anchor.id] == nil, rows.contains(where: { $0.id == anchor.id }) {
            // The row is not realized (lazy stack): bring it in first, then fine-tune on the next pass.
            scroll { $0.scrollTo(id: anchor.id, anchor: .top) }
            corrected = true
        } else if let anchor = pendingAnchor, let f = rowFrames[anchor.id] {
            // Row frames are in viewport coordinates; move the content by the row's error.
            let error = (f.minY - snapshot.viewportHeaderBottom) - anchor.y
            let target = snapshot.headerBottomY + error
            let maxTarget = max(0, snapshot.contentHeight - (snapshot.visibleHeight - Metrics.headerHeight))
            let clamped = min(max(target, 0), maxTarget)
            if abs(clamped - snapshot.headerBottomY) > 0.25 {
                scroll { $0.scrollTo(y: clamped) }
                corrected = true
            }
        }
        if Self.verbose, let st = measureStart { Self.log.notice("settle t=\((ContinuousClock.now - st).milliseconds, privacy: .public)") }
        if Self.verbose { Self.log.notice("settle pass=\(pass) corrected=\(corrected) pin=\(self.pendingPin) anchor=\(String(describing: self.pendingAnchor), privacy: .public) now=\(String(describing: self.currentAnchor()), privacy: .public)") }
        if !corrected, pass < 4, !rows.isEmpty, currentAnchor() == nil {
            // The lazy stack can end up with nothing realized at the current offset (after a burst of size
            // estimate changes). Scrolling by identity makes it lay the rows out again.
            if pinned, atNewest, let last = rows.last?.id {
                scroll { $0.scrollTo(id: last, anchor: .bottom) }
            } else if let id = restingAnchor?.id ?? rows.first?.id {
                scroll { $0.scrollTo(id: id, anchor: .top) }
            }
            corrected = true
        }
        if corrected, pass < 4 {
            scheduleSettle(token: token, pass: pass + 1)
            return
        }
        pendingAnchor = nil
        pendingPin = false
        endScrollRequest()
        heldPosition = nil
        if trimWindowIfNeeded() { return }
        if anchorUserPosition() { return }
        recomputePinned()
        if let start = measureStart {
            lastMS = Int((ContinuousClock.now - start).milliseconds.rounded(.down))
            measureStart = nil
        }
        restingAnchor = currentAnchor()
        updateLabel()
    }

    private func scroll(_ change: (inout ScrollPosition) -> Void) {
        change(&position)
        if Self.verbose { Self.log.notice("scroll request \(String(describing: self.position), privacy: .public)") }
        requestInFlight = true
        scrollRevision &+= 1
    }

    private func beginMeasure() {
        measureStart = .now
    }

    // MARK: Geometry input

    func scrollChanged(_ new: ScrollSnapshot) {
        let old = snapshot
        snapshot = new
        layoutGeneration &+= 1
        if let held = heldPosition, new.contentHeight != held.contentHeight {
            if Self.verbose { Self.log.notice("held compensation from \(held.headerBottomY) by \(new.contentHeight - held.contentHeight)") }
            heldPosition = nil
            let target = held.headerBottomY + new.contentHeight - held.contentHeight
            scroll { $0.scrollTo(y: target) }
            snapshot.visibleMinY = target - Metrics.headerHeight
            return
        }
        if Self.verbose { Self.log.notice("scroll raw=\(new.rawOffsetY) insets=\(new.insetTop)/\(new.insetBottom) minY=\(new.visibleMinY) h=\(new.visibleHeight) content=\(new.contentHeight) dist=\(new.distanceFromBottom)") }
        if old.containerWidth != new.containerWidth || old.visibleHeight != new.visibleHeight, old.visibleHeight > 0 {
            containerChanged()
            return
        }
        if pendingAnchor == nil, !pendingPin {
            recomputePinned()
            if phase == .idle {
                restingAnchor = currentAnchor()
                updateLabel()
            }
            checkPaging()
        }
    }

    func rowDisappeared(_ id: MessageID) {
        rowFrames[id] = nil
    }

    func rowFrameChanged(_ id: MessageID, _ frame: CGRect, gapBelow: CGFloat) {
        layoutGeneration &+= 1
        rowFrames[id] = RowFrame(frame: frame, gapBelow: gapBelow)
    }

    func phaseChanged(_ newPhase: ScrollPhase) {
        if Self.verbose { Self.log.notice("phase \(String(describing: newPhase), privacy: .public)") }
        phase = newPhase
        if newPhase == .interacting { endScrollRequest() }
        if newPhase == .idle, pendingAnchor == nil, !pendingPin {
            recomputePinned()
            restingAnchor = currentAnchor()
            // Geometry may still be landing; settle reads it once quiet, then re-anchors the position.
            settle(measure: false)
            updateLabel()
            checkPaging()
        }
    }

    private func recomputePinned() {
        let now = atNewest && snapshot.distanceFromBottom <= Metrics.pinnedThreshold
        if now != pinned { pinned = now }
        if pinned, unseenCount != 0 { unseenCount = 0 }
    }

    private func checkPaging() {
        // Never while a finger is on the list: moving the offset would cut the drag short.
        guard isLoaded, !isPaging, pendingAnchor == nil, !pendingPin, phase != .interacting else { return }
        guard snapshot.visibleHeight > 0 else { return }
        if !atBeginning, snapshot.visibleMinY < 400 {
            isPaging = true
            loadOlder()
            isPaging = false
        } else if !atNewest, snapshot.distanceFromBottom < 400 {
            isPaging = true
            loadNewer()
            isPaging = false
        }
    }

    /// Development aid: scroll programmatically as if the reader had dragged.
    func debugScroll(by dy: CGFloat) {
        let target = snapshot.headerBottomY + dy
        pinned = snapshot.contentHeight - (target + snapshot.visibleHeight - Metrics.headerHeight) <= Metrics.pinnedThreshold
        pendingPin = false
        pendingAnchor = nil
        scroll { $0.scrollTo(y: target) }
        settle(measure: false)
    }

    // MARK: Label

    func updateLabel() {
        guard isLoaded else { return }
        let first = rows.first?.id ?? 0
        let last = rows.last?.id ?? 0
        let anchor = currentAnchor()
        let top = anchor.map { String($0.id) } ?? "-"
        var y = anchor.map { (($0.y * 10).rounded()) / 10 } ?? 0
        if y == 0 { y = 0 }
        let label = "first \(first) last \(last) loaded \(rows.count) pinned \(pinned ? "yes" : "no") top \(top) y \(String(format: "%.1f", y)) ms \(lastMS)"
        if label != stateLabel { stateLabel = label }
    }

    var streamDone: Bool { streamState == .done }
    var textSize: DynamicTypeSize? { textSizeOverride }
    var showJumpToBottom: Bool { isLoaded && (!pinned || !atNewest) }
}

extension Duration {
    var milliseconds: Double {
        let c = components
        return Double(c.seconds) * 1000 + Double(c.attoseconds) / 1e15
    }
}

/// Generates the 50,000-message dataset on a background thread, started from `App.init` so it overlaps the
/// app's own start-up.
enum DataPreload {
    nonisolated(unsafe) private static var task: Task<Dataset, Never>?

    static func start() {
        guard task == nil else { return }
        task = Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }
    }

    static func dataset() async -> Dataset {
        start()
        return await task!.value
    }
}

/// Process-wide launch timestamp, taken on the first line of the app's own code.
enum LaunchClock {
    nonisolated(unsafe) static var start: ContinuousClock.Instant = .now
    static func mark() { start = .now }
}
