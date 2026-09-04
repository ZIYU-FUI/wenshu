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
        // v0.34 Issue 04: run preflight (= WikiEntityPreflight)
        // before saveReference. Critical issues throw and abort
        // the write (= library never lands in an inconsistent state
        // with empty / duplicate-id / body-missing entities).
        let body = defaultMarkdown(for: reference)
        let allReferences = (try? referenceStore.loadAllReferences()) ?? []
        let issues = WikiEntityPreflight.validate(
            reference,
            bodyMarkdown: body,
            existingReferences: allReferences
        )
        if WikiEntityPreflight.hasErrors(issues) {
            let summary = issues.filter { $0.severity == .error }
                .map { "[\($0.code)] \($0.message)" }
                .joined(separator: "\n")
            NSLog("[wenshu.preflight] blocked: %@\n%@", reference.id.uuidString, summary)
            throw PreflightError.issues(issues)
        }
        // Warnings: log + continue (= non-blocking).
        for warning in issues where warning.severity == .warning {
            NSLog("[wenshu.preflight] warning: %@", warning.message)
        }
        try referenceStore.saveReference(reference, bodyMarkdown: body)
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

/// v0.34 Issue 04: thrown by `EntityIngestion.ingest` when
/// preflight surfaces critical issues. Caller (= chat assistant /
/// LLM Wiki pipeline) renders the issues array as user-facing
/// diagnostic text (= Issue 06 UserFacingError integration point
/// for future ticket).
enum PreflightError: Error, LocalizedError {
    case issues([PreflightIssue])

    var errorDescription: String? {
        switch self {
        case .issues(let issues):
            let errors = issues.filter { $0.severity == .error }
            return "实体入库前检查未通过：\n" + errors
                .map { "[\($0.code)] \($0.message)" }
                .joined(separator: "\n")
        }
    }
}