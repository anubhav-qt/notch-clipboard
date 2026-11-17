@main struct HoverDismissalTests {
    static func main() {
        var notch = HoverDismissal(openedAtNotch: true)
        assert(!notch.shouldClose(pointerInside: true))
        assert(notch.shouldClose(pointerInside: false))
        print("PASS: a panel opened at the notch closes as soon as the pointer leaves")

        var menu = HoverDismissal(openedAtNotch: false)
        for _ in 0..<500 {
            assert(!menu.shouldClose(pointerInside: false))
        }
        assert(!menu.pointerHasVisited)
        assert(!menu.shouldClose(pointerInside: true))
        assert(menu.pointerHasVisited)
        assert(!menu.shouldClose(pointerInside: true))
        assert(menu.shouldClose(pointerInside: false))
        print("PASS: a panel opened from the menu stays open until the pointer has visited and left")

        var dialog = HoverDismissal(openedAtNotch: true)
        assert(!dialog.shouldClose(pointerInside: true))
        assert(!dialog.shouldClose(pointerInside: false, dialogShowing: true))
        assert(!dialog.shouldClose(pointerInside: true, dialogShowing: true))
        assert(!dialog.shouldClose(pointerInside: false))
        assert(!dialog.pointerHasVisited)
        assert(!dialog.shouldClose(pointerInside: true))
        assert(dialog.shouldClose(pointerInside: false))
        print("PASS: after a dialog closes with the pointer outside, the panel waits for another visit")
    }
}
