import SwiftUI

struct RoomView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var store: RoomStore
    @State private var scroll: RoomScroll
    private let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")

    init(launchTime: ContinuousClock.Instant) {
        _store = State(initialValue: RoomStore())
        _scroll = State(initialValue: RoomScroll(launchTime: launchTime))
    }
    private var theme: RoomTheme { RoomTheme(dark: colorScheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            if benchmark { debugBar.zIndex(3) }
            RoomHeader(name: store.dataset.room.name, theme: theme).zIndex(2)
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        if store.messages.first?.id == 1 { WelcomeCard(theme: theme) }
                        ForEach(store.messages) { message in
                            MessageRow(message: message, presentation: store.presentation(message),
                                       users: store.users, theme: theme, scale: store.scale,
                                       availableWidth: geometry.size.width)
                            .id(message.id)
                            .background {
                                GeometryReader { rowGeometry in
                                    Color.clear.preference(key: RowFramesKey.self,
                                        value: [message.id: rowGeometry.frame(in: .named("chatContent"))])
                                }
                            }
                            // The grid gap is outside the measured message row.
                            .padding(.top, store.presentation(message).spacingBefore)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 1.6)
                    .coordinateSpace(name: "chatContent")
                    .background {
                        GeometryReader { contentGeometry in
                            Color.clear.preference(key: ContentLayoutKey.self,
                                value: ContentLayout(size: contentGeometry.size, revision: store.revision))
                        }
                    }
                }
                .scrollPosition($scroll.position)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollIndicators(.visible)
                .scrollClipDisabled()
                .onPreferenceChange(RowFramesKey.self) { scroll.receiveFrames($0) }
                .onPreferenceChange(ContentLayoutKey.self) { scroll.receiveLayout($0) }
                .onScrollGeometryChange(for: RoomMetrics.self) { g in
                    RoomMetrics(offset: g.contentOffset.y, height: g.containerSize.height,
                                contentHeight: g.contentSize.height)
                } action: { _, current in
                    scroll.receiveMetrics(current)
                }
                .onScrollPhaseChange { _, phase in scroll.phaseChanged(phase) }
                .overlay(alignment: .bottom) {
                    if store.hasNewMessages && !scroll.pinned {
                        Button {
                            scroll.requestBottom()
                            store.newest()
                        } label: {
                            Label("Jump to bottom", systemImage: "arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(theme.text, in: Capsule()).foregroundStyle(theme.background)
                        }
                        .buttonStyle(.plain).padding(.bottom, 12)
                    }
                }
                .accessibilityIdentifier("room-scroll")
            }
            RoomComposer(theme: theme).zIndex(2)
        }
        .background(theme.background)
        .foregroundStyle(theme.text)
        .clipped()
        .ignoresSafeArea()
        .onChange(of: scroll.pinned) { _, pinned in
            if pinned { store.hasNewMessages = false }
        }
        .onAppear {
            scroll.loadOlder = {
                scroll.preserve()
                if !store.loadOlder(topID: scroll.topID) { scroll.finishUnchangedClick() }
            }
            scroll.loadNewer = {
                if store.messages.last?.id != store.history.last?.id {
                    scroll.preserveForForwardPage()
                    store.loadNewer()
                }
            }
        }
    }

    private var debugBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                debugButton("Reset") {
                    scroll.click(); scroll.requestBottom(); store.reset()
                }
                debugButton("Jump to 2500") {
                    scroll.click(); scroll.requestJump(2500); store.jumpTo2500()
                }
                debugButton("Load older") {
                    scroll.click(); scroll.preserve()
                    if !store.loadOlder(topID: scroll.topID) { scroll.finishUnchangedClick() }
                }
            }
            HStack(spacing: 5) {
                debugButton("Start stream") { store.startStream(scroll: scroll) }
                debugButton("Text size +") {
                    scroll.click(); scroll.preserve(); store.increaseTextSize()
                }
                debugButton("Boost burst") { store.boostBurst(scroll: scroll) }
            }
            if store.streamDone { Text("Stream done").font(.system(size: 10)) }
            Text(stateLabel)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(stateLabel)
                .accessibilityIdentifier("benchmark-state")
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bubble)
    }
    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).font(.system(size: 11)).controlSize(.small)
    }
    private var stateLabel: String {
        let y = abs(scroll.topY) < 0.05 ? 0 : scroll.topY
        return "first \(store.messages.first?.id ?? 0) last \(store.messages.last?.id ?? 0) loaded \(store.messages.count) pinned \(scroll.pinned ? "yes" : "no") top \(scroll.topID) y \(String(format: "%.1f", y)) ms \(scroll.milliseconds)"
    }
}
