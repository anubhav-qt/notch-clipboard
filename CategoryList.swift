import Foundation

/// One tab in the row beside search.
enum CategoryTab: Equatable {
    case all
    case category(ClipCategory)
    case more
}

/// The user's categories in their order, and where the All tab sits.
struct CategoryList: Equatable {
    var categories: [ClipCategory]
    var allIsLast: Bool

    static let starter = CategoryList(categories: ClipCategory.starters, allIsLast: false)
    static let categoriesKey = "categories"
    static let allIsLastKey = "allTabLast"
    /// How many categories get their own tab; the rest live in More.
    static let tabCount = 3

    var ids: Set<String> {
        Set(categories.map(\.id))
    }

    /// The categories that live in the More menu.
    var more: [ClipCategory] {
        Array(categories.dropFirst(Self.tabCount))
    }

    /// All, the first three categories, then More. All may come after the three instead.
    var tabs: [CategoryTab] {
        var tabs: [CategoryTab] = []
        for category in categories.prefix(Self.tabCount) {
            tabs.append(.category(category))
        }
        if allIsLast {
            tabs.append(.all)
        } else {
            tabs.insert(.all, at: 0)
        }
        tabs.append(.more)
        return tabs
    }

    func category(id: String?) -> ClipCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    /// Reads the stored list. Anything broken or missing gives the starter list.
    static func load(from defaults: UserDefaults) -> CategoryList {
        let allIsLast = defaults.bool(forKey: allIsLastKey)
        guard let data = defaults.data(forKey: categoriesKey) else {
            return CategoryList(categories: ClipCategory.starters, allIsLast: allIsLast)
        }
        guard let stored = try? JSONDecoder().decode([ClipCategory].self, from: data), isValid(stored) else {
            return CategoryList(categories: ClipCategory.starters, allIsLast: allIsLast)
        }
        return CategoryList(categories: stored, allIsLast: allIsLast)
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(categories) {
            defaults.set(data, forKey: Self.categoriesKey)
        }
        defaults.set(allIsLast, forKey: Self.allIsLastKey)
    }

    private static func isValid(_ categories: [ClipCategory]) -> Bool {
        if categories.isEmpty || categories.count > ClipCategory.maxCount {
            return false
        }
        let ids = Set(categories.map(\.id))
        if ids.count != categories.count || ids.contains(ClipCategory.noneID) {
            return false
        }
        let names = categories.map(\.name)
        return CategoryDraft.problem(in: names) == nil
    }
}

/// The Add/Edit sheet works on this copy. Nothing changes until Done.
struct CategoryDraft: Equatable {
    struct Row: Equatable, Identifiable {
        let id: String
        var name: String
    }

    static let emptyNameProblem = "Names can't be empty"
    static let sameNameProblem = "Two categories can't share a name"
    static let longNameProblem = "Names can be at most \(ClipCategory.maxNameLength) characters"

    private(set) var rows: [Row]
    var allIsLast: Bool

    init(_ list: CategoryList) {
        rows = list.categories.map { Row(id: $0.id, name: $0.name) }
        allIsLast = list.allIsLast
    }

    var canAdd: Bool {
        rows.count < ClipCategory.maxCount
    }

    var canRemove: Bool {
        rows.count > 1
    }

    /// Adds an empty row at the end and returns its id, or nil when the list is full.
    @discardableResult mutating func add() -> String? {
        guard canAdd else { return nil }
        let id = UUID().uuidString
        rows.append(Row(id: id, name: ""))
        return id
    }

    mutating func remove(id: String) {
        guard canRemove else { return }
        rows.removeAll { $0.id == id }
    }

    /// Names longer than the limit are cut, so typing past it does nothing.
    mutating func rename(id: String, to name: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].name = String(name.prefix(ClipCategory.maxNameLength))
    }

    /// Moves a row to a new position. Positions past either end stop at the end.
    mutating func move(id: String, to position: Int) {
        guard let from = rows.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(position, 0), rows.count - 1)
        if target == from {
            return
        }
        let row = rows.remove(at: from)
        rows.insert(row, at: target)
    }

    func name(id: String) -> String {
        rows.first { $0.id == id }?.name ?? ""
    }

    /// What stops Done, if anything.
    var problem: String? {
        Self.problem(in: rows.map(\.name))
    }

    /// The finished list, or nil while there is a problem.
    var result: CategoryList? {
        guard problem == nil else { return nil }
        var categories: [ClipCategory] = []
        for row in rows {
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            categories.append(ClipCategory(id: row.id, name: name))
        }
        return CategoryList(categories: categories, allIsLast: allIsLast)
    }

    /// Empty names and names that differ only by case or spaces are not allowed.
    static func problem(in names: [String]) -> String? {
        var seen: Set<String> = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return emptyNameProblem
            }
            if trimmed.count > ClipCategory.maxNameLength {
                return longNameProblem
            }
            let key = trimmed.lowercased()
            if seen.contains(key) {
                return sameNameProblem
            }
            seen.insert(key)
        }
        return nil
    }
}
