import AppKit
import ImageIO

/// One row in the panel, made ready for display.
struct Clip: Identifiable {
    let id: String
    let title: String
    let kind: String
    let created: Double
    let isSaved: Bool
    /// The category chip, or nil when the clip has none (yet).
    let categoryName: String?

    static let imageTitle = "Copied image / screenshot"

    /// Short, single-line-friendly title. Blank text gets a visible name.
    static func displayTitle(for label: String) -> String {
        let short = String(label.prefix(800))
        if short.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Blank text"
        }
        var title = short.replacingOccurrences(of: "\r\n", with: "  ")
        title = title.replacingOccurrences(of: "\r", with: "  ")
        title = title.replacingOccurrences(of: "\n", with: "  ")
        return title
    }

    /// Images show the model's title when there is one.
    static func title(for entry: ClipboardEntry) -> String {
        if entry.kind == "Image" {
            return entry.title ?? imageTitle
        }
        return displayTitle(for: entry.label)
    }
}

/// The small dropdowns that open inside the panel.
enum PanelMenu {
    case more
    case settings
}

@MainActor final class ClipboardModel: ObservableObject {
    @Published var entries: [Clip] = []
    @Published var query = "" { didSet { reload() } }
    @Published var filter: ClipboardFilter = .all { didSet { reload() } }
    /// The chosen category tab; nil is All.
    @Published var categoryID: String? { didSet { reload() } }
    @Published private(set) var categoryList: CategoryList
    @Published private(set) var categoriesAvailable = false
    /// The Add/Edit sheet's working copy; nil while the sheet is closed.
    @Published var categoryDraft: CategoryDraft?
    @Published var openMenu: PanelMenu?
    @Published var reordersHistory: Bool {
        didSet {
            defaults.set(reordersHistory, forKey: Self.reorderKey)
            store?.reordersHistory = reordersHistory
        }
    }
    /// Select mode's picks; nil while Select mode is off.
    @Published private(set) var selection: ClipSelection?
    @Published private(set) var selectionNote: String?
    @Published var accent: AccentColor { didSet { defaults.set(accent.hex, forKey: Self.accentKey) } }
    @Published var isPickingAccent = false
    @Published var notice: String?
    @Published var notchHeight: CGFloat = 0
    @Published var notchWidth: CGFloat = 165
    @Published private(set) var pendingSavedRemovalID: String?
    @Published var skipPendingRemovalConfirmation = false
    private(set) var skipsSavedRemovalConfirmation = false
    private(set) var store: ClipboardStore?
    let categorizer: ClipCategorizer?
    private let defaults: UserDefaults
    /// The sorting job in flight, if any.
    var sortingTask: Task<Void, Never>?
    /// Bumped when the category list changes, so answers about the old list are dropped.
    var sortingVersion = 0
    private var noteTask: Task<Void, Never>?
    /// Seconds to wait before asking a busy model again.
    var retryDelay: TimeInterval = 30
    /// Seconds the Select mode note stays up.
    var noteDuration: TimeInterval = 2.5
    static let accentKey = "accentColor"
    static let reorderKey = "reorderHistory"
    private let imageCache = NSCache<NSString, NSImage>()
    var selected: (() -> Void)?
    var removalRequested: (() -> Void)?
    var slowWork: ((String, TimeInterval) -> Void)?

    var isConfirmingSavedRemoval: Bool { pendingSavedRemovalID != nil }
    var isSelecting: Bool { selection != nil }

    /// Something is waiting on the user, so the panel must not close by itself.
    var holdsPanelOpen: Bool {
        isConfirmingSavedRemoval || categoryDraft != nil || isSelecting
    }

    init(store: ClipboardStore? = nil, categorizer: ClipCategorizer? = makeAppleCategorizer(), defaults: UserDefaults = .standard) {
        imageCache.totalCostLimit = 24 * 1024 * 1024
        self.store = store ?? ClipboardStore()
        self.categorizer = categorizer
        self.defaults = defaults
        var savedAccent = AccentColor.purple
        if let hex = defaults.string(forKey: Self.accentKey), let color = AccentColor(hex: hex) {
            savedAccent = color
        }
        accent = savedAccent
        categoryList = CategoryList.load(from: defaults)
        reordersHistory = defaults.bool(forKey: Self.reorderKey)
        self.store?.reordersHistory = reordersHistory
        reload()
        sortNext()
    }

    func poll() {
        guard let store else { return }
        let start = ProcessInfo.processInfo.systemUptime
        defer { recordDuration("clipboard_poll", since: start) }
        if store.poll() {
            reload()
            sortNext()
        }
    }

    func reload() {
        guard let store else { return }
        let start = ProcessInfo.processInfo.systemUptime
        defer { recordDuration("history_refresh", since: start) }
        let savedIDs = Set(store.savedEntries.map(\.id))
        categoriesAvailable = categorizer?.isAvailable ?? false
        var shownCategory = categoryID
        if !categoriesAvailable {
            shownCategory = nil
        }
        entries = store.filteredEntries(filter, categoryID: shownCategory, query: query).map { entry in
            Clip(id: entry.id,
                 title: Clip.title(for: entry),
                 kind: entry.kind,
                 created: entry.created,
                 isSaved: savedIDs.contains(entry.id),
                 categoryName: categoryList.category(id: entry.categoryID)?.name)
        }
        if var picks = selection {
            let existing = Set(store.entries.map(\.id)).union(savedIDs)
            picks.keep(only: existing)
            if picks != selection {
                selection = picks
            }
        }
        notice = store.error
    }

