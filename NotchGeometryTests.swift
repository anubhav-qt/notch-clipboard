import AppKit

@main struct NotchGeometryTests {
    static func main() {
        for scale: CGFloat in [1, 2] {
            for origin in [NSPoint.zero, NSPoint(x: -1600, y: 120), NSPoint(x: 1600, y: -900)] {
                let frame = NSRect(origin: origin, size: NSSize(width: 1512, height: 982))
                let left = NSRect(x: origin.x, y: frame.maxY - 32, width: 666, height: 32)
                let right = NSRect(x: origin.x + 846, y: frame.maxY - 32, width: 666, height: 32)
                let notch = NotchGeometry(screenFrame: frame, safeAreaTop: 32, leftArea: left, rightArea: right)!
                let pixel = 1 / scale
                assert(notch.rect.width == 180 && notch.rect.height == 32)
                assert(!notch.contains(NSPoint(x: left.maxX - pixel, y: frame.maxY - pixel)))
                assert(notch.contains(NSPoint(x: left.maxX, y: frame.maxY - pixel)))
                assert(notch.contains(NSPoint(x: right.minX - pixel, y: frame.maxY - pixel)))
                assert(!notch.contains(NSPoint(x: right.minX, y: frame.maxY - pixel)))
                assert(!notch.contains(NSPoint(x: right.minX + pixel, y: frame.maxY - pixel)))
                assert(notch.contains(NSPoint(x: notch.rect.midX, y: frame.maxY)))
                assert(notch.contains(NSPoint(x: notch.rect.midX, y: notch.rect.minY)))
                assert(!notch.contains(NSPoint(x: notch.rect.midX, y: notch.rect.minY - pixel)))
                let margin = NotchGeometry.nearMargin
                assert(notch.isNear(NSPoint(x: notch.rect.midX, y: frame.maxY)), "On the notch is near")
                assert(notch.isNear(NSPoint(x: notch.rect.minX - margin + pixel, y: frame.maxY)), "Beside it, on the top edge, is near")
                assert(notch.isNear(NSPoint(x: notch.rect.midX, y: notch.rect.minY - margin + pixel)), "Just below the band is near")
                assert(!notch.isNear(NSPoint(x: notch.rect.minX - margin - pixel, y: frame.maxY)), "Far left is not near")
                assert(!notch.isNear(NSPoint(x: notch.rect.maxX + margin + pixel, y: frame.maxY)), "Far right is not near")
                assert(!notch.isNear(NSPoint(x: notch.rect.midX, y: notch.rect.minY - margin - pixel)), "Lower down is not near")
                assert(!notch.isNear(frame.origin), "The far corner is not near")
            }
        }
        assert(NotchGeometry(screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0, leftArea: nil, rightArea: nil) == nil)
        print("PASS: exact notch edges at 1×/2×, shifted displays, inclusive top edge and no fabricated trigger on notchless displays")
        print("PASS: the area near the notch ends a fixed margin out on each side and below")
    }
}
