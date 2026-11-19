// Book.swift · Wenshu (Wenshu).1 (book module) + v52 (new-book wizard)
//
// Domain model for a single book (= a novel the user is writing).
// ships just the book + its persistence; chapter content
// (= .md files inside the book's directory) lands in alongside
// the EDITOR module.
//
// v52: adds `length` (BookLength enum) + `idea` (optional String) for
// the New Book Creation Wizard. Both fields have defaults + Codable
// back-compat (= book.json files without these keys still
// decode).
//
// Adding any required field forces the architectural decision to
// surface (= not just an incidental change in some file).
//
// Storage layout (= Apple HIG document-based app convention, building
// on the shelf layout):
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json
//     books/<book-id-uuid>/
// book.json             ← encoded Book (this file; includes length +
//                       idea since v52)
//       chapters/<chapter-id-uuid>.md  (current)
//
// id == directory name (= UUID string) so renames don't break the
// filesystem identity (= Apple HIG: URL = identity, name = label).

import Foundation

/// Book length = the scope the user commits to when creating a new
/// book. Drives later chapter management (= chapter list
/// reads the length to suggest word-count targets + chapter split
/// heuristics). Three cases, allCases-ordered (= Picker in the wizard
/// renders in this order: short / medium / long).
enum BookLength: String, CaseIterable, Codable, Sendable {
    case short
    case medium
    case long

    /// Chinese display name for the wizard Picker. Apple HIG Picker
    /// labels are short, single-line (= the system spec example uses
    /// 'Short / Medium / Long' verbatim; we match the wenshu in progress
    /// design vocabulary).
    var displayName: String {
        switch self {
        case .short: return "短篇"
        case .medium: return "中篇"
        case .long: return "长篇"
        }
    }
}

struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    /// Author name; empty string = no author specified (= wenshu doesn't
    /// require one; we just record whatever the user types).
    var author: String
    /// User-picked SF Symbols 6 icon name (= dot.case identifier,
    /// e.g. "book.pages") for the sidebar display. Optional
    /// (= nil = default "book" glyph via `displayIcon`). Mirrors
    /// the Bookshelf.icon pattern (= same shape, same default).
    var icon: String?
    /// Parent bookshelf (= filesystem constraint: the book's directory
    /// must live under its parent shelf's `books/`). Required at init so
    /// no orphan books ever land on disk.
    let shelfId: UUID
    /// v52: declared length at creation. Defaults to `.medium` (= the
    /// most common case; the wizard always sets a value, but defaults
    /// exist for Codable back-compat with book.json files).
    var length: BookLength
    /// v52: the user's one-line story idea. Optional (= the wizard
    /// presents it as ' / optional). nil = not provided.
    var idea: String?
    /// The book's style sheet: = ONE style set runs through the whole
    /// book, = and every adjustment acts on the whole book. Optional
    /// (= nil = the book reads `BookStyleSheet.default`, = the measured
    /// print baseline), = and that is what keeps a book.json written
    /// before the sheet existed decodable.
    var styleSheet: BookStyleSheet?
    /// The book's OWN sheet, = kept apart from `styleSheet` so the two
    /// named sets stay switchable without losing the tuning.
    ///
    /// WHY A SECOND SHEET AND NOT ONE
    ///
    /// A set is a WHOLE sheet, = so choosing General overwrites every
    /// position the reader had moved. = The reader's own tuning therefore
    /// needs a place of its own: = it is written whenever the sheet sits
    /// at none of the sets (= `BookStyleSheetWriteBack`), = and it comes
    /// back when the reader chooses Custom again (= the boss's rule: = a
    /// book tuned, = set to General, = then set back to Custom reads the
    /// tuning it had, = not the set it passed through).
    var customStyleSheet: BookStyleSheet?
    /// The place the reader put the switcher (= a `BookStyleSelection`'s
    /// own identifier, = or nil when the reader never touched it).
    ///
    /// WHY THE PLACE NEEDS ITS OWN RECORD
    ///
    /// The sheet cannot tell Custom from the set it happens to look like:
    /// = a book with no tuning sent to Custom is shown the general set's
    /// sheet (= the boss's ruling of 2026-11-19), = and reading the place
    /// off that sheet answers "General", = so the segment springs back on
    /// the click that chose Custom. = The click has to stick, = because a
    /// control that refuses to move is what a reader calls a bug.
    var styleSelectionIdentifier: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        icon: String? = nil,
        shelfId: UUID,
        length: BookLength = .medium,
        idea: String? = nil,
        styleSheet: BookStyleSheet? = nil,
        customStyleSheet: BookStyleSheet? = nil,
        styleSelectionIdentifier: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.icon = icon
        self.shelfId = shelfId
        self.length = length
        self.idea = idea
        self.styleSheet = styleSheet
        self.customStyleSheet = customStyleSheet
        self.styleSelectionIdentifier = styleSelectionIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filesystem directory name (= UUID string form). Stable across
    /// rename (= Apple HIG document-based app: id is the filesystem
    /// identity, title is just the display label).
    var directoryName: String {
        id.uuidString
    }

    /// The style sheet this book READS: = its own sheet when it has one,
    /// = and the measured print baseline when it does not. = Every reader
    /// asks this, = so a book without a stored sheet and a book with one
    /// cannot disagree about what the book looks like.
    var effectiveStyleSheet: BookStyleSheet {
        styleSheet ?? .default
    }

    /// The place the reader put the switcher, = as the choice itself.
    ///
    /// nil when the book recorded nothing, = which is every book written
    /// before the switcher recorded places (= and the page reads those
    /// off the sheet).
    var styleSelection: BookStyleSelection? {
        get {
            guard let styleSelectionIdentifier else { return nil }
            return BookStyleSelection(persistedIdentifier: styleSelectionIdentifier)
        }
        set { styleSelectionIdentifier = newValue?.persistedIdentifier }
    }

    /// Book icon for sidebar display. Returns `icon` if set,
    /// otherwise the default "book" icon (outline-only).
    var displayIcon: String {
        guard let icon, !icon.isEmpty else { return "book" }
        return icon
    }

    /// id-based identity (= Apple HIG document-based convention).
    /// Renaming changes `title` but NOT `id`, so `book == book` still
    /// holds across renames (critical for SwiftUI List diffing,
    /// @Observable change detection, and selection identity in
    /// WenshuLibrary).
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Codable back-compat (v52)

    //
    // x book.json files don't have 'length' or 'idea' (= fields
    // added in v52). Synthesized Codable would fail to decode them
    // (= keysNotFound). Override init(from:) to provide defaults for
    // missing keys. New fields added in (= synopsis, character
    // list, etc.) should follow the same pattern.

    private enum CodingKeys: String, CodingKey {
        case id, title, author, icon, shelfId, length, idea, styleSheet, customStyleSheet,
             styleSelectionIdentifier, createdAt,
             updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let title = try c.decode(String.self, forKey: .title)
        let author = try c.decode(String.self, forKey: .author)
        let shelfId = try c.decode(UUID.self, forKey: .shelfId)
        let length = try c.decodeIfPresent(BookLength.self, forKey: .length) ?? .medium
        let idea = try c.decodeIfPresent(String.self, forKey: .idea)
        let icon = try c.decodeIfPresent(String.self, forKey: .icon)
        let styleSheet = try c.decodeIfPresent(BookStyleSheet.self, forKey: .styleSheet)
        let customStyleSheet = try c.decodeIfPresent(BookStyleSheet.self, forKey: .customStyleSheet)
        let styleSelectionIdentifier = try c.decodeIfPresent(
            String.self,
            forKey: .styleSelectionIdentifier
        )
        let createdAt = try c.decode(Date.self, forKey: .createdAt)
        let updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.init(
            id: id,
            title: title,
            author: author,
            icon: icon,
            shelfId: shelfId,
            length: length,
            idea: idea,
            styleSheet: styleSheet,
            customStyleSheet: customStyleSheet,
            styleSelectionIdentifier: styleSelectionIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