    func choose(_ clip: Clip) {
        guard let store, !isConfirmingSavedRemoval, !isSelecting else { return }
        let start = ProcessInfo.processInfo.systemUptime
        defer { recordDuration("clipboard_restore", since: start) }
        let restored = store.choose(id: clip.id)
        reload()
        if restored {
            selected?()
        } else {
            NSSound.beep()
        }
    }

    func toggleSaved(_ clip: Clip) {
        guard let store, !isConfirmingSavedRemoval, !isSelecting else { return }
        let needsConfirmation = store.isSaved(id: clip.id) && !skipsSavedRemovalConfirmation
        if needsConfirmation {
            skipPendingRemovalConfirmation = false
            pendingSavedRemovalID = clip.id
            removalRequested?()
            return
        }
        if !store.toggleSaved(id: clip.id) {
            NSSound.beep()
        }
        reload()
    }

    /// Yes or No on the confirmation. The checkbox counts for both answers.
    func finishSavedRemoval(remove: Bool) {
        guard let id = pendingSavedRemovalID, let store else { return }
        skipsSavedRemovalConfirmation = skipPendingRemovalConfirmation
        cancelSavedRemoval()
        guard remove, store.isSaved(id: id) else { return }
        if !store.toggleSaved(id: id) {
            NSSound.beep()
        }
        reload()
    }

    func cancelSavedRemoval() {
        pendingSavedRemovalID = nil
        skipPendingRemovalConfirmation = false
    }

    func clear() {
        guard let store else { return }
        store.clear()
        imageCache.removeAllObjects()
        reload()
    }

    func thumbnail(_ clip: Clip) -> NSImage? {
        guard clip.kind == "Image", let store else { return nil }
        if let cached = imageCache.object(forKey: clip.id as NSString) {
            return cached
        }
        let start = ProcessInfo.processInfo.systemUptime
        defer { recordDuration("thumbnail_decode", since: start) }
        guard let data = store.entry(id: clip.id)?.imageData else { return nil }
        guard let image = Self.makeThumbnail(from: data, maxPixelSize: 200) else { return nil }
        let cost = Int(image.size.width * image.size.height * 4)
        imageCache.setObject(image, forKey: clip.id as NSString, cost: cost)
        return image
    }

    static func makeThumbnail(from data: Data, maxPixelSize: Int) -> NSImage? {
        guard let image = makeSmallImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    /// ImageIO shrinks large screenshots while decoding, so the full image never loads.
    static func makeSmallImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func resetAccent() {
        accent = .purple
    }

    // MARK: Category tabs and menus

    /// nil chooses All.
    func selectCategory(_ id: String?) {
        openMenu = nil
        if categoryID != id {
            categoryID = id
        }
    }

    /// Tapping the open menu's button again closes it.
    func toggleMenu(_ menu: PanelMenu) {
        if openMenu == menu {
            openMenu = nil
        } else {
            openMenu = menu
        }
    }

    func editCategories() {
        openMenu = nil
        categoryDraft = CategoryDraft(categoryList)
    }

    func cancelCategoryDraft() {
        categoryDraft = nil
    }

    /// Done on the sheet. Adding or removing a category sorts every clip again; a rename or move does not.
    func saveCategoryDraft() {
        guard let draft = categoryDraft, let list = draft.result else { return }
        let idsChanged = list.ids != categoryList.ids
        categoryList = list
        list.save(to: defaults)
        categoryDraft = nil
        if let categoryID, !list.ids.contains(categoryID) {
            self.categoryID = nil
        }
        if idsChanged {
            sortEverythingAgain()
        }
        reload()
    }

    // MARK: Select mode

    func toggleSelectMode() {
        if isSelecting {
            cancelSelection()
        } else {
            openMenu = nil
            selection = ClipSelection()
        }
    }

    func cancelSelection() {
        selection = nil
        showNote(nil)
    }

    func pick(_ clip: Clip) {
        guard var picks = selection else { return }
        let outcome = picks.toggle(id: clip.id, kind: clip.kind)
        selection = picks
        switch outcome {
        case .blocked(let note):
            showNote(note)
        case .picked, .unpicked:
            showNote(nil)
        }
    }

    /// Done: text is joined with one space into one paste; images go on the clipboard together.
    func finishSelection() {
        guard let store, let picks = selection, !picks.ids.isEmpty else { return }
        var copied = false
        if picks.group == .image {
            copied = store.chooseAll(ids: picks.ids)
        } else {
            var pieces: [String] = []
            for id in picks.ids {
                pieces.append(store.entry(id: id)?.plainText ?? "")
            }
            copied = store.chooseText(ClipSelection.join(pieces), from: picks.ids)
        }
        cancelSelection()
        reload()
        if copied {
            selected?()
        } else {
            NSSound.beep()
        }
    }

    private func showNote(_ note: String?) {
        noteTask?.cancel()
        noteTask = nil
        selectionNote = note
        guard note != nil else { return }
        let duration = noteDuration
        noteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                self?.selectionNote = nil
            }
        }
    }

    /// The panel closed: menus and the edit sheet go away. Select mode stays until Done, Cancel or Escape.
    func panelClosed() {
        cancelSavedRemoval()
        isPickingAccent = false
        openMenu = nil
        categoryDraft = nil
    }

    func shutdown() {
        sortingTask?.cancel()
        sortingTask = nil
        noteTask?.cancel()
        store?.shutdown()
        store = nil
    }

    func recordDuration(_ stage: String, since start: TimeInterval) {
        let duration = ProcessInfo.processInfo.systemUptime - start
        if duration >= 0.05 {
            slowWork?(stage, duration)
        }
    }
}
