//
//  RemoteEmbeddingModel.swift
//  WenshuApp
//
//  §11.26 弧 ticket 04. HTTP-based embedding backend. One struct, four
//  provider endpoints (= OpenAI / minimax / Gemini / DeepSeek). Uses
//  Apple URLSession. No SPM dependencies.
//
//  / Per boss OOB 2026-10-19: only remote APIs, no local fallback.
//  / When the call fails the struct throws (= no silent degrade).
//

import Foundation

public final class RemoteEmbeddingModel: EmbeddingModel, @unchecked Sendable {
    public let kind: EmbeddingModelKind
    private let apiKey: String
    private let session: URLSession

    public init(kind: EmbeddingModelKind, apiKey: String, session: URLSession = .shared) {
        self.kind = kind
        self.apiKey = apiKey
        self.session = session
    }

    public func embed(_ text: String) async throws -> [Float] {
        let result = try await callRemote(texts: [text])
        guard let first = result.first else {
            throw EmbeddingError.emptyResponse
        }
        return first
    }

    public func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        return try await callRemote(texts: texts)
    }

    private func callRemote(texts: [String]) async throws -> [[Float]] {
        switch kind {
        case .openai, .minimax, .deepseek:
            return try await callOpenAICompatible(texts: texts)
        case .gemini:
            return try await callGemini(texts: texts)
        }
    }

    // MARK: - OpenAI-compatible (OpenAI, minimax, DeepSeek)

    private func callOpenAICompatible(texts: [String]) async throws -> [[Float]] {
        let url = URL(string: kind.endpointURL)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "model": kind.modelIdentifier,
            "input": texts
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        let http = response as? HTTPURLResponse
        guard let status = http?.statusCode, (200..<300).contains(status) else {
            let code = http?.statusCode ?? -1
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw EmbeddingError.httpError(status: code, body: String(snippet))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]] else {
            throw EmbeddingError.malformedResponse
        }
        return try arr.map { item -> [Float] in
            guard let emb = item["embedding"] as? [Any] else { throw EmbeddingError.malformedResponse }
            return emb.compactMap { ($0 as? NSNumber)?.floatValue }
        }
    }

    // MARK: - Gemini

    private func callGemini(texts: [String]) async throws -> [[Float]] {
        // Gemini uses a per-text batch endpoint and key= query param (or x-goog-api-key header).
        var results: [[Float]] = []
        for text in texts {
            var components = URLComponents(string: kind.endpointURL)!
            components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
            var req = URLRequest(url: components.url!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 30
            let body: [String: Any] = [
                "model": "models/" + kind.modelIdentifier,
                "content": ["parts": [["text": text]]]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await session.data(for: req)
            let http = response as? HTTPURLResponse
            guard let status = http?.statusCode, (200..<300).contains(status) else {
                let code = http?.statusCode ?? -1
                let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
                throw EmbeddingError.httpError(status: code, body: String(snippet))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let emb = json["embedding"] as? [String: Any],
                  let values = emb["values"] as? [Any] else {
                throw EmbeddingError.malformedResponse
            }
            results.append(values.compactMap { ($0 as? NSNumber)?.floatValue })
        }
        return results
    }
}

public enum EmbeddingError: LocalizedError {
    case emptyResponse
    case malformedResponse
    case httpError(status: Int, body: String)
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case .emptyResponse: return "Embedding provider returned no vectors."
        case .malformedResponse: return "Embedding provider response could not be parsed."
        case .httpError(let status, let body):
            return "Embedding provider HTTP \(status): \(body)"
        case .missingAPIKey: return "No API key configured for this provider (= set in Settings → 模型 → Embedding)."
        }
    }
}
