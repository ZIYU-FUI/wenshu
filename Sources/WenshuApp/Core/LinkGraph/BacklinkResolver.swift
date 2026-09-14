//
//  BacklinkResolver.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, backend first)
//  Boss 2026-08-19 evening decision Obsidian replica scope A + 'port the backend, no frontend integration'.
//
//  Async parse markdown content + insert into WSLinkRepository (= @MainActor SwiftData wrapper), get bidirectional index. (= Phase 5 ticket 9 deleted LinkIndex actor.)
//  API aligned with Obsidian Backlinks plugin ground truth:
//  - resolve(content, sourceDocId, documentIndex): parse + clear old links + batch insert
//  - backlinks(forDocId): reverse-query all sources (Backlinks panel)
//  - forwardLinks(forDocId): forward-query all targets (Outgoing links panel)
//
//  Same actor + Sendable + Task pattern as v0.18 ticket 04 AgentRuntime.
//

import Foundation

/// DocumentIndex: map doc name (filename / display name) to doc_id (UUID)
/// BacklinkResolver uses it to resolve `[[name]]` → target_doc_id
public protocol DocumentIndexing: Sendable {
    /// Given a doc display name (e.g. "Lin Daiyu"), return doc_id (may be empty, because [[new name]] has no existing doc yet)
    func docId(forName name: String) async -> String?
    /// To doc id, get a display name (reverse, render the panel)
    func name(forDocId docId: String) async -> String?
}

/// BacklinkResolver: async-coordinates Markdown parse + WSLinkRepository insert
public actor BacklinkResolver {
    /// SwiftData-backed link repository (= phase 3 WSLinkRepository).
    /// Default = .shared (= production path); tests inject an in-memory
    /// instance to avoid clobbering shared WSPersistenceContainer.
    private let repository: WSLinkRepository
    private let documentIndex: DocumentIndexing

    public init(repository: WSLinkRepository, documentIndex: DocumentIndexing) {
        self.repository = repository
        self.documentIndex = documentIndex
    }

    /// Default factory: returns a BacklinkResolver backed by
    /// WSLinkRepository.shared (= @MainActor static init).
    /// Production callers (= none currently exist) use this; tests
    /// inject a per-test WSLinkRepository with in-memory ModelContainer.
    @MainActor
    public static func defaultInstance(documentIndex: DocumentIndexing) -> BacklinkResolver {
        BacklinkResolver(repository: .shared, documentIndex: documentIndex)
    }

    /// Parse markdown content, clear old links for sourceDocId, batch insert new links
    public func resolve(content: String, sourceDocId: String) async throws {
        let parsed = InternalLinkParser.parse(content)
        let repository = self.repository
        // Clear old links (when document is rewritten)
        try await MainActor.run {
            try repository.removeAll(sourceDocId: sourceDocId)
        }
        // Batch insert
        for link in parsed {
            let targetDocId = await documentIndex.docId(forName: link.target)
            try await MainActor.run {
                try repository.add(
                    Link(
                        sourceDocId: sourceDocId,
                        targetRef: link.target,
                        targetDocId: targetDocId,
                        line: link.line,
                        offset: link.offset
                    )
                )
            }
        }
    }

    /// Reverse query: given docId, return all backlinks (source link list referencing it)
    public func backlinks(forDocId docId: String) async throws -> [Link] {
        let repository = self.repository
        // 1) First reverse-search by docId (target already resolved links)
        let resolved = try await MainActor.run {
            try repository.searchBackward(targetDocId: docId)
        }
        // 2) Then reverse-search by doc display name (target unresolved links, e.g. [[name]] whose doc was renamed)
        let name = await documentIndex.name(forDocId: docId) ?? ""
        if !name.isEmpty {
            let unresolved = try await MainActor.run {
                try repository.searchBackward(targetRef: name)
            }
            // Merge + deduplicate (Apple HIG: Set semantics)
            let combined = resolved + unresolved.filter { u in !resolved.contains(where: { $0.sourceDocId == u.sourceDocId && $0.offset == u.offset }) }
            return combined.sorted { $0.createdAt > $1.createdAt }
        }
        return resolved
    }

    /// Reverse query: given display name (filename), return all backlinks
    public func backlinks(forName name: String) async throws -> [Link] {
        let repository = self.repository
        return try await MainActor.run {
            try repository.searchBackward(targetRef: name)
        }
    }

    /// Forward query: given sourceDocId, return all targets it references (Outgoing links)
    public func forwardLinks(forDocId docId: String) async throws -> [Link] {
        let repository = self.repository
        return try await MainActor.run {
            try repository.searchForward(sourceDocId: docId)
        }
    }
}
