import UIKit

/// SwiftUI has no pasteboard API on iOS; this is the only UIKit use and it is not a view.
enum Clipboard {
    @MainActor
    static func copy(_ string: String) {
        UIPasteboard.general.string = string
    }
}
