import SwiftUI
import CampfireKit

struct ScrollSnapshot: Equatable {
    var offset: CGFloat = 0
    var height: CGFloat = 0
    var contentHeight: CGFloat = 0
    var width: CGFloat = 0
    var distanceToBottom: CGFloat { max(0, contentHeight - offset - height) }
}

struct RowFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct VisibleAnchor: Equatable {
    let id: Int
    let y: CGFloat
}

enum Restoration: Equatable {
    case bottom
    case row(VisibleAnchor)
}

@MainActor @Observable
final class RoomDiagnostics {
    var first = 0
    var last = 0
    var loaded = 0
    var pinned = true
    var top = 0
    var y: CGFloat = 0
    var milliseconds = 0
    var label: String {
        "first \(first) last \(last) loaded \(loaded) pinned \(pinned ? "yes" : "no") top \(top) y \(String(format: "%.1f", y)) ms \(milliseconds)"
    }
}

struct RoomView: View {
    let started: ContinuousClock.Instant
    @State private var store = RoomStore()
    @State private var diagnostics = RoomDiagnostics()
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var snapshot = ScrollSnapshot()
    @State private var frames: [Int: CGRect] = [:]
    @State private var anchor: VisibleAnchor?
    @State private var pinned = true
    @State private var restoration: Restoration? = .bottom
    @State private var awaitingScroll: Restoration?
    @State private var textOverride: DynamicTypeSize?
    @State private var tapStart: ContinuousClock.Instant?
    @State private var finishTask: Task<Void, Never>?
    @State private var scrollTask: Task<Void, Never>?
    @State private var isScrolling = false
    @State private var paging = false
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @Environment(\.colorScheme) private var scheme
    private let benchmark = ProcessInfo.processInfo.arguments.contains("-uvsBenchmark")

