import AppKit

/// Simulates the stale visibility report without needing to wait hours for macOS.
final class StalePanel: NotchPanel {
    var stale = false
    override var isVisible: Bool { stale || super.isVisible }
    override var isOnActiveSpace: Bool { stale || super.isOnActiveSpace }
    override var occlusionState: NSWindow.OcclusionState { stale ? .visible : super.occlusionState }
}

@main struct PanelSurfaceTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let screen = NSScreen.screens.first!
        let frame = NSRect(x: screen.frame.minX + 80, y: screen.frame.minY + 180, width: 360, height: 240)
        let background = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        background.isReleasedWhenClosed = false
        background.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
        background.backgroundColor = .darkGray
        background.orderFrontRegardless()
        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor
        let surface = PanelSurface(content: content, factory: {
            StalePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        })
        defer { surface.window.orderOut(nil); background.orderOut(nil) }
        func settle() {
            let deadline = Date(timeIntervalSinceNow: 0.06)
            while Date() < deadline {
                if let event = app.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) { app.sendEvent(event) }
                app.updateWindows()
            }
        }
        func show() {
            surface.window.setFrame(frame, display: true)
            surface.window.orderFrontRegardless()
            for _ in 0..<40 {
                settle()
                if surface.exposure.isExposed { return }
            }
            print("Surface failed to appear: \(surface.exposure), generation=\(surface.generation), front app=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")")
            let front = NSWindow.windowNumber(at: NSPoint(x: frame.midX, y: frame.midY), belowWindowWithWindowNumber: 0)
            let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            for info in windows where (info[kCGWindowNumber as String] as? NSNumber)?.intValue == front || (info[kCGWindowNumber as String] as? NSNumber)?.intValue == surface.window.windowNumber {
                print("Window: \(info.filter { [kCGWindowNumber, kCGWindowLayer, kCGWindowBounds, kCGWindowOwnerName, kCGWindowAlpha].map { $0 as String }.contains($0.key) })")
            }
            fflush(stdout)
        }
        show()
        assert(surface.exposure.isExposed)
        assert(!surface.needsRecovery(surface.exposure))

        let stale = surface.window as! StalePanel
        stale.orderOut(nil)
        settle()
        stale.stale = true
        assert(stale.isVisible && stale.isOnActiveSpace && stale.occlusionState.contains(.visible))
        assert(!surface.exposure.ownsContentPoint && !surface.exposure.isExposed)
        let hidden = surface.exposure
        let startBounds = CGRect(x: 80, y: 180, width: 360, height: 240)
        let middleBounds = startBounds.offsetBy(dx: 600, dy: 0)
        let endBounds = startBounds.offsetBy(dx: 1_200, dy: 0)
        assert(!surface.needsRecovery(hidden, serverBounds: startBounds))
        assert(!surface.needsRecovery(hidden, serverBounds: middleBounds) && surface.windowIsMoving)
        assert(!surface.needsRecovery(hidden, serverBounds: endBounds) && surface.failedExposureChecks == 0)
        assert(!surface.needsRecovery(hidden, serverBounds: endBounds))
        assert(surface.needsRecovery(hidden, serverBounds: endBounds))
        let exposed = PanelExposure(ordered: true, onActiveSpace: true, unoccluded: true, ownsContentPoint: true)
        assert(!surface.needsRecovery(exposed))
        print("PASS: Space-animation motion defers recovery; a surface that stays misplaced still recovers")
        assert(!surface.needsRecovery(surface.exposure))
        assert(surface.needsRecovery(surface.exposure))
        print("PASS: detects a hidden surface even with stale visible/active-Space/occlusion flags")

        let oldNumber = stale.windowNumber
        stale.stale = false
        surface.renew()
        show()
        assert(surface.window.windowNumber != oldNumber)
        assert(surface.window.contentView === content && stale.contentView == nil)
        assert(surface.exposure.isExposed)
        assert(!surface.needsRecovery(surface.exposure))
        stale.orderOut(nil)
        settle()
        assert(surface.exposure.isExposed)
        print("PASS: fresh native window restores exposure, preserves content and isolates old-window callbacks")

        let menu = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        menu.isReleasedWhenClosed = false
        menu.level = NSWindow.Level(rawValue: surface.window.level.rawValue + 1)
        menu.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
        menu.backgroundColor = .gray
        menu.orderFrontRegardless()
        settle()
        assert(!surface.exposure.isExposed)
        assert(!surface.needsRecovery(surface.exposure) && !surface.needsRecovery(surface.exposure))
        menu.orderOut(nil)
        for _ in 0..<8 {
            settle()
            if surface.exposure.isExposed { break }
        }
        if !surface.exposure.isExposed {
            print("After menu: \(surface.exposure), current=\(surface.window.windowNumber), menu=\(menu.windowNumber), front=\(NSWindow.windowNumber(at: NSPoint(x: frame.midX, y: frame.midY), belowWindowWithWindowNumber: 0))")
            fflush(stdout)
        }
        assert(surface.exposure.isExposed)
        print("PASS: higher-level system UI does not cause a recovery loop")

        for _ in 0..<100 {
            surface.renew()
            show()
            assert(surface.window.contentView === content && surface.exposure.isExposed)
            assert(!surface.needsRecovery(surface.exposure))
        }
        assert(surface.generation == 102)
        print("PASS: 100 native-window replacements retain the content and remain exposed")
    }
}
