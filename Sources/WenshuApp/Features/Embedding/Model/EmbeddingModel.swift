//
//  EmbeddingModel.swift
//  WenshuApp
//
//  §11.26 弧 ticket 02 + 03. Protocol + model-kind enum for any
//  embedding backend. Apple 1:1 path: protocol-oriented (same shape
//  as URLSession / URLProtocol).
//
//  / Service depends on this protocol only. Concrete backends
//  / (AppleNLEmbedding, mock) live in sibling files. New backends can
//  / be added without touching the service.
//
//  / Per AGENTS.md §6.5 file-naming: this is the canonical <Xxx>Model.swift
//  / (= 1 of 4 suffixes: View/Ops/Service/State/Model; = kind enum inline
//  / since 1-type file would violate §6.9 single-file-dir = deletion rule).
//

import Foundation

public enum EmbeddingModelKind: String, CaseIterable, Codable, Sendable {
    /// BAAI bge-small-zh-v1.5. Chinese-specialized, 512 dim, ~95MB fp16.
    /// Reserved for ticket 04 (= when Apple Metal Toolchain is available
    /// on the build host, this kind routes to MlxEmbeddingModel).
    case bgeSmallZh
    /// BAAI bge-m3. Multilingual, 1024 dim, ~1.1GB fp16. Same ticket 04
    /// dependency as bgeSmallZh.
    case bgeM3
    /// Apple NLEmbedding on-device word-avg. Always available, no
    /// download required. PoC-verified 0.20-0.72 cosine discrimination
    /// for short Chinese text. Currently the production backend (ticket 03).
    case appleNLEmbedding
    /// Mock implementation. For unit tests and local dev only.
    case mock

    public var displayName: String {
        switch self {
        case .bgeSmallZh: return "bge-small-zh-v1.5"
        case .bgeM3: return "bge-m3"
        case .appleNLEmbedding: return "Apple NLEmbedding (system)"
        case .mock: return "Mock (test only)"
        }
    }

    public var sizeBytes: UInt64 {
        switch self {
        case .bgeSmallZh: return 95 * 1024 * 1024
        case .bgeM3: return 1_100 * 1024 * 1024
        case .appleNLEmbedding: return 0
        case .mock: return 0
        }
    }

    public var dimension: Int {
        switch self {
        case .bgeSmallZh: return 512
        case .bgeM3: return 1024
        case .appleNLEmbedding: return 300
        case .mock: return 300
        }
    }

    public var isLarge: Bool {
        sizeBytes > 500 * 1024 * 1024
    }

    /// Locale-driven default: zh-* -> bgeSmallZh, otherwise bgeM3.
    /// (Effective backend is AppleNLEmbedding until ticket 04 wires bge.)
    public static func defaultForLocale(_ locale: Locale = .current) -> EmbeddingModelKind {
        let code = locale.language.languageCode?.identifier ?? "en"
        if code.hasPrefix("zh") { return .bgeSmallZh }
        return .bgeM3
    }
}

public protocol EmbeddingModel: Sendable {
    /// The kind of model this implementation represents.
    var kind: EmbeddingModelKind { get }

    /// Whether the model is ready to embed (downloaded + loaded into memory).
    var isReady: Bool { get async }

    /// Load weights if needed. Idempotent. No-op when already ready.
    func prepare() async throws

    /// Embed a single text into a fixed-dimension Float vector.
    func embed(_ text: String) async throws -> [Float]

    /// Embed a batch of texts. Default implementation calls embed one-by-one.
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
}

public extension EmbeddingModel {
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        var out: [[Float]] = []
        out.reserveCapacity(texts.count)
        for t in texts {
            out.append(try await embed(t))
        }
        return out
    }
}
