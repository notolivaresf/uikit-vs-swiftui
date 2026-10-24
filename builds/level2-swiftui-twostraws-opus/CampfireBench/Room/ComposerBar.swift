import SwiftUI

/// Search and the message composer. Drawn only: nothing can be typed or sent.
struct ComposerBar: View {
    var body: some View {
        HStack(spacing: 10) {
            CircleButton(systemImage: "magnifyingglass", label: "Search", iconSize: 20, weight: .heavy)
            HStack(spacing: 0) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 20, weight: .medium))
                    .padding(.leading, 13)
                Spacer(minLength: 0)
                Button {} label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach a file")
                .padding(.trailing, 10)
                Button {} label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Palette.background)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Palette.ink))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
                .padding(.trailing, 2)
            }
            .foregroundStyle(Palette.ink)
            .frame(height: 38)
            .background(Capsule().fill(Palette.background))
            .overlay(Capsule().strokeBorder(Palette.borderDarker, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Message composer")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Palette.background)
    }
}
