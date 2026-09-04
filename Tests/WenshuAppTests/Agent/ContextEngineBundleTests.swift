//
//  ContextEngineBundleTests.swift · Wenshu · HERMES-PARTIAL-013 (2026-09-04)
//
//  Round-trip tests for the ContextEngine ABC surface (= hermes
//  context_engine.py = 231 LOC):
//    1. testAssembleBundleBasic          — bundle assembly
//    2. testShouldCompressGate           — threshold gate
//    3. testUpdateFromResponse           — usage tracking
//    4. testUpdateModelRecalcThreshold   — model switch updates threshold
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextEngineBundle (HERMES-PARTIAL-013)")
struct ContextEngineBundleTests {

    // MARK: - Test 1: Assemble bundle

    @Test("assembleBundle builds a bundle from explicit inputs")
    func testAssembleBundleBasic() async {
        let engine = ContextEngine()
        let bundle = engine.assembleBundle(
            ephemeralHint: "today is Tuesday",
            cacheableReferences: ["ref 1", "ref 2"],
            perTurnMemos: [
                ContextEngine.MemoryEntry(source: "/a.md", snippet: "remembered X"),
            ]
        )
        #expect(bundle.memories.count == 1)
        #expect(bundle.characterContext.count >= 3)  // ephemeral + 2 refs
        #expect(bundle.characterContext.contains(where: { $0.contains("today is Tuesday") }))
        // isEmpty is false.
        #expect(bundle.isEmpty == false)
    }

    // MARK: - Test 2: Should-compress gate

    @Test("shouldCompress returns true when prompt tokens >= threshold")
    func testShouldCompressGate() async {
        let engine = ContextEngine()
        await engine.updateModel(model: "claude", contextLength: 200_000)
        // thresholdTokens = 200_000 * 0.75 = 150_000
        let status = await engine.getStatus()
        #expect(status.thresholdTokens == 150_000)
        #expect(await engine.shouldCompress(promptTokens: 100_000) == false)
        #expect(await engine.shouldCompress(promptTokens: 160_000) == true)
    }

    // MARK: - Test 3: Update from response

    @Test("updateFromResponse tracks usage state")
    func testUpdateFromResponse() async {
        let engine = ContextEngine()
        let usage = ContextEngine.Usage(
            promptTokens: 5_000,
            completionTokens: 200,
            cacheReadTokens: 1_000
        )
        await engine.updateFromResponse(usage: usage)
        let status = await engine.getStatus()
        #expect(status.lastPromptTokens == 5_000)
        #expect(status.compressionCount == 0)
    }

    // MARK: - Test 4: Update model recalculates threshold

    @Test("updateModel recalculates thresholdTokens from threshold_percent")
    func testUpdateModelRecalcThreshold() async {
        let engine = ContextEngine()
        // Override threshold_percent to 0.5 for a deterministic threshold.
        await engine.setThresholdPercent(0.5)
        await engine.updateModel(model: "gpt-4o", contextLength: 128_000)
        let status = await engine.getStatus()
        #expect(status.contextLength == 128_000)
        #expect(status.thresholdTokens == 64_000)
    }
}

extension ContextEngine {
    /// Test-only setter for threshold_percent (= the public surface uses
    /// the default 0.75; tests need to override it).
    public func setThresholdPercent(_ value: Double) {
        self.thresholdPercent = value
    }
}