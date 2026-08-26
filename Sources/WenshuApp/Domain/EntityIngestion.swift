// EntityIngestion.swift · Wenshu (文枢) · v0.27 (FCP library replica)
//
// Writes IngestionRequests (= entities from ChatTrigger) into the
// reference library's entities layer (= LLM Wiki entities; per boss
// 8/26 '用户只关注实体').
//
// v0.27 MVP writes a minimal Reference per IngestionRequest with:
// - title = IngestionRequest.surfaceForm (= entity name)
// - layer = .layerEntities (= per spec v5 L100-103)
// - summary = empty (= LLM-derived summary lands in v0.27 followups)
//
// Idempotent (= skips if the entity already exists by name + layer).

import Foundation

struct EntityIngestion: Sendable {
    let referenceStore: ReferenceStoring

    /// Ingest a single IngestionRequest. Returns true if a new entity
    /// was written; false if the entity already exists (= idempotent).
    @discardableResult
    func ingest(_ request: IngestionRequest) throws -> Bool {
        let existing = try referenceStore.loadReferences(layer: .layerEntities)
        if existing.contains(where: { $0.title == request.surfaceForm }) {
            return false
        }
        let reference = Reference(
            title: request.surfaceForm,
            layer: .layerEntities,
            summary: ""
        )
        try referenceStore.saveReference(reference, bodyMarkdown: defaultMarkdown(for: reference))
        return true
    }

    /// Ingest a batch of requests. Returns the count of new entities
    /// actually written (= duplicates skipped).
    func ingestBatch(_ requests: [IngestionRequest]) throws -> Int {
        var written = 0
        for request in requests {
            if try ingest(request) {
                written += 1
            }
        }
        return written
    }

    /// Default markdown body (= Apple HIG document convention: H1
    /// matches entity name; empty body until LLM-derived summary lands).
    private func defaultMarkdown(for reference: Reference) -> String {
        "# \(reference.title)\n\n"
    }
}