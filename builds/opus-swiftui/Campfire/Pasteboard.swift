import UIKit

/// The system pasteboard (a data service, not a view).
enum Pasteboard {
    static func copy(_ text: String) { UIPasteboard.general.string = text }
}
