import CampfireKit
import SwiftUI

/// The whole screen: floating header, the message list, the composer and (in benchmark mode) the debug bar.
struct RoomView: View {
    @Environment(RoomStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var systemTypeSize

    var body: some View {
        let palette = Palette.of(colorScheme)
        let typeSize = store.typeOverride ?? systemTypeSize
        ZStack(alignment: .top) {
            palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                MessageList()
                    .overlay(alignment: .bottomTrailing) {
                        if store.showJumpToBottom {
                            JumpToBottomButton()
                                .padding(.trailing, Theme.screenPaddingX)
                                .padding(.bottom, 12)
                        }
                    }
                ComposerView()
                    .padding(.top, 24)
                    .padding(.bottom, Launch.isBenchmark ? 6 : 24)
                if Launch.isBenchmark {
                    DebugBar(typeSize: typeSize)
                }
            }
            .ignoresSafeArea(.container, edges: Launch.isBenchmark ? [] : .bottom)
            HeaderView()
        }
        .environment(\.palette, palette)
        .environment(\.typeScale, TypeScale(typeSize))
        .dynamicTypeSize(typeSize)
        .task { await store.load() }
        .onChange(of: typeSize) { store.scroller.willChangeLayout() }
    }
}

/// The scrolling list of rows. Content runs under the floating header; its top is padded by the header height.
struct MessageList: View {
    @Environment(RoomStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var listWidth: CGFloat = 0
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var nudge: CGFloat = 0

    var body: some View {
        let scroller = store.scroller
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: Theme.headerHeight)
                if store.isLoaded && store.atOldest {
                    WelcomeCard()
                        .padding(.top, 85)
                }
                ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, item in
                    RowContainer(item: item, people: store.people, gap: gap(at: index, item), scroller: scroller)
                        .equatable()
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
            .coordinateSpace(.named(MessageList.space))
            .environment(\.listWidth, listWidth)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width - $0.safeAreaInsets.leading - $0.safeAreaInsets.trailing } action: {
            listWidth = $0
        }
        .scrollPosition($position)
        .onChange(of: store.scrollRequest) { _, request in
            switch request.target {
            case .y(let y):
                // ScrollPosition ignores a request equal to the one it holds; alternate a hair so repeats still apply.
                nudge = nudge == 0 ? 0.001 : 0
                position.scrollTo(y: y + nudge)
            case .row(let id):
                position.scrollTo(id: id, anchor: .top)
            case .bottom:
                // Re-issue even if the position already says "bottom": reset first so the change registers.
                position = ScrollPosition(idType: MessageID.self)
                position.scrollTo(edge: .bottom)
            }
        }
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(store.isPinned ? .bottom : .top, for: .sizeChanges)
        .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { old, new in
            scroller.geometryChanged(old, new)
        }
        .onScrollPhaseChange { _, new in
            scroller.phaseChanged(new)
        }
        .simultaneousGesture(TapGesture().onEnded { store.selection.clear() }, isEnabled: store.selection.current != nil)
        .selectionMenuOverlay(topInset: Theme.headerHeight + 8)
        .opacity(store.isLoaded && listWidth > 0 ? 1 : 0)
    }

    nonisolated static let space = "room-content"

    private func gap(at index: Int, _ item: RowItem) -> CGFloat {
        if index == 0 { return store.atOldest ? 23 : Theme.gapBetweenRows }
        return item.isThreaded ? 0 : Theme.gapBetweenRows
    }
}

struct JumpToBottomButton: View {
    @Environment(RoomStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            if !store.hasNewest {
                store.showNewest()
            } else {
                store.scroller.anchor = .bottom
                store.scroller.willChangeLayout()
            }
            store.setJumpToBottomVisible(false)
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
                .frame(width: Theme.headerButton, height: Theme.headerButton)
                .background(Circle().fill(palette.background))
                .overlay(Circle().strokeBorder(palette.borderDarker, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to bottom")
    }
}

/// One row plus its frame reporting. Equatable so an update that does not touch this row skips it entirely
/// (the closures inside would otherwise make every row dirty on every new message).
struct RowContainer: View, Equatable {
    let item: RowItem
    let people: People
    let gap: CGFloat
    let scroller: ScrollCoordinator

    nonisolated static func == (a: RowContainer, b: RowContainer) -> Bool {
        a.item == b.item && a.gap == b.gap && a.people == b.people && a.scroller === b.scroller
    }

    var body: some View {
        MessageRow(item: item, people: people)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("message-\(item.id)")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(MessageList.space)) } action: { [scroller, id = item.id] frame in
                scroller.rowFrameChanged(id, frame)
            }
            .onDisappear { [scroller, id = item.id] in scroller.rowDisappeared(id) }
            .padding(.top, gap)
    }
}
