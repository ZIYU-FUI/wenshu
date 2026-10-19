//
//  SemanticSearchService.swift
//  WenshuApp
//
//  §11.26 弧 ticket A2. Cosine similarity search across WSBodyEmbedding
//  rows. Caller passes a free-text query (= "林凡师父是谁"), the
//  service embeds it with the active EmbeddingService (= the same model
//  the auto-embed job used), and returns the top-K matching body IDs
//  with their scores (= 0-1 cosine).
//
//  / Pure data layer — no SwiftUI here. The chat zone wraps this in a
//  / sheet / panel. The library zone could also call it (= "show me
//  / entities similar to 林凡" = future ticket).
//

import Foundation
import WenshuData

public struct SemanticSearchResult: Sendable, Equatable {
    public let bodyID: String
    public let score: Float
    public init(bodyID: String, score: Float) {
        self.bodyID = bodyID
        self.score = score
    }
}

public actor SemanticSearchService {
    public static let shared = SemanticSearchService()

    /// Top-K cosine search. `k` defaults to 8 (= dense enough to show
    /// the top of a list, small enough to fit a sheet).
    public func search(query: String, k: Int = 8) async throws -> [SemanticSearchResult] {
        let kind = await EmbeddingService.shared.currentKind()
        let qVec = try await EmbeddingService.shared.embed(query)
        let qNorm = norm(qVec)
        guard qNorm > 0 else { return [] }

        // Pull all embeddings of the active model. For a small library
        // (= a few thousand bodies) this is fast; for a large one, a
        // dedicated vector index lands in a future ticket.
        let rows = await MainActor.run { body_rows(modelKindRaw: kind.rawValue) }
        guard !rows.isEmpty else { return [] }

        // Score every row, drop zero-norm, sort descending, take K.
        var scored: [SemanticSearchResult] = []
        scored.reserveCapacity(rows.count)
        for (bodyID, vec) in rows {
            let vNorm = norm(vec)
            guard vNorm > 0 else { continue }
            let dot = dotProduct(qVec, vec)
            let score = dot / (qNorm * vNorm)
            scored.append(SemanticSearchResult(bodyID: bodyID, score: score))
        }
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(k))
    }

    @MainActor
    private func body_rows(modelKindRaw: String) -> [(String, [Float])] {
        let repo = WSBodyEmbeddingRepository()
        let rows = (try? repo.fetchAll(modelKindRaw: modelKindRaw)) ?? []
        return rows.map { ($0.bodyID, $0.floats) }
    }

    private func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        let n = min(a.count, b.count)
        var s: Float = 0
        for i in 0..<n { s += a[i] * b[i] }
        return s
    }

    private func norm(_ v: [Float]) -> Float {
        var s: Float = 0
        for x in v { s += x * x }
        return sqrt(s)
    }
}
