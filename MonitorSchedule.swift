import Foundation

struct MonitorSchedule {
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
        let poll = now - lastPoll >= 0.25
        let refresh = now - lastRefresh >= 5
        if poll { lastPoll = now }
        if refresh { lastRefresh = now }
        return (poll, refresh, gap)
    }
}
