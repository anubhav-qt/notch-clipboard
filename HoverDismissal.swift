/// Decides when the pointer leaving the panel should close it.
/// Opened at the notch: the pointer starts inside, so leaving closes it.
/// Opened from the menu: the pointer starts far away, so wait until it has visited once.
/// After a dialog: the pointer may have wandered off, so wait for another visit.
struct HoverDismissal {
    private(set) var pointerHasVisited: Bool

    init(openedAtNotch: Bool) {
        pointerHasVisited = openedAtNotch
    }

    mutating func shouldClose(pointerInside: Bool, dialogShowing: Bool = false) -> Bool {
        if dialogShowing {
            pointerHasVisited = false
            return false
        }
        if pointerInside {
            pointerHasVisited = true
            return false
        }
        return pointerHasVisited
    }
}
