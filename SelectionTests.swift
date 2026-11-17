import AppKit

@main struct SelectionTests {
    @MainActor static func main() async throws {
        var picks = ClipSelection()
        assert(!picks.isDimmed(kind: "Text") && !picks.isDimmed(kind: "Image"), "Nothing dims before the first pick")
        assert(picks.isDimmed(kind: "Files") && picks.isDimmed(kind: "PDF"))
        assert(picks.toggle(id: "a", kind: "Text") == .picked)
        assert(picks.toggle(id: "b", kind: "Link") == .picked, "Links count as text")
        assert(picks.toggle(id: "c", kind: "Image") == .blocked(ClipSelection.imagesBlocked))
        assert(picks.toggle(id: "d", kind: "Files") == .blocked(ClipSelection.otherBlocked))
        assert(picks.isDimmed(kind: "Image") && !picks.isDimmed(kind: "Text"))
        assert(picks.number(of: "a") == 1 && picks.number(of: "b") == 2 && picks.number(of: "c") == nil)
        assert(picks.toggle(id: "a", kind: "Text") == .unpicked)
        assert(picks.number(of: "b") == 1, "Numbers close up after an unpick")
        assert(picks.toggle(id: "b", kind: "Text") == .unpicked)
        assert(picks.group == nil && picks.ids.isEmpty)
        assert(picks.toggle(id: "c", kind: "Image") == .picked, "Empty again, so images may start")
        assert(picks.toggle(id: "a", kind: "Text") == .blocked(ClipSelection.textBlocked))
        picks.keep(only: [])
        assert(picks.ids.isEmpty && picks.group == nil)
        print("PASS: text and images never mix, numbers follow pick order, and unpicking closes up")

        assert(ClipSelection.join(["a", "b"]) == "a b")
        assert(ClipSelection.join(["  a\n", "\tb  "]) == "a b", "Each piece is trimmed")
        assert(ClipSelection.join(["a", "   ", "", "b"]) == "a b", "Blank pieces are skipped")
        assert(ClipSelection.join(["line one\nline two", "👋🏽"]) == "line one\nline two 👋🏽", "Inner newlines stay")
        assert(ClipSelection.join([]) == "")
        print("PASS: joined text has exactly one space between pieces")

        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClipboardStore(board: board, file: directory.appendingPathComponent("saved.plist"))
        let model = ClipboardModel(store: store, categorizer: nil, defaults: defaults)
        var selections = 0
        model.selected = { selections += 1 }
        func copy(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
            model.poll()
        }
        func png(_ red: CGFloat) -> Data {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.setColor(NSColor(deviceRed: red, green: 0, blue: 0, alpha: 1), atX: 0, y: 0)
            return bitmap.representation(using: .png, properties: [:])!
        }
        func copyImage(_ red: CGFloat) {
            board.clearContents()
            board.setData(png(red), forType: .png)
            model.poll()
        }
        func clip(_ title: String) -> Clip {
            model.entries.first { $0.title == title }!
        }
        copy("first\n")
        copy("second")
        copy("third")
        let order = model.entries.map(\.id)

        model.toggleSelectMode()
        assert(model.isSelecting && model.holdsPanelOpen)
        model.choose(clip("first\n".replacingOccurrences(of: "\n", with: "  ")))
        assert(selections == 0, "Choosing is off in Select mode")
        model.pick(clip("third"))
        model.pick(clip("first  "))
        let before = board.changeCount
        model.finishSelection()
        assert(board.changeCount != before)
        assert(board.pasteboardItems?.count == 1)
        assert(board.string(forType: .string) == "third first", "Pick order, one space, trimmed")
        assert(!model.isSelecting && selections == 1, "Done leaves Select mode and returns to the app")
        assert(model.entries.map(\.id) == order && model.entries.count == 3, "No new clip and no reordering")
        model.poll()
        assert(model.entries.count == 3, "The joined text is never captured as a clip")
        print("PASS: Done joins text in pick order, adds no clip and leaves history alone")

        model.reordersHistory = true
        assert(defaults.bool(forKey: ClipboardModel.reorderKey))
        model.toggleSelectMode()
        model.pick(clip("second"))
        model.pick(clip("third"))
        model.finishSelection()
        assert(model.entries.map(\.title) == ["second", "third", "first  "], "Reordering puts the picks on top, first pick first")
        assert(model.entries.count == 3)
        model.reordersHistory = false
        print("PASS: with Reorder history on, picked clips move to the top in pick order")

        copyImage(0.2)
        copyImage(0.8)
        let images = model.entries.filter { $0.kind == "Image" }
        model.toggleSelectMode()
        model.pick(images[1])
        model.pick(clip("third"))
        assert(model.selectionNote == ClipSelection.textBlocked)
        model.pick(images[0])
        assert(model.selectionNote == nil, "A good pick clears the note")
        model.pick(clip("third"))
        try await Task.sleep(for: .seconds(model.noteDuration + 0.3))
        assert(model.selectionNote == nil, "The note goes away by itself")
        model.finishSelection()
        let items = board.pasteboardItems ?? []
        assert(items.count == 2, "Two images become two pasteboard items")
        assert(items[0].data(forType: .png) == store.entry(id: images[1].id)!.imageData, "in pick order")
        assert(items[1].data(forType: .png) == store.entry(id: images[0].id)!.imageData)
        print("PASS: images go on the clipboard together as separate items, and the note is quiet")

        model.toggleSelectMode()
        model.finishSelection()
        assert(model.isSelecting, "Done with nothing picked does nothing")
        model.pick(clip("second"))
        model.clear()
        assert(model.selection?.ids.isEmpty == true, "Clearing history drops picks of cleared clips")
        model.toggleSelectMode()
        assert(!model.isSelecting, "The select icon again cancels")
        copy("again")
        model.toggleSelectMode()
        model.pick(clip("again"))
        model.cancelSelection()
        assert(!model.isSelecting && model.selectionNote == nil)
        model.toggleSelectMode()
        model.panelClosed()
        assert(model.isSelecting, "Closing the panel keeps Select mode")
        model.cancelSelection()
        print("PASS: empty Done, Clear History, Cancel and the select icon all behave")

        model.shutdown()
        let relaunched = ClipboardModel(store: ClipboardStore(board: board, file: directory.appendingPathComponent("b.plist")), categorizer: nil, defaults: defaults)
        assert(!relaunched.reordersHistory)
        relaunched.reordersHistory = true
        let again = ClipboardModel(store: ClipboardStore(board: board, file: directory.appendingPathComponent("c.plist")), categorizer: nil, defaults: defaults)
        assert(again.reordersHistory && again.store?.reordersHistory == true, "Reorder history survives a relaunch")
        print("PASS: Reorder history is off by default and remembered")

        assert(TabButton.textWidth(for: "All") < 30)
        assert(TabButton.textWidth(for: String(repeating: "W", count: 20)) == TabButton.maxTextWidth, "Long names are capped")
        assert(TabButton.textWidth(for: "") <= 1)
        print("PASS: tabs are as wide as their text, up to a cap")
    }
}
