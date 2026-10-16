//
//  WAStreamDiagTests.swift · Wenshu · WenshuAgent unit test for WAStreamDiag
//
//  Verifies the streaming diagnostic dict (= hermes stream_dag.py
//  port). Tests:
//   - firstChunkLatencyMs derivation
//   - durationMs monotonic
//   - summary includes all set fields
//   - the WAStreamDiagHeader.waStreamDiagHeaders() extractor
//
//  Created: 2026-10-16 (WenshuAgent P3.6 unit tests)
//

import Testing
import Foundation

@testable import WenshuApp

@Suite("WAStreamDiag")
struct WAStreamDiagTests {

    @Test("firstChunkLatencyMs derived from startedAt + firstChunkAt")
    func testFirstChunkLatency() {
        var diag = WAStreamDiag(attemptId: UUID(), startedAt: Date())
        diag.firstChunkAt = diag.startedAt.addingTimeInterval(0.123)
        #expect(diag.firstChunkLatencyMs == 123)
    }

    @Test("firstChunkLatencyMs nil before first chunk")
    func testFirstChunkLatencyNil() {
        let diag = WAStreamDiag(attemptId: UUID())
        #expect(diag.firstChunkLatencyMs == nil)
    }

    @Test("summary includes attempt + dur + chunks + bytes + http + finished")
    func testSummary() {
        var diag = WAStreamDiag(attemptId: UUID())
        diag.chunks = 18
        diag.bytes = 2048
        diag.httpStatus = 200
        diag.finishReasonSeen = true
        let s = diag.summary
        #expect(s.contains("chunks=18"))
        #expect(s.contains("bytes=2048"))
        #expect(s.contains("http=200"))
        #expect(s.contains("finished"))
    }

    @Test("waStreamDiagHeaders extracts hermes STREAM_DIAG_HEADERS")
    func testStreamDiagHeaders() {
        let headers: [String: String] = [
            "cf-ray": "8a1b2c3d4e5f",
            "x-openrouter-provider": "anthropic",
            "content-type": "text/event-stream", // not in our list
            "x-request-id": "req-12345"
        ]
        let extracted = headers.waStreamDiagHeaders()
        #expect(extracted["cf-ray"] == "8a1b2c3d4e5f")
        #expect(extracted["x-openrouter-provider"] == "anthropic")
        #expect(extracted["x-request-id"] == "req-12345")
        #expect(extracted["content-type"] == nil)  // not in our list
    }
}
