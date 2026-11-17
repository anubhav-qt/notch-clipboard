import AppKit
import SwiftUI

/// Sorts by the first word, so the category tabs have something to filter.
final class WordCategorizer: ClipCategorizer {
    var isAvailable = true
    var canSeeImages = false
    func category(for prompt: String, instructions: String, names: [String]) async throws -> String {
        if prompt.contains("alpha") {
            return "Work"
        }
        if prompt.contains("beta") {
            return "Personal"
        }
        return "Creative"
    }
    func describeImage(_ image: CGImage, instructions: String, names: [String]) async throws -> ImageAnswer {
        ImageAnswer(title: "Test picture", categoryName: "Creative")
    }
}

/// A test copy of the panel on a private clipboard, driven with native mouse and keyboard events.
@MainActor final class Harness {
    let app = NSApplication.shared
    let output: URL
    let board = NSPasteboard.withUniqueName()
    let store: ClipboardStore
    let defaults: UserDefaults
    let model: ClipboardModel
    let panel: NotchPanel
    let host: HostingView
    let screenTop = NSScreen.screens.first!.frame.maxY
    var selections = 0
    var quits = 0

    init(output: URL, directory: URL, defaultsSuite: String) {
        self.output = output
        store = ClipboardStore(board: board, file: directory.appendingPathComponent("saved.plist"))
        for text in ["alpha", "beta 👋🏽", "gamma <tag> \"q\" 100%"] {
            board.clearContents()
            board.setString(text, forType: .string)
            assert(store.poll())
        }
        defaults = UserDefaults(suiteName: defaultsSuite)!
        model = ClipboardModel(store: store, categorizer: WordCategorizer(), defaults: defaults)
        panel = NotchPanel(contentRect: NSRect(x: 300, y: 300, width: 560, height: 440),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        host = HostingView(rootView: HistoryView(model: model))
        host.rootView = HistoryView(model: model) { [weak self] in self?.quits += 1 }
        panel.contentView = host
        panel.makeKeyAndOrderFront(nil)
        model.selected = { [weak self] in self?.selections += 1 }
        // Same as the app delegate: the confirmation takes keyboard focus away from search.
        model.removalRequested = { [weak self] in
            self?.panel.makeKey()
            self?.panel.makeFirstResponder(nil)
        }
    }

    func pump(_ seconds: TimeInterval = 0.12) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            if let event = app.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) {
                app.sendEvent(event)
            }
            app.updateWindows()
        }
        host.layoutSubtreeIfNeeded()
    }

    /// x from the panel's left edge, y from the panel's top edge.
    func screenPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: panel.frame.minX + x, y: screenTop - panel.frame.maxY + y)
    }

    func click(_ x: CGFloat, _ y: CGFloat, count: Int = 1, settle: TimeInterval = 0.12) {
        let point = screenPoint(x, y)
        CGWarpMouseCursorPosition(point)
        // A real pointer moves before it clicks; some views only update what is under it on a move.
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        pump(0.02)
        for clickNumber in 1...count {
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
                event?.setIntegerValueField(.mouseEventClickState, value: Int64(clickNumber))
                event?.post(tap: .cghidEventTap)
            }
        }
        pump(settle)
    }

    func tap(_ point: CGPoint, count: Int = 1, settle: TimeInterval = 0.12) {
        click(point.x, point.y, count: count, settle: settle)
    }

    /// Press, move in small steps, release. Panel coordinates.
    func drag(from start: CGPoint, to end: CGPoint, steps: Int = 12) {
        let from = screenPoint(start.x, start.y)
        let to = screenPoint(end.x, end.y)
        CGWarpMouseCursorPosition(from)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: from, mouseButton: .left)?.post(tap: .cghidEventTap)
        pump(0.05)
        for step in 1...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
            CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            pump(0.03)
        }
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: to, mouseButton: .left)?.post(tap: .cghidEventTap)
        pump()
    }

    func type(_ text: String) {
        let units = Array(text.utf16)
        var index = 0
        while index < units.count {
            let chunk = Array(units[index..<min(index + 16, units.count)])
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: keyDown)
                event?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event?.post(tap: .cghidEventTap)
            }
            index += 16
            pump(0.01)
        }
        pump()
    }

    func press(_ key: CGKeyCode, flags: CGEventFlags = [], times: Int = 1) {
        for _ in 0..<times {
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: keyDown)
                event?.flags = flags
                event?.post(tap: .cghidEventTap)
            }
            pump(0.01)
        }
        pump()
    }

    func snapshot(_ name: String) throws {
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name).png"))
    }

    /// The panel as the screen shows it. Offscreen drawing paints some symbols, like the palette,
    /// plain white under the panel's rounded clip, so colour checks on icons read the real screen.
    func screenImage() throws -> NSBitmapImageRep {
        pump(0.2)
        let file = output.appendingPathComponent("screen.png")
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(panel.windowNumber), file.path]
        try capture.run()
        capture.waitUntilExit()
        return NSBitmapImageRep(data: try Data(contentsOf: file))!
    }

    /// Every hoverable control, as panel-relative rectangles with y measured from the top.
    /// SwiftUI builds no accessibility tree without a screen reader, so the hover views mark the controls.
    func controls() -> [CGRect] {
        var rects: [CGRect] = []
        for view in Self.allSubviews(of: host) {
            guard let hover = view as? HoverTrackingView, !hover.isHiddenOrHasHiddenAncestor else { continue }
            // Skip controls scrolled partly out of view; a click there would land on something else.
            if hover.visibleRect.height < hover.bounds.height - 0.5 {
                continue
            }
            rects.append(panelRect(of: hover))
        }
        return rects
    }

    func panelRect(of view: NSView) -> CGRect {
        let rect = view.convert(view.bounds, to: nil)
        return CGRect(x: rect.minX, y: panel.frame.height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The controls on one horizontal line, left to right.
    func line(at y: CGFloat, maxWidth: CGFloat = 200) -> [CGRect] {
        let matches = controls().filter { abs($0.midY - y) < 4 && $0.width < maxWidth }
        return matches.sorted { $0.minX < $1.minX }
    }

    func topLine() -> [CGPoint] {
        line(at: controls().map(\.midY).min()!).map(\.centre)
    }

    func bottomLine() -> [CGPoint] {
        line(at: controls().map(\.midY).max()!).map(\.centre)
    }

    func rowCentres() -> [CGPoint] {
        let rows = controls().filter { $0.width > 400 }
        return rows.sorted { $0.minY < $1.minY }.map(\.centre)
    }

    /// Editable text fields, top to bottom.
    func textFields() -> [(field: NSTextField, rect: CGRect)] {
        let fields = Self.allSubviews(of: host).compactMap { $0 as? NSTextField }.filter { $0.isEditable }
        return fields.map { ($0, panelRect(of: $0)) }.sorted { $0.1.minY < $1.1.minY }
    }

    func settleSorting() {
        for _ in 0..<40 where model.sortingTask != nil {
            pump(0.05)
        }
        assert(model.sortingTask == nil, "Sorting did not finish")
    }

    static func allSubviews(of view: NSView) -> [NSView] {
        var result = [view]
        for child in view.subviews {
            result += allSubviews(of: child)
        }
        return result
    }
}

extension CGRect {
    var centre: CGPoint { CGPoint(x: midX, y: midY) }
}

@MainActor @main struct UIInputTests {
    @MainActor static func main() throws {
        setvbuf(stdout, nil, _IONBF, 0)
        NSApplication.shared.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let directory = output.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = UUID().uuidString
        let h = Harness(output: output, directory: directory, defaultsSuite: suite)
        let originalMouse = NSEvent.mouseLocation
        defer {
            h.panel.orderOut(nil)
            h.defaults.removePersistentDomain(forName: suite)
            h.board.releaseGlobally()
            CGWarpMouseCursorPosition(CGPoint(x: originalMouse.x, y: h.screenTop - originalMouse.y))
        }
        h.pump(0.3)
        h.settleSorting()
        h.pump()
        try h.snapshot("start")

        let titleRow = h.topLine()
        assert(titleRow.count == 8, "Title row holds 4 filters, palette, select, trash and settings: \(titleRow.count)")
        for index in 4..<7 {
            assert(titleRow[index + 1].x > titleRow[index].x)
        }
        try searchTests(h)
        try filterTests(h, titleRow: titleRow)
        try rowTests(h, titleRow: titleRow)
        try tabTests(h, titleRow: titleRow)
        try moreMenuTests(h)
        try editorTests(h)
        try settingsTests(h, gear: titleRow[7])
        try selectTests(h, selectIcon: titleRow[5])
        try paletteTests(h, titleRow: titleRow)
        try trashTests(h, titleRow: titleRow)
        h.model.shutdown()
    }

    static func searchField(_ h: Harness) -> CGRect {
        h.textFields().first!.rect
    }

    /// The clear button appears right of the field once there is text: 7 points of spacing, then a 14-point icon.
    static func clearSearch(_ h: Harness) {
        let field = searchField(h)
        h.click(field.maxX + 14, field.midY)
    }

    @MainActor static func searchTests(_ h: Harness) throws {
        let search = searchField(h)
        let searchX = search.minX + 20
        let searchY = search.midY
        let tabs = h.line(at: searchY)
        assert(tabs.count == 5, "All, three categories and More beside search: \(tabs.count)")
        assert(tabs[0].minX > search.maxX, "Tabs sit right of search")
        assert(search.width > 200, "Search fills the rest: \(search.width)")
        h.click(searchX, searchY)
        h.type("beta")
        assert(h.model.query == "beta", "query was \(h.model.query)")
        assert(h.model.entries.map(\.title) == ["beta 👋🏽"])
        try h.snapshot("search-beta")
        clearSearch(h)
        assert(h.model.query.isEmpty, "Clear button must empty the search")
        assert(h.model.entries.count == 3)
        h.click(searchX, searchY)
        h.type("👋🏽")
        assert(h.model.entries.map(\.title) == ["beta 👋🏽"], "emoji search: \(h.model.entries.map(\.title))")
        clearSearch(h)
        h.click(searchX, searchY)
        h.type("<tag> \"q\" 100%")
        assert(h.model.entries.count == 1)
        clearSearch(h)
        h.click(searchX, searchY)
        let long = String(repeating: "long text ", count: 200)
        h.type(long)
        assert(h.model.query == long, "long query length \(h.model.query.count)")
        assert(h.model.entries.isEmpty)
        assert(h.line(at: searchY).count == 5, "A long query never pushes the tabs away")
        try h.snapshot("search-long")
        let before = h.board.changeCount
        h.press(36)
        assert(h.board.changeCount == before && h.selections == 0, "Return with no results must do nothing")
        clearSearch(h)
        h.click(searchX, searchY)
        h.type("   ")
        assert(h.model.entries.isEmpty, "Spaces only should match nothing")
        clearSearch(h)
        h.click(searchX, searchY)
        h.type("ALPHA")
        h.press(36)
        assert(h.board.string(forType: .string) == "alpha" && h.selections == 1, "Return copies the first result")
        clearSearch(h)
        print("PASS: search beside the tabs: typing, emoji, odd characters, 2000 characters, spaces, clear button and Return")
    }

    @MainActor static func filterTests(_ h: Harness, titleRow: [CGPoint]) throws {
        let spots = titleRow[0..<4].map { $0 }
        h.tap(spots[3])
        assert(h.model.filter == .saved && h.model.entries.isEmpty, "Saved filter: \(h.model.filter) \(h.model.entries.count)")
        try h.snapshot("saved-empty")
        h.tap(spots[1])
        assert(h.model.filter == .text)
        h.tap(spots[2])
        assert(h.model.filter == .images && h.model.entries.isEmpty)
        for _ in 0..<10 {
            h.tap(spots[1], settle: 0.01)
            h.tap(spots[0], settle: 0.01)
        }
        h.pump()
        assert(h.model.filter == .all, "20 fast taps end on All: \(h.model.filter)")
        h.tap(spots[1], count: 2)
        assert(h.model.filter == .text)
        h.tap(spots[0])
        print("PASS: every filter, 20 fast switches and a double click land on the right filter")
    }

    @MainActor static func rowTests(_ h: Harness, titleRow: [CGPoint]) throws {
        let model = h.model
        let firstRowY = h.rowCentres()[0].y
        let bookmarks = h.controls().filter { $0.width == 28 && $0.height == 32 }.sorted { $0.minY < $1.minY }
        assert(bookmarks.count == 3, "One bookmark per row: \(bookmarks.count)")
        let bookmarkX = bookmarks[0].midX
        let search = searchField(h)
        h.click(bookmarkX, firstRowY)
        assert(model.entries[0].isSaved, "Bookmark click saves")
        assert(!model.isConfirmingSavedRemoval, "Saving never asks")
        try h.snapshot("bookmarked")
        h.click(bookmarkX, firstRowY)
        assert(model.isConfirmingSavedRemoval, "Removing asks first")
        try h.snapshot("confirm-remove")
        h.tap(titleRow[2])
        assert(model.filter == .all, "A click over a filter hits the backdrop, not the filter")
        assert(!model.isConfirmingSavedRemoval, "The backdrop click dismisses the confirmation")
        assert(model.entries[0].isSaved, "Dismissing keeps the item saved")
        h.click(search.minX + 20, search.midY)
        h.click(bookmarkX, firstRowY)
        assert(model.isConfirmingSavedRemoval)
        h.type("x")
        assert(model.query.isEmpty, "Typing does not reach search while the confirmation shows")
        model.cancelSavedRemoval()
        h.pump()
        h.click(bookmarkX, firstRowY, count: 2)
        assert(model.isConfirmingSavedRemoval, "A double click on a saved bookmark shows one confirmation")
        model.cancelSavedRemoval()
        h.pump()
        let order = model.entries.map(\.id)
        let second = model.entries[1]
        let rowPitch = h.rowCentres()[1].y - h.rowCentres()[0].y
        h.click(200, firstRowY + rowPitch)
        assert(h.board.string(forType: .string) == second.title, "Clicking a row copies it")
        assert(model.entries.map(\.id) == order, "With Reorder history off, the copied row keeps its place")
        let afterOne = h.selections
        h.click(200, firstRowY, count: 2)
        assert(h.selections == afterOne + 2, "Each click copies; a double click is harmless")
        assert(model.entries.count == 3)
        print("PASS: bookmark save, confirm on remove, blocked controls during confirm, row copy in place and double clicks")
    }

    @MainActor static func tabTests(_ h: Harness, titleRow: [CGPoint]) throws {
        let model = h.model
        let search = searchField(h)
        func tabs() -> [CGPoint] {
            h.line(at: searchField(h).midY).map(\.centre)
        }
        let spots = tabs()
        let widths = h.line(at: search.midY).map(\.width)
        assert(widths[1] > widths[0] && widths[3] > widths[1], "Each tab is as wide as its text: \(widths)")
        h.tap(spots[1])
        assert(model.categoryID == "work" && model.entries.map(\.title) == ["alpha"], "Work shows only work clips")
        try h.snapshot("tab-work")
        h.tap(spots[1])
        assert(model.categoryID == "work", "Tapping the chosen tab again keeps it")
        h.tap(spots[0])
        assert(model.categoryID == nil && model.entries.count == 3, "All shows everything")
        h.tap(spots[2])
        assert(model.categoryID == "personal" && model.entries.map(\.title) == ["beta 👋🏽"])
        h.tap(titleRow[2])
        assert(model.entries.isEmpty, "Images plus Personal is empty")
        try h.snapshot("tab-empty")
        h.tap(titleRow[0])
        h.click(search.minX + 20, search.midY)
        h.type("gamma")
        assert(model.entries.isEmpty, "Search stays inside the chosen category")
        clearSearch(h)
        for index in 0..<11 {
            h.tap(spots[1 + index % 3], settle: 0.01)
        }
        h.pump()
        assert(model.categoryID == "personal", "11 fast taps end on the last one tapped")
        h.tap(spots[3], count: 2)
        assert(model.categoryID == "creative", "A double click lands on it and stays")
        h.tap(spots[0])
        assert(model.categoryID == nil)
        print("PASS: All and each tab filter, a second tap keeps it, works with filters and search, fast taps and double clicks")
    }

    /// The open dropdown's rows, top to bottom.
    @MainActor static func menuRows(_ h: Harness) -> [CGRect] {
        h.controls().filter { $0.width > 150 && $0.width < 200 && $0.height >= 28 }.sorted { $0.minY < $1.minY }
    }

    @MainActor static func moreMenuTests(_ h: Harness) throws {
        let model = h.model
        let more = h.line(at: searchField(h).midY).last!.centre
        h.tap(more)
        assert(model.openMenu == .more, "More opens its menu")
        try h.snapshot("more-menu")
        var rows = menuRows(h)
        assert(rows.count == 2, "Reference, then Add/Edit categories: \(rows.count)")
        assert(rows[0].minY > more.y, "The menu opens under More")
        h.tap(rows[0].centre)
        assert(model.categoryID == "reference" && model.openMenu == nil, "Picking from More filters and closes the menu")
        assert(model.entries.isEmpty)
        h.tap(more)
        rows = menuRows(h)
        let firstRow = h.rowCentres().first ?? CGPoint(x: 120, y: 300)
        let selectionsBefore = h.selections
        h.click(60, max(firstRow.y, 250))
        assert(model.openMenu == nil, "A click outside closes the menu")
        assert(h.selections == selectionsBefore, "and does not reach the row under it")
        h.tap(more)
        h.tap(more)
        assert(model.openMenu == nil, "More again closes it")
        h.tap(more, count: 2)
        assert(model.openMenu == nil, "A double click opens and closes")
        model.selectCategory(nil)
        h.pump()
        print("PASS: More lists the rest, filters, closes on pick, outside click, second tap and double click")
    }

    /// Editor parts found by their sizes.
    struct EditorParts {
        let handles: [CGRect]
        let removes: [CGRect]
        let names: [(field: NSTextField, rect: CGRect)]
        let add: CGRect?
        let done: CGRect
        let first: CGRect
        let last: CGRect
    }

    @MainActor static func editorParts(_ h: Harness) -> EditorParts {
        let all = h.controls()
        let handles = all.filter { $0.width == 22 && $0.height == 26 }.sorted { $0.minY < $1.minY }
        let removes = all.filter { $0.width == 24 && $0.height == 26 }.sorted { $0.minY < $1.minY }
        let add = all.first { $0.height == 26 && $0.width > 250 }
        let done = all.first { $0.width == 76 && $0.height == 28 }!
        // First and Last are the lowest two squircle segments; the filter toggle sits higher in the title row.
        let segments = all.filter { $0.height == 26 && $0.width > 30 && $0.width < 80 && $0.width != 76 }
        let lowest = segments.sorted { $0.minY > $1.minY }.prefix(2)
        let toggle = lowest.sorted { $0.minX < $1.minX }
        let names = Array(h.textFields().dropFirst())
        return EditorParts(handles: handles, removes: removes, names: names, add: add, done: done, first: toggle[0], last: toggle[1])
    }

    @MainActor static func openEditor(_ h: Harness) {
        let more = h.line(at: searchField(h).midY).last!.centre
        h.tap(more)
        h.tap(menuRows(h).last!.centre)
        h.pump(0.2)
    }

    /// Clicks the end of a name field, deletes everything and types a new name.
    @MainActor static func retype(_ h: Harness, _ rect: CGRect, _ text: String) {
        h.click(rect.maxX - 6, rect.midY)
        h.press(124)
        h.press(51, times: 24)
        if !text.isEmpty {
            h.type(text)
        }
    }

    @MainActor static func editorTests(_ h: Harness) throws {
        let model = h.model
        openEditor(h)
        assert(model.categoryDraft != nil, "Add/Edit categories opens the sheet")
        assert(model.openMenu == nil)
        try h.snapshot("editor")
        var parts = editorParts(h)
        assert(parts.handles.count == 4 && parts.removes.count == 4 && parts.names.count == 4, "One row per category")
        assert(parts.names.map(\.field.stringValue) == ["Work", "Personal", "Creative", "Reference"])
        assert(parts.add != nil, "Add category shows below the rows")
        let bookmarkClicks = h.selections
        h.click(200, 400)
        assert(model.categoryDraft != nil, "A click on the backdrop keeps the sheet")
        assert(h.selections == bookmarkClicks, "and reaches nothing under it")

        retype(h, parts.names[0].rect, "Job")
        assert(model.categoryDraft!.name(id: "work") == "Job", "Typing renames: \(model.categoryDraft!.name(id: "work"))")
        retype(h, parts.names[0].rect, "")
        assert(model.categoryDraft!.problem == CategoryDraft.emptyNameProblem)
        h.pump(0.2)
        try h.snapshot("editor-empty-name")
        parts = editorParts(h)
        h.tap(parts.done.centre)
        assert(model.categoryDraft != nil, "Done waits while a name is empty")
        retype(h, parts.names[0].rect, "personal")
        assert(model.categoryDraft!.problem == CategoryDraft.sameNameProblem, "Same name in another case is caught")
        h.tap(parts.done.centre, count: 2)
        assert(model.categoryDraft != nil)
        retype(h, parts.names[0].rect, String(repeating: "x", count: 30))
        assert(model.categoryDraft!.name(id: "work").count == ClipCategory.maxNameLength, "Typing stops at 20 characters")
        retype(h, parts.names[0].rect, "Job 👋🏽 <b>&")
        assert(model.categoryDraft!.name(id: "work") == "Job 👋🏽 <b>&" && model.categoryDraft!.problem == nil)
        print("PASS: renaming by typing; empty, same and too-long names hold Done; odd characters work; backdrop does nothing")

        h.tap(parts.add!.centre)
        parts = editorParts(h)
        assert(parts.names.count == 5, "Add category adds a row")
        assert(parts.names[4].field.currentEditor() != nil, "The new row has the cursor")
        h.type("Recipes")
        assert(model.categoryDraft!.rows.last!.name == "Recipes")
        for _ in 0..<5 {
            h.tap(editorParts(h).add!.centre, settle: 0.05)
            h.type("n")
        }
        h.pump(0.2)
        try h.snapshot("editor-full")
        parts = editorParts(h)
        assert(model.categoryDraft!.rows.count == ClipCategory.maxCount && parts.add == nil, "At 10 the add row goes away")
        assert(parts.names.last!.field.stringValue == "n", "The list scrolled to the newest row")
        assert(model.categoryDraft!.problem == CategoryDraft.sameNameProblem, "Five rows named n clash")
        // While the list scrolls, the rows slide for about a second after a removal; wait for it.
        for _ in 0..<5 {
            h.tap(editorParts(h).removes.last!.centre, settle: 1.1)
        }
        parts = editorParts(h)
        assert(model.categoryDraft!.rows.count == 5 && parts.add != nil, "Removing brings the add row back: \(model.categoryDraft!.rows.count) \(parts.add != nil)")
        h.tap(parts.removes[4].centre, count: 2, settle: 0.5)
        assert(model.categoryDraft!.rows.count == 4, "A double click on × removes only one row")
        for _ in 0..<3 {
            h.tap(editorParts(h).removes.last!.centre, settle: 0.5)
        }
        assert(model.categoryDraft!.rows.count == 1)
        h.tap(editorParts(h).removes[0].centre, settle: 0.5)
        assert(model.categoryDraft!.rows.count == 1, "The last category can't be removed")
        print("PASS: add focuses and scrolls to the new row, stops at 10, remove stops at 1, a double click on × removes one")

        model.cancelCategoryDraft()
        h.pump()
        assert(model.categoryList == .starter, "Throwing the draft away changes nothing")
        openEditor(h)
        parts = editorParts(h)
        let pitch = parts.handles[1].midY - parts.handles[0].midY
        h.drag(from: parts.handles[0].centre, to: CGPoint(x: parts.handles[0].midX, y: parts.handles[0].midY + pitch * 2))
        assert(model.categoryDraft!.rows.map(\.id) == ["personal", "creative", "work", "reference"], "Dragging down two rows: \(model.categoryDraft!.rows.map(\.id))")
        parts = editorParts(h)
        h.drag(from: parts.handles[3].centre, to: CGPoint(x: parts.handles[3].midX, y: parts.handles[3].midY - pitch * 9))
        assert(model.categoryDraft!.rows.first!.id == "reference", "Dragging past the top stops at the top")
        h.tap(parts.last.centre)
        assert(model.categoryDraft!.allIsLast, "Last puts All after the three tabs")
        h.tap(parts.first.centre)
        h.tap(parts.last.centre, count: 2)
        assert(model.categoryDraft!.allIsLast)
        try h.snapshot("editor-moved")
        h.tap(parts.done.centre)
        assert(model.categoryDraft == nil, "Done saves and closes")
        h.pump(0.2)
        let tabs = h.line(at: searchField(h).midY)
        assert(tabs.count == 5)
        assert(model.categoryList.categories.map(\.id) == ["reference", "personal", "creative", "work"])
        h.tap(tabs[3].centre)
        assert(model.categoryID == nil, "With All last, the fourth tab is All")
        h.tap(tabs[0].centre)
        assert(model.categoryID == "reference")
        try h.snapshot("tabs-all-last")
        h.tap(tabs[3].centre)
        print("PASS: dragging the dots reorders, First/Last moves All, Done saves and the tabs follow")
    }

    @MainActor static func settingsTests(_ h: Harness, gear: CGPoint) throws {
        let model = h.model
        h.tap(gear)
        assert(model.openMenu == .settings, "The gear opens settings")
        try h.snapshot("settings-menu")
        let rows = menuRows(h)
        assert(rows.count == 2, "Reorder history and Quit: \(rows.count)")
        assert(!model.reordersHistory)
        h.tap(rows[0].centre)
        assert(model.reordersHistory && h.defaults.bool(forKey: ClipboardModel.reorderKey), "The switch turns reordering on")
        assert(model.openMenu == .settings, "and the menu stays open")
        try h.snapshot("settings-reorder-on")
        h.tap(rows[0].centre, count: 2)
        assert(model.reordersHistory, "A double click flips twice")
        let order = model.entries.map(\.id)
        h.tap(gear)
        let rowPitch = h.rowCentres()[1].y - h.rowCentres()[0].y
        h.click(200, h.rowCentres()[0].y + rowPitch)
        assert(model.entries[0].id == order[1], "With reordering on, a copied row moves to the top")
        h.tap(gear)
        h.tap(menuRows(h)[0].centre)
        assert(!model.reordersHistory)
        h.tap(menuRows(h)[1].centre)
        assert(h.quits == 1, "Quit Clipboard quits")
        h.tap(gear)
        h.pump()
        if model.openMenu != nil {
            h.tap(gear)
        }
        assert(model.openMenu == nil)
        print("PASS: settings opens under the gear, Reorder history switches and is used, Quit quits")
    }

    @MainActor static func selectTests(_ h: Harness, selectIcon: CGPoint) throws {
        let model = h.model
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 30, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        h.board.clearContents()
        h.board.setData(bitmap.representation(using: .png, properties: [:])!, forType: .png)
        model.poll()
        h.settleSorting()
        h.pump()
        let titles = model.entries.map(\.title)
        let order = model.entries.map(\.id)
        h.tap(selectIcon)
        assert(model.isSelecting, "The select icon starts Select mode")
        h.pump(0.2)
        assert(h.controls().filter { $0.width == 28 && $0.height == 32 }.isEmpty, "Boxes replace the bookmarks")
        let rows = h.rowCentres()
        assert(rows.count == 4)
        let footer = h.bottomLine()
        assert(footer.count == 2 && footer[0].y > rows.last!.y, "Cancel and Done sit at the foot")
        let done = footer[1]
        let cancel = footer[0]
        let before = h.selections
        let clipboard = h.board.changeCount
        h.tap(done)
        assert(model.isSelecting && h.selections == before && h.board.changeCount == clipboard, "Done with nothing picked does nothing")
        h.tap(rows[3])
        h.tap(rows[1])
        assert(model.selection!.ids == [order[3], order[1]], "Taps pick in order")
        assert(h.selections == before, "Picking copies nothing yet")
        h.tap(rows[0])
        assert(model.selectionNote == ClipSelection.imagesBlocked, "The image row is refused with a note")
        try h.snapshot("select-two")
        h.tap(rows[2], count: 2)
        assert(model.selection!.ids == [order[3], order[1]], "A double click picks and unpicks")
        h.tap(rows[1])
        h.tap(rows[1])
        assert(model.selection!.ids == [order[3], order[1]], "Unpick then pick again goes last")
        h.tap(done)
        assert(!model.isSelecting && h.selections == before + 1, "Done copies and leaves Select mode")
        assert(h.board.string(forType: .string) == "\(titles[3]) \(titles[1])")
        assert(model.entries.map(\.id) == order, "History is unchanged")
        h.tap(selectIcon)
        h.tap(rows[0])
        assert(model.selection!.group == .image)
        h.tap(rows[1])
        assert(model.selectionNote == ClipSelection.textBlocked)
        h.tap(cancel)
        assert(!model.isSelecting && model.selectionNote == nil, "Cancel leaves Select mode")
        h.tap(selectIcon, count: 2)
        assert(!model.isSelecting, "A double click on the icon starts and ends it")
        h.tap(selectIcon)
        for _ in 0..<9 {
            h.tap(rows[2], settle: 0.01)
        }
        h.pump()
        assert(model.selection!.ids == [order[2]], "Nine fast taps leave it picked")
        h.tap(selectIcon)
        assert(!model.isSelecting, "The icon again cancels")
        print("PASS: Select mode picks in order, refuses mixing with a note, Done joins with one space, Cancel and fast taps")
    }

    @MainActor static func paletteTests(_ h: Harness, titleRow: [CGPoint]) throws {
        let model = h.model
        let palette = titleRow[4]
        h.tap(palette)
        assert(model.isPickingAccent, "The palette icon opens the picker")
        h.pump(0.2)
        try h.snapshot("accent-picker")
        let swatches = h.controls().filter { $0.width == 20 && $0.height == 20 }.sorted { $0.minX < $1.minX }
        assert(swatches.count == AccentColor.presets.count, "One swatch per preset: \(swatches.count)")
        h.click(10, 200)
        let rest = try h.screenImage()
        assert(Self.isGrey(rest, around: titleRow[5], in: h), "A closed icon is plain grey, not multicolour")
        let reset = h.line(at: swatches[0].midY).last!.centre
        let hueStart = swatches.last!.maxX + 8
        let hueEnd = reset.x - 14 - 8
        for (index, preset) in AccentColor.presets.enumerated() {
            h.tap(swatches[index].centre)
            assert(model.accent == preset.color, "\(preset.name) swatch picks \(preset.name)")
        }
        assert(h.defaults.string(forKey: ClipboardModel.accentKey) == AccentColor.presets.last!.color.hex, "The pick is stored")
        func hue(of accent: AccentColor) -> Double {
            Double(NSColor(red: accent.red, green: accent.green, blue: accent.blue, alpha: 1).hueComponent)
        }
        h.click((hueStart + hueEnd) / 2, swatches[0].midY)
        assert(abs(hue(of: model.accent) - 0.5) < 0.03, "Middle of the hue bar is cyan: \(hue(of: model.accent))")
        h.click(hueStart + 1, swatches[0].midY)
        let start = hue(of: model.accent)
        assert(start < 0.03 || start > 0.97, "Left end is red: \(start)")
        h.drag(from: CGPoint(x: hueStart + 2, y: swatches[0].midY), to: CGPoint(x: hueEnd + 60, y: swatches[0].midY), steps: 10)
        let end = hue(of: model.accent)
        assert(end > 0.97 || end < 0.03, "Dragging past the right end stops at the last hue: \(end)")
        h.tap(swatches[3].centre)
        h.pump(0.2)
        let lime = AccentColor.presets[3].color
        let rep = try h.screenImage()
        let scale = CGFloat(rep.pixelsWide) / h.host.bounds.width
        func tinted(_ point: CGPoint) -> Bool {
            for dx in stride(from: CGFloat(-6), through: 6, by: 1) {
                for dy in stride(from: CGFloat(-6), through: 6, by: 1) {
                    let pixel = rep.colorAt(x: Int((point.x + dx) * scale), y: Int((point.y + dy) * scale))!.usingColorSpace(.sRGB)!
                    // Colour spaces shift the channels a little, so compare hue and strength instead.
                    if abs(Double(pixel.hueComponent) - hue(of: lime)) < 0.04 && pixel.saturationComponent > 0.3 {
                        return true
                    }
                }
            }
            return false
        }
        let segment = h.controls().first { abs($0.midX - titleRow[0].x) < 2 && abs($0.midY - titleRow[0].y) < 2 }!
        assert(tinted(CGPoint(x: segment.minX + 3, y: segment.midY)), "The selected filter outline takes the chosen accent")
        assert(!tinted(h.topLine()[6]), "The closed trash icon stays grey")
        assert(tinted(palette), "The open palette icon is accent coloured")
        try h.snapshot("accent-lime")
        h.tap(reset)
        assert(model.accent == .purple && h.defaults.string(forKey: ClipboardModel.accentKey) == AccentColor.purple.hex, "Reset returns to purple")
        h.tap(reset, count: 2)
        assert(model.accent == .purple, "Resetting twice is harmless")
        h.tap(palette)
        assert(!model.isPickingAccent, "The palette icon closes the picker")
        let closed = try h.screenImage()
        assert(Self.isGrey(closed, around: palette, in: h), "The closed palette is plain grey, not multicolour")
        h.tap(palette, count: 2)
        assert(!model.isPickingAccent, "A double click opens and closes it")
        print("PASS: palette opens and closes, every swatch, hue bar click and drag past the end, tint applied, reset and double clicks")
    }

    /// True when no strongly coloured pixel sits near the point.
    @MainActor static func isGrey(_ rep: NSBitmapImageRep, around point: CGPoint, in h: Harness) -> Bool {
        let scale = CGFloat(rep.pixelsWide) / h.host.bounds.width
        for dx in stride(from: CGFloat(-7), through: 7, by: 1) {
            for dy in stride(from: CGFloat(-7), through: 7, by: 1) {
                let pixel = rep.colorAt(x: Int((point.x + dx) * scale), y: Int((point.y + dy) * scale))!.usingColorSpace(.sRGB)!
                if pixel.saturationComponent > 0.25 && pixel.brightnessComponent > 0.2 {
                    return false
                }
            }
        }
        return true
    }

    @MainActor static func trashTests(_ h: Harness, titleRow: [CGPoint]) throws {
        let model = h.model
        let trash = titleRow[6]
        func clickSheetButton(_ title: String) {
            let sheet = h.panel.attachedSheet!
            let button = Harness.allSubviews(of: sheet.contentView!).compactMap { $0 as? NSButton }.first { $0.title == title }!
            let rect = sheet.convertToScreen(button.convert(button.bounds, to: nil))
            let point = CGPoint(x: rect.midX, y: h.screenTop - rect.midY)
            CGWarpMouseCursorPosition(point)
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            h.pump(0.4)
        }
        let count = model.entries.count
        let clipboardBefore = h.board.string(forType: .string)
        h.tap(trash)
        h.pump(0.3)
        assert(h.panel.attachedSheet != nil, "Clear History asks first, as a sheet on the panel")
        h.press(53)
        h.pump(0.4)
        assert(h.panel.attachedSheet == nil && model.entries.count == count, "Escape cancels and keeps history")
        h.tap(trash, count: 2)
        h.pump(0.3)
        assert(h.panel.attachedSheet != nil)
        h.press(36)
        h.pump(0.4)
        assert(h.panel.attachedSheet != nil && model.entries.count == count, "Return never clears: the sheet has no default button")
        h.press(53)
        h.pump(0.4)
        assert(h.panel.attachedSheet == nil)
        h.tap(trash)
        h.pump(0.3)
        clickSheetButton("Cancel")
        assert(model.entries.count == count)
        h.tap(trash)
        h.pump(0.3)
        clickSheetButton("Clear History")
        assert(model.entries.isEmpty, "Clear History empties the session list")
        assert(h.board.string(forType: .string) == clipboardBefore, "Clearing keeps the system clipboard")
        assert(h.store.savedEntries.count == 1, "Clearing keeps saved items")
        try h.snapshot("cleared")
        h.tap(titleRow[3])
        assert(model.entries.count == 1)
        print("PASS: trash asks first; Escape, Return, double click and Cancel keep history; Clear History keeps saved items and clipboard")
    }
}

