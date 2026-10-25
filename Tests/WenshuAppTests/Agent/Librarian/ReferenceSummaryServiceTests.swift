//
//  ReferenceSummaryServiceTests.swift
//
//  The per-document semantic summary (= the one line that lets the
//  agent decide whether a document constrains the chapter it is
//  writing).
//
//  Covers:
//  - the summary is the model's one line, unquoted,
//  - a cut-off answer and an unreadable answer are errors (= a failed
//    remote call is never a silent empty summary),
//  - a document without a summary gets one,
//  - a summary the caller wrote wins (= no model call),
//  - a document keeps its summary (= one model call per document).
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

/// A connector that answers with a fixed line (= the summary service
/// must be testable without a network).
private final class SummaryStubConnector: LLMConnector, @unchecked Sendable {
    let answer: String
    let stopReason: LLMResponse.StopReason
    private(set) var callCount = 0

    init(answer: String, stopReason: LLMResponse.StopReason = .endTurn) {
        self.answer = answer
        self.stopReason = stopReason
    }

    var connectorID: String { "summary-stub" }
    var contextWindow: Int { 32_000 }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        callCount += 1
        return LLMResponse(
            id: "summary-stub",
            model: options.model,
            blocks: [.text(answer)],
            stopReason: stopReason,
            usage: LLMUsage(inputTokens: 10, outputTokens: 5)
        )
    }

    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            continuation.yield(.text(answer))
            continuation.finish()
        }
    }
}

@Suite("Reference document summary")
@MainActor
struct ReferenceSummaryServiceTests {

    private static func makeStore() throws -> FileSystemReferenceStore {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-reference-summary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
    }

    private static func makeService(
        _ connector: SummaryStubConnector
    ) -> ReferenceSummaryService {
        ReferenceSummaryService(
            connector: { connector },
            model: { "summary-stub-model" }
        )
    }

    // MARK: - The service

    @Test("the summary is the model's one line, unquoted")
    func summaryIsOneUnquotedLine() async throws {
        let connector = SummaryStubConnector(answer: "\"A survey of the harbor tide gauges.\"\n")
        let summary = try await Self.makeService(connector).summarize(
            title: "Harbor survey",
            body: "# Harbor survey\n\nThe tide gauge was read at dawn."
        )
        #expect(summary == "A survey of the harbor tide gauges.")
    }

    @Test("a cut-off answer is an error, not an empty summary")
    func cutOffAnswerThrows() async throws {
        let connector = SummaryStubConnector(answer: "", stopReason: .maxTokens)
        await #expect(throws: ReferenceSummaryError.self) {
            try await Self.makeService(connector).summarize(title: "Harbor survey", body: "body")
        }
    }

    @Test("an unreadable answer is an error, not an empty summary")
    func unreadableAnswerThrows() async throws {
        let connector = SummaryStubConnector(answer: "   \n  ")
        await #expect(throws: ReferenceSummaryError.self) {
            try await Self.makeService(connector).summarize(title: "Harbor survey", body: "body")
        }
    }

    // MARK: - The rule that fills Reference.summary

    @Test("a document without a summary gets one from the model")
    func documentWithoutSummaryGetsOne() async throws {
        let store = try Self.makeStore()
        let connector = SummaryStubConnector(answer: "A survey of the harbor tide gauges.")
        let actor = ReferenceLibraryActor(
            referenceStore: store,
            summaryService: Self.makeService(connector)
        )
        let descriptor = try await actor.createReference(
            title: "Harbor survey",
            bodyMarkdown: "# Harbor survey\n\nThe tide gauge was read at dawn."
        )
        #expect(descriptor.summary == "A survey of the harbor tide gauges.")
        #expect(connector.callCount == 1)
    }

    @Test("a summary the caller wrote wins (= no model call)")
    func callerSummaryWins() async throws {
        let store = try Self.makeStore()
        let connector = SummaryStubConnector(answer: "A survey of the harbor tide gauges.")
        let actor = ReferenceLibraryActor(
            referenceStore: store,
            summaryService: Self.makeService(connector)
        )
        let descriptor = try await actor.createReference(
            title: "Harbor survey",
            bodyMarkdown: "# Harbor survey",
            summary: "Tax records"
        )
        #expect(descriptor.summary == "Tax records")
        #expect(connector.callCount == 0)
    }

    @Test("a document keeps its summary (= one model call per document)")
    func documentKeepsItsSummary() async throws {
        let store = try Self.makeStore()
        let connector = SummaryStubConnector(answer: "A survey of the harbor tide gauges.")
        let actor = ReferenceLibraryActor(
            referenceStore: store,
            summaryService: Self.makeService(connector)
        )
        let created = try await actor.createReference(
            title: "Harbor survey",
            bodyMarkdown: "# Harbor survey"
        )
        #expect(connector.callCount == 1)

        // The same title, no summary in the envelope: the document
        // keeps the summary it has (= the summary is written once, at
        // save time, and is not recomputed on every write).
        let upserted = try await actor.upsertReference(
            title: "Harbor survey",
            bodyMarkdown: "# Harbor survey\n\nMore."
        )
        #expect(upserted.id == created.id)
        #expect(upserted.summary == "A survey of the harbor tide gauges.")
        #expect(connector.callCount == 1)
    }
}
