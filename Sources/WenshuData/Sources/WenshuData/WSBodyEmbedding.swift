//
//  WSBodyEmbedding.swift
//
//  §11.26 弧 ticket A1. Per-body embedding cache. Stores the Float
//  vector for a WSBody row, plus provenance (= which embedding model
//  produced it, when). One row per (bodyID, modelKind) pair — re-embed
//  replaces the row in place.
//
//  / Persistence = SwiftData (= consistent with WSBody itself). Vector
//  / bytes stored as Data (BLOB). Dimension must match the model that
//  / produced the vector (= the modelKind is the source of truth).
//

import Foundation
import SwiftData

@Model
public final class WSBodyEmbedding {
    @Attribute(.unique) public var id: String
    /// FK to WSBody.id (= one body has many embeddings, one per model).
    public var bodyID: String
    /// EmbeddingModelKind rawValue (= "openai" / "minimax" / "gemini" / "deepseek").
    public var modelKindRaw: String
    /// Vector dimension (= 1536 / 1024 / 768 / 1024).
    public var dimension: Int
    /// Raw Float32 bytes (= vector) stored as Data.
    public var vector: Data
    /// When the embedding was produced (= used to invalidate stale rows).
    public var generatedAt: Date

    public init(
        id: String,
        bodyID: String,
        modelKindRaw: String,
        dimension: Int,
        vector: Data,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.bodyID = bodyID
        self.modelKindRaw = modelKindRaw
        self.dimension = dimension
        self.vector = vector
        self.generatedAt = generatedAt
    }

    public var floats: [Float] {
        vector.withUnsafeBytes { raw in
            let count = vector.count / MemoryLayout<Float>.size
            let buffer = raw.bindMemory(to: Float.self)
            return Array(UnsafeBufferPointer(start: buffer.baseAddress, count: count))
        }
    }

    public static func encode(_ floats: [Float]) -> Data {
        floats.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
    }
}
