import Foundation

enum ClipboardAge {
    /// Minutes under 20, five-minute steps under an hour, hours under a day, then days.
    static func label(created: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) -> String {
        let minutes = Int(max(0, now - created) / 60)
        if minutes == 0 {
            return "Just now"
        }
        if minutes < 20 {
            return "\(minutes) min ago"
        }
        if minutes < 60 {
            return "\(minutes / 5 * 5) min ago"
        }
        let hours = minutes / 60
        if hours == 1 {
            return "1 hour ago"
        }
        if hours < 24 {
            return "\(hours) hours ago"
        }
        let days = hours / 24
        if days == 1 {
            return "1 day ago"
        }
        return "\(days) days ago"
    }
}
