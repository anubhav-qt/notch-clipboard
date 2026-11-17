import AppKit
import CryptoKit

let clipboardDataDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Notch Clipboard", isDirectory: true)

struct ClipboardRepresentation {
    let type: String
    let data: Data
}
struct ClipboardItem {
    let representations: [ClipboardRepresentation]
}
struct ClipboardEntry {
    let id: String
    var created: Double
    let source: String
    let label: String
    let kind: String
    let items: [ClipboardItem]
    /// The id of the category this clip was sorted into, `ClipCategory.noneID`, or nil while unsorted.
    var categoryID: String?
    /// A short name the on-device model wrote for an image.
    var title: String?
    var propertyList: [String: Any] {
        var rawItems: [[[String: Any]]] = []
        for item in items {
            var rawItem: [[String: Any]] = []
            for representation in item.representations {
                rawItem.append(["uti": representation.type, "data": representation.data])
            }
            rawItems.append(rawItem)
        }
        var list: [String: Any] = ["id": id, "created": Int64(created), "source": source, "label": label, "kind": kind, "items": rawItems]
        if let categoryID {
            list["category"] = categoryID
        }
        if let title {
            list["title"] = title
        }
        return list
    }
    init?(propertyList: [String: Any]) {
        guard let id = propertyList["id"] as? String,
              let created = propertyList["created"] as? NSNumber,
              let source = propertyList["source"] as? String,
              let label = propertyList["label"] as? String,
              let kind = propertyList["kind"] as? String,
              let rawItems = propertyList["items"] as? [[[String: Any]]] else { return nil }
        var items: [ClipboardItem] = []
        for rawItem in rawItems {
            var representations: [ClipboardRepresentation] = []
            for representation in rawItem {
                guard let type = representation["uti"] as? String, let data = representation["data"] as? Data else { return nil }
                representations.append(ClipboardRepresentation(type: type, data: data))
            }
            items.append(ClipboardItem(representations: representations))
        }
        self.id = id
        self.created = created.doubleValue
        self.source = source
        self.label = label
        self.kind = kind
        self.items = items
        if let storedCategory = propertyList["category"] as? String {
            categoryID = ClipCategory.id(fromStored: storedCategory)
        }
        title = propertyList["title"] as? String
    }
    init(items: [ClipboardItem], source: String) {
        self.items = items
        self.source = source
        created = Date().timeIntervalSince1970
        var digest = SHA256()
        for item in items {
            var count = UInt64(item.representations.count).littleEndian
            withUnsafeBytes(of: &count) { digest.update(data: $0) }
            for representation in item.representations {
                let name = Data(representation.type.utf8)
                var nameCount = UInt64(name.count).littleEndian
                var dataCount = UInt64(representation.data.count).littleEndian
                withUnsafeBytes(of: &nameCount) { digest.update(data: $0) }
                digest.update(data: name)
                withUnsafeBytes(of: &dataCount) { digest.update(data: $0) }
                digest.update(data: representation.data)
            }
        }
        id = digest.finalize().map { String(format: "%02x", $0) }.joined()
        let representations = items.flatMap(\.representations)
        let types = Set(representations.map(\.type))
        func text(_ type: String) -> String? {
            guard let data = representations.first(where: { $0.type == type })?.data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        if types.contains("public.file-url") || types.contains("NSFilenamesPboardType") {
            kind = "Files"
            label = text("public.file-url").flatMap { URL(string: $0)?.lastPathComponent } ?? "Copied files"
        } else if !types.isDisjoint(with: ["public.png", "public.tiff", "public.jpeg", "public.heic"]) {
            kind = "Image"
            label = "Copied image / screenshot"
        } else if types.contains("com.adobe.pdf") {
            kind = "PDF"
            label = "Copied PDF"
        } else {
            kind = types.contains("public.url") ? "Link" : "Text"
            label = text("public.utf8-plain-text") ?? text("public.url") ?? "Rich text"
        }
    }
    func matches(_ query: String) -> Bool {
        if query.isEmpty {
            return true
        }
        if let title, title.localizedCaseInsensitiveContains(query) {
            return true
        }
        return label.localizedCaseInsensitiveContains(query)
            || source.localizedCaseInsensitiveContains(query) || kind.localizedCaseInsensitiveContains(query)
    }
    /// The words of a text clip, for joining several clips into one paste.
    var plainText: String? {
        let representations = items.flatMap(\.representations)
        for type in ["public.utf8-plain-text", "public.url"] {
            if let match = representations.first(where: { $0.type == type }) {
                return String(data: match.data, encoding: .utf8)
            }
        }
        if let rtf = representations.first(where: { $0.type == "public.rtf" }) {
            return NSAttributedString(rtf: rtf.data, documentAttributes: nil)?.string
        }
        return nil
    }
    var imageData: Data? {
        let representations = items.flatMap(\.representations)
        for type in ["public.png", "public.jpeg", "public.heic", "public.tiff"] {
            if let match = representations.first(where: { $0.type == type }) {
                return match.data
            }
        }
        return nil
    }
}

private final class StorageStatus: @unchecked Sendable {
    private let lock = NSLock()
    private var message: String?
    func set(_ value: String?) {
        lock.withLock { message = value }
    }
    func get() -> String? {
        lock.withLock { message }
    }
}

enum ClipboardFilter: String, CaseIterable {
    case all = "All", text = "Text", images = "Images", saved = "Saved"
}

@MainActor final class ClipboardStore {
    private(set) var entries: [ClipboardEntry] = []
    private(set) var savedEntries: [ClipboardEntry] = []
    private(set) var notice: String?
    private var changeCount: Int
    private let board: NSPasteboard
    private let file: URL
    private let writer = DispatchQueue(label: "local.notchclipboard.persistence", qos: .utility)
    private let storageStatus = StorageStatus()
    private var pendingWrite: DispatchWorkItem?
    private var savingAvailable = true
    /// Off: a clip already in this session's history keeps its place when copied again.
    var reordersHistory = false
    static let supportedTypes: Set<String> = [
        "public.utf8-plain-text", "public.utf16-plain-text", "public.url", "public.file-url",
        "public.png", "public.tiff", "public.jpeg", "public.heic", "public.html", "public.rtf",
        "com.apple.flat-rtfd", "com.adobe.pdf", "NSFilenamesPboardType"
    ]
    static let maxCaptureBytes = 64 * 1024 * 1024
    static let excludedTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword", "com.typeit4me.clipping"
    ]
    init(board: NSPasteboard = .general, file: URL = clipboardDataDirectory.appendingPathComponent("saved.plist")) {
        self.board = board
        self.file = file
        changeCount = board.changeCount
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if FileManager.default.fileExists(atPath: file.path) {
                let data = try Data(contentsOf: file)
                guard let raw = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                for value in raw {
                    guard let entry = ClipboardEntry(propertyList: value) else { throw CocoaError(.fileReadCorruptFile) }
                    savedEntries.append(entry)
                }
            }
        } catch {
            // Keep capturing this session, and preserve an unreadable saved file for recovery.
            savedEntries.removeAll()
            savingAvailable = false
            storageStatus.set("Saved items could not be opened: \(error.localizedDescription)")
        }
    }
    var error: String? { storageStatus.get() ?? notice }
    func entry(id: String) -> ClipboardEntry? {
        entries.first { $0.id == id } ?? savedEntries.first { $0.id == id }
    }
    func isSaved(id: String) -> Bool { savedEntries.contains { $0.id == id } }
    func filteredEntries(_ filter: ClipboardFilter, categoryID: String? = nil, query: String = "") -> [ClipboardEntry] {
        let candidates: [ClipboardEntry]
        switch filter {
        case .all: candidates = entries
        case .text: candidates = entries.filter { $0.kind == "Text" || $0.kind == "Link" }
        case .images: candidates = entries.filter { $0.kind == "Image" }
        case .saved: candidates = savedEntries
        }
        var matches: [ClipboardEntry] = []
        for entry in candidates {
            if let categoryID, entry.categoryID != categoryID {
                continue
            }
            if entry.matches(query) {
                matches.append(entry)
            }
        }
        return matches
    }
    /// The newest clip that still needs sorting. A category that no longer exists counts as none yet.
    func nextUnsorted(validIDs: Set<String>) -> ClipboardEntry? {
        for entry in entries + savedEntries {
            guard let categoryID = entry.categoryID else { return entry }
            if categoryID != ClipCategory.noneID && !validIDs.contains(categoryID) {
                return entry
            }
        }
        return nil
    }
    /// Stores a sorting answer. A title is only written once, so it never flickers.
    func setCategory(_ categoryID: String, title: String? = nil, id: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].categoryID = categoryID
            if entries[index].title == nil {
                entries[index].title = title
            }
        }
        if let index = savedEntries.firstIndex(where: { $0.id == id }) {
            savedEntries[index].categoryID = categoryID
            if savedEntries[index].title == nil {
                savedEntries[index].title = title
            }
            save()
        }
    }
    /// Forgets every category, so all clips are sorted again. Titles are kept.
    func resetCategories() {
        for index in entries.indices {
            entries[index].categoryID = nil
        }
        for index in savedEntries.indices {
            savedEntries[index].categoryID = nil
        }
        if !savedEntries.isEmpty {
            save()
        }
    }
    @discardableResult func toggleSaved(id: String) -> Bool {
        guard savingAvailable else { return false }
        if isSaved(id: id) {
            savedEntries.removeAll { $0.id == id }
        } else {
            guard let entry = entry(id: id) else { return false }
            savedEntries.insert(entry, at: 0)
        }
        save()
        return true
    }
    @discardableResult func poll() -> Bool {
        let current = board.changeCount
        guard current != changeCount else { return false }
        changeCount = current
        if #available(macOS 15.4, *), board.accessBehavior == .alwaysDeny {
            notice = "Allow Notch Clipboard in System Settings → Privacy & Security → Paste from Other Apps."
            return true
        }
        guard let items = Self.read(board), current == board.changeCount else { return false }
        let source = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Application"
        insert(ClipboardEntry(items: items, source: source))
        notice = nil
        return true
    }
    @discardableResult func choose(id: String) -> Bool {
        guard let entry = entry(id: id) else { return false }
        guard write(Self.pasteboardItems(for: entry)) else { return false }
        markUsed(id: id)
        return true
    }
    /// Puts several clips on the clipboard at once, in this order, as separate items.
    @discardableResult func chooseAll(ids: [String]) -> Bool {
        var items: [NSPasteboardItem] = []
        for id in ids {
            guard let entry = entry(id: id) else { return false }
            items += Self.pasteboardItems(for: entry)
        }
        guard !items.isEmpty, write(items) else { return false }
        markUsedInOrder(ids)
        return true
    }
    /// Puts one joined string on the clipboard. The clips it came from count as used.
    @discardableResult func chooseText(_ text: String, from ids: [String]) -> Bool {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        guard write([item]) else { return false }
        markUsedInOrder(ids)
        return true
    }
    /// The first id ends up on top when history is reordered.
    private func markUsedInOrder(_ ids: [String]) {
        for id in ids.reversed() {
            markUsed(id: id)
        }
    }
    /// A used clip joins history if it is new to this session (a saved item), and moves up only when reordering.
    private func markUsed(id: String) {
        guard var entry = entry(id: id) else { return }
        entry.created = Date().timeIntervalSince1970
        insert(entry)
    }
    private func write(_ items: [NSPasteboardItem]) -> Bool {
        board.clearContents()
        guard board.writeObjects(items) else {
            notice = "macOS could not restore this clipboard item."
            return false
        }
        // The store wrote this itself, so the next poll must not capture it again.
        changeCount = board.changeCount
        notice = nil
        return true
    }
    private static func pasteboardItems(for entry: ClipboardEntry) -> [NSPasteboardItem] {
        entry.items.map { value -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for representation in value.representations {
                item.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
            }
            return item
        }
    }
    func clear() { entries.removeAll() }
    func shutdown() { writer.sync {} }
    /// Copying the same content again keeps its category and title.
    /// Without reordering, a clip already in history also keeps its place and age.
    private func insert(_ entry: ClipboardEntry) {
        if !reordersHistory && entries.contains(where: { $0.id == entry.id }) {
            return
        }
        var newEntry = entry
        if let known = self.entry(id: entry.id) {
            if newEntry.categoryID == nil {
                newEntry.categoryID = known.categoryID
            }
            if newEntry.title == nil {
                newEntry.title = known.title
            }
        }
        entries.removeAll { $0.id == entry.id }
        entries.insert(newEntry, at: 0)
    }
    private func save() {
        pendingWrite?.cancel()
        let snapshot = savedEntries
        let file = file
        let status = storageStatus
        let task = DispatchWorkItem {
            do {
                let value = snapshot.map(\.propertyList)
                let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
                try data.write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                status.set(nil)
            } catch { status.set("Saved items could not be written: \(error.localizedDescription)") }
        }
        pendingWrite = task
        writer.async(execute: task)
    }
    static func read(_ board: NSPasteboard) -> [ClipboardItem]? {
        guard let native = board.pasteboardItems, !native.isEmpty else { return nil }
        // Password managers mark secrets as concealed or transient. Never record those.
        for item in native {
            let types = Set(item.types.map(\.rawValue))
            if !types.isDisjoint(with: excludedTypes) {
                return nil
            }
        }
        var items: [ClipboardItem] = []
        var bytes = 0
        for item in native {
            var representations: [ClipboardRepresentation] = []
            for type in item.types.sorted(by: { $0.rawValue < $1.rawValue }) where supportedTypes.contains(type.rawValue) {
                guard let data = item.data(forType: type) else { continue }
                bytes += data.count
                if bytes > maxCaptureBytes {
                    return nil
                }
                representations.append(ClipboardRepresentation(type: type.rawValue, data: data))
            }
            if !representations.isEmpty {
                items.append(ClipboardItem(representations: representations))
            }
        }
        return items.isEmpty ? nil : items
    }
}
