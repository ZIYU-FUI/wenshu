// Book.swift · Wenshu (Wenshu) · v0.02.1 (book module) + v52 (new-book wizard)
//
// Domain model for a single book (= a novel the user is writing).
// v0.02.1 ships just the book + its persistence; chapter content
// (= .md files inside the book's directory) lands in v0.03.0 alongside
// the EDITOR module.
//
// v52: adds `length` (BookLength enum) + `idea` (optional String) for
// the New Book Creation Wizard (= 老板 8/15 17:32 '书名, 篇幅选择, 创
// 意点'). Both fields have defaults + Codable back-compat (= v0.02.x
// book.json files without these keys still decode).
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The shape of Book is locked by `Tests/WenshuAppTests/Domain/
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
/// book. v52 introduced this (= 老板 8/15 17:32 '篇幅选择'). Drives
/// later chapter management (= v0.03.0 chapter list reads the length
/// to suggest word-count targets + chapter split heuristics). Three
/// cases, allCases-ordered (= Picker in the wizard renders in this
/// order: 短篇 / 中篇 / 长篇).
enum BookLength: String, CaseIterable, Codable, Sendable {
    case short
    case medium
    case long

    /// Chinese display name for the wizard Picker. Apple HIG Picker
    /// labels are short, single-line (= the system spec example uses
    /// 'Short / Medium / Long' verbatim; we match the wenshu 中文
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
    /// presents it as '可选' / optional). nil = not provided.
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
    var displayIcon: String {
        if let icon, !icon.isEmpty { return icon }
        return "book"
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