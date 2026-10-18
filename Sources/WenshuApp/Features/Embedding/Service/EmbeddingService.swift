//
//  EmbeddingService.swift
//  WenshuApp
//
//  §11.26 弧 ticket 02. Actor-based service that holds the active
//  EmbeddingModel and exposes a single async embed entry point.
//
//  / Apple 1:1: actor isolation prevents the race conditions that hit
//  / PoC step 5 (multiple UI buttons triggering model load concurrently).
//  / Default kind is locale-driven (zh-* -> bgeSmallZh, else bgeM3).
//

import Foundation

public actor EmbeddingService {
    public static let shared = EmbeddingService()

    private var activeKind: EmbeddingModelKind
    private var activeModel: EmbeddingModel?

    public init(defaultKind: EmbeddingModelKind? = nil) {
        self.activeKind = defaultKind ?? EmbeddingModelKind.defaultForLocale()
    }

    public func currentKind() -> EmbeddingModelKind {
        activeKind
    }

    public func setActiveKind(_ kind: EmbeddingModelKind) {
        activeKind = kind
        activeModel = nil
    }

    /// Returns the active model, constructing it lazily. For .mock, this is
    /// instant. For bge / Apple NLEmbedding, ticket 03+ will hook up download
    /// and load logic here.
    public func ensureReady() async throws -> EmbeddingModel {
        if let m = activeModel { return m }
        let model: EmbeddingModel
        switch activeKind {
        case .mock:
            model = MockEmbeddingModel()
        case .appleNLEmbeddingDeprecated:
            model = MockEmbeddingModel()
        case .bgeSmallZh, .bgeM3:
            // Ticket 03 will swap this for the real bge backend.
            // For ticket 02 we still return Mock so the service compiles
            // and is exercisable end-to-end.
            model = MockEmbeddingModel()
        }
        try await model.prepare()
        activeModel = model
        return model
    }

    public func embed(_ text: String) async throws -> [Float] {
        let model = try await ensureReady()
        return try await model.embed(text)
    }

    public func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        let model = try await ensureReady()
        return try await model.embedBatch(texts)
    }
}
