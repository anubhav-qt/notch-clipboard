import AppKit
import SwiftUI

/// A display with a notch, and where that notch sits.
private struct NotchTarget {
    let screen: NSScreen
    let geometry: NotchGeometry
}

private enum KeyCode {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let enter: UInt16 = 76
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = ClipboardModel()
    private var surface: PanelSurface!
    private var panel: NotchPanel { surface.window }
    private var revealView: NotchRevealView!
    private var status: NSStatusItem!
    private var timer: Timer?
    private var tickInterval: TimeInterval = 0
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activeScreen: NSScreen?
    private var previousApp: NSRunningApplication?
    private var notchTargets: [NotchTarget] = []
    private var dismissedAtNotch = false
    private var dismissal = HoverDismissal(openedAtNotch: true)
    private var schedule = MonitorSchedule()
    private let timingLog = TimingLog(directory: clipboardDataDirectory)
    private var interactionActivity: NSObjectProtocol?
    private var isOpen = false
    private var isClosing = false
    private var animationSerial = 0
    private var presentedAt: TimeInterval = 0
    private var lastVisibilityCheck: TimeInterval = 0
    private var spaceChangeCount = 0
    private var recoveryCount = 0
    private var lastRuntimeStatus: NSDictionary?
    private let previewMode = CommandLine.arguments.contains("--preview")
    private let statusURL = clipboardDataDirectory.appendingPathComponent("runtime.plist")

    /// A dialog, the edit sheet or Select mode is showing, so the panel must stay open even if the pointer leaves.
    private var isBusyWithDialog: Bool {
        if NSApp.modalWindow != nil || panel.attachedSheet != nil {
            return true
        }
        return model.holdsPanelOpen
    }

    // MARK: Launch and quit

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        timingLog.record("launch", fields: ["version": version])
        model.slowWork = { [weak self] stage, duration in
            self?.timingLog.record("slow_work", fields: ["stage": stage, "duration_ms": duration * 1000])
        }
        revealView = NotchRevealView(hostedView: HostingView(rootView: HistoryView(model: model)))
        surface = PanelSurface(content: revealView)
        surface.dismiss = { [weak self] in
            self?.closeHistory()
        }
        model.removalRequested = { [weak self] in
            self?.focusPanelForConfirmation()
        }
        model.selected = { [weak self] in
            self?.returnToPreviousApp()
        }
        setupStatusMenu()
        setupEditMenu()
        startMonitoring()
        refreshNotchTargets()
        // Lay out once now, so the first hover does not pay the SwiftUI setup cost.
        if let screen = notchScreen() {
            prepareFrame(on: screen)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
        if previewMode {
            showHistory(on: notchScreen())
        }
        writeStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        model.shutdown()
        endInteractionActivity()
        timingLog.record("quit")
        timingLog.flush()
        try? FileManager.default.removeItem(at: statusURL)
    }

    private func startMonitoring() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalEvent(event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalEvent(event)
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(activeSpaceChanged(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(applicationActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(activeSpaceChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let screenLocked = NSNotification.Name("com.apple.screenIsLocked")
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(sessionResigned), name: screenLocked, object: nil)
        updatePace(mouse: NSEvent.mouseLocation)
    }

    /// Runs the loop fast only while the panel is open or the pointer is near a notch.
    private func updatePace(mouse: NSPoint) {
        let nearNotch = notchTargets.contains { $0.geometry.isNear(mouse) }
        let interval = MonitorSchedule.interval(panelOpen: isOpen, nearNotch: nearNotch)
        if interval == tickInterval {
            return
        }
        tickInterval = interval
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = interval / 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: Menus

    private func setupStatusMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Notch Clipboard")
        status.button?.toolTip = "Notch Clipboard: hover at the notch to open history"
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Clipboard History", action: #selector(openFromMenu), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let clear = NSMenuItem(title: "Clear History…", action: #selector(clearFromMenu), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch Clipboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        status.menu = menu
    }

    /// Gives the search field Cut, Copy, Paste and Select All shortcuts.
    private func setupEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editRoot = NSMenuItem()
        editRoot.submenu = edit
        let main = NSMenu()
        main.addItem(editRoot)
        NSApp.mainMenu = main
    }

    @objc private func openFromMenu() {
        showHistory(on: notchScreen(), fromMenu: true)
    }

    @objc private func clearFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Saved items and the current system clipboard are kept."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear History")
        if alert.runModal() == .alertSecondButtonReturn {
            model.clear()
        }
    }

