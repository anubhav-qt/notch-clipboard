import Foundation

@main struct ClipboardAgeTests {
    static func main() {
        let now: TimeInterval = 10_000_000
        let cases: [(TimeInterval, String)] = [
            (-60, "Just now"), (0, "Just now"), (59, "Just now"),
            (60, "1 min ago"), (119, "1 min ago"), (120, "2 min ago"),
            (19 * 60 + 59, "19 min ago"), (20 * 60, "20 min ago"),
            (24 * 60 + 59, "20 min ago"), (25 * 60, "25 min ago"),
            (59 * 60 + 59, "55 min ago"), (60 * 60, "1 hour ago"),
            (119 * 60 + 59, "1 hour ago"), (120 * 60, "2 hours ago"),
            (23 * 3600 + 3599, "23 hours ago"), (24 * 3600, "1 day ago"),
            (47 * 3600 + 3599, "1 day ago"), (48 * 3600, "2 days ago"),
            (30 * 24 * 3600, "30 days ago")
        ]
        for (elapsed, expected) in cases {
            assert(ClipboardAge.label(created: now - elapsed, now: now) == expected)
        }
        print("PASS: minute steps below 20 minutes, five-minute steps below one hour, hourly steps under a day, then days; no seconds")
    }
}
