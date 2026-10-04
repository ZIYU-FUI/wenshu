// BacklinkResolver.swift · WenshuApp · v0.19
//
// Async parse markdown content + insert into `WSLinkRepository`
// (= @MainActor SwiftData wrapper) for a bidirectional index. API:
//   - `resolve(content, sourceDocId, documentIndex)`: parse +
//     clear old links + batch insert
//   - `backlinks(forDocId)`: reverse-query all sources (Backlinks panel)
//   - `forwardLinks(forDocId)`: forward-query all targets
//     (Outgoing links panel)

import Foundation

/// DocumentIndex: map doc name (filename / display name) to doc_id (UUID)
/// BacklinkResolver uses it to resolve `[[name]]` → target_doc_id
protocol DocumentIndexing: Sendable {
    /// Given a doc display name (e.g. "Lin Daiyu"), return doc_id (may be empty, because [[new name]] has no existing doc yet)
    func docId(forName name: String) async -> String?
    /// To doc id, get a display name (reverse, render the panel)
    func name(forDocId docId: String) async -> String?
}

/// BacklinkResolver: async-coordinates Markdown parse + WSLinkRepository insert
actor BacklinkResolver {
    /// SwiftData-backed link repository (= phase 3 WSLinkRepository).
    /// Default = .shared (= production path); tests inject an in-memory
    /// instance to avoid clobbering shared WSPersistenceContainer.
    private let repository: WSLinkRepository
    private let documentIndex: DocumentIndexing

    init(repository: WSLinkRepository, documentIndex: DocumentIndexing) {
        self.repository = repository
        self.documentIndex = documentIndex
    }

    /// Default factory: returns a BacklinkResolver backed by
    /// WSLinkRepository.shared (= @MainActor static init).
    /// Production callers (= none currently exist) use this; tests
    /// inject a per-test WSLinkRepository with in-memory ModelContainer.
    @MainActor
    // (defaultInstance removed 2026-10 in q99-spec-p0-batch2 — verify-dead.py
    //  confirmed 0 external callers; = the constructor was retained as a
    //  "shorthand for the canonical BacklinkResolver wiring" affordance
    //  but never consumed; = callers instantiate BacklinkResolver
    //  directly via BacklinkResolver(repository: .shared, documentIndex:).
    //  See wenshu-pocock-workflow references/v3.0-design-system-rule.md
    //  + wenshu-dead-code-cleanup SKILL.md.)

    /// Parse markdown content, clear old links for sourceDocId, batch insert new links
    func resolve(content: String, sourceDocId: String) async throws {
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
    func backlinks(forDocId docId: String) async throws -> [Link] {
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
    func backlinks(forName name: String) async throws -> [Link] {
        let repository = self.repository
        return try await MainActor.run {
            try repository.searchBackward(targetRef: name)
        }
    }

    /// Forward query: given sourceDocId, return all targets it references (Outgoing links)
    func forwardLinks(forDocId docId: String) async throws -> [Link] {
        let repository = self.repository
        return try await MainActor.run {
            try repository.searchForward(sourceDocId: docId)
        }
    }
}
