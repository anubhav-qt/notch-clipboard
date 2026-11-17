import AppKit
import ApplicationServices

@MainActor final class RegressionDriver: NSObject, NSApplicationDelegate {
    let runtime = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Notch Clipboard/runtime.plist")
    let resultURL: URL
    let previous = NSWorkspace.shared.frontmostApplication
    var windows: [NSWindow] = []
    var observations: [NSObjectProtocol] = []
    var results: [[String: Any]] = []
    var finished = false
    var failed = false
    let center = NSScreen.screens.first!.frame.midX
    init(resultURL: URL) { self.resultURL = resultURL }
    func log(_ stage: String, _ passed: Bool, details: String = "") {
        results.append(["stage": stage, "passed": passed, "details": details])
        if !passed { failed = true }
        try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: resultURL, options: .atomic)
    }
    func state() -> [String: Any] {
        (try? PropertyListSerialization.propertyList(from: Data(contentsOf: runtime), format: nil) as? [String: Any]) ?? [:]
    }
    func onscreen(_ number: Int) -> Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == number }
    }
    func later(_ delay: Double, _ action: @escaping @MainActor () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action) }
    func wait(_ label: String, remaining: Int = 120, condition: @escaping @MainActor () -> Bool, done: @escaping @MainActor () -> Void) {
        if finished { return }
        if condition() { done(); return }
        if remaining == 0 { log(label, false, details: "Timed out"); finish(); return }
        later(0.02) { self.wait(label, remaining: remaining - 1, condition: condition, done: done) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(); let root = NSMenuItem(); root.submenu = NSMenu(title: "Verification"); menu.addItem(root); NSApp.mainMenu = menu
        for name in ["Space A", "Space B", "Space C"] {
            let window = NSWindow(contentRect: NSRect(x: 150, y: 150, width: 650, height: 400), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Notch Clipboard: \(name)"
            window.backgroundColor = NSColor(white: 0.08, alpha: 1)
            window.collectionBehavior = [.fullScreenPrimary]
            window.isReleasedWhenClosed = false
            windows.append(window)
        }
        windows[0].makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        later(0.4) {
            self.check("normal desktop") {
                self.enterFullScreen(self.windows[0]) {
                    self.check("first full-screen Space") { self.cycle(0) }
                }
            }
        }
        later(60) { if !self.finished { self.log("global timeout", false); self.finish() } }
    }
    func enterFullScreen(_ window: NSWindow, done: @escaping @MainActor () -> Void) {
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { _ in
            if let token { NotificationCenter.default.removeObserver(token) }
            self.later(0.15, done)
        }
        if let token { observations.append(token) }
        window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(nil)
    }
    func check(_ label: String, keepPointer: Bool = false, done: @escaping @MainActor () -> Void) {
        if !keepPointer {
            CGWarpMouseCursorPosition(CGPoint(x: 100, y: 650))
            later(0.16) { self.check(label, keepPointer: true, done: done) }
            return
        }
        CGWarpMouseCursorPosition(CGPoint(x: center, y: 0))
        let start = ProcessInfo.processInfo.systemUptime
        var stableSamples = 0
        wait(label, condition: {
            let state = self.state()
            let number = (state["window"] as? NSNumber)?.intValue ?? -1
            let x = (state["x"] as? NSNumber)?.doubleValue ?? 0
            let y = (state["y"] as? NSNumber)?.doubleValue ?? 0
            let width = (state["width"] as? NSNumber)?.doubleValue ?? 0
            let height = (state["height"] as? NSNumber)?.doubleValue ?? 0
            let hit = NSWindow.windowNumber(at: NSPoint(x: x + width / 2, y: y + height - 120), belowWindowWithWindowNumber: 0)
            let visible = state["open"] as? Bool == true && state["exposed"] as? Bool == true && self.onscreen(number) && hit == number
            stableSamples = visible ? stableSamples + 1 : 0
            return stableSamples >= 12
        }) {
            let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
            self.log(label, true, details: "Exposed for 12 consecutive samples; verified in \(Int(milliseconds)) ms")
            done()
        }
    }
    func cycle(_ index: Int) {
        if index == 4 { prepareAdditionalSpaces(1); return }
        let target = windows[0]
        let entering = !target.styleMask.contains(.fullScreen)
        let notification: Notification.Name = entering ? NSWindow.didEnterFullScreenNotification : NSWindow.didExitFullScreenNotification
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(forName: notification, object: target, queue: .main) { _ in
            if let token { NotificationCenter.default.removeObserver(token) }
            self.wait("test window on active Space", condition: { target.isOnActiveSpace && self.onscreen(target.windowNumber) }) {
                self.check("repeat desktop/full-screen transition \(index + 1), pointer remains at notch", keepPointer: true) { self.later(0.3) { self.cycle(index + 1) } }
            }
        }
        if let token { observations.append(token) }
        target.toggleFullScreen(nil)
    }
    func prepareAdditionalSpaces(_ index: Int) {
        if index == windows.count { visitExistingSpaces(0); return }
        enterFullScreen(windows[index]) {
            self.check("additional full-screen Space \(index + 1)") { self.prepareAdditionalSpaces(index + 1) }
        }
    }
    func visitExistingSpaces(_ index: Int) {
        let order = [0, 1, 2, 1, 0, 2, 0]
        if index == order.count { exitAndRestore(); return }
        let target = windows[order[index]]
        target.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        wait("existing full-screen Space becomes active", condition: { target.isOnActiveSpace && self.onscreen(target.windowNumber) }) {
            self.check("existing full-screen switch \(index + 1), pointer stays at notch", keepPointer: true) {
                self.visitExistingSpaces(index + 1)
            }
        }
    }
    func exitAndRestore() {
        let target = windows[0]
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(forName: NSWindow.didExitFullScreenNotification, object: target, queue: .main) { _ in
            if let token { NotificationCenter.default.removeObserver(token) }
            target.miniaturize(nil)
            self.wait("window minimized", condition: { target.isMiniaturized }) {
                target.deminiaturize(nil)
                target.makeKeyAndOrderFront(nil)
                self.wait("window restored", condition: { !target.isMiniaturized && target.isVisible }) {
                    self.later(0.3) {
                        self.enterFullScreen(target) {
                            self.check("after minimize, restore and full screen") { self.log("complete", true); self.finish() }
                        }
                    }
                }
            }
        }
        if let token { observations.append(token) }
        target.toggleFullScreen(nil)
    }
    func finish() {
        guard !finished else { return }
        finished = true
        CGWarpMouseCursorPosition(CGPoint(x: 100, y: 650))
        for token in observations { NotificationCenter.default.removeObserver(token) }
        for window in windows { window.orderOut(nil) }
        previous?.activate(options: [])
        NSApp.terminate(nil)
    }
}

@main struct SpaceRegression {
    @MainActor static func main() {
        let app = NSApplication.shared
        let driver = RegressionDriver(resultURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        app.delegate = driver
        app.run()
    }
}
