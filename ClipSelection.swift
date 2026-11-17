import Foundation

/// The two kinds of clip that Select mode can pick. They never mix.
enum PickGroup {
    case text
    case image

    static func of(kind: String) -> PickGroup? {
        switch kind {
        case "Text", "Link":
            return .text
        case "Image":
            return .image
        default:
            return nil
        }
    }
}

/// The clips picked in Select mode, in the order they were tapped.
struct ClipSelection: Equatable {
    enum Outcome: Equatable {
        case picked
        case unpicked
        case blocked(String)
    }

    static let imagesBlocked = "Images can't be selected with text"
    static let textBlocked = "Text can't be selected with images"
    static let otherBlocked = "Only text and images can be selected"

    private(set) var ids: [String] = []
    /// Set by the first pick; nil while nothing is picked.
    private(set) var group: PickGroup?

    /// Tapping a picked clip unpicks it. A clip of the other kind is refused with a note.
    mutating func toggle(id: String, kind: String) -> Outcome {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
            if ids.isEmpty {
                group = nil
            }
            return .unpicked
        }
        guard let tapped = PickGroup.of(kind: kind) else {
            return .blocked(Self.otherBlocked)
        }
        if let group, group != tapped {
            return .blocked(Self.note(blocking: tapped))
        }
        ids.append(id)
        group = tapped
        return .picked
    }

    /// The paste position shown in the row's box, starting at 1.
    func number(of id: String) -> Int? {
        guard let index = ids.firstIndex(of: id) else { return nil }
        return index + 1
    }

    /// Rows that can't join the current picks are shown dimmed.
    func isDimmed(kind: String) -> Bool {
        guard let tapped = PickGroup.of(kind: kind) else { return true }
        guard let group else { return false }
        return group != tapped
    }

    /// Drops picks whose clips are gone, for example after Clear History.
    mutating func keep(only existing: Set<String>) {
        ids.removeAll { !existing.contains($0) }
        if ids.isEmpty {
            group = nil
        }
    }

    /// Picked text joined with one space. Each piece is trimmed and blank pieces are skipped.
    static func join(_ pieces: [String]) -> String {
        var kept: [String] = []
        for piece in pieces {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                kept.append(trimmed)
            }
        }
        return kept.joined(separator: " ")
    }

    private static func note(blocking tapped: PickGroup) -> String {
        switch tapped {
        case .image:
            return imagesBlocked
        case .text:
            return textBlocked
        }
    }
}
