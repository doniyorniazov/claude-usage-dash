import Foundation

enum Fmt {
    /// 0.42 -> "42%", 1.30 -> "130%"
    static func percent(_ p: Double) -> String {
        String(format: "%.0f%%", p * 100)
    }

    /// Date -> "5:30PM" — local clock time, no space before AM/PM.
    static func clockTime(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f.string(from: date)
    }

    /// Date -> "Tue, Jun 2" — short weekday + month + day.
    static func weekdayDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    /// Date -> "2h 14m", "3d 4h", "in 12m"
    static func timeUntil(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let secs = max(0, Int(date.timeIntervalSinceNow))
        if secs < 60 { return "\(secs)s" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        let remMin = mins % 60
        if hours < 24 { return remMin > 0 ? "\(hours)h \(remMin)m" : "\(hours)h" }
        let days = hours / 24
        let remHour = hours % 24
        return remHour > 0 ? "\(days)d \(remHour)h" : "\(days)d"
    }
}
