import SwiftUI

struct SelectableMessageText: View {
    let text: Text
    let plainText: String
    @State private var selectedRange: Range<Int>?

    var body: some View {
        Group {
            if let selection = selectedRange {
                text.textRenderer(SelectionTextRenderer())
                    .overlayPreferenceValue(Text.LayoutKey.self) { layouts in
                        GeometryReader { geometry in
                            TextSelectionOverlay(layouts: layouts, geometry: geometry,
                                                 text: plainText, selection: selection, update: updateSelection,
                                                 dismiss: dismissSelection)
                        }
                    }
            } else { text }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: copy)
            Button("Select text", systemImage: "selection.pin.in.out", action: selectAll)
            Button("Reply", systemImage: "arrowshape.turn.up.left") {}
        }
        .accessibilityAction(named: "Select text", selectAll)
        .onChange(of: plainText) { dismissSelection() }
    }

    private func selectAll() { selectedRange = 0..<plainText.utf16.count }
    private func dismissSelection() { selectedRange = nil }
    private func updateSelection(_ range: Range<Int>) { selectedRange = range }
    private func copy() {
        guard let selectedRange else { Clipboard.copy(plainText); return }
        Clipboard.copy(TextSelectionGeometry.substring(plainText, range: selectedRange))
    }
}
