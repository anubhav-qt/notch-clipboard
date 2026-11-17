import AppKit

class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var dismiss: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { dismiss?() }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct PanelExposure {
    let ordered: Bool
    let onActiveSpace: Bool
    let unoccluded: Bool
    let ownsContentPoint: Bool
    // Occlusion notifications can lag behind a removed menu. A WindowServer hit
    // on the panel itself establishes exposure without waiting for that callback.
    var isExposed: Bool { ordered && onActiveSpace && ownsContentPoint }
}

/// Retain the SwiftUI content, but give each presentation a new WindowServer surface.
/// Retiring the native window discards its previous WindowServer/Space state.
@MainActor final class PanelSurface {
    private(set) var window: NotchPanel
    private(set) var generation = 1
    private(set) var failedExposureChecks = 0
    private(set) var windowIsMoving = false
    private var previousServerBounds: CGRect?
    private let content: NSView
    private let factory: @MainActor () -> NotchPanel
    var dismiss: (() -> Void)? { didSet { window.dismiss = dismiss } }

    init(content: NSView, factory: (@MainActor () -> NotchPanel)? = nil) {
        self.content = content
        let make = factory ?? {
            NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        }
        self.factory = make
        window = make()
        configureWindow()
    }

    func renew() {
        let oldWindow = window
        oldWindow.orderOut(nil)
        oldWindow.contentView = nil
        oldWindow.close()
        window = factory()
        generation += 1
        failedExposureChecks = 0
        windowIsMoving = false
        previousServerBounds = nil
        configureWindow()
    }

    private func configureWindow() {
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.animationBehavior = .none
        window.acceptsMouseMovedEvents = true
        window.contentView = content
        window.dismiss = dismiss
    }

    var exposure: PanelExposure {
        // Probe below the notch/menu bar. Space membership and isVisible alone also
        // report true for an ordered window covered by a full-screen app.
        let frame = window.frame
        let points = [
            NSPoint(x: frame.midX, y: frame.maxY - min(120, frame.height / 3)),
            NSPoint(x: frame.minX + frame.width * 0.75, y: frame.midY)
        ]
        let number = window.windowNumber
        let ownsPoint = number > 0 && points.contains {
            NSWindow.windowNumber(at: $0, belowWindowWithWindowNumber: 0) == number
        }
        return PanelExposure(ordered: window.isVisible, onActiveSpace: window.isOnActiveSpace,
                             unoccluded: window.occlusionState.contains(.visible), ownsContentPoint: ownsPoint)
    }

    /// Two failed checks avoid rebuilding during a single compositor update.
    func needsRecovery(_ exposure: PanelExposure, serverBounds: CGRect? = nil) -> Bool {
        if exposure.isExposed {
            failedExposureChecks = 0
            windowIsMoving = false
            previousServerBounds = nil
            return false
        }
        // A Space swipe translates the surface even when AppKit already reports
        // the destination Space as active. Wait for that motion to settle before
        // rebuilding. A stationary, misplaced surface still recovers normally.
        let bounds: CGRect?
        if let serverBounds {
            bounds = serverBounds
        } else {
            bounds = Self.serverBounds(ofWindow: window.windowNumber)
        }
        windowIsMoving = false
        if let bounds {
            if let previous = previousServerBounds {
                windowIsMoving = abs(previous.origin.x - bounds.origin.x) > 1 || abs(previous.origin.y - bounds.origin.y) > 1
            }
            previousServerBounds = bounds
            if windowIsMoving {
                failedExposureChecks = 0
                return false
            }
        }
        // Respect higher-level system UI (menus, Mission Control, screen lock).
        // Repair a lost/covered surface only when a normal app is in front of it.
        let point = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let front = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        let frontIsHigherSystemUI = front != window.windowNumber && Self.layer(ofWindow: front) >= window.level.rawValue
        if frontIsHigherSystemUI {
            failedExposureChecks = 0
            return false
        }
        failedExposureChecks += 1
        return failedExposureChecks >= 2
    }

    private static func windowInfo(_ number: Int) -> [String: Any]? {
        guard number > 0 else { return nil }
        let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]]
        return list?.first
    }

    private static func serverBounds(ofWindow number: Int) -> CGRect? {
        guard let raw = windowInfo(number)?[kCGWindowBounds as String] as? [String: Any] else { return nil }
        return CGRect(dictionaryRepresentation: raw as CFDictionary)
    }

    /// The WindowServer layer, or Int.min when the window is unknown.
    private static func layer(ofWindow number: Int) -> Int {
        guard let layer = windowInfo(number)?[kCGWindowLayer as String] as? NSNumber else { return Int.min }
        return layer.intValue
    }
}
