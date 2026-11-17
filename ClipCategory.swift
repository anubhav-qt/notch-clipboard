import Foundation

/// One group clips are sorted into. Clips remember the id, so a rename keeps them in place.
struct ClipCategory: Equatable, Codable {
    let id: String
    var name: String

    static let work = ClipCategory(id: "work", name: "Work")
    static let personal = ClipCategory(id: "personal", name: "Personal")
    static let creative = ClipCategory(id: "creative", name: "Creative")
    static let reference = ClipCategory(id: "reference", name: "Reference")

    /// What a new install starts with.
    static let starters = [work, personal, creative, reference]

    /// Marks a clip that was sorted but fits no category, so it is not sent again.
    static let noneID = "none"

    static let maxCount = 10
    static let maxNameLength = 20

    /// The starter categories explain themselves to the model, but only while
    /// their name is unchanged. A renamed or new category is sent as its name alone.
    var hint: String? {
        guard let starter = Self.starters.first(where: { $0.id == id }), starter.name == name else { return nil }
        switch id {
        case Self.work.id:
            return "job or study. Code, terminal commands, error messages, work documents, emails, tickets, meeting notes."
        case Self.personal.id:
            return "the user's own life. Messages to friends or family, addresses, phone numbers, plans, shopping lists, bills, rent, health."
        case Self.creative.id:
            return "making things. Drafts, ideas, quotes, stories, poems, design notes, colour codes like #FF7A6B, images."
        case Self.reference.id:
            return "kept to look up later. Links, facts, definitions, how-tos, numbers with no clear owner."
        default:
            return nil
        }
    }

    /// Older saved files stored the name ("Work") instead of the id ("work").
    static func id(fromStored value: String) -> String {
        if let starter = starters.first(where: { $0.name == value }) {
            return starter.id
        }
        return value
    }
}
