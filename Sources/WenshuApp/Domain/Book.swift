// Book.swift · Wenshu (Wenshu) · v0.02.1 (book module) + v52 (new-book wizard)
//
// Domain model for a single book (= a novel the user is writing).
// v0.02.1 ships just the book + its persistence; chapter content
// (= .md files inside the book's directory) lands in v0.03.0 alongside
// the EDITOR module.
//
// v52: adds `length` (BookLength enum) + `idea` (optional String) for
// the New Book Creation Wizard (= 8/15 17:32 ',,
// '). Both fields have defaults + Codable back-compat (= v0.02.x
// book.json files without these keys still decode).
//
// (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
// Owner 8/15 15:55: 'needok,, refactor
// BookTests.swift`. Adding any required field forces the architectural
// decision to surface (= not just an incidental change in some file).
//
// Storage layout (= Apple HIG document-based app convention, building
// on the v0.02.0 shelf layout):
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json
//     books/<book-id-uuid>/
// book.json             ← encoded Book (this file; includes length +
//                       idea since v52)
//       chapters/<chapter-id-uuid>.md  (v0.03.0)
//
// id == directory name (= UUID string) so renames don't break the
// filesystem identity (= Apple HIG: URL = identity, name = label).

import Foundation

/// Book length = the scope the user commits to when creating a new
/// book. v52 introduced this (= 8/15 17:32 '). Drives
/// later chapter management (= v0.03.0 chapter list reads the length
/// to suggest word-count targets + chapter split heuristics). Three
/// cases, allCases-ordered (= Picker in the wizard renders in this
/// order: / in progress /).
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
        case .short:  return "短篇"
        case .medium: return "中篇"
        case .long:   return "长篇"
        }
    }
}

struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    /// Author name; empty string = no author specified (= wenshu doesn't
    /// require one; we just record whatever the user types).
    var author: String
    /// v0.30 boss 8/31 OOB: user-picked Lucide icon name for the
    /// sidebar display. Optional for backward compat (= existing
    /// books default to "book" via `displayIcon`). Mirrors the
    /// Bookshelf.icon pattern (= same shape, same fallback).
    var icon: String?
    /// Parent bookshelf (= filesystem constraint: the book's directory
    /// must live under its parent shelf's `books/`). Required at init so
    /// no orphan books ever land on disk.
    let shelfId: UUID
    /// v52: declared length at creation. Defaults to `.medium` (= the
    /// most common case; the wizard always sets a value, but defaults
    /// exist for Codable back-compat with v0.02.x book.json files).
    var length: BookLength
    /// v52: the user's one-line story idea. Optional (= the wizard
    /// presents it as ' / optional). nil = not provided.
    var idea: String?
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filesystem directory name (= UUID string form). Stable across
    /// rename (= Apple HIG document-based app: id is the filesystem
    /// identity, title is just the display label).
    var directoryName: String {
        id.uuidString
    }

    /// v0.30 boss 8/31 OOB: book icon for sidebar display. Returns
    /// `icon` if set, otherwise the default "book" icon.
    ///
    /// v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide, use SF
    /// Symbols 6': `icon` may still hold a Lucide-era kebab-case name
    /// (= legacy user data persisted in book.json). Fall back to a
    /// generic SF Symbol 6 icon if the stored name isn't a known SF
    /// Symbol (= boss 'ensure display' rule; = users see a real icon
    /// instead of a blank frame until they pick a new one).
    ///
    /// v1.0.0-m1-shell boss 2026-09-15 OOB 'use outline uniformly':
    /// default returns outline (= non-.fill) icons.
    var displayIcon: String {
        guard let icon, !icon.isEmpty else { return "book" }
        // Legacy Lucide names (= kebab-case with hyphens) are not
        // valid SF Symbol identifiers; = replace with the closest
        // semantic match.
        if icon.contains("-") {
            return lucideFallbackForBookIcon(icon) ?? "book"
        }
        return icon
    }

    // id-based identity (= Apple HIG document-based convention).
    // Renaming changes `title` but NOT `id`, so `book == book` still
    // holds across renames (critical for SwiftUI List diffing,
    // @Observable change detection, and selection identity in
    // WenshuLibrary).
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Codable back-compat (v52)
    //
    // v0.02.x book.json files don't have 'length' or 'idea' (= fields
    // added in v52). Synthesized Codable would fail to decode them
    // (= keysNotFound). Override init(from:) to provide defaults for
    // missing keys. New fields added in v0.04+ (= synopsis, character
    // list, etc.) should follow the same pattern.

    private enum CodingKeys: String, CodingKey {
        case id, title, author, icon, shelfId, length, idea, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let title = try c.decode(String.self, forKey: .title)
        let author = try c.decode(String.self, forKey: .author)
        let shelfId = try c.decode(UUID.self, forKey: .shelfId)
        let length = try c.decodeIfPresent(BookLength.self, forKey: .length) ?? .medium
        let idea = try c.decodeIfPresent(String.self, forKey: .idea)
        let icon = try c.decodeIfPresent(String.self, forKey: .icon)  // v0.30 boss OOB: optional
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
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide, use SF
// Symbols 6': map the most common Lucide-era book icon names to
// the closest SF Symbols 6 equivalent (= boss 'ensure display'
// rule; = users with legacy persisted icons see a real glyph
// instead of a blank frame). Returns nil for unrecognized names
// (= caller falls back to the default 'book.fill').
//
// Mapping source: SF Symbols Beta CLI (/Applications/SF Symbols
// Beta.app/Contents/Executables/sfsymbols search) verified 2026-09-15.
func lucideFallbackForBookIcon(_ lucideName: String) -> String? {
    switch lucideName {
    case "book":                   return "book"
    case "book-open":              return "book.pages"
    case "book-plus":              return "book.badge.plus"
    case "book-text":              return "text.book.closed"
    case "library", "library-big": return "books.vertical"
    case "square-library":         return "books.vertical"
    case "notebook":               return "book"
    case "scroll":                 return "scroll"
    default:                       return nil
    }
}