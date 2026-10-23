import SwiftUI

/// The long-pressed message. Its text blocks turn into read-only text editors so the system's own
/// selection (handles, loupe, Look Up / Translate / Select All menu) can pick any range.
struct MessageSelection: Equatable {
    let rowID: Int
}

/// Message text with the system's text selection. On iOS 26 that is the whole text (its long-press menu:
/// Copy, Share...); while the message is selected (`model` set), a text editor with the same characters
/// lies over it, where the system selection picks any range. The text itself stays in place (only faded
/// out) so its layout, and a menu it is showing, carry on.
struct SelectableBlock<Content: View>: View {
    let content: Content
    let text: () -> AttributedString
    let model: RoomModel?

    var body: some View {
        content
            .textSelection(.enabled)
            .opacity(model == nil ? 1 : 0)
            .overlay {
                if let model {
                    if #available(iOS 26, *) {
                        AttributedSelectionEditor(original: text(), model: model)
                            .modifier(EditorInsets())
                    } else {
                        PlainSelectionEditor(original: String(text().characters), model: model)
                            .modifier(EditorInsets())
                    }
                }
            }
    }
}

/// The editor's text container sits 8 pt down and 5 pt in; this lines its glyphs up with the hidden text.
private struct EditorInsets: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -5)
            .padding(.vertical, -8)
            .accessibilityIdentifier("selectable-text")
    }
}

@available(iOS 26, *)
private struct AttributedSelectionEditor: View {
    let original: AttributedString
    let model: RoomModel
    @State private var text = AttributedString()
    @State private var selection = AttributedTextSelection()

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .onAppear { text = original }
            .onChange(of: text) { _, new in
                // Read-only: put back anything typed or pasted. Only the characters count: the editor adds
                // its own attributes (typing font, colour), and resetting for those would drop the selection.
                if !new.characters.elementsEqual(original.characters) { text = original }
            }
            .onChange(of: selection) { _, new in
                var picked = ""
                if case .ranges(let ranges) = new.indices(in: text) {
                    for r in ranges.ranges { picked += String(text[r].characters) }
                }
                model.updateSelectedText(picked)
            }
    }
}

private struct PlainSelectionEditor: View {
    let original: String
    let model: RoomModel
    @State private var text = ""
    @State private var selection: TextSelection?

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .onAppear { text = original }
            .onChange(of: text) { _, new in
                if new != original { text = original }
            }
            .onChange(of: selection) { _, new in
                var picked = ""
                switch new?.indices {
                case .selection(let r): picked = String(text[r])
                case .multiSelection(let set): for r in set.ranges { picked += String(text[r]) }
                default: break
                }
                model.updateSelectedText(picked)
            }
    }
}

/// The long-press menu: Copy (the selected text) and Reply (does nothing).
struct SelectionMenu: View {
    let palette: Palette
    let onCopy: () -> Void
    let onReply: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item("Copy", systemImage: "doc.on.doc", action: onCopy)
            Rectangle().fill(palette.borderDarker.opacity(0.5)).frame(width: 1, height: 22)
            item("Reply", systemImage: "arrowshape.turn.up.left", action: onReply)
        }
        .background(palette.background, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.borderDark, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .fixedSize()
    }

    private func item(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
