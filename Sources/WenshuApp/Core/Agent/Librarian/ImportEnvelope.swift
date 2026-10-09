//
//  ImportEnvelope.swift
//
//  Wire envelope types for the v2.7 markdown import feature
//  (= boss 2026-10-09 directive "导入" / "File > 导入" menu
//  entry; = the path that lets the user point wenshu at a
//  folder of external .md files and have the agent route
//  each one to either a book folder (= world / characters /
//  outlines / chapters / drafts) or the reference library
//  (= research notes; = external knowledge the book can
//  reference).
//
//  This file holds the **data model** only (= the wire
//  contract the ImportService and the Librarian agent pass
//  back and forth; = the service / view / agent that produce
//  and consume the envelope live in other files per the
//  T1/T2/T3/T4 ticket split in
//  .scratch/2026-10-09-md-import-feature/tickets.md).
//
//  Apple canonical shape:
//   - The book-folder destination REUSES the existing
//     `BookFolder` enum (= the 8-case enum
//     that already carries the on-disk directoryName
//     canonical mapping; = the source of truth for
//     "5 standard folders" = its first 5 cases).
//   - The destination is `bookFolder(BookFolder)`
//     or `referenceLibrary` (= the same v2.6 split).
//   - Every Codable + Sendable type here is the wire contract
//     (= the conductor hands these across actor boundaries).
//

import Foundation

// MARK: - Destination (where the LLM routed the file)

/// The final landing site for an imported .md file. The
/// Librarian's "import" system prompt picks one of these per
/// file; = the ImportService writes the body verbatim to the
/// matching directory.
enum ImportDestination: Codable, Sendable, Hashable {
    /// A book folder (= one of the 8 case roles under a book
    /// in the user's library; = `BookFolder` is
    /// the canonical 8-case enum; = the 5 user-visible
    /// standard folders are its first 5 cases).
    /// The body lands at
    /// `<shelvesRoot>/<shelfId>/books/<bookId>/<bookFolder.directoryName>/<uuid>.md`.
    case bookFolder(BookFolder)
    /// The reference library (= the cross-book shared knowledge
    /// store at `<wsRoot>/reference-library/`). The body lands
    /// at `<wsRoot>/reference-library/entities/<uuid>.md` and
    /// the Reference is appended to `entities/entities.json`.
    case referenceLibrary
}

// MARK: - ImportFileInput (the wire request to the agent)

/// What the user picked (= the source file path + the target
/// book). Sent verbatim to the Librarian; = the agent reads
/// the file body from `filePath` and decides where to route.
struct ImportFileInput: Codable, Sendable, Hashable {
    /// Absolute path to the source .md file. The agent reads
    /// the file body from here (= the body is never copied
    /// into a long-lived Data blob; = see spec "Further Notes"
    /// on the 200+ MB source-directory memory budget).
    let filePath: String
    /// The book the user picked in the import sheet (= the
    /// `book.id` from `SidebarService.availableBooks()`).
    /// Required when the user pinned a book as the
    /// destination; = nil when the user pinned the
    /// reference library as the destination (= the boss's
    /// 2026-10-09 round-18 "强制让用户分开导入"
    /// directive; = the LLM gets a nil targetBookId +
    /// the prompt steers it away from book-folder
    /// routing).
    let targetBookId: UUID?
    /// The shelf the target book lives under (= needed to
    /// resolve the on-disk path
    /// `<shelvesRoot>/<shelfId>/books/<bookId>/<folder>/`).
    /// Nil when `targetBookId` is nil (= same reason).
    let targetShelfId: UUID?
}

// MARK: - ImportRoutingResult (the agent's reply)

/// What the Librarian returns for each file (= the LLM's
/// classification + the metadata enrichment the .ws needs
/// to surface the entity in the sidebar / preview pane).
///
/// Boss 2026-10-09 directive: "LLM 的作用只是做分类, 还
/// 有补字段" = the LLM must NOT rewrite the body. The
/// body is written verbatim from the source file
/// (= verified by byte-equal test in
/// ImportRoutingTests.testRouteAndEnrich_doesNotRewriteBody);
/// = this struct carries only the metadata fields the
/// storage layer needs beyond the raw body.
struct ImportRoutingResult: Codable, Sendable, Hashable {
    /// Where the file lands (= the LLM's routing
    /// decision; = the orchestrator's
    /// `processFile` may OVERRIDE this when the
    /// user pinned a destination in the sheet
    /// (= the boss's 2026-10-09 round-18
    /// "强制让用户分开导入" directive); = the
    /// `var` is necessary so the orchestrator
    /// can replace the LLM's classification
    /// with the user-pinned destination).
    var destination: ImportDestination
    /// Title for the entity / book doc. The agent derives
    /// this from the file's H1 (= or the first non-empty
    /// heading; = the same heuristic `EntityClassifier` and
    /// the existing `ReferenceLibraryTool` already use).
    let title: String
    /// One-line summary shown on the card (= the same
    /// `summary` field the existing `Reference` struct
    /// already exposes).
    let summary: String
    /// Free-form tags (= the v2.6 cross-cutting facet; =
    /// written to the on-disk `Reference.tags` field for
    /// reference-destination files; = written to the
    /// BookDoc's frontmatter for book-folder files).
    let tags: Set<String>
    /// Entity type (= character / location / event / etc.;
    /// = ignored for book-folder destinations per the v2.6
    /// facet model; = required for reference-destination
    /// files).
    let entityType: String
    /// Optional CLC category (= only used for reference-
    /// destination files; = nil for book-folder destinations).
    let category: String?
    /// Confidence in the routing decision (= 0.0...1.0). The
    /// sheet surfaces a "low confidence" warning for
    /// `confidence < 0.7`; = a future ticket will let the user
    /// override the routing via chat (= the `confidence`
    /// field is plumbing for that feature).
    let confidence: Double
}

// MARK: - ImportEnvelope (the wire envelope)

/// Discriminated union of wire envelopes the user can
/// trigger from the GUI. Today: only `.importFile`. The
/// shape mirrors `ReferenceLibraryTool.Input` (= the
/// existing reference-write envelope) so the conductor
/// can dispatch with a single switch.
enum ImportEnvelope: Codable, Sendable, Hashable {
    case importFile(ImportFileInput)

    // MARK: Wire format

    private enum CodingKeys: String, CodingKey {
        case kind
        case filePath, targetBookId, targetShelfId
    }

    private enum Kind: String, Codable, Sendable {
        case importFile
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .importFile(let input):
            try c.encode(Kind.importFile, forKey: .kind)
            try c.encode(input.filePath, forKey: .filePath)
            try c.encode(input.targetBookId, forKey: .targetBookId)
            try c.encode(input.targetShelfId, forKey: .targetShelfId)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .importFile:
            let filePath = try c.decode(String.self, forKey: .filePath)
            let bookId = try c.decode(UUID.self, forKey: .targetBookId)
            let shelfId = try c.decode(UUID.self, forKey: .targetShelfId)
            self = .importFile(ImportFileInput(
                filePath: filePath,
                targetBookId: bookId,
                targetShelfId: shelfId
            ))
        }
    }
}
