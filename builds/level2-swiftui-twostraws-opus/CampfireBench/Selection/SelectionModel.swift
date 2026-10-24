import CampfireKit
import SwiftUI

/// The one active text selection in the room: which message and text block, and the selected range
/// (UTF-16 offsets into the block's plain string).
@MainActor
@Observable
final class SelectionModel {
    private(set) var messageID: MessageID?
    private(set) var block = 0
    private(set) var plain = ""
    var range = 0..<0

    func isActive(messageID: MessageID, block: Int) -> Bool {
        self.messageID == messageID && self.block == block
    }

    func selectAll(messageID: MessageID, block: Int, plain: String) {
        self.messageID = messageID
        self.block = block
        self.plain = plain
        range = 0..<plain.utf16.count
    }

    func clear() {
        guard messageID != nil else { return }
        messageID = nil
        plain = ""
        range = 0..<0
    }

    var selectedText: String {
        let utf16 = plain.utf16
        let lower = min(max(0, range.lowerBound), utf16.count)
        let upper = min(max(lower, range.upperBound), utf16.count)
        let start = utf16.index(utf16.startIndex, offsetBy: lower)
        let end = utf16.index(utf16.startIndex, offsetBy: upper)
        return String(plain[start..<end]).replacingOccurrences(of: RichText.attachmentCharacter, with: "")
    }
}
