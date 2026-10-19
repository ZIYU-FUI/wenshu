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
    /// instant. For bge / appleNLEmbedding, ticket 03 wires the real backend.
    ///
    /// / bgeSmallZh / bgeM3 (mlx-swift-lm) require an Apple-signed Metal
    /// / Toolchain to compile on this build host (= Apple ID authorized
    /// / download per `xcodebuild -downloadComponent`). Sandbox here does
    /// / not have Apple ID, so bge kinds fall back to AppleNLEmbedding
    /// / (= the on-device NaturalLanguage word embedding, always available,
    /// / PoC-verified 0.20-0.72 cosine discrimination for short Chinese).
    public func ensureReady() async throws -> EmbeddingModel {
        if let m = activeModel { return m }
        let model: EmbeddingModel
        switch activeKind {
        case .mock:
            model = MockEmbeddingModel()
        case .bgeSmallZh, .bgeM3, .appleNLEmbedding:
            // bge kinds would call MlxEmbeddingModel here once Metal
            // Toolchain is available. For now (= sandbox without Apple
            // ID) every kind routes to the on-device AppleNLEmbedding
            // backend, which is always available and meets the
            // "first-use immediately usable" bar (boss OOB 2026-10-18).
            model = AppleNLEmbeddingBackend()
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