    // MARK: Events

    private func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
            if event.window === panel {
                panel.makeKey()
            }
            return event
        case .keyDown:
            return handleKeyDown(event)
        case .mouseMoved:
            processHover()
            return event
        default:
            return event
        }
    }

    /// Returns nil when the key was used here, so it does not reach the search field.
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if model.isConfirmingSavedRemoval {
            if event.keyCode == KeyCode.escape {
                model.cancelSavedRemoval()
                return nil
            }
            if event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.enter {
                model.finishSavedRemoval(remove: true)
                return nil
            }
        }
        if event.keyCode == KeyCode.escape && isOpen {
            return handleEscape(event)
        }
        return event
    }

    /// Escape closes the innermost thing first: the edit sheet, a menu, Select mode, then the panel.
    private func handleEscape(_ event: NSEvent) -> NSEvent? {
        // A system sheet or alert owns Escape while it shows.
        if NSApp.modalWindow != nil || panel.attachedSheet != nil {
            return event
        }
        if model.categoryDraft != nil {
            model.cancelCategoryDraft()
            return nil
        }
        if model.openMenu != nil {
            model.openMenu = nil
            return nil
        }
        if model.isSelecting {
            model.cancelSelection()
            return nil
        }
        // With a dialog up, Escape belongs to the dialog, not the panel.
        if isBusyWithDialog {
            return event
        }
        closeHistory()
        return nil
    }

    private func handleGlobalEvent(_ event: NSEvent) {
        if event.type == .mouseMoved {
            processHover()
            return
        }
        // A click in another app closes the panel (matters when it was opened from the menu).
        if isOpen && !isBusyWithDialog {
            closeHistory()
        }
    }

    @objc private func tick() {
        let due = schedule.advance(to: ProcessInfo.processInfo.systemUptime)
        if MonitorSchedule.isStall(gap: due.gap, interval: tickInterval) {
            timingLog.record("heartbeat_gap", fields: ["duration_ms": due.gap * 1000, "panel_open": isOpen])
        }
        processHover()
        if due.poll {
            model.poll()
        }
        // Ages like "5 min ago" only need refreshing while someone can see them.
        if due.refresh && isOpen {
            model.reload()
        }
    }

    // MARK: Hover

    private func processHover() {
        if previewMode {
            return
        }
        let mouse = NSEvent.mouseLocation
        if isOpen {
            trackOpenPanel(mouse: mouse)
        } else {
            openIfPointerAtNotch(mouse: mouse)
        }
        updatePace(mouse: mouse)
    }

    private func trackOpenPanel(mouse: NSPoint) {
        // Inclusive edges: the pointer can rest exactly on the top edge of the display.
        let frame = panel.frame
        let insideX = mouse.x >= frame.minX && mouse.x <= frame.maxX
        let insideY = mouse.y >= frame.minY && mouse.y <= frame.maxY
        let pointerInside = insideX && insideY
        let wantsClose = dismissal.shouldClose(pointerInside: pointerInside, dialogShowing: isBusyWithDialog)
        if wantsClose {
            closeHistory()
            return
        }
        let corrected = HoverTrackingView.reconcile(in: panel, screenPoint: mouse)
        if corrected > 0 {
            timingLog.record("hover_reconciled", fields: ["count": corrected])
        }
        checkSurfaceIfDue()
    }

    private func openIfPointerAtNotch(mouse: NSPoint) {
        if NSEvent.pressedMouseButtons != 0 {
            return
        }
        guard let target = notchTarget(containing: mouse) else {
            dismissedAtNotch = false
            return
        }
        if !dismissedAtNotch {
            showHistory(on: target.screen)
        }
    }

    /// macOS can silently lose the panel's window during Space changes. Rebuild it if so.
    private func checkSurfaceIfDue() {
        let now = ProcessInfo.processInfo.systemUptime
        let settled = now - presentedAt > 0.20
        let due = now - lastVisibilityCheck > 0.25
        // Rebuilding the window would drop an attached sheet, so wait for it to close.
        guard settled, due, NSApp.modalWindow == nil, panel.attachedSheet == nil else { return }
        lastVisibilityCheck = now
        let exposure = surface.exposure
        if surface.needsRecovery(exposure), let screen = activeScreen {
            recoveryCount += 1
            timingLog.record("surface_recovery", fields: [
                "ordered": exposure.ordered,
                "on_active_space": exposure.onActiveSpace,
                "owns_content_point": exposure.ownsContentPoint
            ])
            isOpen = false
            showHistory(on: screen, recovering: true)
        }
        if surface.windowIsMoving {
            timingLog.record("surface_in_motion")
        }
        writeStatus(exposure: surface.exposure)
    }

    // MARK: Notch geometry

    /// Asking macOS for the notch shape is slow, so do it only when displays or Spaces change.
    private func refreshNotchTargets() {
        var targets: [NotchTarget] = []
        for screen in NSScreen.screens {
            if let geometry = NotchGeometry(screen: screen) {
                targets.append(NotchTarget(screen: screen, geometry: geometry))
            }
        }
        notchTargets = targets
    }

    private func notchTarget(containing point: NSPoint) -> NotchTarget? {
        notchTargets.first { $0.geometry.contains(point) }
    }

    private func notchScreen() -> NSScreen? {
        if let target = notchTargets.first {
            return target.screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: Open and close

    private func prepareFrame(on screen: NSScreen) {
        if model.notchHeight != screen.safeAreaInsets.top {
            model.notchHeight = screen.safeAreaInsets.top
        }
        let width = min(560, screen.frame.width - 40)
        let height = min(440, screen.frame.height - 60)
        let notch = NotchGeometry(screen: screen)?.rect
        let notchWidth = notch?.width ?? 165
        if model.notchWidth != notchWidth {
            model.notchWidth = notchWidth
        }
        let centerX = notch?.midX ?? screen.frame.midX
        let frame = NSRect(x: centerX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
    }

    private func showHistory(on screen: NSScreen?, recovering: Bool = false, fromMenu: Bool = false) {
        guard let screen, !isOpen else { return }
        let start = ProcessInfo.processInfo.systemUptime
        activeScreen = screen
        if !recovering {
            previousApp = NSWorkspace.shared.frontmostApplication
            dismissal = HoverDismissal(openedAtNotch: !fromMenu)
            if model.query.isEmpty {
                model.reload()
            } else {
                model.query = ""
            }
        }
        // Keep the SwiftUI content but use a fresh native window, so it joins the current Space.
        surface.renew()
        prepareFrame(on: screen)
        animationSerial += 1
        isClosing = false
        revealView.reveal(open: true, notchWidth: model.notchWidth, notchHeight: model.notchHeight, duration: 0.14)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        if interactionActivity == nil {
            interactionActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Respond to clipboard panel interaction")
        }
        isOpen = true
        presentedAt = ProcessInfo.processInfo.systemUptime
        lastVisibilityCheck = presentedAt
        writeStatus()
        timingLog.record("panel_open", fields: [
            "duration_ms": (ProcessInfo.processInfo.systemUptime - start) * 1000,
            "recovering": recovering,
            "from_menu": fromMenu,
            "generation": surface.generation
        ])
    }

    private func closeHistory(animated: Bool = true) {
        guard isOpen else { return }
        model.panelClosed()
        isOpen = false
        endInteractionActivity()
        timingLog.record("panel_close", fields: ["animated": animated])
        isClosing = animated
        animationSerial += 1
        // Stay closed while the pointer rests on the notch; reopen only after it leaves and returns.
        dismissedAtNotch = notchTarget(containing: NSEvent.mouseLocation) != nil
        if animated {
            let serial = animationSerial
            let closingPanel = panel
            revealView.reveal(open: false, notchWidth: model.notchWidth, notchHeight: model.notchHeight, duration: 0.11)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
                self?.finishClosing(panel: closingPanel, serial: serial)
            }
        } else {
            panel.orderOut(nil)
            revealView.reveal(open: false, notchWidth: model.notchWidth, notchHeight: model.notchHeight, duration: 0)
        }
        writeStatus()
    }

    private func finishClosing(panel closingPanel: NotchPanel, serial: Int) {
        // A newer open or close started meanwhile; it owns the panel now.
        guard animationSerial == serial, !isOpen else { return }
        closingPanel.orderOut(nil)
        isClosing = false
        writeStatus()
    }

    private func resetPresentation() {
        endInteractionActivity()
        model.panelClosed()
        // Also cancels a contraction still pending from the previous Space.
        animationSerial += 1
        isOpen = false
        isClosing = false
        dismissedAtNotch = false
        panel.orderOut(nil)
        revealView.reveal(open: false, notchWidth: model.notchWidth, notchHeight: model.notchHeight, duration: 0)
        writeStatus()
    }

    private func focusPanelForConfirmation() {
        panel.makeKey()
        panel.makeFirstResponder(nil)
    }

    private func returnToPreviousApp() {
        closeHistory()
        guard let previousApp else { return }
        if previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate(options: [])
        }
    }

    private func endInteractionActivity() {
        if let interactionActivity {
            ProcessInfo.processInfo.endActivity(interactionActivity)
            self.interactionActivity = nil
        }
    }

    // MARK: System notifications

    @objc private func activeSpaceChanged(_ notification: Notification) {
        timingLog.record("space_or_display_changed")
        spaceChangeCount += 1
        refreshNotchTargets()
        resetPresentation()
        processHover()
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              NSApp.modalWindow == nil else { return }
        // Clicking a control on a nonactivating panel can hand focus back to the previous app.
        // Keep the panel open when the pointer is still on it.
        if isOpen && panel.isOnActiveSpace && panel.frame.contains(NSEvent.mouseLocation) {
            previousApp = app
            return
        }
        // Select mode keeps the panel open until Done, Cancel or Escape, even while another app is used.
        if isOpen && panel.isOnActiveSpace && model.isSelecting {
            previousApp = app
            return
        }
        timingLog.record("foreground_reset", fields: ["panel_open": isOpen])
        resetPresentation()
        processHover()
    }

    @objc private func sessionResigned() {
        closeHistory(animated: false)
    }

    @objc private func systemWillSleep() {
        timingLog.record("system_sleep")
        closeHistory(animated: false)
    }

    @objc private func systemDidWake() {
        schedule = MonitorSchedule()
        timingLog.record("system_wake")
        refreshNotchTargets()
        processHover()
    }

    // MARK: Runtime status

    /// Writes a small state file that the Space regression tests read.
    private func writeStatus(exposure: PanelExposure? = nil) {
        let frame = panel.frame
        let exposure = exposure ?? surface.exposure
        let status: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "open": isOpen,
            "closing": isClosing,
            "onActiveSpace": panel.isOnActiveSpace,
            "windowVisible": panel.isVisible,
            "spaceChanges": spaceChangeCount,
            "window": panel.windowNumber,
            "x": frame.minX,
            "y": frame.minY,
            "width": frame.width,
            "height": frame.height,
            "surfaceGeneration": surface.generation,
            "recoveries": recoveryCount,
            "confirmingSavedRemoval": model.isConfirmingSavedRemoval,
            "selecting": model.isSelecting,
            "editingCategories": model.categoryDraft != nil,
            "surfaceMoving": surface.windowIsMoving,
            "exposed": exposure.isExposed,
            "unoccluded": exposure.unoccluded,
            "ownsContentPoint": exposure.ownsContentPoint
        ]
        if lastRuntimeStatus?.isEqual(to: status) == true {
            return
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: status, format: .binary, options: 0) else { return }
        do {
            try data.write(to: statusURL, options: .atomic)
            lastRuntimeStatus = status as NSDictionary
        } catch {
            // Not saved; the next status change tries again.
        }
    }
}

@main struct NotchClipboardApp {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--configure-screenshots") || arguments.contains("--restore-screenshots") {
            configureScreenshots(restore: arguments.contains("--restore-screenshots"))
            return
        }
        // The login agent can start a second copy. Leave before touching any shared state.
        if anotherCopyIsRunning() {
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private static func configureScreenshots(restore: Bool) {
        do {
            try ScreenshotSettings.configure(restore: restore)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func anotherCopyIsRunning() -> Bool {
        let identifier = Bundle.main.bundleIdentifier ?? "local.notchclipboard.app"
        let myID = ProcessInfo.processInfo.processIdentifier
        let copies = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        return copies.contains { $0.processIdentifier != myID }
    }
}
