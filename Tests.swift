import AppKit

@main struct ClipboardTests {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("saved.plist")
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let store = ClipboardStore(board: board, file: file)
        func copy(_ value: String) { board.clearContents(); board.setString(value, forType: .string) }
        assert(!store.reordersHistory, "Reorder history is off by default")
        copy("first"); assert(store.poll())
        let firstID = store.entries[0].id
        let firstCreated = store.entries[0].created
        copy("second"); assert(store.poll())
        copy("first"); assert(store.poll())
        assert(store.entries.count == 2 && store.entries[1].id == firstID, "A repeat Cmd+C keeps its place")
        assert(store.entries[1].created == firstCreated, "and its age")
        assert(store.entries[1].matches("FIRST"))
        assert(store.choose(id: firstID))
        assert(board.string(forType: .string) == "first")
        assert(store.entries.map(\.label) == ["second", "first"], "Choosing from the panel keeps the place too")
        assert(!store.poll())
        store.reordersHistory = true
        copy("first"); assert(store.poll())
        assert(store.entries.map(\.label) == ["first", "second"], "With reordering on, a repeat moves to the top")
        assert(store.choose(id: store.entries[1].id))
        assert(board.string(forType: .string) == "second")
        assert(store.entries[0].label == "second")
        assert(!store.poll())
        store.reordersHistory = false
        print("PASS: capture, deduplication, reorder on and off, search and clipboard restoration")

        let files = ["file:///tmp/one.txt", "file:///tmp/two.txt"].map { value -> NSPasteboardItem in
            let item = NSPasteboardItem()
            item.setString(value, forType: .fileURL)
            return item
        }
        board.clearContents(); assert(board.writeObjects(files)); assert(store.poll())
        let filesID = store.entries[0].id
        copy("third"); assert(store.poll())
        assert(store.choose(id: filesID))
        assert(board.pasteboardItems?.count == 2)
        assert(board.pasteboardItems?[1].string(forType: .fileURL) == "file:///tmp/two.txt")
        print("PASS: multi-file clipboard restoration")

        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.setColor(NSColor(deviceRed: 0.5, green: 0, blue: 0.5, alpha: 1), atX: 0, y: 0)
        let png = bitmap.representation(using: .png, properties: [:])!
        board.clearContents(); board.setData(png, forType: .png); assert(store.poll())
        let imageID = store.entries[0].id
        let link = NSPasteboardItem()
        link.setString("https://example.com", forType: .URL)
        link.setString("https://example.com", forType: .string)
        board.clearContents(); board.writeObjects([link]); assert(store.poll())
        let linkID = store.entries[0].id
        assert(store.filteredEntries(.all).count == store.entries.count)
        assert(store.filteredEntries(.text).count == 4)
        assert(store.filteredEntries(.text).contains { $0.id == linkID })
        assert(store.filteredEntries(.text).allSatisfy { $0.kind == "Text" || $0.kind == "Link" })
        assert(store.filteredEntries(.images).map(\.id) == [imageID])
        assert(store.filteredEntries(.saved).isEmpty)
        assert(store.filteredEntries(.images, query: "SCREENSHOT").count == 1)
        assert(store.filteredEntries(.text, query: "missing").isEmpty)
        print("PASS: All, Text (including links), Images and search within filters")

        let clipboardVersion = board.changeCount
        let sessionIDs = store.entries.map(\.id)
        assert(store.toggleSaved(id: firstID))
        assert(store.toggleSaved(id: imageID))
        assert(store.toggleSaved(id: filesID))
        assert(store.isSaved(id: imageID))
        assert(board.changeCount == clipboardVersion && store.entries.map(\.id) == sessionIDs)
        assert(store.filteredEntries(.saved, query: "FIRST").map(\.id) == [firstID])
        assert(!store.toggleSaved(id: "missing"))
        assert(!store.choose(id: "missing"))
        store.shutdown()
        let reloaded = ClipboardStore(board: board, file: file)
        assert(reloaded.entries.isEmpty)
        assert(reloaded.savedEntries.map(\.id) == [filesID, imageID, firstID])
        assert(reloaded.entry(id: imageID)?.imageData == png)
        assert(reloaded.choose(id: imageID))
        assert(board.data(forType: .png) == png)
        assert(!reloaded.poll())
        assert(reloaded.entries.map(\.id) == [imageID])
        assert(reloaded.choose(id: filesID))
        assert(board.pasteboardItems?[1].string(forType: .fileURL) == "file:///tmp/two.txt")
        print("PASS: saving leaves clipboard untouched; saved text, images and files survive a new session")

        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        assert(permissions?.intValue == 0o600)
        reloaded.clear()
        assert(reloaded.entries.isEmpty && reloaded.savedEntries.count == 3)
        assert(board.pasteboardItems?[1].string(forType: .fileURL) == "file:///tmp/two.txt")
        assert(reloaded.toggleSaved(id: imageID))
        assert(!reloaded.isSaved(id: imageID))
        reloaded.shutdown()
        let nextSession = ClipboardStore(board: board, file: file)
        assert(nextSession.entries.isEmpty && nextSession.savedEntries.map(\.id) == [filesID, firstID])
        print("PASS: private persistence, unsaving persists, clearing session retains Saved and clipboard")

        let concealed = NSPasteboardItem()
        concealed.setString("concealed", forType: .string)
        concealed.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        board.clearContents(); board.writeObjects([concealed])
        let count = nextSession.entries.count
        assert(!nextSession.poll() && nextSession.entries.count == count)
        for index in 0..<505 { copy("session item \(index)"); assert(nextSession.poll()) }
        assert(nextSession.entries.count == 505)
        assert(nextSession.entries.last?.label == "session item 0")
        nextSession.shutdown()
        assert(ClipboardStore(board: board, file: file).entries.isEmpty)
        print("PASS: concealed-item exclusion, continuous capture, full session retention and session reset")

        let corruptFile = directory.appendingPathComponent("corrupt.plist")
        let corruptData = Data("invalid saved file".utf8)
        try corruptData.write(to: corruptFile)
        let damaged = ClipboardStore(board: board, file: corruptFile)
        assert(damaged.error != nil)
        copy("capture still runs"); assert(damaged.poll())
        assert(damaged.entries[0].label == "capture still runs")
        assert(!damaged.toggleSaved(id: damaged.entries[0].id))
        damaged.shutdown()
        let preserved = try Data(contentsOf: corruptFile)
        assert(preserved == corruptData)
        print("PASS: unavailable saved storage cannot stop capture or overwrite unreadable data")
    }
}
