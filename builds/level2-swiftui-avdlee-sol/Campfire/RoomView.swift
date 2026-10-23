import SwiftUI

struct RoomView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @State private var store = RoomStore()
    @State private var viewport = RoomViewport()
    private let benchmark = ProcessInfo.processInfo.arguments.contains("-uvsBenchmark")

    var body: some View {
        GeometryReader { bounds in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    RoomHeader(name: "General")
                    if benchmark { BenchmarkBar(store: store, viewport: viewport, defaultTextSize: systemTextSize) }
                }
                .background { HeaderImageBackdrop(viewport: viewport) }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("room-header")
                .compositingGroup()
                .zIndex(1)
                room(width: bounds.size.width)
                RoomComposer().compositingGroup().zIndex(1)
            }
            .background(RoomColors(scheme).background)
            .foregroundStyle(RoomColors(scheme).text)
        }
        .ignoresSafeArea()
        .task {
            viewport.headerHeight = benchmark ? 108 : 58
            store.beforeMutation = { viewport.preserve() }
            store.followsLiveTail = { viewport.pinned && !viewport.userScrolling }
            store.tailDidChange = { viewport.setAtNewest($0) }
            store.visibleAnchorID = { viewport.top }
            await store.load()
        }
        .onChange(of: systemTextSize) { _, _ in viewport.preserve() }
    }

    private func room(width: CGFloat) -> some View {
        ScrollView {
            // A bounded, eager stack provides exact geometry for all loaded rows: ordinarily
            // at most 300 (one page at the live tail). The 50,000-message history
            // never enters the view hierarchy; preserving the visible row takes priority when paging.
            VStack(spacing: 0) {
                if store.rows.first?.id == 1 { WelcomeCard() }
                ForEach(store.rows) { row in
                    MessageRow(row: row, users: store.users, width: width)
                        .equatable()
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(key: RoomLayoutKey.self,
                                    value: RoomLayout(frames: [row.id: geometry.frame(in: .named("room-content"))]))
                            }
                        }
                        .padding(.top, row.id == 1 ? 0 : row.presentation.isThreaded ? -1.2 : CampfireStyle.rowGap)
                }
            }
            .frame(maxWidth: .infinity)
            .coordinateSpace(name: "room-content")
            .backgroundPreferenceValue(HeaderImageAnchorsKey.self) { anchors in
                GeometryReader { geometry in
                    Color.clear.preference(key: HeaderImagesKey.self,
                        value: anchors.mapValues { HeaderImage(rect: geometry[$0.bounds], color: $0.color) })
                }
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: RoomLayoutKey.self,
                        value: RoomLayout(width: geometry.size.width, height: geometry.size.height, revision: store.revision,
                                          textSize: store.textSize ?? systemTextSize))
                }
            }
        }
        .environment(\.dynamicTypeSize, store.textSize ?? systemTextSize)
        .scrollPosition($viewport.position)
        .scrollIndicators(.hidden)
        .onPreferenceChange(RoomLayoutKey.self) { layout in viewport.changedLayout(layout) }
        .onPreferenceChange(HeaderImagesKey.self) { images in viewport.changedImages(images) }
        .onScrollGeometryChange(for: ScrollMeasurement.self) { geometry in
            return ScrollMeasurement(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                              height: geometry.contentSize.height, size: geometry.containerSize)
        } action: { _, new in
            viewport.changedScroll(new)
        }
        .onScrollPhaseChange { _, phase in
            viewport.changedPhase(phase)
            if phase == .idle {
                if viewport.shouldLoadOlder() {
                    viewport.preserve()
                    store.loadOlder()
                } else if !viewport.isRestoring, viewport.nearBottom, store.rows.last?.id != store.all.last?.id {
                    if store.deferredLiveTail {
                        viewport.go(.bottom)
                        store.newest()
                    } else { store.loadNewer() }
                }
                viewport.allowNextPagination()
            }
        }
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            if !viewport.pinned {
                Button {
                    viewport.beginTap()
                    viewport.go(.bottom)
                    store.newest()
                } label: {
                    Label("Jump to bottom", systemImage: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoomColors(scheme).background, in: Capsule())
                        .overlay(Capsule().strokeBorder(RoomColors(scheme).strongBorder, lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityIdentifier("jump-bottom")
            }
        }
        .accessibilityIdentifier("room-scroll")
    }
}

private struct BenchmarkBar: View {
    let store: RoomStore
    let viewport: RoomViewport
    let defaultTextSize: DynamicTypeSize
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    Button("Reset") {
                        viewport.beginTap()
                        viewport.go(.bottom)
                        store.reset()
                    }
                    Button("Jump to 2500") {
                        viewport.beginTap()
                        viewport.go(.row(2500, 0))
                        store.jump()
                    }
                    Button("Load older") {
                        viewport.beginTap()
                        viewport.preserve()
                        store.loadOlder()
                    }
                    Button("Start stream") { store.startStream() }.disabled(store.streamRunning || store.streamDone)
                    Button("Text size +") {
                        viewport.beginTap()
                        viewport.preserve()
                        store.largerText(current: defaultTextSize)
                    }
                    Button("Boost burst") { store.boostBurst() }
                    if store.streamDone { Text("Stream done").accessibilityIdentifier("stream-done") }
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
            }
            .scrollIndicators(.hidden)
            Text(stateLabel)
                .font(.system(size: 10, design: .monospaced))
                .frame(height: 12, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 10)
                .accessibilityIdentifier("benchmark-state")
                .accessibilityValue(viewport.isRestoring ? "laying out" : "ready")
        }
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.plain)
        .padding(.bottom, 6)
        .background(RoomColors(scheme).bubble, ignoresSafeAreaEdges: [])

    }
    private var stateLabel: String {
        "first \(store.rows.first?.id ?? 0) last \(store.rows.last?.id ?? 0) loaded \(store.rows.count) pinned \(viewport.pinned ? "yes" : "no") top \(viewport.top) y \(String(format: "%.1f", viewport.topY)) ms \(viewport.milliseconds)"
    }
}

/// The sticky header fades over the image behind it, while the scrolling viewport retains
/// a precise, independent boundary for selection, geometry, and hit testing.
private struct HeaderImageBackdrop: View {
    let viewport: RoomViewport
    var body: some View {
        GeometryReader { _ in
            if let image = viewport.headerImage {
                Color(rgb: image.color)
                    .frame(width: image.rect.width, height: image.rect.height)
                    .position(x: image.rect.midX, y: image.rect.midY)
            }
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
