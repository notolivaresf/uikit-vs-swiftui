import SwiftUI
import CampfireKit

struct RoomView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @State private var store: RoomStore
    @State private var scroll: RoomScrollState
    private let benchmark = ProcessInfo.processInfo.arguments.contains("-uvsBenchmark")

    init(launchedAt: ContinuousClock.Instant, generation: Task<Dataset, Never>) {
        _store = State(initialValue: RoomStore(generation: generation))
        _scroll = State(initialValue: RoomScrollState(launchedAt: launchedAt))
    }

    private var effectiveTextSize: DynamicTypeSize { store.overrideTextSize ? store.textSize : systemTextSize }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                RoomHeader(name: store.roomName)
                if benchmark {
                    BenchmarkBar(label: scroll.debugLabel, streamDone: store.streamDone,
                                 reset: reset, jump: jump, older: older,
                                 stream: store.startStream, textSize: increaseTextSize, boosts: store.boostBurst)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("roomHeader")
            TranscriptView(store: store, scroll: scroll, older: autoOlder, newer: autoNewer)
                .environment(\.dynamicTypeSize, effectiveTextSize)
                .overlay(alignment: .bottomTrailing) {
                    if scroll.ready && (!scroll.pinned || !store.isAtNewestPage) {
                        Button("Jump to bottom", systemImage: "arrow.down") { jumpToBottom() }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .tint(scheme == .dark ? .white : .black)
                            .foregroundStyle(CampfireStyle.background(scheme))
                            .padding(14)
                    }
                }
            RoomComposer()
        }
        .foregroundStyle(scheme == .dark ? .white : .black)
        .background(CampfireStyle.background(scheme))
        .task { await start() }
        .onChange(of: store.revision) { scroll.updateWindow(store.items) }
        .onChange(of: systemTextSize) { scroll.preserve(); scroll.scheduleLayout() }
    }

    private func start() async {
        store.beforeChange = { if !scroll.userScrolling { scroll.preserve() } }
        store.afterChange = { scroll.updateWindow(store.items) }
        store.visibleTopID = { scroll.topID }
        await store.load()
        scroll.updateWindow(store.items)
    }

    private func reset() {
        scroll.measureTap(); scroll.request(.bottom)
        store.reset()
        scroll.updateWindow(store.items)
    }

    private func jump() {
        scroll.measureTap(); scroll.request(.row(id: 2500, y: 0))
        store.jumpTo2500()
        scroll.updateWindow(store.items)
    }

    private func older() {
        scroll.measureTap(); scroll.preserve()
        store.loadOlder(preserving: scroll.topID)
        scroll.updateWindow(store.items)
    }

    private func autoOlder() {
        guard store.hasOlder, scroll.ready, !scroll.restoring else { return }
        scroll.preserve()
        store.loadOlder(preserving: scroll.topID)
        scroll.updateWindow(store.items)
    }

    private func autoNewer() {
        guard store.hasNewer, scroll.ready, !scroll.restoring else { return }
        scroll.preserve()
        store.loadNewer(preserving: scroll.topID)
        scroll.updateWindow(store.items)
    }

    private func increaseTextSize() {
        scroll.measureTap(); scroll.preserve()
        store.increaseTextSize(from: effectiveTextSize)
        scroll.scheduleLayout()
    }

    private func jumpToBottom() {
        scroll.request(.bottom)
        store.jumpToNewest()
        scroll.updateWindow(store.items)
    }
}
