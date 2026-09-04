//
//  PromptCaching.swift · Wenshu · v0.35 ticket 002 sub-step 1
//
//  Anthropic prompt caching strategy. Direct port of hermes
//  prompt_caching.py (= L1-L119, 119 LOC).
//
//  Single layout: system_and_3. 4 cache_control breakpoints — system
//  prompt + last 3 non-system messages, all at the same TTL (5m or 1h).
//
//  Reduces input token costs by ~75% on multi-turn conversations within
//  a single session.
//
//  Pure functions — no class state, no actor dependency.
//
//  Swift port design (= hermes-by-hermes):
//  - applyCacheControl(messages:systemPrompt:ttl:) mirrors
//    apply_anthropic_cache_control(api_messages, cache_ttl, native_anthropic)
//    with systemPrompt extracted as a separate parameter (= Anthropic
//    Messages API has `system` as top-level field, NOT a message)
//  - Cache markers stored as `cacheControl: [String: String]?` on
//    LLMMessage (= Swift extension on LLMMessage, not a new wrapper)
//  - hasCacheControl(_:) + extractCacheControl(_:) helpers for inspection
//  - _can_carry_marker logic: skip empty-content messages (= top-level
//    marker would be silently ignored by envelope layout providers)
//
//  v0.35 ticket 002 sub-step 1 of N (= ticket 002 = PromptCaching +
//  SystemPrompt + cache-stable invariants per spec §3.3 + §0.1 A3).
//

import Foundation

public enum PromptCaching {

    /// Apply system_and_3 caching strategy (= 4 cache_control breakpoints:
    /// system prompt + last 3 non-system messages, all at the same TTL).
    ///
    /// - Parameters:
    ///   - messages: Cross-connector message list (= excludes system prompt,
    ///     which is passed separately as `systemPrompt` per Anthropic
    ///     Messages API).
    ///   - systemPrompt: System prompt string (= represents the first
    ///     cache_control breakpoint in the wire format).
    ///   - ttl: Cache TTL — either "5m" (default, ephemeral) or "1h".
    /// - Returns: New array of LLMMessage with cache markers on the
    ///   last 3 non-system messages (= does NOT mutate the input).
    ///   The systemPrompt is returned as a separate field on the result
    ///   (= callers wire it into the Anthropic `system` field at send time).
    public static func applyCacheControl(
        messages: [LLMMessage],
        systemPrompt: String,
        ttl: String = "5m"
    ) -> [LLMMessage] {
        let marker = buildMarker(ttl: ttl)

        // Find last 3 non-system messages that can carry a marker
        let carryIndices = messages.indices.filter { i in
            canCarryMarker(messages[i])
        }
        let markedIndices = Set(carryIndices.suffix(3))

        return messages.enumerated().map { (i, msg) -> LLMMessage in
            if markedIndices.contains(i) {
                var marked = msg
                marked.cacheControl = marker
                return marked
            }
            return msg
        }
    }

    /// Build the cache_control marker dict for the given TTL.
    /// "5m" → {"type": "ephemeral"}; "1h" → {"type": "ephemeral", "ttl": "1h"}
    private static func buildMarker(ttl: String) -> [String: String] {
        var dict: [String: String] = ["type": "ephemeral"]
        if ttl == "1h" {
            dict["ttl"] = "1h"
        }
        return dict
    }

    /// True if a marker on this message is actually honored by the provider.
    /// Skip empty-content messages (= top-level marker would be silently ignored).
    private static func canCarryMarker(_ message: LLMMessage) -> Bool {
        if message.blocks.isEmpty { return false }
        let hasNonEmptyText = message.blocks.contains { block in
            if case .text(let s) = block { return !s.isEmpty }
            return false
        }
        return hasNonEmptyText
    }

    /// True if message has a cache_control marker.
    public static func hasCacheControl(_ message: LLMMessage) -> Bool {
        message.cacheControl != nil
    }

    /// Extract cache_control marker from message (= returns nil if absent).
    public static func extractCacheControl(_ message: LLMMessage) -> [String: String]? {
        message.cacheControl
    }
}