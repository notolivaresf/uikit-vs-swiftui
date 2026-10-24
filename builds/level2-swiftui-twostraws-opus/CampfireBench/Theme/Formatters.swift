import Foundation

/// Times and dates are always UTC so the same data reads the same everywhere.
enum Formatters {
    private static let utc = TimeZone(identifier: "UTC")!
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let gregorian = Calendar(identifier: .gregorian)

    /// "10:12 AM"
    static let time = Date.VerbatimFormatStyle(
        format: "\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits) \(dayPeriod: .standard(.abbreviated))",
        locale: posix, timeZone: utc, calendar: gregorian)

    /// "October 15, 2026" (shown uppercased)
    static let day = Date.VerbatimFormatStyle(
        format: "\(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits)",
        locale: posix, timeZone: utc, calendar: gregorian)

    static func timeString(_ date: Date) -> String { date.formatted(time) }

    static func dayString(_ date: Date) -> String { date.formatted(day).uppercased() }

    static func fileSize(_ bytes: Int) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
