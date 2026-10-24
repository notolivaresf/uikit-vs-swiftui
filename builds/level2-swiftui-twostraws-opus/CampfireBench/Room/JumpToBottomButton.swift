import SwiftUI

struct JumpToBottomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Palette.background))
                .overlay(Circle().strokeBorder(Palette.borderDarker, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to bottom")
        .accessibilityIdentifier("jumpToBottom")
    }
}
