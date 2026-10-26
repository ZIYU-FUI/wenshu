//
//  SystemPromptTests.swift · Wenshu
//
//  The system prompt the app sends, built the way the app builds it.
//
//  Two builders own the two halves. The tier builder owns the stable
//  tier (= the byte-stable cache prefix); PromptBuilder owns the
//  dynamic tier (= the volatile part). The joined prompt is what the
//  caller sends.
//
//  Byte-stable invariant: identical inputs produce byte-identical output
//  (= the cache-prefix invariant the stable tier exists for).
//
//  Test surface:
//  1. the joined prompt is a single non-empty string
//  2. the stable tier and the dynamic tier are both present
//  3. the caller message reaches the dynamic tier
//  4. no caller message = no caller section
//  5. Byte stability: identical inputs across 100 calls = identical outputs
//  6. Different ephemeral hint produces different output (= dynamic tier)
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("SystemPrompt (ticket 002 sub-step 2)")
struct SystemPromptTests {

    // MARK: - The live builders

    /// The stable tier, as the turn loop builds it.
    private func stableTier(
        provider: SystemPrompt.ProviderGuidance = .unknown,
        locale: SystemPrompt.Locale = .english
    ) -> String {
        PromptTierBuilder.stableTier(
            settings: PromptSettings(),
            provider: provider,
            locale: locale
        )
    }

    /// The dynamic tier, as the turn loop builds it.
    private func dynamicTier(
        callerExtras: [String: String] = [:],
        ephemeralHint: String = ""
    ) -> String {
        PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            callerExtras: callerExtras,
            ephemeralHint: ephemeralHint
        )
    }

    /// The prompt the caller sends: the stable tier, then the dynamic tier.
    private func joinedPrompt(
        callerExtras: [String: String] = [:],
        ephemeralHint: String = ""
    ) -> String {
        PromptBuilder(
            stableTier: stableTier(),
            dynamicTier: dynamicTier(callerExtras: callerExtras, ephemeralHint: ephemeralHint)
        ).joinedPrompt
    }

    // MARK: - Test 1: the joined prompt

    @Test("the joined system prompt is a single non-empty string")
    func testJoinedPromptReturnsString() {
        let prompt = joinedPrompt(ephemeralHint: "today is Tuesday")
        #expect(!prompt.isEmpty)
        // The identity must survive into the prompt.
        #expect(prompt.contains("文枢") || prompt.lowercased().contains("writing"))
    }

    // MARK: - Test 2: both tiers are present

    @Test("the stable tier and the dynamic tier are both present")
    func testBothTiersPresent() {
        let stable = stableTier()
        let dynamic = dynamicTier(
            callerExtras: ["caller_message": "respond in iambic pentameter"],
            ephemeralHint: "Tuesday"
        )

        // Stable tier present (= system identity, byte-stable)
        #expect(!stable.isEmpty)
        // Dynamic tier present (= the volatile half)
        #expect(!dynamic.isEmpty)
    }

    // MARK: - Test 3: the caller message is carried

    @Test("Caller-supplied message reaches the dynamic tier")
    func testCallerMessageAppended() {
        let dynamic = dynamicTier(
            callerExtras: ["caller_message": "respond in iambic pentameter"],
            ephemeralHint: "Tuesday"
        )
        #expect(dynamic.contains("iambic pentameter"))
    }

    // MARK: - Test 4: no caller message = no caller section

    @Test("No caller message = no caller section in the dynamic tier")
    func testEmptyCallerMessage() {
        let withMessage = dynamicTier(
            callerExtras: ["caller_message": "foo"],
            ephemeralHint: "Tuesday"
        )
        let withoutMessage = dynamicTier(ephemeralHint: "Tuesday")

        #expect(withMessage.contains("foo"))
        #expect(!withoutMessage.contains("foo"))
    }

    // MARK: - Test 5: Byte stability across 100 calls (= cache-stable invariant)

    @Test("Byte stability: identical inputs across 100 calls produce identical outputs")
    func testByteStability() {
        let first = stableTier()
        var last = first
        for _ in 0..<100 {
            last = stableTier()
        }

        // Byte-identical (= cache hit on subsequent calls)
        #expect(first == last)
        let firstBytes = Data(first.utf8)
        let lastBytes = Data(last.utf8)
        #expect(firstBytes == lastBytes)
    }

    // MARK: - Test 6: Different ephemeral hint produces different output

    @Test("Different ephemeral hint produces different output (= dynamic tier)")
    func testDifferentEphemeralHint() {
        let p1 = dynamicTier(ephemeralHint: "Tuesday")
        let p2 = dynamicTier(ephemeralHint: "Wednesday")

        #expect(p1 != p2)
        #expect(p1.contains("Tuesday"))
        #expect(p2.contains("Wednesday"))
    }
}
