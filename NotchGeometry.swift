import AppKit

struct NotchGeometry {
    let rect: NSRect
    init?(screenFrame: NSRect, safeAreaTop: CGFloat, leftArea: NSRect?, rightArea: NSRect?) {
        guard safeAreaTop > 0, let leftArea, let rightArea,
              leftArea.width > 0, rightArea.width > 0, rightArea.minX > leftArea.maxX else { return nil }
        rect = NSRect(x: leftArea.maxX, y: screenFrame.maxY - safeAreaTop,
                      width: rightArea.minX - leftArea.maxX, height: safeAreaTop)
    }
    init?(screen: NSScreen) {
        self.init(screenFrame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
                  leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
    }
    func contains(_ point: NSPoint) -> Bool {
        // The cursor can sit exactly on the display's top edge (maxY).
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
    /// The area around the notch where the pointer may be heading for it.
    func isNear(_ point: NSPoint) -> Bool {
        let around = rect.insetBy(dx: -Self.nearMargin, dy: -Self.nearMargin)
        return around.contains(point)
    }
    static let nearMargin: CGFloat = 160
}
