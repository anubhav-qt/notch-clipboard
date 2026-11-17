import AppKit
import SwiftUI

/// SwiftUI hover delivery can lag on a non-key panel. Track even while another
/// app owns focus, and keep this view transparent to the row's two buttons.
struct HoverRegion: NSViewRepresentable {
    var cornerRadius: CGFloat = 7
    let onChange: (Bool) -> Void
    func makeNSView(context: Context) -> HoverTrackingView {
        let view = HoverTrackingView()
        view.onChange = onChange
        view.cornerRadius = cornerRadius
        view.hoverEnabled = context.environment.isEnabled
        return view
    }
    func updateNSView(_ view: HoverTrackingView, context: Context) {
        view.onChange = onChange
        view.cornerRadius = cornerRadius
        view.hoverEnabled = context.environment.isEnabled
    }
}

final class HoverTrackingView: NSView {
    private static let liveViews = NSHashTable<HoverTrackingView>.weakObjects()
    var onChange: ((Bool) -> Void)?
    var cornerRadius: CGFloat = 7
    var hoverEnabled = true
    private(set) var hovered = false
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self, userInfo: nil))
        // Also handle a row appearing underneath a stationary pointer, including
        // reopening the panel or scrolling a new row into view.
        DispatchQueue.main.async { [weak self] in self?.refreshPointer() }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            Self.liveViews.remove(self)
            setHovered(false)
        } else {
            Self.liveViews.add(self)
        }
    }
    override func mouseEntered(with event: NSEvent) { refreshPointer() }
    override func mouseMoved(with event: NSEvent) { refreshPointer() }
    override func mouseExited(with event: NSEvent) { setHovered(false) }
    func refreshPointer() {
        guard let window, window.isVisible else {
            setHovered(false)
            return
        }
        updatePointer(windowPoint: window.convertPoint(fromScreen: NSEvent.mouseLocation))
    }
    private func updatePointer(windowPoint: NSPoint) {
        guard hoverEnabled && !isHiddenOrHasHiddenAncestor else {
            setHovered(false)
            return
        }
        let location = convert(windowPoint, from: nil)
        let outline = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        setHovered(visibleRect.contains(location) && outline.contains(location))
    }
    /// Native entered/exited events remain the fast path. Sampling repairs an
    /// omitted event after scrolling, reparenting, or a compositor/Space change.
    static func reconcile(in window: NSWindow, screenPoint: NSPoint) -> Int {
        let point = window.convertPoint(fromScreen: screenPoint)
        var corrected = 0
        for view in liveViews.allObjects where view.window === window {
            let before = view.hovered
            view.updatePointer(windowPoint: point)
            if before != view.hovered { corrected += 1 }
        }
        return corrected
    }
    private func setHovered(_ value: Bool) {
        guard hovered != value else { return }
        hovered = value
        onChange?(value)
    }
}
