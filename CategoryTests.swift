import AppKit

/// Stands in for Apple's model: answers from a list and records what it was asked.
final class FakeCategorizer: ClipCategorizer {
    var isAvailable = true
    var canSeeImages = false
    var answers: [Result<String, Error>] = []
    var imageAnswers: [Result<ImageAnswer, Error>] = []
    var prompts: [String] = []
    var instructions: [String] = []
    var names: [[String]] = []
    var imageWidths: [Int] = []
    var delay: TimeInterval = 0

    func category(for prompt: String, instructions: String, names: [String]) async throws -> String {
        prompts.append(prompt)
        self.instructions.append(instructions)
        self.names.append(names)
        // Like the real model, the answer is settled when asked and still arrives if the caller moved on.
        var answer = Result<String, Error>.success("Reference")
        if !answers.isEmpty {
            answer = answers.removeFirst()
        }
        if delay > 0 {
            await Self.wait(delay)
        }
        return try answer.get()
    }

    /// A wait that ignores cancellation.
    private static func wait(_ seconds: TimeInterval) async {
        await withCheckedContinuation { done in
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                done.resume()
            }
        }
    }

    func describeImage(_ image: CGImage, instructions: String, names: [String]) async throws -> ImageAnswer {
        imageWidths.append(max(image.width, image.height))
        self.instructions.append(instructions)
        self.names.append(names)
        guard !imageAnswers.isEmpty else { return ImageAnswer(title: "Some picture", categoryName: "Creative") }
        return try imageAnswers.removeFirst().get()
    }
}

struct OddError: Error {}

@main struct CategoryTests {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("saved.plist")
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fake = FakeCategorizer()
        let store = ClipboardStore(board: board, file: file)
        let model = ClipboardModel(store: store, categorizer: fake, defaults: defaults)
        model.retryDelay = 0.05

        func settle(_ model: ClipboardModel) async {
            var rounds = 0
            while let task = model.sortingTask {
                await task.value
                rounds += 1
                assert(rounds < 50, "Sorting never finished")
            }
        }
        func copy(_ text: String) async {
            board.clearContents()
            board.setString(text, forType: .string)
            model.poll()
            await settle(model)
        }
        func png(width: Int, height: Int, red: CGFloat) -> Data {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.setColor(NSColor(deviceRed: red, green: 0.2, blue: 0.3, alpha: 1), atX: 0, y: 0)
            return bitmap.representation(using: .png, properties: [:])!
        }
        func copyImage(_ data: Data) async {
            board.clearContents()
            board.setData(data, forType: .png)
            model.poll()
            await settle(model)
        }
        func category(of text: String) -> String? {
            store.entries.first { $0.label == text }?.categoryID
        }

        fake.answers = [.success("Work")]
        await copy("git commit -m \"fix: login\"")
        assert(model.categoriesAvailable)
        assert(model.entries[0].categoryName == "Work")
        assert(store.entries[0].categoryID == "work", "Clips store the id, not the name")
        assert(fake.prompts.count == 1)
        assert(fake.prompts[0].hasPrefix("Copied from "))
        assert(fake.prompts[0].contains("Kind: Text."))
        assert(fake.prompts[0].hasSuffix("git commit -m \"fix: login\""))
        assert(fake.names[0] == ["Work", "Personal", "Creative", "Reference"])
        assert(fake.instructions[0].contains("Work: job or study."))
        assert(fake.instructions[0].contains("Use Reference when nothing else fits."))
        print("PASS: a new text clip is sent to the model once, with every category name and its hint")

        let calls = fake.prompts.count
        await copyImage(png(width: 4, height: 4, red: 0.1))
        assert(model.entries[0].kind == "Image")
        assert(model.entries[0].categoryName == "Creative")
        assert(model.entries[0].title == Clip.imageTitle)
        assert(fake.prompts.count == calls && fake.imageWidths.isEmpty)
        print("PASS: without image vision, images go to Creative with the plain title and no model call")

