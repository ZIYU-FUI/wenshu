//
//  SystemPromptAndSanitizationTests.swift · Wenshu · v0.38 Batch 3 sub-step 4
//
//  Tests for SystemPrompt + MessageSanitization (= v0.35 ticket 002/001).
//
// Per cadence 2026-09-03 'resume' (= auto-pilot mode
// per 'ok' + ') + 'PO execute,
// don't' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = SystemPrompt + MessageSanitization
//  are v0.35 ticket 002/001 (= my work).
//
//  The system prompt half drives the live builders: the tier builder
//  for the stable tier, PromptBuilder for the dynamic tier.
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("SystemPrompt deep (= v0.35 ticket 002)")
struct SystemPromptDeepTests {

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

    @Test("the joined system prompt produces non-empty output")
    func buildProducesOutput() {
        #expect(!joinedPrompt(ephemeralHint: "today is sunny").isEmpty)
    }

    @Test("the stable tier is byte-stable across calls (= cache hit invariant)")
    func buildByteStable() {
        let p1 = stableTier()
        let p2 = stableTier()
        #expect(p1 == p2)
    }

    @Test("an empty ephemeral hint still yields a usable prompt")
    func buildEmptyHint() {
        let p1 = joinedPrompt(ephemeralHint: "")
        let p2 = joinedPrompt(ephemeralHint: "x")
        // Different ephemeralHint produces different output
        #expect(p1 != p2)
        #expect(!p1.isEmpty)
    }

    @Test("the caller message reaches the dynamic tier")
    func buildCallerMessage() {
        let p1 = dynamicTier(ephemeralHint: "h")
        let p2 = dynamicTier(
            callerExtras: ["caller_message": "extra"],
            ephemeralHint: "h"
        )
        #expect(p1 != p2)
        #expect(p2.contains("extra"))
    }

    @Test("the stable tier and the dynamic tier are both present")
    func bothTiersPresent() {
        let stable = stableTier()
        let dynamic = dynamicTier(ephemeralHint: "today is sunny")
        #expect(!stable.isEmpty)
        #expect(!dynamic.isEmpty)
        // dynamic contains the ephemeralHint
        #expect(dynamic.contains("today is sunny"))
    }

    @Test("no dynamic tier when there is no hint and no caller extras")
    func noDynamicWhenEmpty() {
        let stable = stableTier()
        let dynamic = dynamicTier()
        #expect(!stable.isEmpty)
        #expect(dynamic.isEmpty)
    }
}

@Suite("MessageSanitization (= v0.35 ticket 001)")
struct MessageSanitizationTests {

    @Test("sanitizeText: preserves newline + carriage return")
    func sanitizePreservesNewlines() {
        let text = "Line 1\nLine 2\r\nLine 3"
        let clean = MessageSanitization.sanitizeText(text)
        #expect(clean == "Line 1\nLine 2\r\nLine 3")
    }

    @Test("sanitizeText: preserves Unicode + emoji + CJK")
    func sanitizePreservesUnicode() {
        let text = "你好🌏αβγ"
        let clean = MessageSanitization.sanitizeText(text)
        #expect(clean == "你好🌏αβγ")
    }

    @Test("sanitizeText: removes DEL (U+007F)")
    func sanitizeRemovesDEL() {
        let text = "Hello\u{007F}World"
        let clean = MessageSanitization.sanitizeText(text)
        #expect(clean == "HelloWorld")
    }

    @Test("sanitizeText: empty input returns empty")
    func sanitizeEmpty() {
        #expect(MessageSanitization.sanitizeText("") == "")
    }

    @Test("sanitize: cleans all text blocks in messages")
    func sanitizeMessages() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [
                .text("Hello\u{0001}"),
                .text("World\u{0007}!")
            ])
        ]
        let clean = MessageSanitization.sanitize(messages)
        #expect(clean.count == 1)
        if case .text(let s) = clean[0].blocks[0] {
            #expect(s == "Hello")
        } else {
            Issue.record("expected text block")
        }
    }

    @Test("sanitize: preserves tool_use + tool_result structure")
    func sanitizePreservesToolBlocks() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .assistant, blocks: [
                .toolUse(id: "t1", name: "ReadFile", input: "{}"),
                .toolResult(toolUseID: "t1", output: "content\u{0001}"),
                .thinking(text: "thinking\u{0007}", signature: "sig")
            ])
        ]
        let clean = MessageSanitization.sanitize(messages)
        #expect(clean[0].blocks.count == 3)
        // toolUse is preserved
        if case .toolUse(let id, let name, _) = clean[0].blocks[0] {
            #expect(id == "t1")
            #expect(name == "ReadFile")
        } else {
            Issue.record("expected toolUse block")
        }
        // toolResult has sanitized output
        if case .toolResult(let toolUseID, let output) = clean[0].blocks[1] {
            #expect(toolUseID == "t1")
            #expect(output == "content")  // control char stripped
        } else {
            Issue.record("expected toolResult block")
        }
        // thinking has sanitized text
        if case .thinking(let text, let sig) = clean[0].blocks[2] {
            #expect(text == "thinking")  // control char stripped
            #expect(sig == "sig")
        } else {
            Issue.record("expected thinking block")
        }
    }

    @Test("sanitize: empty text block becomes empty after sanitize")
    func sanitizeEmptyText() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("")])
        ]
        let clean = MessageSanitization.sanitize(messages)
        // empty text stays empty
        if case .text(let s) = clean[0].blocks[0] {
            #expect(s == "")
        } else {
            Issue.record("expected text block")
        }
    }
}
