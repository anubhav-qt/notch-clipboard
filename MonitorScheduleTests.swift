import Foundation

@main struct MonitorScheduleTests {
    static func main() {
        var schedule = MonitorSchedule(now: 100)
        let early = schedule.advance(to: 100.01)
        assert(!early.poll && !early.refresh)
        let tooSoon = schedule.advance(to: 100.49)
        assert(!tooSoon.poll, "The clipboard is checked twice a second, not sooner")
        let normal = schedule.advance(to: 100.5)
        assert(normal.poll && !normal.refresh)
        // A delayed callback must do overdue work immediately, without waiting
        // for another 30/600 timer callbacks to accumulate.
        let stalled = schedule.advance(to: 108)
        assert(stalled.poll && stalled.refresh && stalled.gap > 7)
        let next = schedule.advance(to: 108.01)
        assert(!next.poll && !next.refresh)
        let poll = schedule.advance(to: 108.5)
        assert(poll.poll && !poll.refresh)
        let refresh = schedule.advance(to: 113)
        assert(refresh.poll && refresh.refresh)
        let woke = MonitorSchedule(now: 50_000)
        var afterWake = woke
        assert(afterWake.advance(to: 50_000.01).gap < 0.1)
        let fast = MonitorSchedule.fastInterval
        let slow = MonitorSchedule.slowInterval
        assert(MonitorSchedule.interval(panelOpen: true, nearNotch: false) == fast, "Open panel runs fast")
        assert(MonitorSchedule.interval(panelOpen: false, nearNotch: true) == fast, "Near the notch runs fast")
        assert(MonitorSchedule.interval(panelOpen: true, nearNotch: true) == fast)
        assert(MonitorSchedule.interval(panelOpen: false, nearNotch: false) == slow, "Anywhere else runs slow")
        assert(slow <= 0.1 && slow > fast, "Slow still notices the notch within a tenth of a second")
        assert(!MonitorSchedule.isStall(gap: slow + 0.05, interval: slow), "A normal slow beat is no stall")
        assert(MonitorSchedule.isStall(gap: fast + 0.11, interval: fast), "A late fast beat is a stall")
        assert(!MonitorSchedule.isStall(gap: fast + 0.09, interval: fast))
        print("PASS: fast while open or near the notch, slow elsewhere, and stalls judged against the pace")
        print("PASS: elapsed-time polling catches up after a delayed callback; normal cadence and wake reset stay correct")
    }
}
