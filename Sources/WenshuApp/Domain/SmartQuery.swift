// Sources/WenshuApp/Domain/SmartQuery.swift
//
// Saved-search query (= FCP Library Smart Collection analogue).
// v0.26 ships the static skeleton (= schema + storage); v0.27+
// implements the search engine.

import Foundation

/// A single saved search (= FCP Library Smart Collection analogue).
/// `queryJSON` is the structured search predicate (= JSON-encoded
/// {entityType, namePattern, refIds, etc.}). v0.27+ will deserialize
/// it via SmartQueryParser.
struct SmartQuery: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    /// JSON-encoded search predicate. Per Apple HIG, a JSON string
    /// (= rather than a Swift Codable struct) decouples the storage
    /// format from the parser type (= parser can evolve without
    /// breaking stored queries).
    var queryJSON: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        queryJSON: String = "{}",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.queryJSON = queryJSON
        self.createdAt = createdAt
    }

    /// Filename on disk (= `<uuid>.json`).
    var filename: String {
        "\(id.uuidString).json"
    }

    // (emptyJSON removed 2026-10 in q99-spec-p0-batch2 — verify-dead.py
    //  confirmed 0 external callers; = no SmartQuery consumer ever needed
    //  the literal "{}" placeholder (= all real saved searches serialize
    //  through Codable). See wenshu-pocock-workflow
    //  references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup
    //  SKILL.md.)

    /// On-disk path (= `<reference-library-root>/indexes/saved-searches/<uuid>.json`).
    func onDiskPath(under referenceLibraryRoot: URL) -> URL {
        referenceLibraryRoot
            .appendingPathComponent("indexes", isDirectory: true)
            .appendingPathComponent("saved-searches", isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func == (lhs: SmartQuery, rhs: SmartQuery) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
