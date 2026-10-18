//
//  EmbeddingMockOps.swift
//  WenshuApp
//
//  §11.26 弧 ticket 02. Mock embedding backend for unit tests + local dev.
//
//  / Implements the same word-avg strategy PoC step 3 verified works
//  / for short Chinese text. The 0.20-0.72 cosine range is acceptable
//  / for development. Production swaps this for the bge backend in
//  / ticket 03.
//

import Foundation

public final class MockEmbeddingModel: EmbeddingModel, @unchecked Sendable {
    public let kind: EmbeddingModelKind = .mock
    public var isReady: Bool { true }

    public init() {}

    public func prepare() async throws {
        // No-op: mock is always ready.
    }

    public func embed(_ text: String) async throws -> [Float] {
        let dim = kind.dimension
        var vec = [Float](repeating: 0, count: dim)

        // Stable hash-based word embedding. Each character contributes
        // to a fixed subset of dimensions. Not semantic, but stable
        // across runs.
        for scalar in text.unicodeScalars {
            let h = Int(scalar.value)
            for i in 0..<8 {
                let idx = (h &+ i &* 31) % dim
                if idx >= 0 && idx < dim {
                    vec[idx] += 1.0 / Float(text.count + 1)
                }
            }
        }
        return vec
    }
}
