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
    ///   When compression is a no-op (e.g. message count <= keepRecentTurns),
    ///   returns the original messages and system message unchanged.
    public func compressContext(
        messages: [LLMMessage],
        systemMessage: String
    ) -> (messages: [LLMMessage], systemMessage: String) {
        // 1. Early exit if messages already fit budget
        let totalTokens = messages.reduce(0) { $0 + tokenEstimator.estimate($1) }
        if totalTokens <= policy.maxTokens {
            return (messages, systemMessage)
        }

        // 2. Early exit if message count <= keepRecentTurns
        if messages.count <= policy.keepRecentTurns {
            return (messages, systemMessage)
        }

        // 3. Split: older messages + recent messages
        let splitIndex = messages.count - policy.keepRecentTurns
        let olderMessages = Array(messages[0..<splitIndex])
        let recentMessages = Array(messages[splitIndex..<messages.count])

        // 4. Build synthesized summary message (= hermes behavior:
        // replace older turns with one summary block)
        let summaryText = String(
            format: policy.summaryTemplate,
            olderMessages.count
        )
        let summaryMessage = LLMMessage(
            role: .assistant,
            blocks: [.text(summaryText)]
        )

        // 5. Concatenate: [summary] + recent messages
        var compressed: [LLMMessage] = [summaryMessage]
        compressed.append(contentsOf: recentMessages)

        // 6. System message preserved byte-stable (= AGENTS.md §11.3)
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
        return max(1, totalChars / 4)
    }
}