//
//  AppleNLEmbeddingBackend.swift
//  WenshuApp
//
//  §11.26 弧 ticket 03. Backend that wraps Apple's on-device
//  NaturalLanguage framework. Per PoC step 3, the word-avg strategy
//  (over NLEmbedding.wordEmbedding(.zh-Hans)) gives 0.20-0.72 cosine
//  discrimination for short Chinese text. Lower than bge but always
//  available, no download required.
//
//  / Acts as the always-available fallback when MLX bge prepare() fails
//  (= network blocked, hub unreachable, model not yet downloaded).
//

import Foundation
import NaturalLanguage

public actor AppleNLEmbeddingBackend: EmbeddingModel {
    public let kind: EmbeddingModelKind = .appleNLEmbedding
    public private(set) var isReady: Bool = false

    private let wordEmbedding: NLEmbedding?
    private let tokenizer: NLTokenizer

    public init() {
        // Chinese word embedding is available on macOS 27; other languages
        // may also have word embeddings; we pick Chinese as the primary
        // because most wenshu novels are written in zh-Hans per OOB 2026-10-18.
        self.wordEmbedding = NLEmbedding.wordEmbedding(for: .simplifiedChinese)
            ?? NLEmbedding.wordEmbedding(for: .english)
        self.tokenizer = NLTokenizer(unit: .word)
        self.isReady = wordEmbedding != nil
    }

    public func prepare() async throws {
        // Word embeddings are always present on macOS 27. Nothing to load.
    }

    public func embed(_ text: String) async throws -> [Float] {
        let dim = kind.dimension
        guard let wordEmbedding else { return [Float](repeating: 0, count: dim) }

        var doubleVectors: [[Double]] = []
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            if let v = wordEmbedding.vector(for: token) {
                doubleVectors.append(v)
            }
            return true
        }

        guard !doubleVectors.isEmpty else { return [Float](repeating: 0, count: dim) }
        var avg = [Float](repeating: 0, count: dim)
        for v in doubleVectors { for i in 0..<dim { avg[i] += Float(v[i]) } }
        for i in 0..<dim { avg[i] /= Float(doubleVectors.count) }
        // L2 normalize so cosine = dot product.
        var norm: Float = 0
        for x in avg { norm += x * x }
        let n = sqrt(norm)
        if n > 0 { for i in 0..<dim { avg[i] /= n } }
        return avg
    }
}
