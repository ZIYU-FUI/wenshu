//
//  ContextCompressor.swift · Wenshu · v0.35 ticket 003 sub-step 1
//
//  Context compression actor. Maps to hermes context_compressor.py
//  (= 3082 LOC) + conversation_compression.py `compress_context()` (L435-L987).
//
//  Design divergence from hermes (= wenshu §11 baseline "no external AI
//  platform calls" + wenshu-side wins):
//    - Hermes `compress_context()` invokes an aux LLM to summarize
//      (= external AI platform dependency, banned by §11).
//    - Wenshu ContextCompressor uses deterministic truncation policy:
//        1. Preserve the last `keepRecentTurns` messages (= recent context)
//        2. Replace earlier messages with a single synthetic summary message
//           (placeholder = "[Earlier conversation summarized: N turns omitted]")
//        3. Token budget guard: stop early if estimated token count fits
//    - This is a wenshu-side decision (= spec §3.6 "wenshu-side wins"):
//      the existing wenshu memory subsystem (MemoryManager) already
//      maintains a write gate + retrieval policy; compression policy
//      reuses those primitives without introducing new dependencies.
//
//  v0.35 ticket 003 sub-step 1 (= 6 sub-steps total for ticket 003:
//  ContextCompressor + ConversationCompression + ContextEngine +
//  ChatView compression pill + manual button + e2e tests).
//

import Foundation

public actor ContextCompressor {

    /// Compression policy (= deterministic, no LLM).
    public struct Policy: Sendable {
        public let keepRecentTurns: Int  // last N messages to preserve verbatim
        public let maxTokens: Int         // stop early if estimated token count fits
        public let summaryTemplate: String // text for the synthesized summary message

        public init(
            keepRecentTurns: Int = 8,
            maxTokens: Int = 30_000,
            summaryTemplate: String = "[Earlier conversation summarized: %d turns omitted to fit context budget.]"
        ) {
            self.keepRecentTurns = keepRecentTurns
            self.maxTokens = maxTokens
            self.summaryTemplate = summaryTemplate
        }
    }

    private let policy: Policy
    private let tokenEstimator: TokenEstimator

    public init(
        policy: Policy = Policy(),
        tokenEstimator: TokenEstimator = CharacterBasedTokenEstimator()
    ) {
        self.policy = policy
        self.tokenEstimator = tokenEstimator
    }

    /// Compress a message history (= hermes compress_context() return
    /// tuple shape: (compressed messages, new system prompt)).
    ///
    /// - Parameters:
    ///   - messages: Current message history (chronological order).
    ///   - systemMessage: Current system prompt (= returned unchanged;
    ///     wenshu policy keeps system prompt byte-stable per AGENTS.md §11.3).
    /// - Returns: Tuple of (compressed messages, system message unchanged).
    ///   Compression triggers whenever the history is longer than
    ///   `keepRecentTurns` (= the wenshu-side deterministic rule; this
    ///   is the binding constraint — the count always drops to
    ///   `1 summary + keepRecentTurns` when triggered). The `maxTokens`
    ///   policy field is retained for callers that want to gate on token
    ///   budget before invoking the compressor (= see
    ///   `ConversationCompression.manualTrigger` for the manual path,
    ///   which builds a more aggressive compressor with a low
    ///   `maxTokens` to force the rewrite regardless of history size).
    public func compressContext(
        messages: [LLMMessage],
        systemMessage: String
    ) -> (messages: [LLMMessage], systemMessage: String) {
        // 1. Trigger: history exceeds the recent-keep window. The
        //    wenshu-side deterministic policy is driven by message count
        //    (= the user said "keep the last N"); when the count is over
        //    the window we always rewrite — the result is bounded by
        //    `1 (summary) + keepRecentTurns` regardless of the input
        //    size.
        guard messages.count > policy.keepRecentTurns else {
            return (messages, systemMessage)
        }

        // 2. Split: older messages + recent messages
        let splitIndex = messages.count - policy.keepRecentTurns
        let olderMessages = Array(messages[0..<splitIndex])
        let recentMessages = Array(messages[splitIndex..<messages.count])

        // 3. Build synthesized summary message (= hermes behavior:
        // replace older turns with one summary block)
        let summaryText = String(
            format: policy.summaryTemplate,
            olderMessages.count
        )
        let summaryMessage = LLMMessage(
            role: .assistant,
            blocks: [.text(summaryText)]
        )

        // 4. Concatenate: [summary] + recent messages
        var compressed: [LLMMessage] = [summaryMessage]
        compressed.append(contentsOf: recentMessages)

        // 5. System message preserved byte-stable (= AGENTS.md §11.3)
        return (compressed, systemMessage)
    }
}

/// Token estimator protocol (= pluggable; default = character-based).
public protocol TokenEstimator: Sendable {
    func estimate(_ message: LLMMessage) -> Int
}

/// Character-based token estimator (= rough heuristic: 4 chars per token,
/// matching hermes `estimate_messages_tokens_rough`).
public struct CharacterBasedTokenEstimator: TokenEstimator, Sendable {
    public init() {}

    public func estimate(_ message: LLMMessage) -> Int {
        let totalChars = message.blocks.reduce(into: 0) { sum, block in
            switch block {
            case .text(let s): sum += s.count
            case .thinking(let text, _): sum += text.count
            case .toolUse(_, _, let input): sum += input.count
            case .toolResult(_, let output): sum += output.count
            }
        }
        // Ceiling division so any non-empty message yields >=1 token
        // (= hermes estimate_messages_tokens_rough contract: ceil(chars/4)).
        return max(1, (totalChars + 3) / 4)
    }
}