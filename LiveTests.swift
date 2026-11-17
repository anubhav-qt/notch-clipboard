import AppKit

/// Checks the installed, running app: menu opening, outside clicks, pointer exit and the Clear sheet.
/// Never presses Clear History, so real history is untouched.
@main struct LiveTests {
    @MainActor static func main() {
        setvbuf(stdout, nil, _IONBF, 0)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let runtime = clipboardDataDirectory.appendingPathComponent("runtime.plist")
        let screenTop = NSScreen.screens.first!.frame.maxY
        let originalMouse = NSEvent.mouseLocation
        var failures = 0
        defer {
            CGWarpMouseCursorPosition(CGPoint(x: originalMouse.x, y: screenTop - originalMouse.y))
            if failures > 0 {
                exit(1)
            }
        }

        func pump(_ seconds: TimeInterval) {
            let deadline = Date(timeIntervalSinceNow: seconds)
            while Date() < deadline {
                if let event = app.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) {
                    app.sendEvent(event)
                }
            }
        }
        func state() -> [String: Any] {
            guard let data = try? Data(contentsOf: runtime) else { return [:] }
            return (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]) ?? [:]
        }
        func isOpen() -> Bool {
            state()["open"] as? Bool ?? false
        }
        func check(_ name: String, _ passed: Bool) {
            print("\(passed ? "PASS" : "FAIL"): \(name)")
            if !passed {
                failures += 1
            }
        }
        func openFromMenu() {
            let script = """
            tell application "System Events" to tell process "NotchClipboard" to tell menu bar item 1 of menu bar 2
            click
            delay 0.3
            click menu item "Open Clipboard History" of menu 1
            end tell
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
            pump(0.6)
        }
        /// x from the panel's left edge, y from its top edge.
        func panelPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let s = state()
            let left = s["x"] as? CGFloat ?? 0
            let bottom = s["y"] as? CGFloat ?? 0
            let height = s["height"] as? CGFloat ?? 0
            return CGPoint(x: left + x, y: screenTop - (bottom + height) + y)
        }
        func move(to point: CGPoint) {
            CGWarpMouseCursorPosition(point)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            pump(0.3)
        }
        func click(at point: CGPoint) {
            CGWarpMouseCursorPosition(point)
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            pump(0.4)
        }
        func press(_ key: CGKeyCode) {
            for down in [true, false] {
                CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)?.post(tap: .cghidEventTap)
            }
            pump(0.4)
        }

        // The title row sits under the notch: top padding is the notch height plus 10, the row is about 30 tall.
        let titleY = max(17, NSScreen.screens.first!.safeAreaInsets.top + 10) + 15
        let trashX: CGFloat = 496

        // A scratch window of our own, so test clicks never land in the user's apps.
        let scratchFrame = NSRect(x: 40, y: 60, width: 160, height: 100)
        let scratch = NSWindow(contentRect: scratchFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        scratch.isReleasedWhenClosed = false
        scratch.backgroundColor = .darkGray
        scratch.level = .floating
        scratch.orderFrontRegardless()
        defer { scratch.orderOut(nil) }
        let outside = CGPoint(x: scratchFrame.midX, y: screenTop - scratchFrame.midY)
        move(to: outside)

        openFromMenu()
        pump(1.0)
        check("menu Open keeps the panel open while the pointer is far away", isOpen())
        click(at: outside)
        check("a click in another app closes a menu-opened panel", !isOpen())

        openFromMenu()
        move(to: panelPoint(300, 300))
        check("pointer entering a menu-opened panel keeps it open", isOpen())
        move(to: outside)
        check("pointer leaving after a visit closes it", !isOpen())

        openFromMenu()
        move(to: panelPoint(300, 300))
        click(at: panelPoint(trashX, titleY))
        move(to: outside)
        check("leaving while the Clear sheet shows keeps the panel open", isOpen())
        press(53)
        check("Escape closes only the sheet, not the panel", isOpen())
        move(to: panelPoint(300, 300))
        move(to: outside)
        check("after the sheet closes, leaving closes the panel", !isOpen())

        openFromMenu()
        openFromMenu()
        pump(0.3)
        check("choosing Open twice is harmless", isOpen())
        // Click the selected All filter first so the panel has keyboard focus; it changes nothing.
        click(at: panelPoint(40, titleY))
        press(53)
        check("Escape closes the panel", !isOpen())
    }
}
