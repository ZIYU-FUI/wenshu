//
//  WSBodyEmbeddingRepository.swift
//
//  §11.26 弧 ticket A1. CRUD for WSBodyEmbedding rows. Used by:
//  - WSEntityRepository.replaceBody (= fire-and-forget embed after
//    every body write; the same markdown may produce an embedding
//    many times — we re-upsert by (bodyID, modelKind)).
//  - EmbeddingSearchService (ticket A2) — for cosine similarity
//    queries against the current embedding model.
//

import Foundation
import SwiftData

@MainActor
public final class WSBodyEmbeddingRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    /// Idempotent upsert by (bodyID, modelKindRaw).
    public func upsert(
        bodyID: String,
        modelKindRaw: String,
        floats: [Float],
        dimension: Int
    ) throws {
        let descriptor = FetchDescriptor<WSBodyEmbedding>(
            predicate: #Predicate { $0.bodyID == bodyID && $0.modelKindRaw == modelKindRaw }
        )
        let existing = try context.fetch(descriptor).first
        if let row = existing {
            row.vector = WSBodyEmbedding.encode(floats)
            row.dimension = dimension
            row.generatedAt = Date()
        } else {
            let row = WSBodyEmbedding(
                id: "\(bodyID)::\(modelKindRaw)",
                bodyID: bodyID,
                modelKindRaw: modelKindRaw,
                dimension: dimension,
                vector: WSBodyEmbedding.encode(floats)
            )
            context.insert(row)
        }
        try context.save()
    }

    public func fetch(bodyID: String, modelKindRaw: String) throws -> WSBodyEmbedding? {
        let descriptor = FetchDescriptor<WSBodyEmbedding>(
            predicate: #Predicate { $0.bodyID == bodyID && $0.modelKindRaw == modelKindRaw }
        )
        return try context.fetch(descriptor).first
    }

    /// All embeddings for a body, regardless of model (= used for
    /// future re-embed sweep).
    public func fetchAll(bodyID: String) throws -> [WSBodyEmbedding] {
        let descriptor = FetchDescriptor<WSBodyEmbedding>(
            predicate: #Predicate { $0.bodyID == bodyID }
        )
        return try context.fetch(descriptor)
    }

    /// All embeddings of one model across the whole library (= used by
    /// ticket A2 cosine search). The caller iterates and computes
    /// similarity in-memory (= small library, N <= a few thousand).
    public func fetchAll(modelKindRaw: String) throws -> [WSBodyEmbedding] {
        let descriptor = FetchDescriptor<WSBodyEmbedding>(
            predicate: #Predicate { $0.modelKindRaw == modelKindRaw }
        )
        return try context.fetch(descriptor)
    }

    public func delete(bodyID: String, modelKindRaw: String) throws {
        let descriptor = FetchDescriptor<WSBodyEmbedding>(
            predicate: #Predicate { $0.bodyID == bodyID && $0.modelKindRaw == modelKindRaw }
        )
        if let row = try context.fetch(descriptor).first {
            context.delete(row)
            try context.save()
        }
    }
}
