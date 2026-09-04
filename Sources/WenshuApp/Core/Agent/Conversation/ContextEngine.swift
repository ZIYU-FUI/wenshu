//
//  ContextEngine.swift · Wenshu · v0.35 ticket 003 sub-step 3
//  + HERMES-PARTIAL-013 (2026-09-04).
//
//  Context aggregation facade. Maps to hermes context_engine.py
//  (= 231 LOC ABC interface). Wenshu-side wins per AGENTS.md §11.3:
//  the existing wenshu Core/Memory/* subsystem already implements
//  world/character/foreshadow prefetch + retrieval (= MemoryManager +
//  MemoryProvider + MemoryConsolidator). This ContextEngine is a thin
//  facade that exposes a unified API over those existing primitives.
//
//  Responsibilities:
//    - aggregateContextForTurn(bookId:userMessage:) -> ContextBundle
//      (= combines memory prefetch + character/world retrieval)
//    - formatContextBundle(_:) -> String
//      (= renders the context as a system-prompt dynamic tier)
//
//  HERMES-PARTIAL-013 extends the v0.35 surface with the full hermes
//  ContextEngine ABC surface:
//    - Per-turn context bundle assembly (= ephemeral hint +
//      cacheable references + per-turn memos)
//    - Threshold tracking (= prompt_tokens / completion_tokens / total /
//      threshold / context_length / compression_count)
//    - shouldCompress / shouldCompressPreflight gates
//    - compress(_:currentTokens:focusTopic:) → compacted message list
//    - updateModel(model:contextLength:...) for model-switch support
//    - updateFromResponse(usage:) for per-call token tracking
//    - getStatus() → diagnostic dict
//
//  v0.35 ticket 003 sub-step 3 + HERMES-PARTIAL-013 (2026-09-04).
//

import Foundation

