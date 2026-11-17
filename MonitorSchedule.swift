import Foundation

struct MonitorSchedule {
    /// Smooth hover tracking while the panel is open or the pointer is near a notch.
    static let fastInterval: TimeInterval = 1.0 / 120.0
    /// A light backup check everywhere else; pointer moves are also reported by events.
    static let slowInterval: TimeInterval = 0.1
    static let pollInterval: TimeInterval = 0.5
    static let refreshInterval: TimeInterval = 5

    private var lastPoll: TimeInterval
    private var lastRefresh: TimeInterval
    private var lastTick: TimeInterval
    init(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lastPoll = now
        lastRefresh = now
        lastTick = now
    }
    mutating func advance(to now: TimeInterval) -> (poll: Bool, refresh: Bool, gap: TimeInterval) {
        let gap = now - lastTick
        lastTick = now
        let poll = now - lastPoll >= Self.pollInterval
        let refresh = now - lastRefresh >= Self.refreshInterval
        if poll { lastPoll = now }
        if refresh { lastRefresh = now }
        return (poll, refresh, gap)
    }

    /// How often the loop should run right now.
    static func interval(panelOpen: Bool, nearNotch: Bool) -> TimeInterval {
        if panelOpen || nearNotch {
            return fastInterval
        }
        return slowInterval
    }

    /// A gap this much longer than the planned interval means the app was held up.
    static func isStall(gap: TimeInterval, interval: TimeInterval) -> Bool {
        gap > interval + 0.1
    }
}
