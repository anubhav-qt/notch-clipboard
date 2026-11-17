import Foundation

@main struct MonitorScheduleTests {
    static func main() {
        var schedule = MonitorSchedule(now: 100)
        let early = schedule.advance(to: 100.01)
        assert(!early.poll && !early.refresh)
        let normal = schedule.advance(to: 100.25)
        assert(normal.poll && !normal.refresh)
        // A delayed callback must do overdue work immediately, without waiting
        // for another 30/600 timer callbacks to accumulate.
        let stalled = schedule.advance(to: 108)
        assert(stalled.poll && stalled.refresh && stalled.gap > 7)
        let next = schedule.advance(to: 108.01)
        assert(!next.poll && !next.refresh)
        let poll = schedule.advance(to: 108.25)
        assert(poll.poll && !poll.refresh)
        let refresh = schedule.advance(to: 113)
        assert(refresh.poll && refresh.refresh)
        let woke = MonitorSchedule(now: 50_000)
        var afterWake = woke
        assert(afterWake.advance(to: 50_000.01).gap < 0.1)
        print("PASS: elapsed-time polling catches up after a delayed callback; normal cadence and wake reset stay correct")
    }
}
