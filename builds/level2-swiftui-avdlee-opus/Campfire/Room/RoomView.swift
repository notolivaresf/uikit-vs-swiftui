import SwiftUI
import CampfireKit

/// The single Campfire room: floating header, message list, composer and (for benchmarks) the debug bar.
struct RoomView: View {
    @State private var model: RoomModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @State private var selectTextAction = SelectTextAction()
    @State private var selecting: SelectableText?
    init(benchmark: Bool) {
        _model = State(initialValue: RoomModel(benchmark: benchmark))
    }

    var body: some View {
        let palette = Palette.of(colorScheme)
        VStack(spacing: 0) {
            // The list lives in an overlay of a flexible spacer: the room's layout never has to measure the
            // scroll view's content, which would otherwise happen on every streamed message.
            Color.clear
                .overlay {
                    ZStack(alignment: .top) {
                        MessagesView(model: model)
                            .dynamicTypeSize(model.textSize ?? systemTextSize)
                        HeaderBar()
                            // Solid cover above the header, behind the status bar (the content runs up under it).
                            .background(alignment: .top) {
                                palette.background
                                    .frame(height: 400)
                                    .offset(y: -400)
                                    .allowsHitTesting(false)
                            }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    JumpToBottomOverlay(model: model)
                }
            if model.benchmark {
                ComposerBar(bottomPadding: 10)
                DebugBar(model: model)
            } else {
                // Campfire keeps the composer 24 pt above the bottom edge, which clears the home indicator.
                ComposerBar(bottomPadding: 24)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .background(palette.background.ignoresSafeArea())
        .environment(\.palette, palette)
        .environment(\.selectTextAction, selectTextAction)
        .sheet(item: $selecting) { item in
            SelectTextSheet(text: item.text)
        }
        .onAppear { selectTextAction.handler = { selecting = SelectableText(text: $0) } }
        .task {
            await model.load()
            await Autorun.run(model)
        }
        .onAppear { model.systemTextSize = systemTextSize }
        .onChange(of: systemTextSize) { old, new in model.systemTextSizeChanged(to: new, from: old) }
    }
}

struct MessagesView: View {
    @Bindable var model: RoomModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if model.atBeginning {
                    WelcomeCard()
                }
                Color.clear.frame(height: Metrics.rowGap)
                let rows = model.rows
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    // The gap to the next row sits below each row, so a row's frame starts at its own top and
                    // scrolling to a row's top edge needs no correction.
                    let gap = index + 1 < rows.count ? Metrics.gap(before: rows[index + 1]) : 0
                    MessageRow(row: row)
                        .equatable()
                        .padding(.bottom, gap)
                        .modifier(FrameReporter(id: row.id, gap: gap, model: model))
                        .onDisappear { model.rowDisappeared(row.id) }
                }
            }
        }
        .contentMargins(.top, Metrics.headerHeight, for: .scrollContent)
        .scrollPosition(Binding(get: { model.position }, set: { model.positionWritten($0) }))
        .background { RevisionReader(revision: model.scrollRevision) }
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollGeometryChange(for: ScrollSnapshot.self) { geometry in
            ScrollSnapshot(
                // contentOffset is UIKit-style (negative insets at rest); containerSize excludes the insets,
                // so contentOffset + top inset is the content y at the header's bottom edge.
                visibleMinY: geometry.contentOffset.y + geometry.contentInsets.top - Metrics.headerHeight,
                visibleHeight: geometry.containerSize.height + Metrics.headerHeight,
                contentHeight: geometry.contentSize.height,
                containerWidth: geometry.containerSize.width,
                rawOffsetY: geometry.contentOffset.y,
                insetTop: geometry.contentInsets.top,
                insetBottom: geometry.contentInsets.bottom)
        } action: { _, new in
            model.scrollChanged(new)
        }
        .onScrollPhaseChange { _, phase in
            model.phaseChanged(phase)
        }
        .accessibilityIdentifier("messages")
    }
}

/// Makes MessagesView depend on the scroll revision so programmatic scrolls re-read the position binding.
private struct RevisionReader: View {
    let revision: Int
    var body: some View { Color.clear }
}

/// Separate view so the unseen-message count only re-renders the button, not the room.
struct JumpToBottomOverlay: View {
    let model: RoomModel

    var body: some View {
        if model.showJumpToBottom {
            JumpToBottomButton(count: model.unseenCount) { model.jumpToBottom() }
                .padding(.trailing, 14)
                .padding(.bottom, 12)
                .transition(.opacity)
        }
    }
}

struct JumpToBottomButton: View {
    let count: Int
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.background)
                .frame(width: 42, height: 42)
                .background(Circle().fill(palette.text))
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(verbatim: count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule().fill(palette.negative))
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to bottom")
        .accessibilityIdentifier("jump-to-bottom")
    }
}

/// Reports a row's frame in scroll view space.
struct FrameReporter: ViewModifier {
    let id: MessageID
    let gap: CGFloat
    let model: RoomModel

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .scrollView(axis: .vertical))
        } action: { frame in
            model.rowFrameChanged(id, frame, gapBelow: gap)
        }
    }
}

struct SelectableText: Identifiable {
    let id = UUID()
    let text: String
}

/// A message's text in a text view where any range can be selected and copied. The text cannot be changed:
/// edits are put back immediately.
struct SelectTextSheet: View {
    let text: String
    @State private var content: String
    @State private var selection: TextSelection?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(text: String) {
        self.text = text
        _content = State(initialValue: text)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $content, selection: $selection)
                .font(.system(size: 17))
                .focused($focused)
                .onChange(of: content) { _, new in
                    if new != text { content = text }
                }
                .padding(.horizontal, 12)
                .navigationTitle("Select Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            focused = true
            selection = TextSelection(range: content.startIndex..<content.endIndex)
        }
        .accessibilityIdentifier("select-text-sheet")
    }
}