    var body: some View {
        let colors = RoomColors(dark: scheme == .dark)
        VStack(spacing: 0) {
            RoomHeader(title: "General").zIndex(1)
            if benchmark {
                DebugBar(diagnostics: diagnostics, streamDone: store.streamDone,
                         streaming: store.streaming, action: debugAction)
            }
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    if store.rows.first?.id == 1 { WelcomeCard() }
                    ForEach(store.rows) { row in
                        MessageRow(row: row, users: store.users)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(key: RowFrames.self,
                                        value: [row.id: geometry.frame(in: .named("chat-content"))])
                                }
                            }
                            .padding(.top, row.presentation.isThreaded ? -1.2 : row.presentation.isFirstOfDay ? 0 : 21.28)
                            .id(row.id)
                    }
                }
                .coordinateSpace(name: "chat-content")
                .padding(.bottom, 1.6)
            }
            .clipped()
            .accessibilityIdentifier("chat-scroll")
            .scrollPosition($position)
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .onScrollGeometryChange(for: ScrollSnapshot.self) { geometry in
                ScrollSnapshot(offset: geometry.visibleRect.minY, height: geometry.containerSize.height,
                               contentHeight: geometry.contentSize.height, width: geometry.containerSize.width)
            } action: { old, new in
                snapshot = new
                if isScrolling && restoration == nil && awaitingScroll == nil { pinned = new.distanceToBottom <= 100 }
                updateDiagnostics()
                if restoration == .bottom { applyRestoration() }
                finishMeasurement()
                if !paging && restoration == nil && awaitingScroll == nil {
                    if !pinned && new.offset < 60 { pageOlder() }
                    else if isScrolling && new.distanceToBottom < 60 && store.rows.last?.id != store.history.last?.id { pageNewer() }
                }
            }
            .onScrollPhaseChange { _, phase in
                isScrolling = phase == .interacting || phase == .decelerating
                if phase == .idle {
                    updateDiagnostics()
                    finishMeasurement()
                }
            }
            .onPreferenceChange(RowFrames.self) { new in
                if !frames.isEmpty && frames != new && restoration == nil {
                    if let awaitingScroll { restoration = awaitingScroll } else { preserve() }
                }
                frames = new
                applyRestoration()
                updateDiagnostics()
                finishMeasurement()
            }
            .overlay(alignment: .bottomTrailing) {
                if store.ready && (!pinned || store.hasUnread) {
                    Button {
                        pinned = true
                        store.followsBottom = true
                        restoration = .bottom
                        store.newest()
                    } label: {
                        Label("Jump to bottom", systemImage: "arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(colors.background, in: Capsule())
                            .overlay(Capsule().stroke(colors.outline, lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .accessibilityIdentifier("jump-bottom")
                }
            }
            .environment(\.dynamicTypeSize, textOverride ?? systemTextSize)
            RoomComposer()
        }
        .foregroundStyle(colors.text)
        .background(colors.background)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .task {
            tapStart = started
            await store.load()
        }
    }

    private func preserve() {
        restoration = pinned ? .bottom : anchor.map(Restoration.row)
    }

    private func applyRestoration() {
        guard let target = restoration, !frames.isEmpty else { return }
        awaitingScroll = target
        pinned = target == .bottom
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            switch target {
            case .bottom:
                position.scrollTo(edge: .bottom)
                pinned = true
            case .row(let target):
                guard let frame = frames[target.id] else { return }
                position.scrollTo(y: max(0, frame.minY - target.y))
                pinned = false
            }
        }
        restoration = nil
        paging = false
        finishMeasurement()
    }

    private func updateDiagnostics() {
        if let awaitingScroll {
            switch awaitingScroll {
            case .bottom:
                guard snapshot.distanceToBottom < 1 else { return }
            case .row(let target):
                guard let frame = frames[target.id], abs(frame.minY - snapshot.offset - target.y) < 1 else { return }
            }
            self.awaitingScroll = nil
        }
        let visible = store.rows.first { row in
            guard let frame = frames[row.id] else { return false }
            return frame.maxY - 1.6 > snapshot.offset + 0.5 && frame.minY + 1.6 < snapshot.offset + snapshot.height
        }
        if let visible, let frame = frames[visible.id] {
            anchor = VisibleAnchor(id: visible.id, y: frame.minY - snapshot.offset)
            diagnostics.top = visible.id
            diagnostics.y = frame.minY - snapshot.offset
        }
        diagnostics.first = store.rows.first?.id ?? 0
        diagnostics.last = store.rows.last?.id ?? 0
        diagnostics.loaded = store.rows.count
        diagnostics.pinned = pinned
        store.followsBottom = pinned
    }

    private func finishMeasurement() {
        guard tapStart != nil, store.ready, !frames.isEmpty else { return }
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled, let tapStart, restoration == nil, awaitingScroll == nil else { return }
            updateDiagnostics()
            let elapsed = tapStart.duration(to: .now).components
            diagnostics.milliseconds = Int(elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000)
            self.tapStart = nil
        }
    }

    private func pageOlder() {
        guard !paging else { return }
        preserve()
        paging = true
        if !store.loadOlder() { restoration = nil; paging = false; finishMeasurement() }
    }

    private func pageNewer() {
        restoration = anchor.map(Restoration.row)
        pinned = false
        paging = true
        store.loadNewer()
    }

    private func debugAction(_ action: DebugAction) {
        if action != .startStream && action != .boostBurst { tapStart = .now }
        switch action {
        case .reset:
            restoration = .bottom
            textOverride = nil
            pinned = true
            store.reset()
        case .jump:
            restoration = .row(VisibleAnchor(id: 2500, y: 0))
            pinned = false
            store.jump(to: 2500)
        case .older: pageOlder()
        case .startStream: store.startStream()
        case .textSize:
            preserve()
            let sizes = DynamicTypeSize.allCases
            let index = sizes.firstIndex(of: textOverride ?? systemTextSize) ?? 0
            textOverride = index + 1 < sizes.count ? sizes[index + 1] : nil
        case .boostBurst: store.boostBurst()
        }
    }
}

enum DebugAction { case reset, jump, older, startStream, textSize, boostBurst }

struct DebugBar: View {
    let diagnostics: RoomDiagnostics
    let streamDone: Bool
    let streaming: Bool
    let action: (DebugAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            FlowLayout(spacing: 8) {
                Button("Reset") { action(.reset) }
                Button("Jump to 2500") { action(.jump) }
                Button("Load older") { action(.older) }
                Button("Start stream") { action(.startStream) }.disabled(streaming || streamDone)
                Button("Text size +") { action(.textSize) }
                Button("Boost burst") { action(.boostBurst) }
                if streamDone { Text("Stream done").accessibilityIdentifier("stream-done") }
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            Text(diagnostics.label)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("benchmark-state")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.primary.opacity(0.05))
    }
}
