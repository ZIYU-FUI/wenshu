//
//  EmbeddingModel.swift
//  WenshuApp
//
//  §11.26 弧 ticket 04. Protocol + model-kind enum for remote
//  embedding providers (= OpenAI / minimax / Gemini / DeepSeek).
//
//  / Per boss OOB 2026-10-19: only remote APIs. Local fallbacks
//  / (Apple NLEmbedding, Mock) removed (= 体验打折扣). When the
//  / remote call fails, the service throws (= no silent fallback).
//
//  / Per AGENTS.md §6.5 file-naming: this is the canonical <Xxx>Model.swift
//  / (= 1 of 4 suffixes: View/Ops/Service/State/Model; = kind enum inline
//  / since 1-type file would violate §6.9 single-file-dir = deletion rule).
//

import Foundation

public enum EmbeddingModelKind: String, CaseIterable, Codable, Sendable {
    /// OpenAI text-embedding-3-small. 1536 dim. Generic multilingual.
    case openai
    /// minimax M2-Embedding. 1024 dim. (per boss 2026-10-19: "minimaxi 的 token plan 是有向量模型的".)
    case minimax
    /// Google text-embedding-004. 768 dim.
    case gemini
    /// DeepSeek embedding (via OpenAI-compatible /v1/embeddings endpoint). 1024 dim.
    case deepseek

    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .minimax: return "minimax"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        }
    }

    /// Reuses WenshuAgent's existing provider slugs (= same key can power
    /// both LLM and embedding per boss OOB 2026-10-19 "可以沿用大模型").
    public var providerSlug: String {
        switch self {
        case .openai: return "openai"
        case .minimax: return "minimax-cn"
        case .gemini: return "gemini"
        case .deepseek: return "deepseek"
        }
    }

    public var dimension: Int {
        switch self {
        case .openai: return 1536
        case .minimax: return 1024
        case .gemini: return 768
        case .deepseek: return 1024
        }
    }

    public var endpointURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1/embeddings"
        case .minimax: return "https://api.minimax.chat/v1/embeddings"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"
        case .deepseek: return "https://api.deepseek.com/v1/embeddings"
        }
    }

    public var modelIdentifier: String {
        switch self {
        case .openai: return "text-embedding-3-small"
        case .minimax: return "M2-Embedding"
        case .gemini: return "text-embedding-004"
        case .deepseek: return "deepseek-embedding"
        }
    }
}

public protocol EmbeddingModel: Sendable {
    var kind: EmbeddingModelKind { get }
    func embed(_ text: String) async throws -> [Float]
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
