import AppKit
import QuartzCore

/// Hosts the panel content and grows it out of the notch with a shape mask.
final class NotchRevealView: NSView {
    private let revealMask = CAShapeLayer()

    init(hostedView: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.isGeometryFlipped = false
        layer?.mask = revealMask
        addSubview(hostedView)
        hostedView.frame = bounds
        hostedView.autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func reveal(open: Bool, notchWidth: CGFloat, notchHeight: CGFloat, duration: TimeInterval) {
        revealMask.frame = bounds
        let height = max(1, notchHeight)
        let notch = CGRect(x: bounds.midX - notchWidth / 2, y: bounds.maxY - height, width: notchWidth, height: height)
        let small = CGPath(roundedRect: notch, cornerWidth: 9, cornerHeight: 9, transform: nil)
        let large = CGPath(roundedRect: bounds, cornerWidth: 15, cornerHeight: 15, transform: nil)
        // Start from the shape on screen right now, so a reversed animation never jumps.
        let start = revealMask.presentation()?.path ?? revealMask.path ?? small
        let end = open ? large : small

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        revealMask.path = end
        CATransaction.commit()

        if duration == 0 {
            revealMask.removeAnimation(forKey: "notchReveal")
            return
        }
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = start
        animation.toValue = end
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0.72, 0, 1)
        revealMask.add(animation, forKey: "notchReveal")
    }
}
