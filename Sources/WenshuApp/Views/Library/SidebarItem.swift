// SidebarItem.swift · Wenshu · v1.69
//
// v1.69 sidebar MVVM cleanup (= boss 2026-09-22 OOB '老的文件没
// 删, UI/业务/数据没分离的删掉'): extracted from
// NewLibraryOutlineView.swift (the v0.30 legacy sidebar that
// packed 2520 LOC of view body + selection handling + state
// persistence + business logic into one file).
//
// SidebarItem is the data model (= a Hashable + Codable enum
// that identifies one row in the sidebar tree = the union of all
// selectable rows: shelf / book / folder / reference category).
// Lives in its own file (= no SwiftUI import) so:
//   - PreviewPane / WorkspaceView / ShellMiddleColumn can read
//     the same SidebarItem without importing the legacy sidebar
//     view (= clean module boundary).
//   - AppState.sidebarSelection (= the Codable property in
//     AppState.swift) persists the selection via the Codable
//     conformance here.
//   - Tests (= WorkspaceViewPreviewScopeTests + future tests)
//     can target the enum independently of any view code.

import Foundation

/// Identifies a single sidebar item for List(selection:) binding.
/// v0.30: composite enum (= book OR reference category) because
/// Apple HIG allows ONE selection type per List, so we unify
/// both selection kinds into one Hashable enum.
enum SidebarItem: Hashable, Codable {
    case book(UUID)
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2): shelf
    // (= first tree level) is now a clickable tree row, not just a
    // SwiftUI Section header. Tagging it with .shelf(UUID) lets
    // the user select a shelf directly (= will eventually scope preview
    // pane to the shelf; for now it just keeps the shelf row
    // highlighted when selected).
    case shelf(UUID)
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): folder row
    // (= third tree level, e.g. Worldview / Characters / Chapter Outline / Novel Body /
    // Novel Drafts). Tagging with .folder(bookId, folderName) lets
    // the user select a folder directly; preview pane will scope to
    // that folder's content (= shows the .md files inside).
    case folder(bookId: UUID, folderName: String)
    case referenceCategory(String)  // = EntityCategory.directoryName

    static let referenceLibraryRoot = SidebarItem.referenceCategory("__root__")

    // MARK: - v0.30 boss 8/31 OOB: Codable for AppStorage persistence
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
    private enum CodingKeys: String, CodingKey {
        case kind, book, shelf, folder, referenceCategory
    }
    private enum Kind: String, Codable {
        case book, shelf, folder, referenceCategory
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .book(let id):
            try c.encode(Kind.book, forKey: .kind)
            try c.encode(id.uuidString, forKey: .book)
        case .shelf(let id):
            try c.encode(Kind.shelf, forKey: .kind)
            try c.encode(id.uuidString, forKey: .shelf)
        case .folder(let bookId, let folderName):
            try c.encode(Kind.folder, forKey: .kind)
            try c.encode(bookId.uuidString, forKey: .book)
            try c.encode(folderName, forKey: .folder)
        case .referenceCategory(let dirName):
            try c.encode(Kind.referenceCategory, forKey: .kind)
            try c.encode(dirName, forKey: .referenceCategory)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        // v0.71 P1 batch 6 dual-axis followup (= Q99 Standards axis MED):
        // replaced the previous `UUID(uuidString: s) ?? UUID()` silent
        // swap (= the audit called this a data-corruption symptom that
        // invisibly re-points a restored sidebar selection to a
        // non-existent book) with explicit `try UUID(uuidString: s)`.
        // A malformed UUID string now propagates a `DecodingError`
        // (= visible to the caller) instead of silently substituting a
        // fresh UUID (= restores correct semantics: corrupt
        // persistence = crash on read, not silent data loss).
        switch kind {
        case .book:
            let s = try c.decode(String.self, forKey: .book)
            self = .book(try Self.parseUUID(s))
        case .shelf:
            let s = try c.decode(String.self, forKey: .shelf)
            self = .shelf(try Self.parseUUID(s))
        case .folder:
            let s = try c.decode(String.self, forKey: .book)
            let f = try c.decode(String.self, forKey: .folder)
            self = .folder(bookId: try Self.parseUUID(s), folderName: f)
        case .referenceCategory:
            let d = try c.decode(String.self, forKey: .referenceCategory)
            self = .referenceCategory(d)
        }
    }

    /// v0.71 P1 batch 6: parse a UUID string and surface malformed input
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