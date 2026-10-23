import SwiftUI
import UIKit // UIPasteboard only; the selection surface is SwiftUI TextEditor.

/// Text.textSelection on iOS 18–26 only copies entire Text views. A temporary, constant-bound
/// TextEditor supplies native range handles without changing the message or its measured layout.
/// https://developer.apple.com/documentation/swiftui/view/textselection(_:)
struct RangeSelectionOverlay: View {
    let text: String
    let fontSize: CGFloat
    let done: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var selection: TextSelection?
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: .constant(text), selection: $selection)
            .font(.system(size: fontSize))
            .lineSpacing(fontSize * 0.20625)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .background(RoomColors(scheme).bubble)
            .focused($focused)
            .accessibilityLabel("Select message text")
            .accessibilityIdentifier("range-selection")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Copy") { UIPasteboard.general.string = selectedText }
                    Button("Reply") {}
                    Spacer()
                    Button("Done") { focused = false; done() }
                }
            }
            .task {
                focused = true
                selection = TextSelection(range: text.startIndex..<text.endIndex)
            }
    }

    private var selectedText: String {
        guard let selection else { return text }
        switch selection.indices {
        case .selection(let range): return String(text[range])
        case .multiSelection(let ranges): return ranges.ranges.map { String(text[$0]) }.joined(separator: "\n")
        @unknown default: return text
        }
    }
}
