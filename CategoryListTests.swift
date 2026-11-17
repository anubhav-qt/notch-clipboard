import Foundation

@main struct CategoryListTests {
    static func main() {
        let starter = CategoryList.starter
        assert(starter.categories.map(\.name) == ["Work", "Personal", "Creative", "Reference"])
        assert(!starter.allIsLast, "All is first by default")
        let names = starter.tabs.map(tabName)
        assert(names == ["All", "Work", "Personal", "Creative", "More"], "\(names)")
        assert(starter.more.map(\.name) == ["Reference"])
        var last = starter
        last.allIsLast = true
        assert(last.tabs.map(tabName) == ["Work", "Personal", "Creative", "All", "More"])
        let two = CategoryList(categories: [.work, .personal], allIsLast: false)
        assert(two.tabs.map(tabName) == ["All", "Work", "Personal", "More"], "More stays for Add/Edit")
        assert(two.more.isEmpty)
        print("PASS: tabs are All, the first three and More; All can go last; More is always there")

        var draft = CategoryDraft(starter)
        assert(draft.problem == nil && draft.result == starter)
        draft.rename(id: "work", to: "")
        assert(draft.problem == CategoryDraft.emptyNameProblem && draft.result == nil)
        draft.rename(id: "work", to: "   \n ")
        assert(draft.problem == CategoryDraft.emptyNameProblem, "Spaces only count as empty")
        draft.rename(id: "work", to: "personal")
        assert(draft.problem == CategoryDraft.sameNameProblem, "Names differ by more than case")
        draft.rename(id: "work", to: " Personal ")
        assert(draft.problem == CategoryDraft.sameNameProblem, "and by more than spaces")
        draft.rename(id: "work", to: String(repeating: "w", count: 50))
        assert(draft.name(id: "work").count == ClipCategory.maxNameLength, "Typing past 20 characters does nothing")
        draft.rename(id: "work", to: "Café 👋🏽 <b>&\"x\"")
        assert(draft.problem == nil && draft.result!.categories[0].name == "Café 👋🏽 <b>&\"x\"")
        draft.rename(id: "missing", to: "ghost")
        assert(draft.rows.count == 4)
        print("PASS: empty, spaces-only, same-name and too-long names are caught; odd characters are fine")

        var full = CategoryDraft(starter)
        var added: [String] = []
        while let id = full.add() {
            added.append(id)
            full.rename(id: id, to: "Extra \(added.count)")
        }
        assert(full.rows.count == ClipCategory.maxCount && !full.canAdd && added.count == 6)
        assert(full.add() == nil, "An 11th category is refused")
        assert(Set(added).count == added.count, "New rows get their own ids")
        for row in full.rows {
            full.remove(id: row.id)
        }
        assert(full.rows.count == 1 && !full.canRemove, "The last category can't be removed")
        assert(full.problem == nil)
        print("PASS: between 1 and 10 categories, with fresh ids for new ones")

        var moving = CategoryDraft(starter)
        moving.move(id: "work", to: 2)
        assert(moving.rows.map(\.id) == ["personal", "creative", "work", "reference"])
        moving.move(id: "work", to: -5)
        assert(moving.rows.map(\.id) == ["work", "personal", "creative", "reference"])
        moving.move(id: "work", to: 99)
        assert(moving.rows.map(\.id) == ["personal", "creative", "reference", "work"])
        moving.move(id: "ghost", to: 0)
        assert(moving.rows.count == 4)
        print("PASS: moving stops at either end and ignores unknown rows")

        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        assert(CategoryList.load(from: defaults) == starter, "A new install gets the starters")
        var custom = CategoryDraft(starter)
        let recipes = custom.add()!
        custom.rename(id: recipes, to: "Recipes")
        custom.allIsLast = true
        custom.result!.save(to: defaults)
        assert(CategoryList.load(from: defaults) == custom.result!)
        let broken: [Data] = [
            Data("not json".utf8),
            try! JSONEncoder().encode([ClipCategory]()),
            try! JSONEncoder().encode([ClipCategory.work, ClipCategory(id: "x", name: "work")]),
            try! JSONEncoder().encode([ClipCategory.work, ClipCategory(id: "work", name: "Other")]),
            try! JSONEncoder().encode([ClipCategory(id: ClipCategory.noneID, name: "None")]),
            try! JSONEncoder().encode([ClipCategory(id: "long", name: String(repeating: "x", count: 21))]),
            try! JSONEncoder().encode((0..<11).map { ClipCategory(id: "\($0)", name: "N\($0)") })
        ]
        for data in broken {
            defaults.set(data, forKey: CategoryList.categoriesKey)
            let loaded = CategoryList.load(from: defaults)
            assert(loaded.categories == ClipCategory.starters, "Broken data gives the starters")
            assert(loaded.allIsLast, "and keeps All's place")
        }
        print("PASS: the list is saved and loaded; broken, empty, duplicate or oversized data gives the starters")

        assert(ClipCategory.work.hint != nil)
        assert(ClipCategory(id: "work", name: "Job").hint == nil, "A renamed starter has no hint")
        assert(ClipCategory(id: "x", name: "Work").hint == nil, "A new category named Work has no hint")
        assert(ClipCategory.id(fromStored: "Creative") == "creative")
        assert(ClipCategory.id(fromStored: "a-uuid") == "a-uuid")
        let instructions = CategoryPrompt.textInstructions(for: [ClipCategory(id: "x", name: "Recipes"), .work])
        assert(instructions.contains("one of 2 groups"))
        assert(instructions.contains("\nRecipes\n"))
        assert(!instructions.contains("Use Reference"), "No catch-all line once Reference is gone")
        print("PASS: only unchanged starters carry a hint, and the prompt lists the user's names in order")
    }

    static func tabName(_ tab: CategoryTab) -> String {
        switch tab {
        case .all:
            return "All"
        case .category(let category):
            return category.name
        case .more:
            return "More"
        }
    }
}
