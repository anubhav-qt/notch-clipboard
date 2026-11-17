import AppKit

@main struct ModelTests {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }

        assert(Clip.displayTitle(for: "") == "Blank text")
        assert(Clip.displayTitle(for: "  \n\t ") == "Blank text")
        assert(Clip.displayTitle(for: "a\nb") == "a  b")
        assert(Clip.displayTitle(for: "a\r\nb") == "a  b")
        assert(Clip.displayTitle(for: "a\rb") == "a  b")
        assert(Clip.displayTitle(for: String(repeating: "x", count: 5_000)).count == 800)
        assert(Clip.displayTitle(for: "héllo 👋🏽 <tag> \"quote\"") == "héllo 👋🏽 <tag> \"quote\"")
        print("PASS: titles name blank text, flatten every newline style, cap length and keep odd characters")

        let store = ClipboardStore(board: board, file: directory.appendingPathComponent("saved.plist"))
        let model = ClipboardModel(store: store, categorizer: nil, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        func copy(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
            model.poll()
        }
        copy("   ")
        assert(model.entries.first?.title == "Blank text")
        copy("alpha 👋🏽")
        copy("beta")
        assert(store.toggleSaved(id: store.entries[1].id))
        model.reload()
        assert(model.entries.map(\.isSaved) == [false, true, false])
        model.query = "👋🏽"
        assert(model.entries.map(\.title) == ["alpha 👋🏽"])
        model.query = String(repeating: "z", count: 10_000)
        assert(model.entries.isEmpty)
        model.query = ""
        model.filter = .saved
        assert(model.entries.count == 1 && model.entries[0].isSaved)
        model.filter = .all
        print("PASS: blank capture, saved flags, emoji search, huge queries and filters")

        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3000, pixelsHigh: 1500,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = bitmap.representation(using: .png, properties: [:])!
        let thumbnail = ClipboardModel.makeThumbnail(from: png, maxPixelSize: 200)!
        assert(thumbnail.size.width == 200 && thumbnail.size.height == 100)
        assert(ClipboardModel.makeThumbnail(from: Data("not an image".utf8), maxPixelSize: 200) == nil)
        board.clearContents()
        board.setData(png, forType: .png)
        model.poll()
        let image = model.entries[0]
        assert(image.kind == "Image")
        assert(model.thumbnail(image) === model.thumbnail(image))
        assert(model.thumbnail(model.entries[1]) == nil)
        print("PASS: thumbnails shrink large images, reject bad data, are cached and only made for images")

        let start = ProcessInfo.processInfo.systemUptime
        for index in 0..<1_000 {
            board.clearContents()
            board.setString("entry \(index) " + String(repeating: "word ", count: 200), forType: .string)
            assert(store.poll())
        }
        for entry in store.entries.prefix(300) {
            assert(store.toggleSaved(id: entry.id))
        }
        let filled = ProcessInfo.processInfo.systemUptime
        model.reload()
        let reloadMS = (ProcessInfo.processInfo.systemUptime - filled) * 1000
        model.query = "entry 999"
        let searchMS = (ProcessInfo.processInfo.systemUptime - filled) * 1000 - reloadMS
        assert(model.entries.count == 1)
        assert(reloadMS < 50, "Reload of 1000 rows took \(reloadMS) ms")
        assert(searchMS < 50, "Search of 1000 rows took \(searchMS) ms")
        print("PASS: 1000 rows with 300 saved reload in \(Int(reloadMS)) ms and search in \(Int(searchMS)) ms (setup \(Int((filled - start) * 1000)) ms)")
        model.shutdown()
    }
}
