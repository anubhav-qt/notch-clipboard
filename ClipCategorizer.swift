import CoreGraphics
import Foundation
import FoundationModels
import PDFKit

/// What the model says about one copied image.
struct ImageAnswer: Equatable {
    let title: String
    let categoryName: String
}

/// Sorts one clip into one of the given category names. Tests swap in a fake.
protocol ClipCategorizer {
    var isAvailable: Bool { get }
    /// True when the model can look at pictures (macOS 27 with vision).
    var canSeeImages: Bool { get }
    func category(for prompt: String, instructions: String, names: [String]) async throws -> String
    func describeImage(_ image: CGImage, instructions: String, names: [String]) async throws -> ImageAnswer
}

/// How a request can fail, so the model knows whether to try again.
enum CategorizerFailure: Error {
    /// The model will not sort this clip, so it gets the fallback.
    case refused
    /// The model is busy or not ready; the same clip is tried again later.
    case retryLater
}

/// What the on-device model reads for each clip.
enum CategoryPrompt {
    static let maxCharacters = 1_500
    /// Images are shrunk to this many pixels on the long side before the model sees them.
    static let imagePixels = 768

    /// One line per category, in the user's order, plus the tie-break rules.
    static func instructions(for categories: [ClipCategory], subject: String) -> String {
        var lines = ["You sort \(subject) into exactly one of \(categories.count) groups by purpose. Ask: where would the user look for this later?"]
        for category in categories {
            if let hint = category.hint {
                lines.append("\(category.name): \(hint)")
            } else {
                lines.append("\(category.name)")
            }
        }
        lines.append("If two groups fit, choose the one listed first.")
        if let reference = categories.first(where: { $0.id == ClipCategory.reference.id }) {
            lines.append("Use \(reference.name) when nothing else fits.")
        }
        return lines.joined(separator: "\n")
    }

    static func textInstructions(for categories: [ClipCategory]) -> String {
        instructions(for: categories, subject: "clipboard items")
    }

    static func imageInstructions(for categories: [ClipCategory]) -> String {
        let sorting = instructions(for: categories, subject: "copied images and screenshots")
        return sorting + "\nAlso give the image a short title of 2 to 5 words that says what it shows."
    }

    static func text(for entry: ClipboardEntry) -> String {
        var body = entry.label
        if entry.kind == "Files" {
            body = fileNames(in: entry).joined(separator: "\n")
        }
        if entry.kind == "PDF" {
            body = pdfText(in: entry) ?? entry.label
        }
        let short = String(body.prefix(maxCharacters))
        return "Copied from \(entry.source). Kind: \(entry.kind).\n\n\(short)"
    }

    private static func fileNames(in entry: ClipboardEntry) -> [String] {
        var names: [String] = []
        for item in entry.items {
            for representation in item.representations where representation.type == "public.file-url" {
                guard let path = String(data: representation.data, encoding: .utf8) else { continue }
                guard let url = URL(string: path) else { continue }
                names.append(url.lastPathComponent)
            }
        }
        if names.isEmpty {
            names.append(entry.label)
        }
        return names
    }

    private static func pdfText(in entry: ClipboardEntry) -> String? {
        for item in entry.items {
            for representation in item.representations where representation.type == "com.adobe.pdf" {
                guard let document = PDFDocument(data: representation.data) else { continue }
                guard let text = document.string, !text.isEmpty else { continue }
                return text
            }
        }
        return nil
    }
}

/// Tidies a model-written image title: one line, no quotes, at most 5 words and 40 characters.
enum ImageTitle {
    static let maxWords = 5
    static let maxCharacters = 40

    static func clean(_ raw: String) -> String? {
        let unwanted = CharacterSet(charactersIn: "\"'“”‘’`.,:;!?")
        var words: [String] = []
        for word in raw.components(separatedBy: .whitespacesAndNewlines) {
            let trimmed = word.trimmingCharacters(in: unwanted)
            if !trimmed.isEmpty {
                words.append(trimmed)
            }
        }
        let title = words.prefix(maxWords).joined(separator: " ")
        if title.isEmpty {
            return nil
        }
        return String(title.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces)
    }
}

/// Apple's on-device model, when this Mac has it switched on.
func makeAppleCategorizer() -> ClipCategorizer? {
    if #available(macOS 26.0, *) {
        return AppleCategorizer()
    }
    return nil
}

@available(macOS 26.0, *)
struct AppleCategorizer: ClipCategorizer {
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var canSeeImages: Bool {
        if #available(macOS 27.0, *) {
            return SystemLanguageModel.default.capabilities.contains(.vision)
        }
        return false
    }

    func category(for prompt: String, instructions: String, names: [String]) async throws -> String {
        // A fresh session per clip, so one clip never sways the next.
        let session = LanguageModelSession(instructions: instructions)
        do {
            let schema = try GenerationSchema(root: Self.choice(of: names), dependencies: [])
            let answer = try await session.respond(to: prompt, schema: schema, options: Self.options)
            return try answer.content.value(String.self)
        } catch {
            throw Self.failure(for: error)
        }
    }

    func describeImage(_ image: CGImage, instructions: String, names: [String]) async throws -> ImageAnswer {
        guard #available(macOS 27.0, *) else { throw CategorizerFailure.refused }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let schema = try GenerationSchema(root: Self.imageInfo(names: names), dependencies: [])
            let answer = try await session.respond(schema: schema, options: Self.options) {
                "Give this copied image a short title and one group."
                Attachment(image)
            }
            let title = try answer.content.value(String.self, forProperty: "title")
            let category = try answer.content.value(String.self, forProperty: "category")
            return ImageAnswer(title: title, categoryName: category)
        } catch {
            throw Self.failure(for: error)
        }
    }

    private static let options = GenerationOptions(samplingMode: .greedy)

    /// Guided generation: the model can only answer one of these names.
    private static func choice(of names: [String]) -> DynamicGenerationSchema {
        DynamicGenerationSchema(name: "Category", anyOf: names)
    }

    private static func imageInfo(names: [String]) -> DynamicGenerationSchema {
        let title = DynamicGenerationSchema.Property(
            name: "title",
            description: "2 to 5 words saying what the image shows",
            schema: DynamicGenerationSchema(type: String.self))
        let category = DynamicGenerationSchema.Property(name: "category", schema: choice(of: names))
        return DynamicGenerationSchema(name: "ImageInfo", properties: [title, category])
    }

    /// Busy or not ready means try again later. Anything else means this clip is refused.
    private static func failure(for error: Error) -> CategorizerFailure {
        if #available(macOS 27.0, *) {
            if let modern = error as? LanguageModelError {
                return failure(forModern: modern)
            }
        }
        if let older = error as? LanguageModelSession.GenerationError {
            return failure(forOlder: older)
        }
        return .refused
    }

    @available(macOS 27.0, *)
    private static func failure(forModern error: LanguageModelError) -> CategorizerFailure {
        switch error {
        case .rateLimited, .timeout:
            return .retryLater
        default:
            return .refused
        }
    }

    private static func failure(forOlder error: LanguageModelSession.GenerationError) -> CategorizerFailure {
        switch error {
        case .rateLimited, .concurrentRequests, .assetsUnavailable:
            return .retryLater
        default:
            return .refused
        }
    }
}
