import Foundation

enum LaunchOptions {
    /// `-uvsBenchmark YES` shows the debug bar.
    static let isBenchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
}
