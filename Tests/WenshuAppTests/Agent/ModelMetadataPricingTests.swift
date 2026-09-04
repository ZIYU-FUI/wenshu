//
//  ModelMetadataPricingTests.swift · Wenshu · HERMES-PARTIAL-015 (2026-09-04)
//
//  Round-trip tests for ModelMetadata extensions (= hermes
//  model_metadata.py = 2,434 LOC):
//    1. testContextWindowPerModel         — per-model token count lookup
//    2. testPricingPerModel               — pricing lookup + cost math
//    3. testFeaturesPerModel              — feature matrix
//    4. testEstimateTokens                — rough token estimator
//    5. testCostComputation               — Pricing.cost math
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ModelMetadataPricing (HERMES-PARTIAL-015)")
struct ModelMetadataPricingTests {

    // MARK: - Test 1: Per-model context window

    @Test("contextWindow(for:) returns the right per-model token count")
    func testContextWindowPerModel() {
        #expect(WenshuModelCatalog.contextWindow(for: "claude-opus-4-20250514") == 200_000)
        #expect(WenshuModelCatalog.contextWindow(for: "claude-3-5-sonnet-20241022") == 200_000)
        #expect(WenshuModelCatalog.contextWindow(for: "gpt-4o") == 128_000)
        #expect(WenshuModelCatalog.contextWindow(for: "deepseek-chat") == 64_000)
        #expect(WenshuModelCatalog.contextWindow(for: "gemini-2.0-flash") == 1_000_000)
        #expect(WenshuModelCatalog.contextWindow(for: "unknown-model") == 0)
    }

    // MARK: - Test 2: Pricing lookup

    @Test("pricing(for:) returns the right Pricing for known models")
    func testPricingPerModel() {
        let opusPrice = WenshuModelCatalog.pricing(for: "claude-opus-4-20250514")
        #expect(opusPrice != nil)
        #expect(opusPrice?.inputPerMTok == 15.0)
        #expect(opusPrice?.outputPerMTok == 75.0)
        #expect(opusPrice?.cachedInputPerMTok == 1.50)

        let sonnetPrice = WenshuModelCatalog.pricing(for: "claude-3-5-sonnet-20241022")
        #expect(sonnetPrice?.inputPerMTok == 3.0)
        #expect(sonnetPrice?.outputPerMTok == 15.0)

        let ollamaPrice = WenshuModelCatalog.pricing(for: "llama3-local")
        #expect(ollamaPrice == nil)  // local models have no pricing
    }

    // MARK: - Test 3: Feature matrix

    @Test("features(for:) returns the right feature flags per model")
    func testFeaturesPerModel() {
        let opusFeatures = WenshuModelCatalog.features(for: "claude-opus-4-20250514")
        #expect(opusFeatures.contains(.vision))
        #expect(opusFeatures.contains(.tools))
        #expect(opusFeatures.contains(.streaming))
        #expect(opusFeatures.contains(.reasoning))
        #expect(opusFeatures.contains(.adaptiveThinking))
        #expect(opusFeatures.contains(.promptCaching))
        #expect(opusFeatures.contains(.redactedThinking))

        let ollamaFeatures = WenshuModelCatalog.features(for: "llama3-local")
        #expect(ollamaFeatures.contains(.tools))
        #expect(ollamaFeatures.contains(.streaming))
        #expect(!ollamaFeatures.contains(.vision))

        // Helper boolean accessors.
        #expect(WenshuModelCatalog.supportsVision("claude-opus-4-20250514") == true)
        #expect(WenshuModelCatalog.supportsTools("claude-opus-4-20250514") == true)
        #expect(WenshuModelCatalog.supportsStreaming("llama3-local") == true)
        #expect(WenshuModelCatalog.supportsReasoning("claude-opus-4-20250514") == true)
        #expect(WenshuModelCatalog.supportsAdaptiveThinking("claude-opus-4-20250514") == true)
        #expect(WenshuModelCatalog.supportsPromptCaching("claude-opus-4-20250514") == true)
    }

    // MARK: - Test 4: Rough token estimator

    @Test("estimateTokensRough + estimateMessagesTokensRough are reasonable")
    func testEstimateTokens() {
        #expect(WenshuModelCatalog.estimateTokensRough("hello world") >= 2)
        #expect(WenshuModelCatalog.estimateTokensRough("") == 0)
        let msgs = [
            LLMMessage(role: .user, blocks: [.text("hello")]),
            LLMMessage(role: .assistant, blocks: [.text("hi")])
        ]
        #expect(WenshuModelCatalog.estimateMessagesTokensRough(msgs) > 0)
    }

    // MARK: - Test 5: Pricing.cost math

    @Test("Pricing.cost computes input + cached + output correctly")
    func testCostComputation() {
        let pricing = WenshuModelCatalog.Pricing(
            inputPerMTok: 3.0,
            cachedInputPerMTok: 0.30,
            outputPerMTok: 15.0
        )
        // 1M uncached input + 0 cached + 1M output:
        //   inputCost = 1 * 3 = 3
        //   outputCost = 1 * 15 = 15
        //   total = 18
        let cost1 = pricing.cost(inputTokens: 1_000_000, outputTokens: 1_000_000)
        #expect(abs(cost1 - 18.0) < 0.0001)

        // 1M total input with 500k cached:
        //   uncached = 500k, inputCost = 0.5 * 3 = 1.5
        //   cachedCost = 0.5 * 0.30 = 0.15
        //   total = 1.65
        let cost2 = pricing.cost(inputTokens: 1_000_000, outputTokens: 0, cachedTokens: 500_000)
        #expect(abs(cost2 - 1.65) < 0.0001)

        // 0 input + 0 output → 0 cost
        let cost3 = pricing.cost(inputTokens: 0, outputTokens: 0)
        #expect(cost3 == 0)
    }
}