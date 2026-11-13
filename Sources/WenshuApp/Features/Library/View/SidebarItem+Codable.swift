//
//  SidebarItem+Codable.swift
//
//  The sidebar row's JSON shape (= the `Codable` conformance that
//  `SidebarItem` declares).
//
//  Why it is its own file (= the house's own §6.6 split pattern, = the
//  same shape as `AppleSidebarView+Nodes.swift` and
//  `SidebarService+ReferenceLibrary.swift`): = the conformance is a
//  SINGLE concern (= the shape the selection is persisted in), = and
//  the tree's formatting gate measures the ADDED lines of a change, =
//  so a case added to this block has to live in a block the formatter
//  agrees with.
//

import Foundation

extension SidebarItem {
    // MARK: - v0.30 (see OOB.md #2026-08-31): Codable for AppStorage persistence

    //
    // Custom JSON encode/decode for @AppStorage (= AppStorage uses
    // String, so we round-trip via JSONEncoder/JSONDecoder). Flat
    // shape (= 'kind' discriminator + per-case keys) keeps the
    // JSON human-readable in `defaults read`.
    //
    // JSON shapes:
    //   {"kind": "book", "book": "<UUID>"}
    //   {"kind": "shelf", "shelf": "<UUID>"}
    //   {"kind": "folder", "book": "<UUID>", "folder": "world"}
    //   {"kind": "referenceCategory", "referenceCategory": "Literature"}
    //   {"kind": "tag", "tag": "<tag-string>"}
    //   {"kind": "allLibrary"}
    private enum CodingKeys: String, CodingKey {
        case kind, book, shelf, folder, referenceCategory, referenceUnclassified, tag, allLibrary
    }

    private enum Kind: String, Codable {
        case book, shelf, folder, referenceCategory, referenceUnclassified, tag, allLibrary
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .book(id):
            try c.encode(Kind.book, forKey: .kind)
            try c.encode(id.uuidString, forKey: .book)
        case let .shelf(id):
            try c.encode(Kind.shelf, forKey: .kind)
            try c.encode(id.uuidString, forKey: .shelf)
        case let .folder(bookId, folderName):
            try c.encode(Kind.folder, forKey: .kind)
            try c.encode(bookId.uuidString, forKey: .book)
            try c.encode(folderName, forKey: .folder)
        case let .referenceCategory(dirName):
            try c.encode(Kind.referenceCategory, forKey: .kind)
            try c.encode(dirName, forKey: .referenceCategory)
        case .referenceUnclassified:
            try c.encode(Kind.referenceUnclassified, forKey: .kind)
        case let .tag(tagString):
            try c.encode(Kind.tag, forKey: .kind)
            try c.encode(tagString, forKey: .tag)
        case .allLibrary:
            try c.encode(Kind.allLibrary, forKey: .kind)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        //
        // replaced the previous `UUID(uuidString: s) ?? UUID()` silent
        // swap (= the audit called this a data-corruption symptom that
        // invisibly re-points a restored sidebar selection to a
        // non-existent book) with explicit `try UUID(uuidString: s)`.
        // A malformed UUID string now propagates a `DecodingError`
        // (= visible to the caller = caller can decide to drop the
        // corrupt entry vs silently re-pointing to a random fresh UUID).
        switch kind {
        case .book:
            let s = try c.decode(String.self, forKey: .book)
            self = try .book(Self.parseUUID(s))
        case .shelf:
            let s = try c.decode(String.self, forKey: .shelf)
            self = try .shelf(Self.parseUUID(s))
        case .folder:
            let s = try c.decode(String.self, forKey: .book)
            let f = try c.decode(String.self, forKey: .folder)
            self = try .folder(bookId: Self.parseUUID(s), folderName: f)
        case .referenceCategory:
            let d = try c.decode(String.self, forKey: .referenceCategory)
            self = .referenceCategory(d)
        case .referenceUnclassified:
            self = .referenceUnclassified
        case .tag:
            let t = try c.decode(String.self, forKey: .tag)
            self = .tag(t)
        case .allLibrary:
            self = .allLibrary
        }
    }

    ///
    /// (= replaces the previous `UUID(uuidString:) ?? UUID()` silent swap).
    /// Throws `DecodingError.dataCorrupted` if the string is not a valid
    /// UUID (= visible to the caller = caller can decide to drop the
    /// corrupt entry vs silently re-pointing to a random fresh UUID).
    private static func parseUUID(_ s: String) throws -> UUID {
        if let uuid = UUID(uuidString: s) {
            return uuid
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "SidebarItem: invalid UUID string '\(s)'"
        ))
    }
}
