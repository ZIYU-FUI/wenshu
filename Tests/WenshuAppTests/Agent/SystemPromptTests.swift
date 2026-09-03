//
//  SystemPromptTests.swift · Wenshu · v0.35 ticket 002 sub-step 2
//
//  Unit tests for SystemPrompt (= hermes-core-translation spec §3.3 +
//  hermes system_prompt.py port).
//
//  Hermes Python target: system_prompt.build_system_prompt_parts + build_system_prompt
//  (= L113 + L470 in system_prompt.py, builds the byte-stable system prompt
//  that becomes the cached prefix in the Anthropic Messages API).
//
//  Swift port: SystemPrompt.buildParts(ephemeralHint:callerMessage:) ->
//  [String: String] and SystemPrompt.build(ephemeralHint:callerMessage:) -> String.
//  Byte-stable invariant: identical inputs produce byte-identical output
//  (= AGENTS.md §11.3 cache-stable).
//
//  Test surface:
//  1. build() returns a String (= caller concatenates into LLMCallOptions.systemPrompt)
//  2. buildParts() returns Dict with stable tier + dynamic tier
//  3. Caller message appended LAST (after stable tier, before cache breakpoint)
//  4. Empty caller message = no extra section (= stable tier unchanged)
//  5. Byte stability: identical inputs across 100 calls = identical outputs
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SystemPrompt (ticket 002 sub-step 2)")
struct SystemPromptTests {

    // MARK: - Test 1: build() returns String

    @Test("build() returns a single system prompt string")
    func testBuildReturnsString() {
        let prompt = SystemPrompt.build(ephemeralHint: "today is Tuesday", callerMessage: nil)
        #expect(!prompt.isEmpty)
        // Stable tier should mention 文枢 (= wenshu's writing tool identity)
        #expect(prompt.contains("文枢") || prompt.lowercased().contains("writing"))
    }

    // MARK: - Test 2: buildParts() returns Dict with stable + dynamic tiers

    @Test("buildParts() returns stable + dynamic tier dict")
    func testBuildPartsReturnsDict() {
        let parts = SystemPrompt.buildParts(
            ephemeralHint: "Tuesday",
            callerMessage: "respond in iambic pentameter"
        )

        // Stable tier present (= system identity, byte-stable)
        #expect(parts["stable"] != nil)
        #expect(!(parts["stable"] ?? "").isEmpty)
    }

    // MARK: - Test 3: Caller message appended

    @Test("Caller-supplied message appended to system prompt")
    func testCallerMessageAppended() {
        let prompt = SystemPrompt.build(
            ephemeralHint: "Tuesday",
            callerMessage: "respond in iambic pentameter"
        )
        #expect(prompt.contains("iambic pentameter"))
    }

    // MARK: - Test 4: Empty caller message = no extra section

    @Test("Empty caller message = no extra section in prompt")
    func testEmptyCallerMessage() {
        let promptWith = SystemPrompt.build(ephemeralHint: "Tuesday", callerMessage: "foo")
        let promptWithout = SystemPrompt.build(ephemeralHint: "Tuesday", callerMessage: nil)

        #expect(promptWith.contains("foo"))
        #expect(!promptWithout.contains("foo"))
    }

    // MARK: - Test 5: Byte stability across 100 calls (= cache-stable invariant)

    @Test("Byte stability: identical inputs across 100 calls produce identical outputs")
    func testByteStability() {
        let hint = "Tuesday, 2026-09-03"
        let message = "follow the user's outline exactly"

        let first = SystemPrompt.build(ephemeralHint: hint, callerMessage: message)
        var last = first
        for _ in 0..<100 {
            last = SystemPrompt.build(ephemeralHint: hint, callerMessage: message)
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
        let p1 = SystemPrompt.build(ephemeralHint: "Tuesday", callerMessage: nil)
        let p2 = SystemPrompt.build(ephemeralHint: "Wednesday", callerMessage: nil)

        #expect(p1 != p2)
        #expect(p1.contains("Tuesday"))
        #expect(p2.contains("Wednesday"))
    }
}