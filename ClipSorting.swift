import AppKit

/// What came back from the model for one clip.
enum SortResult {
    case answer(categoryName: String, title: String?)
    case retryLater
    case refused
}

/// Sorting clips into categories in the background, newest first, one at a time.
extension ClipboardModel {
    /// Sorts the newest unsorted clip, then the next, until none are left.
    func sortNext() {
        guard let store, let categorizer, sortingTask == nil, categorizer.isAvailable else { return }
        var changed = false
        while let entry = store.nextUnsorted(validIDs: categoryList.ids) {
            if entry.kind != "Image" {
                sortText(entry, with: categorizer)
                break
            }
            if categorizer.canSeeImages, let image = smallImage(for: entry) {
                sortImage(entry, image: image, with: categorizer)
                break
            }
            // macOS 26, or a picture that will not decode: no model, just the fallback.
            store.setCategory(fallbackID(forKind: entry.kind), id: entry.id)
            changed = true
        }
        if changed {
            reload()
        }
    }

    /// Forgets every category and starts over, dropping any answer still on its way.
    func sortEverythingAgain() {
        sortingVersion += 1
        sortingTask?.cancel()
        sortingTask = nil
        store?.resetCategories()
        sortNext()
    }

    /// Where a clip goes when the model can't or won't sort it: images to Creative,
    /// everything else to Reference. If that category was removed, no category.
    func fallbackID(forKind kind: String) -> String {
        var wanted = ClipCategory.reference.id
        if kind == "Image" {
            wanted = ClipCategory.creative.id
        }
        if categoryList.ids.contains(wanted) {
            return wanted
        }
        return ClipCategory.noneID
    }

    private func smallImage(for entry: ClipboardEntry) -> CGImage? {
        guard let data = entry.imageData else { return nil }
        return Self.makeSmallImage(from: data, maxPixelSize: CategoryPrompt.imagePixels)
    }

    private func sortText(_ entry: ClipboardEntry, with categorizer: ClipCategorizer) {
        let id = entry.id
        let kind = entry.kind
        let version = sortingVersion
        let prompt = CategoryPrompt.text(for: entry)
        let instructions = CategoryPrompt.textInstructions(for: categoryList.categories)
        let names = categoryList.categories.map(\.name)
        sortingTask = Task { [weak self] in
            var result = SortResult.refused
            do {
                let name = try await categorizer.category(for: prompt, instructions: instructions, names: names)
                result = .answer(categoryName: name, title: nil)
            } catch CategorizerFailure.retryLater {
                result = .retryLater
            } catch {
                // Refused or an unknown error: the fallback, so one clip can never block the rest.
                result = .refused
            }
            self?.finishSorting(id: id, kind: kind, version: version, result: result)
        }
    }

    private func sortImage(_ entry: ClipboardEntry, image: CGImage, with categorizer: ClipCategorizer) {
        let id = entry.id
        let kind = entry.kind
        let version = sortingVersion
        let instructions = CategoryPrompt.imageInstructions(for: categoryList.categories)
        let names = categoryList.categories.map(\.name)
        sortingTask = Task { [weak self] in
            var result = SortResult.refused
            do {
                let answer = try await categorizer.describeImage(image, instructions: instructions, names: names)
                result = .answer(categoryName: answer.categoryName, title: ImageTitle.clean(answer.title))
            } catch CategorizerFailure.retryLater {
                result = .retryLater
            } catch {
                result = .refused
            }
            self?.finishSorting(id: id, kind: kind, version: version, result: result)
        }
    }

    private func finishSorting(id: String, kind: String, version: Int, result: SortResult) {
        // The category list changed while the model was thinking; a newer job owns sorting now.
        guard version == sortingVersion else { return }
        sortingTask = nil
        guard let store else { return }
        switch result {
        case .retryLater:
            waitThenSortAgain(version: version)
        case .refused:
            store.setCategory(fallbackID(forKind: kind), id: id)
            reload()
            sortNext()
        case .answer(let name, let title):
            var categoryID = fallbackID(forKind: kind)
            if let match = categoryList.categories.first(where: { $0.name == name }) {
                categoryID = match.id
            }
            store.setCategory(categoryID, title: title, id: id)
            reload()
            sortNext()
        }
    }

    /// The model was busy. Try again a little later.
    private func waitThenSortAgain(version: Int) {
        let delay = retryDelay
        sortingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, version == self.sortingVersion else { return }
            self.sortingTask = nil
            self.sortNext()
        }
    }
}
