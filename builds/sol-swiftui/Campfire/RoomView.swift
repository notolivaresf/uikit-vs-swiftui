import SwiftUI
import CampfireKit

private struct RoomLayout: Equatable {
    var frames: [Int: CGRect] = [:]
    var width: CGFloat = 0
    var textSize: DynamicTypeSize = .large
}

private struct RowFrames: PreferenceKey {
    static let defaultValue = RoomLayout()
    static func reduce(value: inout RoomLayout, nextValue: () -> RoomLayout) {
        let next = nextValue()
        value.frames.merge(next.frames, uniquingKeysWith: { _, new in new })
        if next.width > 0 { value.width = next.width; value.textSize = next.textSize }
    }
}

private struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var height: CGFloat = 0
    var contentHeight: CGFloat = 0
    var width: CGFloat = 0
}

private struct RoomAnchor {
    var id: Int
    var y: CGFloat
    var bottom: Bool
}

struct RoomView: View {
    @Bindable var store: RoomStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @State private var overrideTextSize: DynamicTypeSize?
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var frames: [Int: CGRect] = [:]
    @State private var metrics = ScrollMetrics()
    @State private var anchor = RoomAnchor(id: 50000, y: 0, bottom: true)
    @State private var pending: RoomAnchor? = RoomAnchor(id: 50000, y: 0, bottom: true)
    @State private var pinned = true
    @State private var phase = ScrollPhase.idle
    @State private var layoutWidth: CGFloat = 0
    @State private var layoutTextSize: DynamicTypeSize?
    @State private var milliseconds = 0
    @State private var tapStarted: ContinuousClock.Instant?
    @State private var settleTask: Task<Void, Never>?
    @State private var lastAutoPage = ContinuousClock.now
    private let benchmark = ProcessInfo.processInfo.arguments.contains("-uvsBenchmark")
    private var theme: RoomTheme { RoomTheme(scheme: scheme) }
    private var textSize: DynamicTypeSize { overrideTextSize ?? systemTextSize }

    var body: some View {
        VStack(spacing: 0) {
            RoomHeader(name: store.dataset.room.name).zIndex(100)
            if benchmark { debugBar.zIndex(100) }
            timeline
            RoomComposer().zIndex(100)
        }
        .background(theme.background)
        .foregroundStyle(theme.text)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .environment(\.dynamicTypeSize, textSize)
        .onChange(of: systemTextSize) { _, _ in preserveForRelayout() }
        .onAppear {
            tapStarted = store.started
            store.onFeedChange = { event in
                switch event {
                case .message, .boost:
                    preserve()
                    store.receive(event, pinned: pinned)
                    scheduleRestore()
                default: break
                }
            }
            store.onBurst = { id, boost in
                preserve()
                store.addDebugBoost(id, boost)
                scheduleRestore()
            }
        }
    }

