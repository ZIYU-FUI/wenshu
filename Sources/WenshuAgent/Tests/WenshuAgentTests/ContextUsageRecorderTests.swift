import Foundation
import Testing
@testable import WenshuAgent

/// The context reading the chat zone's meter shows.
///
/// Two facts are checked: the window the reading is measured against is
/// the one the agent compresses against (= one number, read from the
/// provider's own row), and the parts the reading names are measured
/// rather than guessed.
@Suite("The context reading names the window and its parts")
struct ContextUsageRecorderTests {
    // MARK: - Helpers

    /// A connector that states no window of its own, so the resolution
    /// the protocol carries is what answers.
    private struct WindowlessConnector: LLMConnector {
        nonisolated let connectorID: String

        func send(messages _: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
            LLMResponse(
                id: "unused",
                model: options.model,
                blocks: [],
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

    // MARK: - The window

    @Test("A connector's window is the one its provider publishes")
    func connectorWindowComesFromTheProvider() {
        #expect(
            Provider.by(slug: "minimax-cn")?.defaultContextWindowTokens == 1_000_000,
            "the provider table is where a provider's window lives"
        )
        #expect(
            Provider.by(slug: "anthropic")?.defaultContextWindowTokens == 200_000,
            "each provider carries its own window"
        )
        #expect(
            Provider.by(slug: "deepseek")?.defaultContextWindowTokens == 64000,
            "a provider with a smaller window says so"
        )
    }

    @Test("A connector reads its window from its provider's row")
    func connectorReadsItsProvidersRow() {
        #expect(
            WindowlessConnector(connectorID: "minimax-cn").contextWindow == 1_000_000,
            "a connector on a 1,000,000-token provider must not claim 200,000"
        )
        #expect(
            WindowlessConnector(connectorID: "anthropic").contextWindow == 200_000,
            "a connector on a 200,000-token provider says so"
        )
    }

    @Test("A connector whose provider is unknown answers with the shared default")
    func unknownProviderFallsBackToTheDefault() {
        #expect(
            Provider.by(slug: "not-a-provider") == nil,
            "the lookup must not invent a provider"
        )
        #expect(
            WindowlessConnector(connectorID: "not-a-provider").contextWindow == 200_000,
            "the shared default is the fallback for a connector with no row"
        )
    }

    // MARK: - The parts

    @Test("A prompt's parts are measured, and the tool results are their own part")
    func partsAreMeasured() {
        let messages = [
            LLMMessage(role: .user, blocks: [.text(String(repeating: "u", count: 400))]),
            LLMMessage(
                role: .tool,
                blocks: [.toolResult(toolUseID: "t", output: String(repeating: "r", count: 800), isError: false)]
            ),
        ]
        let measured = ContextUsageMeasure.messageTokens(messages)
        #expect(measured.conversation == 100, "the conversation's own text is a part")
        #expect(measured.toolResults == 200, "the tool results are their own part")
    }

    @Test("The tool schemas are a part of their own")
    func schemasAreMeasured() {
        let schemas = [
            ToolRegistrySchema(
                name: "read",
                description: String(repeating: "d", count: 200),
                inputSchema: ["path": ToolRegistrySchemaProperty(
                    type: "string",
                    description: String(repeating: "p", count: 200)
                )]
            ),
        ]
        #expect(
            ContextUsageMeasure.toolSchemaTokens(schemas) > 0,
            "the schemas travel with every request, so they are a part"
        )
        #expect(
            ContextUsageMeasure.toolSchemaTokens([]) == 0,
            "a request with no schemas has no schema part"
        )
    }

    @Test("An empty text is worth no tokens")
    func emptyTextIsWorthNothing() {
        #expect(ContextUsageMeasure.tokens("") == 0, "empty text costs nothing")
        #expect(
            ContextUsageMeasure.tokens("abcd") == 1,
            "the measure is characters over four"
        )
    }

    // MARK: - The provider's own accounting

    @Test("A provider that counts the cache inside the input count reports the input count")
    func cacheInsideTheInputCountIsNotAddedTwice() {
        let usage = LLMUsage(
            inputTokens: 1000,
            outputTokens: 100,
            cacheReadTokens: 800,
            cacheCreationTokens: 200,
            cacheTokensIncludedInInput: true
        )
        #expect(
            usage.promptTokens == 1000,
            "the cached prefix is already inside the input count: \(usage.promptTokens)"
        )
    }

    @Test("A provider that reports the cache beside the input count reports the sum")
    func cacheBesideTheInputCountIsAdded() {
        let usage = LLMUsage(
            inputTokens: 1000,
            outputTokens: 100,
            cacheReadTokens: 800,
            cacheCreationTokens: 200,
            cacheTokensIncludedInInput: false
        )
        #expect(
            usage.promptTokens == 2000,
            "the provider received the cached tokens too: \(usage.promptTokens)"
        )
    }

    // MARK: - The reading

    @Test("The reading's occupancy is the prompt's share of the window")
    func occupancyIsTheShareOfTheWindow() {
        let snapshot = ContextUsageSnapshot(
            promptTokens: 250_000,
            completionTokens: 1000,
            contextWindow: 1_000_000
        )
        #expect(
            abs(snapshot.occupancy - 0.25) < 0.0001,
            "the occupancy is the prompt's share: \(snapshot.occupancy)"
        )
    }

    @Test("The occupancy never exceeds the window")
    func occupancyIsCappedAtTheWindow() {
        let snapshot = ContextUsageSnapshot(
            promptTokens: 1_500_000,
            completionTokens: 0,
            contextWindow: 1_000_000
        )
        #expect(snapshot.occupancy == 1.0, "the fill cannot pass the window's end")
    }

    @Test("The reading knows the size of each part it names")
    func readingKnowsItsParts() {
        let snapshot = ContextUsageSnapshot(
            promptTokens: 1000,
            completionTokens: 100,
            contextWindow: 10000,
            categories: [
                ContextUsageCategory(id: .systemPrompt, tokens: 400),
                ContextUsageCategory(id: .toolResults, tokens: 300),
            ]
        )
        #expect(snapshot.tokens(for: .systemPrompt) == 400, "the system prompt's size is known")
        #expect(snapshot.tokens(for: .toolResults) == 300, "the tool results' size is known")
        #expect(
            snapshot.tokens(for: .memory) == 0,
            "a part the reading does not carry is worth nothing"
        )
    }

    @Test("The recorder keeps each conversation's reading apart")
    func recorderKeepsConversationsApart() async {
        let recorder = ContextUsageRecorder()
        await recorder.record(
            conversationId: "first",
            snapshot: ContextUsageSnapshot(
                promptTokens: 100,
                completionTokens: 0,
                contextWindow: 1000
            )
        )
        await recorder.record(
            conversationId: "second",
            snapshot: ContextUsageSnapshot(
                promptTokens: 900,
                completionTokens: 0,
                contextWindow: 1000
            )
        )
        let first = await recorder.snapshot(conversationId: "first")
        let second = await recorder.snapshot(conversationId: "second")
        #expect(first?.promptTokens == 100, "the first conversation keeps its own reading")
        #expect(second?.promptTokens == 900, "the second conversation keeps its own reading")
        #expect(
            await recorder.mostRecentSnapshot()?.promptTokens == 900,
            "the most recent reading is the one that just spent the tokens"
        )
    }
}
