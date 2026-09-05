//
//  BacklinkResolver.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, backend first)
//  Boss 2026-08-19 evening decision Obsidian replica scope A + 'port the backend, no frontend integration'.
//
//  Async parse markdown content + insert into LinkIndex, get bidirectional index.
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

/// BacklinkResolver: async-coordinates Markdown parse + LinkIndex insert
public actor BacklinkResolver {
    private let index: LinkIndex
    private let documentIndex: DocumentIndexing

    public init(index: LinkIndex, documentIndex: DocumentIndexing) {
        self.index = index
        self.documentIndex = documentIndex
    }

    /// Parse markdown content, clear old links for sourceDocId, batch insert new links
    public func resolve(content: String, sourceDocId: String) async throws {
        let parsed = InternalLinkParser.parse(content)
        // Clear old links (when document is rewritten)
        try await index.removeAll(sourceDocId: sourceDocId)
        // Batch insert
        for link in parsed {
            let targetDocId = await documentIndex.docId(forName: link.target)
            try await index.add(
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

    /// Reverse query: given docId, return all backlinks (source link list referencing it)
    public func backlinks(forDocId docId: String) async throws -> [Link] {
        // 1) First reverse-search by docId (target already resolved links)
        let resolved = try await index.searchBackward(targetDocId: docId)
        // 2) Then reverse-search by doc display name (target unresolved links, e.g. [[name]] whose doc was renamed)
        let name = await documentIndex.name(forDocId: docId) ?? ""
        if !name.isEmpty {
            let unresolved = try await index.searchBackward(targetRef: name)
            // Merge + deduplicate (Apple HIG: Set semantics)
            let combined = resolved + unresolved.filter { u in !resolved.contains(where: { $0.sourceDocId == u.sourceDocId && $0.offset == u.offset }) }
            return combined.sorted { $0.createdAt > $1.createdAt }
        }
        return resolved
    }

    /// Reverse query: given display name (filename), return all backlinks
    public func backlinks(forName name: String) async throws -> [Link] {
        try await index.searchBackward(targetRef: name)
    }

    /// Forward query: given sourceDocId, return all targets it references (Outgoing links)
    public func forwardLinks(forDocId docId: String) async throws -> [Link] {
        try await index.searchForward(sourceDocId: docId)
    }
}
