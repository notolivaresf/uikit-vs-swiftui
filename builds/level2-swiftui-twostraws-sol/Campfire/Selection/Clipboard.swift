import SwiftUI

enum Clipboard {
    @MainActor static func copy(_ text: String) {
        // A system clipboard service only; all views and selection UI are SwiftUI.
        UIPasteboard.general.string = text.replacing("\u{FFFC} ", with: "")
    }
}