        fake.canSeeImages = true
        fake.imageAnswers = [.success(ImageAnswer(title: "  \"Login Screen Error.\"  ", categoryName: "Work"))]
        await copyImage(png(width: 3000, height: 1500, red: 0.5))
        assert(fake.imageWidths == [CategoryPrompt.imagePixels], "The model sees a shrunk copy: \(fake.imageWidths)")
        assert(fake.instructions.last!.contains("short title of 2 to 5 words"))
        assert(model.entries[0].title == "Login Screen Error")
        assert(model.entries[0].categoryName == "Work")
        model.query = "screen err"
        assert(model.entries.count == 1 && model.entries[0].kind == "Image", "Search finds the image by its title")
        model.query = ""
        fake.imageAnswers = [.failure(CategorizerFailure.refused)]
        await copyImage(png(width: 8, height: 8, red: 0.9))
        assert(model.entries[0].title == Clip.imageTitle && model.entries[0].categoryName == "Creative")
        fake.imageAnswers = [.success(ImageAnswer(title: "...", categoryName: "Banana"))]
        await copyImage(png(width: 9, height: 9, red: 0.7))
        assert(model.entries[0].title == Clip.imageTitle, "An empty title keeps the plain one")
        assert(model.entries[0].categoryName == "Creative", "A name that is not in the list falls back")
        fake.canSeeImages = false
        print("PASS: with vision, images get a clean model title and category; failures keep today's behaviour")

        assert(ImageTitle.clean("one two three four five six seven") == "one two three four five")
        assert(ImageTitle.clean("A\nB\tC") == "A B C")
        assert(ImageTitle.clean("“Quoted”!") == "Quoted")
        assert(ImageTitle.clean("") == nil && ImageTitle.clean("  . , ") == nil)
        assert(ImageTitle.clean(String(repeating: "x", count: 90))!.count == ImageTitle.maxCharacters)
        assert(ImageTitle.clean("Café 👋🏽 menu") == "Café 👋🏽 menu")
        print("PASS: image titles are one line, at most 5 words and 40 characters, with no quotes")

        let beforeRefusal = fake.prompts.count
        fake.answers = [.failure(CategorizerFailure.refused), .success("Work")]
        await copy("something the model refuses")
        assert(category(of: "something the model refuses") == "reference")
        fake.answers = [.failure(OddError()), .success("Work")]
        await copy("something that breaks the model")
        assert(category(of: "something that breaks the model") == "reference")
        fake.answers = [.success("Banana")]
        await copy("an answer outside the list")
        assert(category(of: "an answer outside the list") == "reference")
        assert(fake.prompts.count == beforeRefusal + 3, "A refusal is final; the model is not asked again")
        fake.answers = []
        print("PASS: a refusal, an unknown error or a made-up name falls back to Reference")

        fake.answers = [.failure(CategorizerFailure.retryLater), .failure(CategorizerFailure.retryLater), .success("Personal")]
        let before = fake.prompts.count
        await copy("dinner with mum on friday")
        assert(category(of: "dinner with mum on friday") == "personal")
        assert(fake.prompts.count == before + 3)
        print("PASS: a busy model is asked again later until it answers")

        fake.answers = [.success("Creative")]
        let repeated = fake.prompts.count
        await copy("git commit -m \"fix: login\"")
        assert(category(of: "git commit -m \"fix: login\"") == "work")
        assert(fake.prompts.count == repeated)
        fake.answers = []
        print("PASS: copying the same content again keeps its category and skips the model")

        let long = String(repeating: "é", count: 5_000)
        await copy(long)
        assert(fake.prompts.last!.filter { $0 == "é" }.count == CategoryPrompt.maxCharacters)
        print("PASS: the model reads at most \(CategoryPrompt.maxCharacters) characters of a clip")

        model.selectCategory("work")
        assert(model.entries.map(\.categoryName) == ["Work", "Work"])
        model.filter = .images
        assert(model.entries.count == 1, "Images plus Work is the one work screenshot")
        model.filter = .text
        model.query = "login"
        assert(model.entries.count == 1)
        model.query = "dinner"
        assert(model.entries.isEmpty)
        model.query = ""
        model.filter = .all
        model.selectCategory("work")
        assert(model.categoryID == "work", "Tapping the chosen tab again keeps it")
        model.selectCategory(nil)
        assert(model.categoryID == nil && model.entries.count == store.entries.count, "All clears the filter")
        print("PASS: a category tab filters together with the toggle and search, and All clears it")

        let work = store.entries.first { $0.categoryID == "work" && $0.kind == "Text" }!
        let titled = store.entries.first { $0.title == "Login Screen Error" }!
        assert(store.toggleSaved(id: work.id) && store.toggleSaved(id: titled.id))
        model.shutdown()
        let reopened = ClipboardStore(board: board, file: file)
        assert(reopened.savedEntries.count == 2)
        assert(reopened.savedEntries.contains { $0.categoryID == "work" && $0.kind == "Text" })
        assert(reopened.savedEntries.contains { $0.title == "Login Screen Error" }, "Saved images keep their title")
        reopened.shutdown()
        print("PASS: saved items keep their category and image title across launches")

