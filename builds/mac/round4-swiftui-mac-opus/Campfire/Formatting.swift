import Foundation

/// Times and dates are shown in UTC so the same data reads the same on every machine.
enum Formatting {
    private static let utc = TimeZone(identifier: "UTC")!

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    nonisolated(unsafe) private static var timeCache: [Int: String] = [:]

    /// "10:12 AM"
    static func timeString(_ date: Date) -> String {
        let minute = Int(date.timeIntervalSince1970 / 60)
        if let s = timeCache[minute] { return s }
        let s = time.string(from: date)
        timeCache[minute] = s
        return s
    }

    /// "OCTOBER 16, 2026"
    static func dayString(_ date: Date) -> String {
        day.string(from: date).uppercased()
    }

    static func initial(of name: String) -> String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}
