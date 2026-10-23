import Foundation

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

    /// "10:12 AM" in UTC.
    static func timeString(_ date: Date) -> String { time.string(from: date) }

    /// "OCTOBER 16, 2026" in UTC.
    static func dayString(_ date: Date) -> String { day.string(from: date).uppercased() }

    /// Campfire shows file sizes like "245 KB".
    static func fileSize(_ bytes: Int) -> String {
        let units = ["Bytes", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
        return unit == 0 ? "\(bytes) Bytes" : "\(Int(value.rounded())) \(units[unit])"
    }
}