        var raw = try PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as! [[String: Any]]
        // Saving inserts at the top, so the image is first and the text second.
        raw[0]["category"] = "Banana"
        raw[1]["category"] = "Personal"
        try PropertyListSerialization.data(fromPropertyList: raw, format: .binary, options: 0).write(to: file)
        let old = ClipboardStore(board: board, file: file)
        assert(old.savedEntries[1].categoryID == "personal", "1.2 files stored the name; it maps to the id")
        let second = FakeCategorizer()
        second.canSeeImages = true
        second.imageAnswers = [.success(ImageAnswer(title: "New Title", categoryName: "Reference"))]
        let relaunched = ClipboardModel(store: old, categorizer: second, defaults: defaults)
        await settle(relaunched)
        assert(second.names.count == 1, "Only the unknown one is sorted again")
        assert(old.savedEntries[0].categoryID == "reference")
        assert(old.savedEntries[0].title == "Login Screen Error", "A title, once written, is kept")
        relaunched.shutdown()
        print("PASS: old stored names still load, and an unknown category is sorted again at launch")

        try await editingTests(directory: directory)
        try await offlineTests(directory: directory)
    }

    /// Renaming, adding, removing and moving categories through the edit sheet's draft.
    @MainActor static func editingTests(directory: URL) async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fake = FakeCategorizer()
        let store = ClipboardStore(board: board, file: directory.appendingPathComponent("edit.plist"))
        let model = ClipboardModel(store: store, categorizer: fake, defaults: defaults)
        func settle() async {
            while let task = model.sortingTask {
                await task.value
            }
        }
        func copy(_ text: String, answer: String) async {
            fake.answers = [.success(answer)]
            board.clearContents()
            board.setString(text, forType: .string)
            model.poll()
            await settle()
        }
        func edit(_ change: (inout CategoryDraft) -> Void) async {
            model.editCategories()
            change(&model.categoryDraft!)
            model.saveCategoryDraft()
            await settle()
        }
        await copy("standup notes", answer: "Work")
        await copy("rent is due", answer: "Personal")
        let asked = fake.prompts.count

        model.selectCategory("work")
        await edit { $0.rename(id: "work", to: "  Job  ") }
        assert(model.categoryDraft == nil, "Done closes the sheet")
        assert(model.entries.map(\.categoryName) == ["Job"], "A rename keeps clips in place")
        assert(model.categoryID == "work", "and keeps the chosen tab")
        assert(fake.prompts.count == asked, "A rename sorts nothing again")
        await copy("deploy script", answer: "Job")
        assert(fake.names.last == ["Job", "Personal", "Creative", "Reference"])
        assert(!fake.instructions.last!.contains("job or study"), "A renamed starter loses its hint")
        print("PASS: renaming trims the name, keeps every clip, and the model sees the new name")

        await edit { $0.move(id: "reference", to: 0) }
        assert(model.categoryList.categories.map(\.id) == ["reference", "work", "personal", "creative"])
        assert(fake.prompts.count == asked + 1, "Moving sorts nothing again")
        print("PASS: moving a category changes the order only")

        let beforeAdd = fake.prompts.count
        var added = ""
        await edit { draft in
            added = draft.add()!
            draft.rename(id: added, to: "Recipes")
        }
        assert(model.categoryList.categories.last?.name == "Recipes")
        assert(fake.prompts.count == beforeAdd + 3, "Adding sorts every clip again")
        assert(fake.names.last!.contains("Recipes"))
        print("PASS: adding a category sorts every clip again with the new name")

        await edit { $0.remove(id: "work") }
        assert(model.categoryID == nil, "Removing the chosen category goes back to All")
        assert(!model.categoryList.ids.contains("work"))
        assert(store.entries.allSatisfy { $0.categoryID != "work" })
        print("PASS: removing a category sorts again and clears a filter on it")

        await edit { $0.remove(id: "creative") }
        board.clearContents()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        board.setData(bitmap.representation(using: .png, properties: [:])!, forType: .png)
        model.poll()
        await settle()
        assert(store.entries[0].categoryID == ClipCategory.noneID, "Without Creative, images get no category")
        assert(model.entries[0].categoryName == nil)
        await edit { $0.remove(id: "reference") }
        fake.answers = [.failure(CategorizerFailure.refused)]
        board.clearContents()
        board.setString("refused without reference", forType: .string)
        model.poll()
        await settle()
        assert(store.entries[0].categoryID == ClipCategory.noneID)
        let calls = fake.prompts.count
        model.reload()
        model.sortNext()
        await settle()
        assert(fake.prompts.count == calls, "A clip with no category is not sent again")
        print("PASS: with Creative or Reference removed, the fallback is no category, sorted only once")

        fake.delay = 0.3
        fake.answers = [.success("Personal")]
        board.clearContents()
        board.setString("slow answer", forType: .string)
        model.poll()
        assert(model.sortingTask != nil)
        let oldTask = model.sortingTask!
        let oldQuestions = fake.prompts.count
        while fake.prompts.count == oldQuestions {
            await Task.yield()
        }
        fake.delay = 0
        // The old question is out. The newest clip is asked first again, so the new list's answer for it is Travel.
        fake.answers = [.success("Travel")]
        await edit { draft in
            let id = draft.add()!
            draft.rename(id: id, to: "Travel")
        }
        await oldTask.value
        await settle()
        let travel = model.categoryList.categories.first { $0.name == "Travel" }!
        assert(store.entries[0].label == "slow answer")
        assert(store.entries[0].categoryID == travel.id, "The late answer about the old list is dropped")
        assert(store.entries.allSatisfy { $0.categoryID != nil }, "Everything is sorted for the new list")
        print("PASS: an answer about the old list is dropped and sorting starts over")

        model.retryDelay = 0.3
        fake.answers = [.failure(CategorizerFailure.retryLater)]
        board.clearContents()
        board.setString("busy then edited", forType: .string)
        model.poll()
        await model.sortingTask!.value
        assert(model.sortingTask != nil, "A retry is waiting")
        // The model said busy; a retry is now waiting. Changing the list must cancel it for good.
        fake.delay = 0.1
        let before = fake.prompts.count
        await edit { draft in
            let id = draft.add()!
            draft.rename(id: id, to: "Garden")
        }
        try? await Task.sleep(for: .seconds(0.5))
        await settle()
        fake.delay = 0
        model.retryDelay = 0.05
        let textClips = store.entries.filter { $0.kind != "Image" }.count
        assert(fake.prompts.count - before == textClips, "Each clip is asked once: \(fake.prompts.count - before) for \(textClips)")
        print("PASS: a waiting retry from before an edit never starts a second sort")

        model.editCategories()
        model.categoryDraft!.rename(id: added, to: "")
        model.saveCategoryDraft()
        assert(model.categoryDraft != nil, "Done waits while a name is empty")
        model.cancelCategoryDraft()
        assert(model.categoryList.categories.contains { $0.name == "Recipes" }, "Escape throws the draft away")
        model.editCategories()
        model.categoryDraft!.allIsLast = true
        model.saveCategoryDraft()
        model.shutdown()
        let relaunched = ClipboardModel(store: ClipboardStore(board: board, file: directory.appendingPathComponent("edit2.plist")), categorizer: nil, defaults: defaults)
        assert(relaunched.categoryList == model.categoryList, "The list and All's place survive a relaunch")
        assert(relaunched.categoryList.allIsLast)
        relaunched.shutdown()
        print("PASS: Done waits on a bad name, Escape discards, and the list survives a relaunch")
    }

    @MainActor static func offlineTests(directory: URL) async throws {
        let offline = FakeCategorizer()
        offline.isAvailable = false
        let quietBoard = NSPasteboard.withUniqueName()
        defer { quietBoard.releaseGlobally() }
        let quietStore = ClipboardStore(board: quietBoard, file: directory.appendingPathComponent("quiet.plist"))
        let quiet = ClipboardModel(store: quietStore, categorizer: offline, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        quietBoard.clearContents()
        quietBoard.setString("hello", forType: .string)
        quiet.poll()
        assert(quiet.sortingTask == nil)
        assert(!quiet.categoriesAvailable)
        quiet.selectCategory("work")
        assert(quiet.entries.count == 1)
        assert(offline.prompts.isEmpty)
        let none = ClipboardModel(store: quietStore, categorizer: nil, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        assert(!none.categoriesAvailable)
        print("PASS: without Apple Intelligence nothing is sent and the category filter is ignored")

        quietBoard.clearContents()
        quietBoard.setString("sorted after clear", forType: .string)
        offline.isAvailable = true
        quiet.poll()
        assert(quiet.sortingTask != nil)
        quiet.clear()
        while let task = quiet.sortingTask {
            await task.value
        }
        assert(quiet.entries.isEmpty)
        quiet.shutdown()
        print("PASS: clearing history while a clip is being sorted is safe")
    }
}