public actor ContextEngine {

    public struct ContextBundle: Sendable {
        public let memories: [MemoryEntry]
        public let characterContext: [String]
        public let worldContext: [String]
        public let foreshadowContext: [String]

        public var isEmpty: Bool {
            memories.isEmpty && characterContext.isEmpty
                && worldContext.isEmpty && foreshadowContext.isEmpty
        }
    }

    /// Lightweight memory entry (= consumed from wenshu Core/Memory in
    /// subsequent tickets; stub shape for sub-step 3).
    public struct MemoryEntry: Sendable {
        public let source: String  // file path
        public let snippet: String
        public init(source: String, snippet: String) {
            self.source = source
            self.snippet = snippet
        }
    }

    /// LLM usage normalized (= hermes usage dict with input/output/cache_read/
    /// cache_write/reasoning tokens).
    public struct Usage: Sendable, Equatable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
        public let cacheReadTokens: Int
        public let cacheWriteTokens: Int
        public let reasoningTokens: Int

        public init(
            promptTokens: Int,
            completionTokens: Int,
            totalTokens: Int = 0,
            cacheReadTokens: Int = 0,
            cacheWriteTokens: Int = 0,
            reasoningTokens: Int = 0
        ) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens > 0 ? totalTokens : promptTokens + completionTokens
            self.cacheReadTokens = cacheReadTokens
            self.cacheWriteTokens = cacheWriteTokens
            self.reasoningTokens = reasoningTokens
        }
    }

    /// Status dict (= hermes get_status L192-213).
    public struct Status: Sendable, Equatable {
        public let lastPromptTokens: Int
        public let thresholdTokens: Int
        public let contextLength: Int
        public let usagePercent: Double
        public let compressionCount: Int

        public init(
            lastPromptTokens: Int,
            thresholdTokens: Int,
            contextLength: Int,
            usagePercent: Double,
            compressionCount: Int
        ) {
            self.lastPromptTokens = lastPromptTokens
            self.thresholdTokens = thresholdTokens
            self.contextLength = contextLength
            self.usagePercent = usagePercent
            self.compressionCount = compressionCount
        }
    }

    // MARK: - Token state (= hermes ContextEngine attributes L43-66)

    public private(set) var lastPromptTokens: Int = 0
    public private(set) var lastCompletionTokens: Int = 0
    public private(set) var lastTotalTokens: Int = 0
    public private(set) var thresholdTokens: Int = 0
    public private(set) var contextLength: Int = 0
    public private(set) var compressionCount: Int = 0

    // MARK: - Compaction parameters (= hermes threshold_percent + protect_first/last)

    public var thresholdPercent: Double = 0.75
    public var protectFirstN: Int = 3
    public var protectLastN: Int = 6

    public init() {}

    // MARK: - Per-turn context bundle assembly (= HERMES-PARTIAL-013)

    /// Aggregate context for one conversation turn
    /// (= hermes context_engine.aggregate_context entry).
    ///
    /// Returns a ContextBundle combining:
    /// - ephemeral hint (per-turn, not cacheable)
    /// - cacheable references (character / world / foreshadow)
    /// - per-turn memos (memory subsystem)
    public func aggregateContextForTurn(
        bookId: String?,
        userMessage: String
    ) async -> ContextBundle {
        // TODO(ticket-009): wire MemoryManager.prefetch + character/world
        // retrieval from wenshu Core/Memory/* subsystem
        _ = bookId
        _ = userMessage
        return ContextBundle(
            memories: [],
            characterContext: [],
            worldContext: [],
            foreshadowContext: []
        )
    }

    /// Assemble a context bundle from explicit inputs (= HERMES-PARTIAL-013
    /// bundle-construction surface; the caller wires ephemeral hint +
    /// cacheable references + per-turn memos through this entry point
    /// without depending on the Memory subsystem).
    public func assembleBundle(
        ephemeralHint: String = "",
        cacheableReferences: [String] = [],
        perTurnMemos: [MemoryEntry] = [],
        characterContext: [String] = [],
        worldContext: [String] = [],
        foreshadowContext: [String] = []
    ) -> ContextBundle {
        var allRefs = cacheableReferences
        if !ephemeralHint.isEmpty {
            // Ephemeral hint sits at the front of the cacheable section.
            allRefs.insert("[ephemeral] " + ephemeralHint, at: 0)
        }
        return ContextBundle(
            memories: perTurnMemos,
            characterContext: characterContext.isEmpty ? allRefs : characterContext,
            worldContext: worldContext,
            foreshadowContext: foreshadowContext
        )
    }

    /// Format a context bundle as a system-prompt dynamic tier (= renders
    /// for LLM consumption).
    public func formatContextBundle(_ bundle: ContextBundle) -> String {
        var sections: [String] = []
        if !bundle.memories.isEmpty {
            let memoryLines = bundle.memories.map { "- [\($0.source)] \($0.snippet)" }.joined(separator: "\n")
            sections.append("Relevant memories:\n\(memoryLines)")
        }
        if !bundle.characterContext.isEmpty {
            sections.append("Characters:\n" + bundle.characterContext.joined(separator: "\n"))
        }
        if !bundle.worldContext.isEmpty {
            sections.append("World:\n" + bundle.worldContext.joined(separator: "\n"))
        }
        if !bundle.foreshadowContext.isEmpty {
            sections.append("Foreshadowing:\n" + bundle.foreshadowContext.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Token state + compression gates (= hermes ContextEngine surface)

    /// Update tracked token usage from an API response (= hermes
    /// update_from_response L71-82). Called after every LLM call.
    public func updateFromResponse(usage: Usage) {
        lastPromptTokens = usage.promptTokens
        lastCompletionTokens = usage.completionTokens
        lastTotalTokens = usage.totalTokens
    }

    /// Whether compaction should fire this turn (= hermes should_compress L83).
    public func shouldCompress(promptTokens: Int? = nil) -> Bool {
        let tokens = promptTokens ?? lastPromptTokens
        return thresholdTokens > 0 && tokens >= thresholdTokens
    }

    /// Whether preflight compression should run (= hermes should_compress_preflight L110).
    public func shouldCompressPreflight(messagesCount: Int) -> Bool {
        return messagesCount > protectFirstN + protectLastN + 1
    }

    /// Compact the message list and return the new list (= hermes compress L87).
    /// In wenshu-side-wins mode, delegates to ContextCompressor with the
    /// current engine's policy (protect_first_n / protect_last_n).
    public func compress(
        messages: [LLMMessage],
        currentTokens: Int? = nil,
        focusTopic: String? = nil
    ) async -> [LLMMessage] {
        let compressor = ContextCompressor(
            policy: ContextCompressor.Policy(
                keepRecentTurns: protectLastN,
                maxTokens: thresholdTokens
            )
        )
        let result = await compressor.compressContext(
            messages: messages,
            systemMessage: ""
        )
        compressionCount += 1
        return result.messages
    }

    /// Update on model switch or fallback activation (= hermes update_model L215-231).
    /// Recalculates threshold_tokens from threshold_percent.
    public func updateModel(
        model: String,
        contextLength: Int,
        baseURL: String = "",
        apiKey: String = "",
        provider: String = "",
        apiMode: String = ""
    ) {
        self.contextLength = contextLength
        self.thresholdTokens = Int(Double(contextLength) * thresholdPercent)
    }

    /// Status dict for display/logging (= hermes get_status L192-213).
    public func getStatus() -> Status {
        let lastPrompt = lastPromptTokens > 0 ? lastPromptTokens : 0
        let percent = contextLength > 0
            ? min(100.0, Double(lastPrompt) / Double(contextLength) * 100.0)
            : 0.0
        return Status(
            lastPromptTokens: lastPrompt,
            thresholdTokens: thresholdTokens,
            contextLength: contextLength,
            usagePercent: percent,
            compressionCount: compressionCount
        )
    }
}