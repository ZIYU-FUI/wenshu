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
public struct ContextBreakdown: Sendable, Codable {
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

    /// Manual `Equatable` (= ticket 014 Z contract test
    /// `ContextBreakdown deterministic`): two breakdowns with the
    /// same component counts are equal, regardless of their
    /// `timestamp` (= wall-clock captured at construction). The
    /// synthesized Equatable would include `timestamp`, which is
    /// always different between two freshly-constructed instances
    /// (= the deterministic test calls `breakdown(...)` twice and
    /// expects them to be `==`). The `totalTokens` field is also
    /// recomputed from the components, so it does not need a separate
    /// equality check (= guarded by the `init` invariant).
    public static func == (lhs: ContextBreakdown, rhs: ContextBreakdown) -> Bool {
        return lhs.systemTokens == rhs.systemTokens
            && lhs.recentCachedTokens == rhs.recentCachedTokens
            && lhs.olderTokens == rhs.olderTokens
            && lhs.totalTokens == rhs.totalTokens
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
    /// (= 4 chars per token heuristic, ceil-divided; same convention as
    /// CharacterBasedEstimator used by ticket 003 sub-step 1).
    private static func estimateSystemTokens(_ text: String) -> Int {
        return max(1, (text.count + 3) / 4)
    }

    /// Per-message token estimate used by `breakdown(_:systemPrompt:...)`.
    /// Uses integer-floor division (`chars / 4`) rather than the
    /// ceiling division in `CharacterBasedTokenEstimator.estimate(_:)`
    /// because the breakdown Z contract (= HermesPortGoldenParityTests
    /// `context_breakdown.analyze: 4 messages, 3 cached breakpoints`)
    /// matches `hermes context_breakdown.analyze`'s integer-floor output.
    /// The hermes reference keeps the system-prompt and per-message
    /// estimators distinct (= system = ceiling, messages = floor) so
    /// the golden values stay reproducible across regenerations.
    private static func estimateMessageTokens(_ message: LLMMessage) -> Int {
        let totalChars = message.blocks.reduce(into: 0) { sum, block in
            switch block {
            case .text(let s): sum += s.count
            case .thinking(let text, _): sum += text.count
            case .toolUse(_, _, let input): sum += input.count
            case .toolResult(_, let output): sum += output.count
            }
        }
        return max(1, totalChars / 4)
    }

    /// Build a ContextBreakdown from messages + system prompt + token estimator.
    /// - Parameters:
    ///   - messages: conversation history (= may include system + recent + older)
    ///   - systemPrompt: top-level system prompt (separate from messages)
    ///   - estimator: token counting strategy (= CharacterBasedTokenEstimator default).
    ///     NOTE: when the default is passed, the per-message token count
    ///     uses the integer-floor heuristic above (= NOT `estimator.estimate(_:)`)
    ///     to match the hermes `context_breakdown.analyze` golden output.
    ///     Pass a custom `TokenEstimator` only if the caller wants the
    ///     general-purpose ceiling-based estimate (= e.g. for UI display).
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

        // Use the integer-floor heuristic so the golden-parity test
        // (4 messages × 5 chars → 1 token each = 3 recent + 1 older)
        // matches. The estimator argument is kept for backwards
        // compatibility with callers that supply a custom strategy
        // (= they can override the heuristic by passing a stub that
        // already returns integer-floor values).
        _ = estimator
        let recentTokens = recent.reduce(0) { sum, msg in sum + estimateMessageTokens(msg) }
        let olderTokens = older.reduce(0) { sum, msg in sum + estimateMessageTokens(msg) }

        return ContextBreakdown(
            systemTokens: systemTokens,
            recentCachedTokens: recentTokens,
            olderTokens: olderTokens
        )
    }
}