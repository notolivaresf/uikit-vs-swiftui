import Foundation

/// What the harness looks for in the app under test. All of it comes from PROMPT.md: the debug bar shown
/// with `-uvsBenchmark YES`. Nothing else is needed, so both builds are measured the same way.
enum Bar {
    static let bundleID = "campfire.bench"
    static let reset = "Reset"
    static let jump = "Jump to 2500"
    static let older = "Load older"
    static let start = "Start stream"
    static let textSize = "Text size +"
    static let boostBurst = "Boost burst"
    static let streamDone = "Stream done"
    /// The state label reads, in exactly this form (PROMPT.md):
    /// `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`
    static let stateKeys = ["first", "last", "loaded", "pinned", "top", "y", "ms"]
}
