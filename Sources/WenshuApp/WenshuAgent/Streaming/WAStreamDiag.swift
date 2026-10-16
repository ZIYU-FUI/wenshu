//
//  WAStreamDiag.swift · Wenshu · WenshuAgent streaming diagnostic dict
//
//  Per-attempt diagnostic dict (= hermes `stream_diag.py` ported to Swift).
//  Records: startedAt, firstChunkAt, chunks count, bytes count, httpStatus,
//  finishReasonSeen, servingProvider (cf-ray/x-openrouter-provider from
//  response headers), requestHeaders (STREAM_DIAG_HEADERS subset), lastError.
//
//  Created: 2026-10-16 (WenshuAgent P3.2)
//  Source: hermes `agent/stream_diag.py` 240 LOC
//

import Foundation

public struct WAStreamDiag: Sendable {
    public let attemptId: UUID
    public var startedAt: Date
    public var firstChunkAt: Date?
    public var chunks: Int
    public var bytes: Int
    public var httpStatus: Int?
    public var finishReasonSeen: Bool
    public var servingProvider: String?
    public var lastError: String?

    public init(
        attemptId: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.attemptId = attemptId
        self.startedAt = startedAt
        self.firstChunkAt = nil
        self.chunks = 0
        self.bytes = 0
        self.httpStatus = nil
        self.finishReasonSeen = false
        self.servingProvider = nil
        self.lastError = nil
    }

    public var firstChunkLatencyMs: Int? {
        guard let first = firstChunkAt else { return nil }
        return Int(first.timeIntervalSince(startedAt) * 1000)
    }

    public var durationMs: Int {
        Int(Date().timeIntervalSince(startedAt) * 1000)
    }

    public var summary: String {
        var parts: [String] = []
        parts.append("attempt=\(attemptId.uuidString.prefix(8))")
        parts.append("dur=\(durationMs)ms")
        if let lat = firstChunkLatencyMs {
            parts.append("first=\(lat)ms")
        }
        parts.append("chunks=\(chunks)")
        parts.append("bytes=\(bytes)")
        if let s = httpStatus {
            parts.append("http=\(s)")
        }
        if let sp = servingProvider {
            parts.append("serving=\(sp)")
        }
        if finishReasonSeen {
            parts.append("finished")
        }
        if let err = lastError {
            parts.append("err=\(err)")
        }
        return parts.joined(separator: " ")
    }
}

/// hermes STREAM_DIAG_HEADERS = response headers that reveal the actual
/// serving infrastructure (= what cf-ray or x-openrouter-provider returned).
public enum WAStreamDiagHeader: String, CaseIterable {
    case cfRay           = "cf-ray"
    case cfCache         = "cf-cache-status"
    case openRouterProv  = "x-openrouter-provider"
    case openRouterModel = "x-openrouter-model"
    case requestId       = "x-request-id"
    case vercelId        = "x-vercel-id"
    case via             = "via"
    case server          = "server"
}

public extension Dictionary where Key == String, Value == String {
    /// Extracts hermes STREAM_DIAG_HEADERS into a flat dict.
    func waStreamDiagHeaders() -> [String: String] {
        var out: [String: String] = [:]
        for key in WAStreamDiagHeader.allCases {
            if let value = self[key.rawValue] {
                out[key.rawValue] = value
            }
        }
        return out
    }
}

/// Mutable reference-box for `WAStreamDiag` (= a `var` `struct`
/// captured by a closure cannot be mutated; = this box solves the
/// mutation-across-async-task problem).
final class MutableWAStreamDiag: @unchecked Sendable {
    var diag: WAStreamDiag

    init(_ initial: WAStreamDiag) {
        self.diag = initial
    }
}
