import SwiftUI

struct SelectionHandle: View {
    let rect: CGRect
    let isStart: Bool

    var body: some View {
        ZStack(alignment: isStart ? .top : .bottom) {
            Rectangle().fill(.blue).frame(width: 2, height: rect.height)
            Circle().fill(.blue).frame(width: 10, height: 10)
                .offset(y: isStart ? -8 : 8)
        }
        .frame(width: 30, height: max(30, rect.height))
        .contentShape(.rect)
        .offset(x: (isStart ? rect.minX : rect.maxX) - 15, y: rect.minY)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(isStart ? "selectionStart" : "selectionEnd")
    }
}
