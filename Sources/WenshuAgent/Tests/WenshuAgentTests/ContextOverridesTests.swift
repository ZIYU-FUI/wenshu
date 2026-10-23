//
//  ContextOverridesTests.swift · Wenshu
//
//  The rule under test: the numbers the user picked in the settings screen
//  are the numbers the runtime uses.
//
//  The settings struct is a value; it does not know what the compressor or
//  the recall does with it. So every test here drives the RUNTIME CONSUMER
//  (= the compressor that decides to compress, the window it protects, the
//  recall that fills the prompt) and reads the difference the user's
//  number makes.
//
//  The holder is one process-wide value, so the suite is serialized: Swift
//  Testing runs the tests of a suite in parallel, and they would otherwise
//  overwrite each other's numbers and read each other's result.
//

import Foundation
import SwiftData
import Testing
import WenshuData
@testable import WenshuAgent

@Suite("Context overrides", .serialized)
struct ContextOverridesTests {

    /// Restore the shared holder after a test, so one test's numbers cannot
    /// leak into another.
    private func withOverrides(_ values: ContextOverrides.Values, _ body: () -> Void) {
        let previous = ContextOverrides.values
        ContextOverrides.install(values)
        defer { ContextOverrides.install(previous) }
        body()
    }

    /// The same, for a body that awaits.
    private func withOverrides(_ values: ContextOverrides.Values, _ body: () async -> Void) async {
        let previous = ContextOverrides.values
        ContextOverrides.install(values)
        defer { ContextOverrides.install(previous) }
        await body()
    }

    private func user(_ text: String) -> LLMMessage {
        LLMMessage(role: .user, blocks: [.text(text)])
    }

    /// A transcript of `count` messages, each worth `tokens` tokens.
    private func transcript(count: Int, tokens: Int) -> [LLMMessage] {
        (0..<count).map { _ in
            LLMMessage(role: .user, blocks: [.text(String(repeating: "x", count: max(0, tokens * 4 - 8)))])
        }
    }

    // MARK: - The compression threshold

    @Test("the threshold the user picked decides whether the compressor runs")
    func thresholdReachesTheCompressor() {
        let messages = transcript(count: 100, tokens: 100)
        // Half the window: over the low threshold, under the high one.
        let window = 20_000

        var decided: [Bool] = []
        for threshold in [0.3, 0.9] {
            withOverrides(ContextOverrides.Values(compressionThreshold: threshold)) {
                // The compressor is built after the install, the way the
                // conversation loop builds it each turn.
                decided.append(HistoryCompressor().needsCompression(messages, contextWindow: window))
            }
        }
        #expect(decided == [true, false],
                "the user's threshold must decide whether compression runs")
    }

    @Test("a threshold outside the fraction range never reaches the compressor")
    func thresholdOutOfRangeFallsBack() {
        withOverrides(ContextOverrides.Values(compressionThreshold: 1.5)) {
            #expect(ContextOverrides.compressionThreshold == 0.85,
                    "a threshold above the whole window is not a share of it")
        }
        withOverrides(ContextOverrides.Values(compressionThreshold: -1)) {
            #expect(ContextOverrides.compressionThreshold == 0.85,
                    "a negative threshold is not a share of a window")
        }
    }

    // MARK: - The keep fraction

    @Test("the keep fraction decides how much of the transcript survives")
    func keepFractionReachesTheWindow() {
        let messages = transcript(count: 40, tokens: 50)

        var ends: [Int] = []
        for fraction in [0.1, 0.9] {
            withOverrides(ContextOverrides.Values(keepFraction: fraction)) {
                guard let window = HistoryCompressor().compressionWindow(messages) else {
                    Issue.record("a 40-message transcript must have a compression window")
                    return
                }
                ends.append(window.end)
            }
        }
        #expect(ends[0] > ends[1],
                "a smaller keep fraction must protect less of the transcript")
    }

    @Test("a keep fraction outside the fraction range never reaches the compressor")
    func keepFractionOutOfRangeFallsBack() {
        withOverrides(ContextOverrides.Values(keepFraction: 0)) {
            #expect(ContextOverrides.keepFraction == 0.3,
                    "zero would keep nothing, which is not a fraction of a transcript")
        }
        withOverrides(ContextOverrides.Values(keepFraction: 2)) {
            #expect(ContextOverrides.keepFraction == 0.3,
                    "a fraction above one is not a fraction of a transcript")
        }
    }

    // MARK: - The memory cap

    @MainActor
    private func adapter(provider: any MemoryProvider) -> MemoryAdapter {
        let schema = Schema([WSMemory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return MemoryAdapter(
            defaults: .standard,
            memory: WSMemoryRepository(container: container),
            provider: provider
        )
    }

    @MainActor
    @Test("the memory cap the user picked bounds the recall")
    func memoryCapReachesTheRecall() async {
        let provider = StubMemoryProvider(lines: (0..<8).map { "memory \($0)" })
        let previous = ContextOverrides.values
        defer { ContextOverrides.install(previous) }

        var counts: [Int] = []
        for cap in [2, 5] {
            ContextOverrides.install(ContextOverrides.Values(memoryCap: cap))
            let entries = await adapter(provider: provider).retrieve(forUserMessage: "hello")
            counts.append(entries.count)
        }
        #expect(counts == [2, 5],
                "the user's cap must decide how many memories reach the prompt")
    }

    @MainActor
    @Test("a cap of zero is not a cap (= it falls back to the default)")
    func zeroMemoryCapFallsBack() async {
        let provider = StubMemoryProvider(lines: (0..<8).map { "memory \($0)" })
        let previous = ContextOverrides.values
        defer { ContextOverrides.install(previous) }

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 0))
        #expect(ContextOverrides.memoryCap == 5,
                "zero must not silence the recall and must not mean unlimited")
        let entries = await adapter(provider: provider).retrieve(forUserMessage: "hello")
        #expect(entries.count == 5,
                "a zero cap must not recall nothing and must not recall everything")
    }

    @MainActor
    @Test("the recall is bounded by characters as well as by count")
    func recallIsBoundedByCharacters() async {
        // A cap far above the number of rows, so the character budget is the
        // bound that bites.
        let provider = StubMemoryProvider(lines: (0..<40).map { _ in String(repeating: "y", count: 200) })
        let previous = ContextOverrides.values
        defer { ContextOverrides.install(previous) }

        ContextOverrides.install(ContextOverrides.Values(memoryCap: 50))
        let entries = await adapter(provider: provider).retrieve(forUserMessage: "hello")
        let characters = entries.reduce(0) { $0 + $1.snippet.count }
        #expect(characters <= MemoryAdapter.characterBudget,
                "the character budget must bound what the recall carries")
        #expect(!entries.isEmpty, "the budget must not silence the recall")
    }
}

/// A provider that hands back a fixed list of memories.
private struct StubMemoryProvider: MemoryProvider {
    let lines: [String]

    var slug: String { "stub" }
    var isEnabled: Bool { true }

    func getSystemPrompt() -> String { "" }

    func prefetch(forUserMessage message: String) async -> String {
        lines.joined(separator: "\n")
    }

    func sync(userMessage: String, assistantResponse: String) async {}

    func getToolSchemas() -> [ToolSchema] { [] }

    func preCompressCheckpoint() async -> String? { nil }
}
