import SwiftUI

/// Copy and Reply above a selected message. Reply does nothing in this build.
struct SelectionMenu: View {
    let selection: SelectionModel

    var body: some View {
        let text = selection.selectedText
        HStack(spacing: 0) {
            Button("Copy") {
                Clipboard.copy(text)
                selection.clear()
            }
            .padding(.horizontal, 16)
            Divider().frame(height: 20).overlay(Color.white.opacity(0.35))
            Button("Reply") {
                selection.clear()
            }
            .padding(.horizontal, 16)
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.white)
        .frame(height: 38)
        .background(Capsule().fill(Color(white: 0.16)))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        .fixedSize()
        .dynamicTypeSize(.large)
    }
}

/// Where the selected message's bubble is, so the room can float the menu over it.
struct SelectedBubbleKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Floats the Copy / Reply menu just above the selected bubble, kept inside the visible message area.
    func selectionMenuOverlay(_ selection: SelectionModel) -> some View {
        overlayPreferenceValue(SelectedBubbleKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, selection.messageID != nil {
                    let rect = proxy[anchor]
                    let halfHeight: CGFloat = 19
                    let above = rect.minY - 8 - halfHeight
                    let y = above >= halfHeight + 6 ? above : max(halfHeight + 6, min(rect.minY + halfHeight + 8, proxy.size.height - halfHeight - 6))
                    SelectionMenu(selection: selection)
                        .position(x: min(max(rect.midX, 90), proxy.size.width - 90), y: y)
                }
            }
        }
    }
}
