//
//  EmbeddingService.swift
//  WenshuApp
//
//  §11.26 弧 ticket 04. Actor-based service that owns the active
//  remote embedding model and exposes embed / embedBatch.
//
//  / Per boss OOB 2026-10-19: only remote APIs. The service fetches
//  / the user's stored API key from WenshuAgent (= AES-GCM ciphertext
//  / decrypted at call site, see WenshuAgent/Keychain). When the call
//  / fails, the service throws (= no silent fallback to a local
//  / model). The user is told via an error in the UI layer.
//

import Foundation

public actor EmbeddingService {
    public static let shared = EmbeddingService()

    private var activeKind: EmbeddingModelKind
    private var activeModel: EmbeddingModel?

    public init(defaultKind: EmbeddingModelKind? = nil) {
        self.activeKind = defaultKind ?? .minimax
    }

    public func currentKind() -> EmbeddingModelKind { activeKind }
    public func setActiveKind(_ kind: EmbeddingModelKind) { activeKind = kind; activeModel = nil }

    public func ensureReady() async throws -> EmbeddingModel {
        if let m = activeModel { return m }
        let key = try await lookupAPIKey(for: activeKind)
        let model = RemoteEmbeddingModel(kind: activeKind, apiKey: key)
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

    /// Resolve the encrypted API key for the provider slug via the project's
    /// existing key store. WenshuAgent.shared returns the plaintext for an
    /// already-decrypted AES-GCM blob; = same path the LLM agent uses.
    private func lookupAPIKey(for kind: EmbeddingModelKind) async throws -> String {
        // Map embedding kind -> WenshuAgent Provider enum (= already loaded
        // from WenshuAgent/Connector/BuiltInProviders.swift). The slug must
        // exist as a Provider. If the user hasn't added a key yet, raise
        // missingAPIKey (caught by the UI; the user is told to add the key
        // in Settings → 模型 → Embedding).
        guard let provider = Provider.by(slug: kind.providerSlug) else {
            throw EmbeddingError.missingAPIKey
        }
        let key = await MainActor.run { ProviderKeychain.loadKeySync(for: provider) } ?? ""
        guard !key.isEmpty else { throw EmbeddingError.missingAPIKey }
        return key
    }
}
