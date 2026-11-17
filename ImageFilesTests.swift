import AppKit

/// "Save images as files": off by default, PNG files on capture, file pastes, and safe failures.
@main struct ImageFilesTests {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = directory.appendingPathComponent("Pictures/Notch Clipboard")
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        func pictures() -> [String] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            return names.sorted()
        }
        func bitmap(_ red: Double) -> NSBitmapImageRep {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3, pixelsHigh: 2,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.setColor(NSColor(deviceRed: red, green: 0.2, blue: 0.4, alpha: 1), atX: 1, y: 1)
            return rep
        }
        func copyImage(_ data: Data, type: NSPasteboard.PasteboardType) {
            board.clearContents()
            board.setData(data, forType: type)
        }
        let png = bitmap(0.1).representation(using: .png, properties: [:])!

        let store = ClipboardStore(board: board, file: directory.appendingPathComponent("saved.plist"), imageFolder: folder)
        assert(!store.savesImagesAsFiles, "Off by default")
        copyImage(png, type: .png)
        assert(store.poll())
        store.shutdown()
        assert(pictures().isEmpty, "Off: no files are written")
        assert(store.choose(id: store.entries[0].id))
        assert(board.string(forType: .fileURL) == nil && board.data(forType: .png) == png, "Off: images paste as pictures")
        print("PASS: off by default, no files and plain picture pastes")

        store.savesImagesAsFiles = true
        copyImage(bitmap(0.5).representation(using: .png, properties: [:])!, type: .png)
        assert(store.poll())
        store.shutdown()
        let pngClip = store.entries[0]
        let pngFile = store.imageFiles.url(for: pngClip, picture: 0)
        assert(pictures() == [pngFile.lastPathComponent], "On: a copied image becomes one PNG file: \(pictures())")
        let savedPNG = try Data(contentsOf: pngFile)
        assert(savedPNG == pngClip.imageData, "A PNG is saved byte for byte")

        let tiff = bitmap(0.9).tiffRepresentation!
        copyImage(tiff, type: .tiff)
        assert(store.poll())
        store.shutdown()
        let tiffFile = store.imageFiles.url(for: store.entries[0], picture: 0)
        let converted = try Data(contentsOf: tiffFile)
        assert(converted.starts(with: [0x89, 0x50, 0x4E, 0x47]), "TIFF is saved as real PNG")
        assert(NSBitmapImageRep(data: converted)?.pixelsWide == 3, "and keeps its size")
        assert(pictures().count == 2)

        copyImage(tiff, type: .tiff)
        assert(store.poll())
        store.shutdown()
        assert(pictures().count == 2, "Copying the same image again writes no second file")
        board.clearContents()
        board.setString("just words", forType: .string)
        assert(store.poll())
        store.shutdown()
        assert(pictures().count == 2, "Text writes no file")
        print("PASS: on: PNG kept as is, TIFF converted, repeats and text write nothing new")

        assert(store.choose(id: pngClip.id))
        assert(board.string(forType: .fileURL) == pngFile.absoluteString, "Picking an image pastes its file")
        assert(board.data(forType: .png) == pngClip.imageData, "and still the picture, for apps that want one")
        assert(!store.poll(), "Pasting the file is not captured as a new clip")
        try FileManager.default.removeItem(at: pngFile)
        assert(store.choose(id: pngClip.id))
        assert(FileManager.default.fileExists(atPath: pngFile.path), "A deleted file is written again on paste")
        let textID = store.entries.first { $0.kind == "Text" }!.id
        assert(store.choose(id: textID))
        assert(board.string(forType: .fileURL) == nil, "Text never pastes as a file")
        print("PASS: picking an image pastes its file and picture, rewrites a deleted file, text is untouched")

        let two = [NSPasteboardItem(), NSPasteboardItem()]
        two[0].setData(bitmap(0.3).representation(using: .png, properties: [:])!, forType: .png)
        two[1].setData(bitmap(0.7).representation(using: .png, properties: [:])!, forType: .png)
        board.clearContents()
        board.writeObjects(two)
        assert(store.poll())
        let pair = store.entries[0]
        assert(store.choose(id: pair.id))
        let pasted = board.pasteboardItems!.map { $0.string(forType: .fileURL) }
        let expected = [0, 1].map { store.imageFiles.url(for: pair, picture: $0).absoluteString }
        assert(pasted == expected, "Two pictures paste as two numbered files: \(pasted)")
        assert(expected[1].hasSuffix("%202.png"))
        print("PASS: a clip with two pictures writes and pastes two files")

        let blocker = directory.appendingPathComponent("not a folder")
        try Data("x".utf8).write(to: blocker)
        let stuck = ClipboardStore(board: board, file: directory.appendingPathComponent("stuck.plist"), imageFolder: blocker)
        stuck.savesImagesAsFiles = true
        copyImage(png, type: .png)
        assert(stuck.poll())
        stuck.shutdown()
        assert(stuck.error?.contains("image file") == true, "A folder that cannot be made is reported")
        assert(stuck.choose(id: stuck.entries[0].id), "The picture still pastes")
        assert(board.string(forType: .fileURL) == nil && board.data(forType: .png) == png)
        stuck.savesImagesAsFiles = false
        store.savesImagesAsFiles = true
        assert(store.choose(id: pngClip.id) && store.error == nil, "A working write clears the problem")
        print("PASS: an unwritable folder is reported, the picture still pastes, and the note clears")

        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        func makeModel() -> ClipboardModel {
            let fresh = ClipboardStore(board: board, file: directory.appendingPathComponent("\(UUID()).plist"), imageFolder: folder)
            return ClipboardModel(store: fresh, categorizer: nil, defaults: defaults)
        }
        let first = makeModel()
        assert(!first.savesImagesAsFiles && first.store?.savesImagesAsFiles == false, "The setting starts off")
        first.savesImagesAsFiles = true
        assert(defaults.bool(forKey: ClipboardModel.imageFilesKey))
        let again = makeModel()
        assert(again.savesImagesAsFiles && again.store?.savesImagesAsFiles == true, "The setting survives a relaunch")
        again.savesImagesAsFiles = false
        assert(!makeModel().savesImagesAsFiles)
        first.shutdown()
        again.shutdown()
        print("PASS: the switch is off by default, reaches the store and is remembered")
    }
}
