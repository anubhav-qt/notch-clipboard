import AppKit

/// Writes copied images as PNG files, for the "Save images as files" setting.
/// A file is named after the clip's id, so copying the same image again reuses it.
struct ImageFiles {
    static let defaultFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/Notch Clipboard", isDirectory: true)
    static let imageTypes = ["public.png", "public.jpeg", "public.heic", "public.tiff"]

    let folder: URL

    /// The file for one picture of a clip. Most clips hold one; several pictures get numbers.
    func url(for entry: ClipboardEntry, picture: Int) -> URL {
        let shortID = String(entry.id.prefix(12))
        var name = "Clipboard image \(shortID)"
        if picture > 0 {
            name += " \(picture + 1)"
        }
        return folder.appendingPathComponent(name).appendingPathExtension("png")
    }

    /// Writes every picture of an image clip that is not on disk yet.
    /// Gives one file per clipboard item, or nil for an item with no picture. Throws when a file cannot be written.
    @discardableResult func write(_ entry: ClipboardEntry) throws -> [URL?] {
        var files: [URL?] = []
        var picture = 0
        for item in entry.items {
            guard let data = Self.imageData(in: item) else {
                files.append(nil)
                continue
            }
            let file = url(for: entry, picture: picture)
            picture += 1
            if !FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Self.png(from: data).write(to: file, options: .atomic)
            }
            files.append(file)
        }
        return files
    }

    /// The best picture in one clipboard item, PNG first.
    static func imageData(in item: ClipboardItem) -> Data? {
        for type in imageTypes {
            if let match = item.representations.first(where: { $0.type == type }) {
                return match.data
            }
        }
        return nil
    }

    /// PNG stays as it is; JPEG, HEIC and TIFF are converted.
    static func png(from data: Data) throws -> Data {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return data
        }
        guard let bitmap = NSBitmapImageRep(data: data),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return png
    }
}
