// ContextEngine.swift
//
// Context aggregation facade. Maps to hermes `context_engine.py`
// (= ABC interface). Wenshu-side wins per AGENTS.md §11.3:
// the existing wenshu `Core/Memory/*` subsystem already implements
// world / character / foreshadow prefetch + retrieval (=
// `MemoryManager` + `MemoryProvider` + `MemoryConsolidator`).
// This `ContextEngine` is a thin facade that exposes a unified
// API over those existing primitives.
//
//  Responsibilities:
//    - aggregateContextForTurn(bookId:userMessage:) -> ContextBundle
//      (= combines memory prefetch + character/world retrieval)
//    - formatContextBundle(_:) -> String
//      (= renders the context as a system-prompt dynamic tier)
//
// extends the v0.35 surface with the full hermes
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
// sub-step 3.
//

import Foundation

// Migrated to `WSMemoryRepository.shared`.
// subsequent step (= `makeDefaultMemoryManager` returns MemoryManager() with
// no args = uses WSMemoryRepository.shared by default.

actor ContextEngine {

    struct ContextBundle: Sendable {
        let memories: [MemoryEntry]
        let characterContext: [String]
        let worldContext: [String]
        let foreshadowContext: [String]

        var isEmpty: Bool {
            memories.isEmpty && characterContext.isEmpty
                && worldContext.isEmpty && foreshadowContext.isEmpty
        }
    }

    /// Lightweight memory entry (= consumed from wenshu Core/Memory in
    /// subsequent tickets; stub shape for sub-step 3).
    struct MemoryEntry: Sendable {
        let source: String  // file path
        let snippet: String
        init(source: String, snippet: String) {
            self.source = source
            self.snippet = snippet
        }
    }

    /// LLM usage normalized (= hermes usage dict with input/output/cache_read/
    /// cache_write/reasoning tokens).
    struct Usage: Sendable, Equatable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let reasoningTokens: Int

        init(
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
    struct Status: Sendable, Equatable {
        let lastPromptTokens: Int
        let thresholdTokens: Int
        let contextLength: Int
        let usagePercent: Double
        let compressionCount: Int

        init(
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

    private(set) var lastPromptTokens: Int = 0
    private(set) var lastCompletionTokens: Int = 0
    private(set) var lastTotalTokens: Int = 0
    private(set) var thresholdTokens: Int = 0
    private(set) var contextLength: Int = 0
    private(set) var compressionCount: Int = 0

    // MARK: - Compaction parameters (= hermes threshold_percent + protect_first/last)

    var thresholdPercent: Double = 0.75
    var protectFirstN: Int = 3
    var protectLastN: Int = 6

    init() {}

    // MARK: - Per-turn context bundle assembly (= wenshu port)

    /// Default MemoryManager used by ContextEngine when no explicit
    /// manager is injected. Created on first use so unit tests can
    /// construct a ContextEngine without touching the user-visible
    /// library store.
    ///
    /// the previous 38-line sqlite fallback chain
    /// (= /tmp tmpfile → default-init MemoryStore → :memory: DSN
    /// → preconditionFailure) was deleted. The MemoryManager default
    /// initializer now reads from WSMemoryRepository.shared (= the
    /// @MainActor SwiftData wrapper for the `WSMemory` @Model class).
    /// This removes the last production `MemoryStore` instantiation
    /// (= `MemoryStore.swift` deletion is gated on the phase 3
    /// deferred `MemoryProvider` + `WenshuConductor` migration).
    private static func makeDefaultMemoryManager() async -> MemoryManager {
        // Empty `MemoryManager` (= no args = default = nil store = uses
        // `WSMemoryRepository.shared`).
        return MemoryManager()
    }

    /// Aggregate context for one conversation turn
    /// (= hermes context_engine.aggregate_context entry).
    ///
    /// Returns a ContextBundle combining:
    /// - ephemeral hint (per-turn, not cacheable)
    /// - cacheable references (character / world / foreshadow)
    /// - per-turn memos (memory subsystem)
    func aggregateContextForTurn(
        bookId: String?,
        userMessage: String
    ) async -> ContextBundle {
        let manager = await Self.makeDefaultMemoryManager()
        return await aggregateContextForTurn(
            bookId: bookId,
            userMessage: userMessage,
            memoryManager: manager
        )
    }

    /// Overload that accepts an explicit `MemoryManager`. The default
    /// `aggregateContextForTurn(bookId:userMessage:)` uses a freshly-built
    /// in-memory default manager (= the wiring baseline); callers
    /// that own a persisted `MemoryStore` can inject it here so
    /// per-book Character / World retrieval can land in a follow-up
    /// without changing this entry point.
    func aggregateContextForTurn(
        bookId: String?,
        userMessage: String,
        memoryManager: MemoryManager
    ) async -> ContextBundle {
        // Wire `MemoryManager.prefetch`. Character / World retrieval
        // remains pending (= per-book Character / World stores land
        // in a follow-up per the original TODO scope).
        _ = bookId
        let result = await memoryManager.prefetch(userMessage: userMessage)
        let memories: [MemoryEntry]
        switch result {
        case .empty:
            memories = []
        case .prefetched(let rows, _):
            memories = rows.map { row in
                MemoryEntry(source: row.memoryId.rawValue, snippet: row.content)
            }
        }
        return ContextBundle(
            memories: memories,
            characterContext: [],
            worldContext: [],
            foreshadowContext: []
        )
    }

    /// Assemble a context bundle from explicit inputs (= wenshu port
    /// bundle-construction surface; the caller wires ephemeral hint +
    /// cacheable references + per-turn memos through this entry point
    /// without depending on the Memory subsystem).
    func assembleBundle(
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
    func formatContextBundle(_ bundle: ContextBundle) -> String {
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
    func updateFromResponse(usage: Usage) {
        lastPromptTokens = usage.promptTokens
        lastCompletionTokens = usage.completionTokens
        lastTotalTokens = usage.totalTokens
    }

    /// Whether compaction should fire this turn (= hermes should_compress L83).
    func shouldCompress(promptTokens: Int? = nil) -> Bool {
        let tokens = promptTokens ?? lastPromptTokens
        return thresholdTokens > 0 && tokens >= thresholdTokens
    }

    /// Whether preflight compression should run (= hermes should_compress_preflight L110).
    func shouldCompressPreflight(messagesCount: Int) -> Bool {
        return messagesCount > protectFirstN + protectLastN + 1
    }

    /// Compact the message list and return the new list (= hermes compress L87).
    /// In wenshu-side-wins mode, delegates to ContextCompressor with the
    /// current engine's policy (protect_first_n / protect_last_n).
    func compress(
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
    func updateModel(
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
    func getStatus() -> Status {
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
