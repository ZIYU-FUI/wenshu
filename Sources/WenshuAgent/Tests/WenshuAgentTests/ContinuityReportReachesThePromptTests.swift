//
//  ContinuityReportReachesThePromptTests.swift · Wenshu
//
//  The book's own report reaches the writer's turn.
//
//  The report has a slot in the context bundle and nowhere else: = =
//  the bundle's `worldContext` and `foreshadowContext` are what the
//  prompt renders as its `World:` and `Foreshadowing:` sections. = =
//  These drive the runtime's own composition (= the same path the
//  turn takes), = = because a report that renders but does not reach
//  the prompt is a report nobody reads.
//
//

import Foundation
import Testing
@testable import WenshuAgent

@Suite("ContinuityReport (= the book's report reaches the prompt)")
struct ContinuityReportReachesThePromptTests {
    /// A provider that always answers with this report.
    private struct FixedProvider: ContinuityProvider {
        let report: ContinuityReport
        func continuityReport() async -> ContinuityReport {
            report
        }
    }

    private static let aReport = ContinuityReport(
        worldConflicts: [
            ContinuityReport.WorldConflict(
                subject: "张铁牛",
                attribute: "年龄",
                severity: "blocking",
                rule: "One value at a moment.",
                claimIDs: ["张铁牛#1", "张铁牛#2"]
            ),
        ],
        brokenThreads: [
            ContinuityReport.BrokenThread(
                chapter: 3,
                kind: "plant-never-paid-off",
                detail: "chapter 3 plants a thread that no chapter pays off"
            ),
        ]
    )

    // MARK: - The report's own shape

    @Test("the report's world rows name the subject, the rule, and the claims")
    func theWorldRowsNameEverything() {
        let rows = Self.aReport.worldContext
        #expect(rows.count == 1)
        #expect(rows[0].contains("张铁牛"))
        #expect(rows[0].contains("年龄"))
        #expect(rows[0].contains("One value at a moment."))
        #expect(rows[0].contains("张铁牛#1"))
    }

    @Test("the report's thread rows name the chapter the break happens in")
    func theThreadRowsNameTheirChapter() {
        let rows = Self.aReport.foreshadowContext
        #expect(rows.count == 1)
        #expect(rows[0].contains("chapter 3"))
        #expect(rows[0].contains("plant-never-paid-off"))
    }

    @Test("an empty report says nothing")
    func anEmptyReportSaysNothing() {
        let report = ContinuityReport()
        #expect(report.isEmpty)
        #expect(report.worldContext.isEmpty)
        #expect(report.foreshadowContext.isEmpty)
    }

    // MARK: - The report in the prompt

    @Test("the bundle renders the report as the world's and the threads' sections")
    func theBundleRendersTheReport() {
        let rendered = PromptBuilder.renderContextBundle(
            ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: Self.aReport.worldContext,
                foreshadowContext: Self.aReport.foreshadowContext
            )
        )
        #expect(rendered.contains("World:"))
        #expect(rendered.contains("Foreshadowing:"))
        #expect(rendered.contains("张铁牛"))
        #expect(rendered.contains("chapter 3"))
    }

    @Test("a turn with no report carries no world and no thread section")
    func aTurnWithNoReportCarriesNoSections() {
        let rendered = PromptBuilder.renderContextBundle(
            ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            )
        )
        #expect(!rendered.contains("World:"))
        #expect(!rendered.contains("Foreshadowing:"))
    }

    @Test("the turn's own prompt carries the report")
    func theTurnsPromptCarriesTheReport() async {
        // The runtime's own composition path: = = the loop asks the
        // provider once and puts the answer in the bundle, = = and the
        // prompt renders the bundle.
        let loop = ConversationLoop(
            connection: QuietConnector(),
            systemPrompt: "stable",
            continuityProvider: FixedProvider(report: Self.aReport)
        )
        let composed = await loop.composeSystemPrompt(
            override: "write the next chapter",
            persistent: nil
        )
        let text = composed.text ?? ""
        #expect(text.contains("World:"))
        #expect(text.contains("Foreshadowing:"))
        #expect(text.contains("张铁牛"))
    }

    @Test("a turn whose provider says nothing carries no report")
    func aTurnWithAnEmptyProviderCarriesNoReport() async {
        let loop = ConversationLoop(
            connection: QuietConnector(),
            systemPrompt: "stable",
            continuityProvider: FixedProvider(report: ContinuityReport())
        )
        let composed = await loop.composeSystemPrompt(
            override: "write the next chapter",
            persistent: nil
        )
        let text = composed.text ?? ""
        #expect(!text.contains("World:"))
        #expect(!text.contains("Foreshadowing:"))
    }

    @Test("a turn with no provider carries no report")
    func aTurnWithNoProviderCarriesNoReport() async {
        let loop = ConversationLoop(
            connection: QuietConnector(),
            systemPrompt: "stable"
        )
        let composed = await loop.composeSystemPrompt(
            override: "write the next chapter",
            persistent: nil
        )
        let text = composed.text ?? ""
        #expect(!text.contains("World:"))
        #expect(!text.contains("Foreshadowing:"))
    }
}

/// A connector that answers nothing (= the turn's prompt is composed
/// before any call is made, = = so the prompt is what this proves).
private actor QuietConnector: LLMConnector {
    nonisolated let connectorID: String = "quiet"
    nonisolated let contextWindow: Int = 32000

    func send(
        messages _: [LLMMessage],
        options: LLMCallOptions
    ) async throws -> LLMResponse {
        LLMResponse(
            id: "quiet",
            model: options.model,
            blocks: [.text("")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }

    nonisolated func stream(
        messages _: [LLMMessage],
        options _: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { $0.finish() }
    }
}
