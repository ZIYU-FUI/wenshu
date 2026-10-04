// MemoryManager.swift
//
// hermes `MemoryManager.prefetch_all` + `sync_all` parity. Wenshu-side
// wins: this is the canonical Swift-side type per AGENTS.md §11.3;
// the hermes-port adapter (`MemoryAdapter`) delegates here.
//
// Hermes pattern:
//   pre-turn:  prefetch_all(user_message) → context
//   post-turn: sync_all(user_msg, assistant_response) → persist

import Foundation

/// Result of a prefetch operation.
enum PrefetchResult: Sendable, Equatable {
    case empty                          // no relevant memories found
    case prefetched(memories: [Memory], totalChars: Int)
}

/// Result of a sync operation.
enum SyncResult: Sendable, Equatable {
    case synced(writtenCount: Int, totalChars: Int)
    case stagedForApproval              // hermes write-gate stage
    case blocked(reason: String)         // hermes write-gate block
}

/// MemoryManager: orchestrates pre-turn prefetch + post-turn sync for WenshuConductor.
/// Mirrors hermes agent/memory_manager.py pattern.
actor MemoryManager {
    /// `store` was optionalized. When nil (= default), the actor delegates
    /// reads / writes to WSMemoryRepository.shared (= the @MainActor
    /// SwiftData wrapper for the `WSMemory` @Model).
    /// Max character budget for prefetch (= hermes default = 2200).
    /// All memory calls go through WSMemoryRepository.shared (= Apple
    /// SwiftData-backed).
    private let maxCharBudget: Int

    /// MemoryManager delegate injects WSMemoryRepository. The injected
    /// value is preferred (= same injection shape as WenshuConductor.repositories);
    /// when nil, the singleton `.shared` is used (every existing caller
    /// keeps working without changes).
    private let memory: WSMemoryRepository

    init(maxCharBudget: Int = 2200, memory: WSMemoryRepository? = nil) {
        self.maxCharBudget = maxCharBudget
        // .shared is @MainActor-isolated; actor bodies are not. assumeIsolated
        // (= safe at runtime because every production caller constructs
        // MemoryManager from a MainActor context).
        self.memory = memory ?? MainActor.assumeIsolated { WSMemoryRepository.shared }
    }

    /// prefetch: pre-turn — load relevant memories based on user message.
    /// hermes equivalent: `prefetch_all(user_message) → Dict[str, str]`.
    /// Simple keyword-match (no embeddings yet — v0.24+).
    func prefetch(userMessage: String) async -> PrefetchResult {
        let memories = await searchMemory(userId: "default", query: userMessage, limit: 10)
        guard !memories.isEmpty else {
            return .empty
        }
        // Apply char budget (hermes: total ≤ memory_char_limit).
        var totalChars = 0
        var prefetched: [Memory] = []
        for memory in memories {
            let next = totalChars + memory.content.count
            if next > maxCharBudget { break }
            prefetched.append(memory)
            totalChars = next
        }
        return .prefetched(memories: prefetched, totalChars: totalChars)
    }

    /// prefetch: pre-turn with explicit candidate limit. Used by
    /// ContextEngine so callers can pin the up-to-N ceiling
    /// without rebuilding the char budget.
    /// hermes parity: same signature shape as `prefetch_all(user_message)`
    /// with a caller-supplied top-K.
    func prefetch(userMessage: String, limit: Int) async -> PrefetchResult {
        guard limit > 0 else { return .empty }
        let memories = await searchMemory(userId: "default", query: userMessage, limit: limit)
        guard !memories.isEmpty else {
            return .empty
        }
        var totalChars = 0
        var prefetched: [Memory] = []
        for memory in memories {
            let next = totalChars + memory.content.count
            if next > maxCharBudget { break }
            prefetched.append(memory)
            totalChars = next
        }
        return .prefetched(memories: prefetched, totalChars: totalChars)
    }

    /// fetch: raw top-N memory rows, ignoring char budget. Used by
    /// ContextEngine where the downstream bundle assembly decides
    /// its own truncation policy. Limit defaults to 20 (= the
    /// ContextEngine 'up to 20 relevant memory items' surface).
    func fetch(limit: Int = 20) async -> [Memory] {
        guard limit > 0 else { return [] }
        return await searchMemory(userId: "default", query: "", limit: limit)
    }

    /// sync: post-turn — persist assistant's response (or important info from turn).
    /// hermes equivalent: `sync_all(user_msg, assistant_response)`.
    /// Goes through `MemoryWriteGate` (= hermes `_apply_write_gate` parity).
    func sync(userMessage: String, assistantResponse: String) async -> SyncResult {
        // Combine user + assistant for memory write (hermes does the same).
        let content = "user: \(userMessage.prefix(200))\nassistant: \(assistantResponse.prefix(200))"
        let decision = MemoryWriteGate.evaluateAdd(content: content)
        switch decision {
        case .allow:
            await addMemory(userId: "default", content: content)
            let total = await countMemory(userId: "default")
            return .synced(writtenCount: 1, totalChars: total)
        case .stageForApproval:
            // hermes: stage to pending queue. wenshu v0.23: silent stage (no GUI yet).
            return .stagedForApproval
        case .block(let reason):
            return .blocked(reason: reason)
        }
    }

    /// queuePrefetch: async background prefetch (next-turn optimization).
    /// hermes equivalent: `queue_prefetch_all(user_msg)` — runs on background thread,
    /// result is ready for next turn. wenshu impl: returns immediately, prefetches
    /// in detached task, result stored for next call.
    private var prefetchedForNextTurn: PrefetchResult?

    func queuePrefetch(userMessage: String) {
        let budget = maxCharBudget
        Task.detached {
            let result = await self.prefetchInBackground(
                userMessage: userMessage,
                budget: budget
            )
            await self.storePrefetchedResult(result)
        }
    }

    /// Take the queued prefetch result (called at next turn start).
    func takeQueuedPrefetch() -> PrefetchResult? {
        let result = prefetchedForNextTurn
        prefetchedForNextTurn = nil
        return result
    }

    private func storePrefetchedResult(_ result: PrefetchResult) {
        self.prefetchedForNextTurn = result
    }

    private func prefetchInBackground(
        userMessage: String,
        budget: Int
    ) async -> PrefetchResult {
        let memories = await searchMemory(userId: "default", query: userMessage, limit: 10)
        guard !memories.isEmpty else {
            return .empty
        }
        var totalChars = 0
        var prefetched: [Memory] = []
        for memory in memories {
            let next = totalChars + memory.content.count
            if next > budget { break }
            prefetched.append(memory)
            totalChars = next
        }
        return .prefetched(memories: prefetched, totalChars: totalChars)
    }

    // MARK: - SwiftData bridge helpers
    //
    // MemoryManager always delegates reads / writes to
    // WSMemoryRepository.shared (= the @MainActor SwiftData wrapper for
    // `WSMemory` @Model).
    //
    // The bridge uses `await MainActor.run { ... }` because:
    //   - WSMemoryRepository is @MainActor (= synchronous SwiftData ops).
    //   - MemoryManager is an actor (= async methods run on the actor's
    //     executor; = not MainActor).
    //
    // All helpers return [Memory] / Int / Bool (= the public-API shape)
    // so existing prefetch / sync callsites stay backend-agnostic.

    /// searchMemory: actor-isolated read (= delegates to SwiftData).
    private func searchMemory(
        userId: String,
        query: String,
        limit: Int
    ) async -> [Memory] {
        return await MainActor.run {
            (try? memory.search(userId: userId, query: query, limit: limit)) ?? []
        }
    }

    /// addMemory: actor-isolated write.
    @discardableResult
    private func addMemory(userId: String, content: String) async -> Bool {
        return await MainActor.run {
            (try? memory.add(userId: userId, content: content)) != nil
        }
    }

    /// countMemory: actor-isolated count.
    private func countMemory(userId: String) async -> Int {
        return await MainActor.run {
            (try? memory.count(userId: userId)) ?? 0
        }
    }
}
