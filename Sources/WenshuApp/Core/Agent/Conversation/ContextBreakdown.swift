//
//  ContextBreakdown.swift · Wenshu · v0.36 ticket 014 sub-step 1
//
//  Diagnostic breakdown of conversation context composition
//  (= ticket 003 L40 acceptance criterion from spec §3.1 L198-199).
//
//  Used by ContextEngine.swift (= ticket 003 sub-step 3) to report what
//  portion of the context budget each message block occupies. Enables
//  chat UI to display breakdown like:
//    "system: 1,200 tokens (4%)
//     recent 3 messages: 28,500 tokens (95%)
//     older compressed: 400 tokens (1%)"
//
//  Per ADR-0011 (deterministic compression policy) + ADR-0010 (cache-stable
//  invariant), breakdown respects cache markers (= system + last 3
//  non-system messages are flagged as cacheable).
//
//  Per ADR-0009 (wenshu-side wins), uses existing TokenEstimator protocol
//  (= ticket 003 sub-step 1) — no duplicate estimator.
//
//  v0.36 sub-step 1 of 2 for ticket 014.
//

import Foundation

/// Per-component token accounting for a conversation context.
/// Reported by ContextEngine.breakdown() (= thin facade over Core/Memory/*).
public struct ContextBreakdown: Sendable, Equatable, Codable {
    public let systemTokens: Int
    public let recentCachedTokens: Int     // last 3 non-system (= cacheable)
    public let olderTokens: Int            // everything else
    public let totalTokens: Int
    public let timestamp: Date

    public init(
        systemTokens: Int,
        recentCachedTokens: Int,
        olderTokens: Int,
        timestamp: Date = Date()
    ) {
        self.systemTokens = systemTokens
        self.recentCachedTokens = recentCachedTokens
        self.olderTokens = olderTokens
        self.totalTokens = systemTokens + recentCachedTokens + olderTokens
        self.timestamp = timestamp
    }

    /// Fraction of total tokens occupied by system message (= 0.0 to 1.0).
    public var systemFraction: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(systemTokens) / Double(totalTokens)
    }

    /// Fraction occupied by recent 3 (= cacheable per ADR-0010).
    public var recentCachedFraction: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(recentCachedTokens) / Double(totalTokens)
    }

    /// Fraction occupied by older compressed messages.
    public var olderFraction: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(olderTokens) / Double(totalTokens)
    }

    /// Human-readable summary (= for chat UI display).
    public var summary: String {
        return String(
            format: "system: %d tokens (%.0f%%)\nrecent 3 cached: %d tokens (%.0f%%)\nolder: %d tokens (%.0f%%)",
            systemTokens, systemFraction * 100,
            recentCachedTokens, recentCachedFraction * 100,
            olderTokens, olderFraction * 100
        )
    }
}

/// Pure function (= deterministic) that partitions [LLMMessage] into the
/// three ContextBreakdown components. Respects PromptCaching 4-breakpoint
/// invariant (= system message + last 3 non-system = cacheable).
public enum ContextBreakdownAnalyzer {

    /// Rough character-count estimate for the system prompt.
    /// (= 4 chars per token heuristic; same convention as
    /// CharacterBasedTokenEstimator in ContextCompressor.swift).
    private static func estimateSystemTokens(_ text: String) -> Int {
        return max(1, text.count / 4)
    }

    /// Build a ContextBreakdown from messages + system prompt + token estimator.
    /// - Parameters:
    ///   - messages: conversation history (= may include system + recent + older)
    ///   - systemPrompt: top-level system prompt (separate from messages)
    ///   - estimator: token counting strategy (= CharacterBasedTokenEstimator default)
    ///   - cachedBreakpointsCount: how many trailing non-system messages are
    ///     cacheable (= 3 per ADR-0010 PromptCaching invariant)
    public static func breakdown(
        messages: [LLMMessage],
        systemPrompt: String,
        estimator: TokenEstimator = CharacterBasedTokenEstimator(),
        cachedBreakpointsCount: Int = 3
    ) -> ContextBreakdown {
        let systemTokens = estimateSystemTokens(systemPrompt)

        // Per ChatMessageBridge (= ticket 003 sub-step 5 followup):
        // System prompt travels as top-level parameter, NOT as in-band
        // message. So ALL messages are non-system (= user / assistant /
        // tool). Partition into recent (= cacheable) + older based on
        // PromptCaching 4-breakpoint invariant (= last 3 non-system).
        let recent = Array(messages.suffix(cachedBreakpointsCount))
        let older = Array(messages.dropLast(cachedBreakpointsCount))

        let recentTokens = recent.reduce(0) { sum, msg in sum + estimator.estimate(msg) }
        let olderTokens = older.reduce(0) { sum, msg in sum + estimator.estimate(msg) }

        return ContextBreakdown(
            systemTokens: systemTokens,
            recentCachedTokens: recentTokens,
            olderTokens: olderTokens
        )
    }
}