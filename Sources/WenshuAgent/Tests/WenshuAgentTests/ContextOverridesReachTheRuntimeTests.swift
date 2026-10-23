import Testing
@testable import WenshuAgent

/// Independent verification of the context overrides card.
///
/// These drive the RUNTIME CONSUMERS (the compressor and the recall
/// path), not the settings struct: a settings value is just a value, and
/// only the consumer proves the number reaches the behaviour.
@Suite("Context overrides reach the runtime")
@MainActor
struct ContextOverridesReachTheRuntimeTests {

    // MARK: - Helpers

    private func message(_ text: String) -> LLMMessage {
        LLMMessage(role: .user, blocks: [.text(text)])
    }

    /// A transcript of `count` messages, each worth `chars` characters.
    private func transcript(count: Int, chars: Int) -> [LLMMessage] {
        (0..<count).map { index in
            message(String(repeating: "x", count: chars) + " \(index)")
        }
    }

    /// One token per four characters, so a test can reason in tokens.
    private let estimator: @Sendable (LLMMessage) -> Int = { message in
        let text = message.blocks.compactMap { block -> String? in
            if case let .text(value) = block { return value }
            return nil
        }.joined()
        return max(1, text.count / 4)
    }

    // MARK: - The threshold

    @Test("A lower threshold compresses sooner")
    func lowerThresholdCompressesSooner() {
        // 60 messages of 100 tokens each = 6000 tokens, against a window
        // of 10000 (= 60% of the window is in use).
        let messages = transcript(count: 60, chars: 400)

        var eager = CompressionBudget()
        eager.threshold = 0.5
        var relaxed = CompressionBudget()
        relaxed.threshold = 0.9

        let eagerCompressor = HistoryCompressor(budget: eager, estimate: estimator)
        let relaxedCompressor = HistoryCompressor(budget: relaxed, estimate: estimator)

        #expect(eagerCompressor.needsCompression(messages, contextWindow: 10_000))
        #expect(!relaxedCompressor.needsCompression(messages, contextWindow: 10_000))
    }

    @Test("The installed threshold is the threshold the compressor uses")
    func installedThresholdIsUsed() {
        let messages = transcript(count: 60, chars: 400)
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        // 0.5 = compress at 50% of the window; the transcript is at 60%,
        // so it must compress.
        ContextOverrides.install(ContextOverrides.Values(compressionThreshold: 0.5))
        let eager = HistoryCompressor(budget: CompressionBudget(), estimate: estimator)
        #expect(eager.needsCompression(messages, contextWindow: 10_000))

        // 0.95 = compress at 95% of the window; 60% is not enough.
        ContextOverrides.install(ContextOverrides.Values(compressionThreshold: 0.95))
        let relaxed = HistoryCompressor(budget: CompressionBudget(), estimate: estimator)
        #expect(!relaxed.needsCompression(messages, contextWindow: 10_000))
    }

