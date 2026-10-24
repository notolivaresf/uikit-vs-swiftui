import Foundation

/// Process-wide timing reference for the debug bar's `ms` value.
enum LaunchClock {
    /// Set by the app's first line of code.
    nonisolated(unsafe) private(set) static var start = ContinuousClock.now

    static func markStart() { start = .now }

    static func milliseconds(since instant: ContinuousClock.Instant) -> Int {
        let elapsed = ContinuousClock.now - instant
        let (seconds, attoseconds) = elapsed.components
        return Int(seconds * 1000 + attoseconds / 1_000_000_000_000_000)
    }
}
