// IngestionRequest.swift · Wenshu (FCP library replica)
//
// Detects when a chat message hints at a new entity (= a character /
// world fact / research reference) and emits an `IngestionRequest`
// for the LLM Wiki pipeline.
//
// Trigger heuristics (conservative):
// 1. Chinese-style quoted names (= single corner brackets U+300C/U+300D)
// 2. BookTitle patterns (= canonical Chinese titles list)
//
// Future versions may add LLM-based extraction.

import Foundation

/// An LLM Wiki ingestion request (= what the EntityIngestion pipeline
/// picks up to write entities into the reference library).
struct IngestionRequest: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let surfaceForm: String          // = e.g. "" / ""
    let kind: SmartQueryEntityType   // = .character / .world / .reference
    let sourceMessageId: UUID?       // = which chat message triggered this
    let createdAt: Date

    init(
        id: UUID = UUID(),
        surfaceForm: String,
        kind: SmartQueryEntityType,
        sourceMessageId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.surfaceForm = surfaceForm
        self.kind = kind
        self.sourceMessageId = sourceMessageId
        self.createdAt = createdAt
    }
}