    private var timeline: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                if store.firstID == 1 { WelcomeCard() }
                ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, row in
                    MessageRow(row: row, users: store.users, extraBoosts: store.extraBoosts[row.id] ?? [])
                        .equatable()
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(key: RowFrames.self,
                                                       value: RoomLayout(frames: [row.id: geometry.frame(in: .named("room-content"))]))
                            }
                        }
                        .padding(.top, rowGap(index, row))
                        .id(row.id)
                }
                Color.clear.frame(height: 1.6).id("bottom")
            }
            .padding(.horizontal, 14.01)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: RowFrames.self,
                                           value: RoomLayout(width: geometry.size.width, textSize: textSize))
                }
            }
            .coordinateSpace(name: "room-content")
            .scrollTargetLayout()
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.top, for: .sizeChanges)
        .scrollIndicators(.hidden)
        .onPreferenceChange(RowFrames.self) { value in
            if layoutWidth > 0 && (abs(value.width - layoutWidth) > 0.5 || value.textSize != layoutTextSize) {
                preserve()
            }
            layoutWidth = value.width
            layoutTextSize = value.textSize
            frames = value.frames
            if pending != nil { restore(); scheduleRestore() } else { updateAnchor() }
            finishTimingAfterLayout()
        }
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                          height: geometry.containerSize.height,
                          contentHeight: geometry.contentSize.height, width: geometry.containerSize.width)
        } action: { _, new in
            let resized = metrics.width > 0 && (abs(metrics.width - new.width) > 0.5 || abs(metrics.height - new.height) > 0.5)
            if resized { preserve(); scheduleRestore() }
            metrics = new
            if pending != nil { restore() } else { updateAnchor() }
            if phase == .interacting || phase == .decelerating { autoPage() }
        }
        .onScrollPhaseChange { _, new in
            phase = new
            if new == .idle {
                updateAnchor()
                autoPage()
            } else if new == .interacting {
                settleTask?.cancel()
                pending = nil
                tapStarted = nil
            }
        }
        .scrollClipDisabled()
        .accessibilityIdentifier("timeline")
        .overlay(alignment: .bottomTrailing) {
            if !pinned {
                Button {
                    beginTap()
                    pending = RoomAnchor(id: store.newestID, y: 0, bottom: true)
                    store.latest()
                    scheduleRestore()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                        Text(store.unread > 0 ? "\(store.unread) new messages" : "Jump to bottom")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(theme.text, in: Capsule()).foregroundStyle(theme.background)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jump-bottom")
                .padding(14)
            }
        }
    }

    private func rowGap(_ index: Int, _ row: RoomRow) -> CGFloat {
        guard index > 0 else { return 0 }
        return row.presentation.isThreaded ? -1.2 : 21.28
    }

    private var debugBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                debugButton("Reset") {
                    overrideTextSize = nil
                    pending = RoomAnchor(id: 50000, y: 0, bottom: true)
                    store.reset()
                }
                debugButton("Jump to 2500") {
                    pending = RoomAnchor(id: 2500, y: 0, bottom: false)
                    store.jump(to: 2500)
                }
                debugButton("Load older") {
                    preserve(keepBottom: false)
                    store.older(preserving: anchor.id)
                }
                Button("Start stream") { store.startStream() }
                    .disabled(store.streaming || store.streamDone)
            }
            HStack(spacing: 0) {
                debugButton("Text size +") {
                    preserve()
                    let sizes = DynamicTypeSize.allCases
                    let index = sizes.firstIndex(of: textSize) ?? 3
                    overrideTextSize = index + 1 == sizes.count ? nil : sizes[index + 1]
                }
                Button("Boost burst") { store.burst() }
                Spacer(minLength: 0)
                if store.streamDone { Text("Stream done").accessibilityIdentifier("stream-done") }
            }
            Text(stateLabel)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("benchmark-state")
        }
        .font(.system(size: 11, weight: .medium))
        .buttonStyle(DebugButtonStyle())
        .padding(.horizontal, 6).padding(.vertical, 5)
        .background(theme.bubble, ignoresSafeAreaEdges: [])
        .environment(\.dynamicTypeSize, .large)
    }

    private var stateLabel: String {
        "first \(store.firstID) last \(store.lastID) loaded \(store.loaded.count) pinned \(pinned ? "yes" : "no") top \(anchor.id) y \(String(format: "%.1f", anchor.y)) ms \(milliseconds)"
    }

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title) {
            beginTap()
            action()
            scheduleRestore()
        }
    }

    private func beginTap() {
        tapStarted = .now
        settleTask?.cancel()
    }

    private func preserve(keepBottom: Bool = true) {
        guard pending == nil else { return }
        pending = RoomAnchor(id: anchor.id, y: anchor.y, bottom: keepBottom && pinned)
    }

    private func preserveForRelayout() {
        preserve()
        scheduleRestore()
    }

    private func restore() {
        guard let target = pending, metrics.height > 0, !frames.isEmpty else { return }
        if target.bottom {
            position.scrollTo(edge: .bottom)
            pinned = true
        } else if let frame = frames[target.id] {
            let desired = max(0, frame.minY - target.y)
            position.scrollTo(y: desired)
            pinned = false
        }
        finishTimingAfterLayout()
    }

    private func scheduleRestore() {
        settleTask?.cancel()
        settleTask = Task { @MainActor in
            // Wait for SwiftUI's new row measurements, then correct the content offset without animation.
            await Task.yield()
            guard !Task.isCancelled else { return }
            restore()
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            restore()
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            pending = nil
            updateAnchor()
            finishTimingAfterLayout()
        }
    }

    private func updateAnchor() {
        guard pending == nil, metrics.height > 0 else { return }
        let visible = frames.filter { $0.value.maxY > metrics.offset + 2.0 && $0.value.minY < metrics.offset + metrics.height }
        if let top = visible.min(by: { $0.key < $1.key }) {
            let y = top.value.minY - metrics.offset
            anchor = RoomAnchor(id: top.key, y: abs(y) < 0.5 ? 0 : y, bottom: pinned)
        }
        pinned = store.lastID == store.newestID && metrics.contentHeight - metrics.offset - metrics.height <= 100
        if pinned { store.unread = 0 }
    }

    private func finishTimingAfterLayout() {
        guard tapStarted != nil, !frames.isEmpty, metrics.height > 0 else { return }
        // Initial layout has no explicit mutation to schedule the settling pass.
        if settleTask == nil && pending != nil { scheduleRestore(); return }
        guard pending == nil, let start = tapStarted else { return }
        let elapsed = start.duration(to: .now)
        milliseconds = Int(elapsed.components.seconds * 1000) + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        tapStarted = nil
    }

    private func autoPage() {
        guard pending == nil, metrics.height > 0, ContinuousClock.now - lastAutoPage > .milliseconds(250) else { return }
        if metrics.offset < 80 && store.canLoadOlder {
            lastAutoPage = .now
            preserve(keepBottom: false)
            store.older(preserving: anchor.id)
            scheduleRestore()
        } else if metrics.contentHeight - metrics.offset - metrics.height < 80 && store.canLoadNewer {
            lastAutoPage = .now
            preserve(keepBottom: false)
            store.newer()
            scheduleRestore()
        }
    }
}

private struct DebugButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(.primary.opacity(configuration.isPressed ? 0.15 : 0.05), in: RoundedRectangle(cornerRadius: 4))
            .padding(.trailing, 4)
    }
}