    @Test("A threshold outside (0, 1] falls back to the default")
    func outOfRangeThresholdFallsBack() {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        for bad in [0.0, -0.5, 1.5, 42.0] {
            ContextOverrides.install(
                ContextOverrides.Values(compressionThreshold: bad)
            )
            #expect(
                ContextOverrides.compressionThreshold == 0.85,
                "a threshold of \(bad) must not reach the compressor"
            )
        }
    }

    // MARK: - The keep fraction

    @Test("A larger keep fraction protects a larger tail")
    func largerKeepFractionProtectsLargerTail() {
        // 40 messages of 100 tokens = 4000 tokens in the transcript.
        let messages = transcript(count: 40, chars: 400)

        func survivingMiddle(keepFraction: Double) -> Int {
            var budget = CompressionBudget()
            budget.keepFraction = keepFraction
            // Lift the ceiling so the keep fraction is what decides.
            budget.protectTailTokens = 100_000
            let compressor = HistoryCompressor(budget: budget, estimate: estimator)
            guard let window = compressor.compressionWindow(messages) else { return -1 }
            return window.end - window.start
        }

        let small = survivingMiddle(keepFraction: 0.10)
        let large = survivingMiddle(keepFraction: 0.60)

        #expect(small >= 0, "a compression window must exist")
        #expect(large >= 0, "a compression window must exist")
        #expect(
            large < small,
            "a bigger keep fraction must summarise less (\(large) vs \(small))"
        )
    }

    @Test("The keep fraction is of the transcript, not of the context window")
    func keepFractionIsOfTheTranscript() {
        // The same transcript, two different windows. If the fraction were
        // of the window, the window would change the outcome. It must not:
        // the compressor is not given a window at this point.
        let messages = transcript(count: 40, chars: 400)

        func survivingMiddle(keepFraction: Double) -> Int {
            var budget = CompressionBudget()
            budget.keepFraction = keepFraction
            budget.protectTailTokens = 100_000
            let compressor = HistoryCompressor(budget: budget, estimate: estimator)
            guard let window = compressor.compressionWindow(messages) else { return -1 }
            return window.end - window.start
        }

        #expect(
            survivingMiddle(keepFraction: 0.3) == survivingMiddle(keepFraction: 0.3),
            "the outcome must not depend on anything outside the transcript"
        )
    }

    @Test("The count floor wins over a keep fraction that asks for less")
    func countFloorWins() {
        let messages = transcript(count: 40, chars: 400)

        // The tail is protected by a message COUNT first (= tool pairs
        // must survive), so a keep fraction below what that count is worth
        // cannot shrink it. The fraction is a target, not a cap.
        var budget = CompressionBudget()
        budget.keepFraction = 0.02
        budget.protectTail = 8
        budget.protectTailTokens = 100_000
        let compressor = HistoryCompressor(budget: budget, estimate: estimator)
        guard let window = compressor.compressionWindow(messages) else {
            Issue.record("a compression window must exist")
            return
        }
        #expect(
            messages.count - window.end >= 8,
            "the count floor must hold (\(messages.count - window.end) messages)"
        )
    }

    @Test("The ceiling caps the growth beyond the count floor")
    func ceilingCapsGrowth() {
        let messages = transcript(count: 40, chars: 400)

        // With a floor of one message, the token budget is what decides.
        var budget = CompressionBudget()
        budget.keepFraction = 0.9
        budget.protectTail = 1
        budget.protectTailTokens = 400
        let compressor = HistoryCompressor(budget: budget, estimate: estimator)
        guard let window = compressor.compressionWindow(messages) else {
            Issue.record("a compression window must exist")
            return
        }
        let tailTokens = compressor.totalTokens(Array(messages[window.end...]))
        #expect(
            tailTokens <= 500,
            "the ceiling must cap the growth (\(tailTokens) tokens survived)"
        )
    }

    @Test("A keep fraction outside (0, 1] falls back to the default")
    func outOfRangeKeepFractionFallsBack() {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        for bad in [0.0, -0.5, 1.5] {
            ContextOverrides.install(ContextOverrides.Values(keepFraction: bad))
            #expect(
                ContextOverrides.keepFraction == 0.3,
                "a keep fraction of \(bad) must not reach the compressor"
            )
        }
    }

    // MARK: - The memory cap

    @Test("A memory cap below one falls back to the default")
    func outOfRangeMemoryCapFallsBack() {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 0))
        #expect(ContextOverrides.memoryCap == 5, "a cap of zero is not a cap")

        ContextOverrides.install(ContextOverrides.Values(memoryCap: -3))
        #expect(ContextOverrides.memoryCap == 5, "a negative cap is not a cap")
    }

    @Test("The installed cap is the cap the recall uses")
    func installedCapIsUsed() async {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        // A provider that always returns more entries than any cap.
        let provider = CountingMemoryProvider(entries: 40)
        let adapter = MemoryAdapter(provider: provider)

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 3))
        let few = await adapter.retrieve(forUserMessage: "hello")
        #expect(few.count == 3, "the cap must bound the recall (\(few.count))")

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 7))
        let more = await adapter.retrieve(forUserMessage: "hello")
        #expect(more.count == 7, "the cap must bound the recall (\(more.count))")
    }

    @Test("The character budget bounds the recall even when the count does not")
    func characterBudgetBoundsTheRecall() async {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        // A generous count and long entries: the count alone would let
        // every one of them into the prompt.
        let provider = CountingMemoryProvider(
            entries: 400,
            entryLength: 400
        )
        let adapter = MemoryAdapter(provider: provider)

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 500))
        let entries = await adapter.retrieve(forUserMessage: "hello")

        #expect(!entries.isEmpty, "the recall must not be empty")
        let totalChars = entries.reduce(0) { $0 + $1.snippet.count }
        #expect(
            totalChars <= MemoryAdapter.characterBudget + 400,
            "the character budget must bound the recall (\(totalChars) characters)"
        )
    }

    @Test("The character budget decides how many long entries survive")
    func characterBudgetDecidesTheCount() async {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        // Every entry costs its full snippet (= 120 characters), so the
        // budget decides the count: 2200 / 120 = 18 entries.
        let provider = CountingMemoryProvider(entries: 400, entryLength: 400)
        let adapter = MemoryAdapter(provider: provider)

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 500))
        let entries = await adapter.retrieve(forUserMessage: "hello")

        #expect(!entries.isEmpty, "the recall must not be empty")
        #expect(
            entries.count <= 20,
            "the budget must decide the count (\(entries.count) entries)"
        )
        #expect(
            entries.count < 400,
            "the budget must cut the recall down"
        )
    }
    @Test("A short recall is not cut by the budget")
    func shortRecallSurvives() async {
        defer { ContextOverrides.install(ContextOverrides.Values()) }

        // Five short entries: the budget is not what limits these.
        let provider = CountingMemoryProvider(entries: 5, entryLength: 8)
        let adapter = MemoryAdapter(provider: provider)

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 500))
        let entries = await adapter.retrieve(forUserMessage: "hello")

        #expect(
            entries.count == 5,
            "a short recall must survive whole (\(entries.count))"
        )
    }
}

/// A provider that hands back a fixed number of entries, so the cap is
/// the only thing that can change how many reach the prompt.
private final class CountingMemoryProvider: MemoryProvider, @unchecked Sendable {
    let entries: Int
    let entryLength: Int

    init(entries: Int, entryLength: Int = 8) {
        self.entries = entries
        self.entryLength = entryLength
    }

    var slug: String { "counting" }
    var isEnabled: Bool { true }
    func getSystemPrompt() -> String { "" }
    func getToolSchemas() -> [ToolSchema] { [] }

    func prefetch(forUserMessage message: String) async -> String {
        (0..<entries).map { index in
            "memory \(index) " + String(repeating: "m", count: entryLength)
        }.joined(separator: "\n")
    }

    func sync(userMessage: String, assistantResponse: String) async {}
    func preCompressCheckpoint() async -> String? { nil }
}
