import AppKit

@main struct HoverTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let screen = NSScreen.screens.first!
        let originalMouse = NSEvent.mouseLocation
        let panel = NotchPanel(contentRect: NSRect(x: 80, y: 180, width: 360, height: 240), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
        let tracker = HoverTrackingView(frame: NSRect(x: 0, y: 0, width: 360, height: 240))
        panel.contentView = tracker
        var changes: [Bool] = []
        tracker.onChange = { changes.append($0) }
        let foreground = NSWorkspace.shared.frontmostApplication
        panel.orderFrontRegardless()
        // A standalone AppKit test process can become active during startup.
        // Return focus explicitly before checking inactive-window tracking.
        foreground?.activate(options: [])
        defer {
            panel.orderOut(nil)
            CGWarpMouseCursorPosition(CGPoint(x: originalMouse.x, y: screen.frame.maxY - originalMouse.y))
        }
        func pump(until done: () -> Bool, timeout: TimeInterval) {
            let deadline = Date(timeIntervalSinceNow: timeout)
            while Date() < deadline && !done() {
                let slice = min(deadline, Date(timeIntervalSinceNow: 0.005))
                if let event = app.nextEvent(matching: .any, until: slice, inMode: .default, dequeue: true) { app.sendEvent(event) }
                app.updateWindows()
            }
        }
        func move(_ point: NSPoint) {
            let quartz = CGPoint(x: point.x, y: screen.frame.maxY - point.y)
            CGWarpMouseCursorPosition(quartz)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: quartz, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
        move(NSPoint(x: 40, y: 100))
        pump(until: { false }, timeout: 0.08)
        if app.isActive {
            let other = NSWorkspace.shared.runningApplications.first { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            other?.activate(options: [])
            pump(until: { !app.isActive }, timeout: 0.3)
        }
        assert(!panel.isKeyWindow && !app.isActive)
        assert(tracker.trackingAreas.contains { $0.options.contains(.activeAlways) })
        let start = ProcessInfo.processInfo.systemUptime
        move(NSPoint(x: 180, y: 280))
        pump(until: { tracker.hovered }, timeout: 0.12)
        assert(tracker.hovered, "Hover must arrive promptly while another app keeps focus")
        let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
        assert(tracker.hitTest(NSPoint(x: 10, y: 10)) == nil)
        move(NSPoint(x: 40, y: 100))
        pump(until: { !tracker.hovered }, timeout: 0.12)
        assert(!tracker.hovered && changes == [true, false])
        print("PASS: inactive panel receives hover in \(Int(milliseconds)) ms; exit clears immediately and tracking does not intercept clicks")
        let inside = NSPoint(x: panel.frame.minX + 100, y: panel.frame.minY + 100)
        let outside = NSPoint(x: panel.frame.minX - 1, y: panel.frame.minY + 100)
        assert(HoverTrackingView.reconcile(in: panel, screenPoint: inside) == 1 && tracker.hovered)
        assert(HoverTrackingView.reconcile(in: panel, screenPoint: inside) == 0)
        assert(HoverTrackingView.reconcile(in: panel, screenPoint: outside) == 1 && !tracker.hovered)
        tracker.hoverEnabled = false
        assert(HoverTrackingView.reconcile(in: panel, screenPoint: inside) == 0 && !tracker.hovered)
        tracker.hoverEnabled = true
        tracker.isHidden = true
        assert(HoverTrackingView.reconcile(in: panel, screenPoint: inside) == 0 && !tracker.hovered)
        print("PASS: sampling repairs missing enter/exit events, avoids redundant updates and respects disabled or hidden controls")
    }
}
