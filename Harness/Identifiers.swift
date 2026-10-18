import Foundation

/// Accessibility identifiers both apps must set. Documented in docs/spec.md ("Accessibility identifiers").
enum ChatID {
    static let list = "chat.messageList"
    static let roomTitle = "chat.roomTitle"
    static let composerInput = "chat.composer.input"
    static let composerSend = "chat.composer.send"
    static let typingIndicator = "chat.typingIndicator"
    static let jumpToBottom = "chat.jumpToBottom"
    static let loadingOlder = "chat.loadingOlder"
    static func message(_ id: Int) -> String { "chat.message.\(id)" }
    static func messageBoost(_ id: Int, _ index: Int) -> String { "chat.message.\(id).boost.\(index)" }

    // Debug panel, only shown when launched with `-uvsBenchmark YES`. Plain buttons / labels, no gestures needed.
    static let debugJumpToOld = "chat.debug.jumpToOld"        // jumps to message id 2_500 (of 50k: far from both ends)
    static let debugPrepend500 = "chat.debug.prepend500"      // prepends the 500 messages older than the oldest loaded
    static let debugStartBurst = "chat.debug.startBurst"      // starts the 20 msg/s, 30 s live feed
    static let debugBurstDone = "chat.debug.burstDone"        // label becomes "done" when the feed has ended
    static let debugState = "chat.debug.state"                // label value "first=<id> last=<id> loaded=<n> bottom=<0|1>"
    static let debugReset = "chat.debug.reset"                // reload the newest page, scrolled to bottom, feed stopped
}

/// Signpost names the apps emit (subsystem `dev.amazinghumans.uvs`, category `chat`), one interval each.
enum ChatSignpost {
    static let subsystem = "dev.amazinghumans.uvs"
    static let category = "chat"
    static let initialLoad = "initialLoad"      // from launch to first page on screen
    static let jumpToMessage = "jumpToMessage"  // from tap to target row visible
    static let prepend = "prepend"              // from data arrival to scroll position restored
    static let burstInsert = "burstInsert"      // each batch of incoming messages applied (one interval per batch)
}
