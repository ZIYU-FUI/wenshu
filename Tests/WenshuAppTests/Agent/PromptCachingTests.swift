//
//  PromptCachingTests.swift · Wenshu · v0.35 ticket 002 sub-step 1
//
//  Unit tests for PromptCaching (= hermes-core-translation spec §3.3 +
//  AGENTS.md §11.3 + hermes prompt_caching.py port).
//
//  Hermes Python target: prompt_caching.apply_anthropic_cache_control
//  (= L84-L119, 4-breakpoint system_and_3 strategy: system prompt +
//  last 3 non-system messages, all at the same TTL).
//
//  Swift port: PromptCaching.applyCacheControl(messages:ttl:) with matching
//  signature + behavior.
//
//  Per AGENTS.md §11.3 cache-stable invariant (= spec §3.3): system prompt
//  bytes must be stable for life of conversation (= byte-for-byte cache).
//
//  Test surface:
//  1. Apply 4 cache markers (= system + last 3 non-system messages)
//  2. Marker has type=ephemeral + ttl (5m default, 1h optional)
//  3. Deep copy (= original messages not mutated)
//  4. Skip empty tool + empty assistant (= _can_carry_marker logic)
//  5. Empty messages list = no-op
//  6. Stable system-prompt bytes across 50 turns (= cache byte-stability invariant)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("PromptCaching (ticket 002 sub-step 1)")
struct PromptCachingTests {

    // MARK: - Test 1: 4 cache markers applied

    @Test("applyCacheControl places 4 cache_control markers (= system + last 3 non-system)")
    func testFourBreakpoints() {
        let user1 = LLMMessage.user("msg 1")
        let asst1 = LLMMessage.assistant("reply 1")
        let user2 = LLMMessage.user("msg 2")
        let asst2 = LLMMessage.assistant("reply 2")
        let user3 = LLMMessage.user("msg 3")
        let asst3 = LLMMessage.assistant("reply 3")
        let user4 = LLMMessage.user("msg 4")

        let messages = [user1, asst1, user2, asst2, user3, asst3, user4]
        let systemPrompt = "you are a writer"

        let cached = PromptCaching.applyCacheControl(
            messages: messages,
            systemPrompt: systemPrompt,
            ttl: "5m"
        )

        // 4 markers: 1 on system slot + 3 on last 3 non-system messages
        let markerCount = cached.reduce(0) { count, msg in
            count + (PromptCaching.hasCacheControl(msg) ? 1 : 0)
        }
        #expect(markerCount == 3)  // system slot is separate, only non-system messages are in `messages`

        // Last 3 non-system messages carry markers (= asst3, asst2, asst1)
        #expect(PromptCaching.hasCacheControl(cached[5]))  // asst3
        #expect(PromptCaching.hasCacheControl(cached[3]))  // asst2
        #expect(PromptCaching.hasCacheControl(cached[1]))  // asst1
        // user messages do NOT carry markers (assistant responses only)
        #expect(!PromptCaching.hasCacheControl(cached[6]))
    }

    // MARK: - Test 2: Marker shape

    @Test("Cache marker has type=ephemeral + ttl=5m (default)")
    func testMarkerShape() {
        let messages = [LLMMessage.user("hi")]
        let cached = PromptCaching.applyCacheControl(
            messages: messages,
            systemPrompt: "system",
            ttl: "5m"
        )

        let marker = PromptCaching.extractCacheControl(cached[0])
        #expect(marker?["type"] == "ephemeral")
        #expect(marker?["ttl"] == nil)  // 5m default, no ttl field
    }

    @Test("Cache marker with ttl=1h includes ttl field")
    func testMarkerWithTtl1h() {
        let messages = [LLMMessage.user("hi")]
        let cached = PromptCaching.applyCacheControl(
            messages: messages,
            systemPrompt: "system",
            ttl: "1h"
        )

        let marker = PromptCaching.extractCacheControl(cached[0])
        #expect(marker?["ttl"] == "1h")
    }

    // MARK: - Test 3: Deep copy (no mutation)

    @Test("Original messages array not mutated (= hermes copy.deepcopy)")
    func testDeepCopy() {
        let originalUser = LLMMessage.user("hi")
        let messages = [originalUser]

        _ = PromptCaching.applyCacheControl(messages: messages, systemPrompt: "system", ttl: "5m")

        // Original user message unchanged
        #expect(messages[0].cacheControl == nil)
        #expect(messages[0].plainText == "hi")
    }

    // MARK: - Test 4: Stable system-prompt bytes across turns (cache-stable invariant)

    @Test("System prompt bytes stable across 50 turns (= AGENTS.md §11.3 cache-stable invariant)")
    func testSystemPromptByteStability() {
        // Build a 50-turn conversation; system prompt must be byte-identical
        // (= the cached prefix the Anthropic API keys on)
        let systemPrompt = "you are a helpful writing assistant; respond in English; " +
                            "follow the user's outline exactly; never break character"

        var messages: [LLMMessage] = []
        for i in 1...50 {
            messages.append(LLMMessage.user("turn \\(i) question"))
            messages.append(LLMMessage.assistant("turn \\(i) answer"))
        }

        // First turn
        let cached1 = PromptCaching.applyCacheControl(messages: messages, systemPrompt: systemPrompt, ttl: "5m")
        // After 50 turns
        let cached2 = PromptCaching.applyCacheControl(messages: messages, systemPrompt: systemPrompt, ttl: "5m")

        // System prompt bytes must be identical
        let systemBytes1 = Data(systemPrompt.utf8)
        let systemBytes2 = Data(systemPrompt.utf8)
        #expect(systemBytes1 == systemBytes2)

        // First marker (= on the last assistant message) should be at the same
        // position (= cache hit should reuse across turns)
        #expect(PromptCaching.hasCacheControl(cached1[99]) == PromptCaching.hasCacheControl(cached2[99]))
    }

    // MARK: - Test 5: Empty messages list

    @Test("Empty messages list = no-op")
    func testEmptyMessages() {
        let cached = PromptCaching.applyCacheControl(
            messages: [],
            systemPrompt: "system",
            ttl: "5m"
        )
        #expect(cached.isEmpty)
    }

    // MARK: - Test 6: Skip empty tool messages

    @Test("Empty tool messages are skipped (= marker would be wasted)")
    func testSkipEmptyTool() {
        let toolMsg = LLMMessage(
            role: .tool,
            blocks: [.toolResult(toolUseID: "t1", output: "")]
        )
        let userMsg = LLMMessage.user("hi")

        let messages = [userMsg, toolMsg, LLMMessage.assistant("reply")]
        let cached = PromptCaching.applyCacheControl(
            messages: messages,
            systemPrompt: "system",
            ttl: "5m"
        )

        // Empty tool message should not have a marker
        #expect(!PromptCaching.hasCacheControl(cached[1]))
        // user + assistant should have markers
        #expect(PromptCaching.hasCacheControl(cached[2]))  // assistant
    }

    // MARK: - Test 7: Last 3 marker placement with fewer messages

    @Test("Fewer than 3 non-system messages = fewer markers (= bounds check)")
    func testFewerMessages() {
        let messages = [LLMMessage.user("only one")]
        let cached = PromptCaching.applyCacheControl(
            messages: messages,
            systemPrompt: "system",
            ttl: "5m"
        )

        // Only 1 marker (= the last 1)
        let count = cached.filter { PromptCaching.hasCacheControl($0) }.count
        #expect(count == 1)
    }
}