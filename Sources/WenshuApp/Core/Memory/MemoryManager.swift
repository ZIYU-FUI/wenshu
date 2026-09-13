//
//  MemoryManager.swift · Wenshu · v0.23 ticket 013.009 (hermes gap 8)
//
// Boss 2026-08-23: hermes MemoryManager.prefetch_all + sync_all parity.
//  Source: github.com/NousResearch/hermes-agent/blob/main/agent/memory_manager.py:11
//
//  Hermes pattern:
//    pre-turn:  prefetch_all(user_message) → context
//    post-turn: sync_all(user_msg, assistant_response) → persist
//
//  wenshu impl: MemoryManager.prefetch / sync / queuePrefetch (background).
//

import Foundation

/// Result of a prefetch operation.
public enum PrefetchResult: Sendable, Equatable {
    case empty                          // no relevant memories found
    case prefetched(memories: [Memory], totalChars: Int)
}

/// Result of a sync operation.
public enum SyncResult: Sendable, Equatable {
    case synced(writtenCount: Int, totalChars: Int)
    case stagedForApproval              // hermes write-gate stage
    case blocked(reason: String)         // hermes write-gate block
}

/// MemoryManager: orchestrates pre-turn prefetch + post-turn sync for WenshuConductor.
/// Mirrors hermes agent/memory_manager.py pattern.
public actor MemoryManager {
    /// Phase 5 ticket 4: `store` is now optional. When nil (= default),
    /// the actor delegates reads/writes to WSMemoryRepository.shared
    /// (= the @MainActor SwiftData wrapper for the `WSMemory` @Model).
    /// Direct MemoryStore usage (= the legacy sqlite3 actor) is preserved
    /// for tests that want to inject a custom store; = MemoryStore.swift
    /// deletion is gated on every other caller migrating (= future ticket).
    private let store: MemoryStore?
    private let maxCharBudget: Int  // hermes default = 2200
    public init(store: MemoryStore? = nil, maxCharBudget: Int = 2200) {
        self.store = store
        self.maxCharBudget = maxCharBudget
    }

    /// prefetch: pre-turn — load relevant memories based on user message.
    /// hermes equivalent: `prefetch_all(user_message) → Dict[str, str]`.
    /// Simple keyword-match (no embeddings yet — v0.24+).
    public func prefetch(userMessage: String) async -> PrefetchResult {
        guard let memories = try? await searchMemory(userId: "default", query: userMessage, limit: 10), !memories.isEmpty else {
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

    /// prefetch: pre-turn with explicit candidate limit. Used by the
    /// ContextEngine wiring (ticket-009 followup) so callers can pin
    /// the up-to-N ceiling without rebuilding the char budget.
    /// hermes parity: same signature shape as `prefetch_all(user_message)`
    /// with a caller-supplied top-K.
    public func prefetch(userMessage: String, limit: Int) async -> PrefetchResult {
        guard limit > 0 else { return .empty }
        guard let memories = try? await searchMemory(userId: "default", query: userMessage, limit: limit), !memories.isEmpty else {
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
    /// ContextEngine wiring where the downstream bundle assembly
    /// decides its own truncation policy (= ticket-009 baseline).
    /// Limit defaults to 20 to match the ContextEngine "up to 20
    /// relevant memory items" surface documented in the ticket spec.
    public func fetch(limit: Int = 20) async -> [Memory] {
        guard limit > 0 else { return [] }
        return (try? await searchMemory(userId: "default", query: "", limit: limit)) ?? []
    }

    /// sync: post-turn — persist assistant's response (or important info from turn).
    /// hermes equivalent: `sync_all(user_msg, assistant_response)`.
    /// Goes through MemoryWriteGate (ticket 013.001) per hermes _apply_write_gate.
    public func sync(userMessage: String, assistantResponse: String) async -> SyncResult {
        // Combine user + assistant for memory write (hermes does the same).
        let content = "user: \(userMessage.prefix(200))\nassistant: \(assistantResponse.prefix(200))"
        let decision = MemoryWriteGate.evaluateAdd(content: content)
        switch decision {
        case .allow:
            do {
                try await addMemory(userId: "default", content: content)
                let total = (try? await countMemory(userId: "default")) ?? 0
                return .synced(writtenCount: 1, totalChars: total)
            } catch {
                return .blocked(reason: "MemoryStore.add failed: \(error)")
            }
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

    public func queuePrefetch(userMessage: String) {
        let storeRef = store
        let budget = maxCharBudget
        Task.detached {
            // `self.` (= instance call) because prefetchInBackground now reads
            // WSMemoryRepository.shared (= @MainActor) when storeRef is nil.
            // Static call would force MainActor.run from the actor's executor;
            // = instance call preserves actor isolation.
            let result = await self.prefetchInBackground(
                store: storeRef,
                userMessage: userMessage,
                budget: budget
            )
            await self.storePrefetchedResult(result)
        }
    }

    /// Take the queued prefetch result (called at next turn start).
    public func takeQueuedPrefetch() -> PrefetchResult? {
        let result = prefetchedForNextTurn
        prefetchedForNextTurn = nil
        return result
    }

    private func storePrefetchedResult(_ result: PrefetchResult) {
        self.prefetchedForNextTurn = result
    }

    private func prefetchInBackground(
        store: MemoryStore?,
        userMessage: String,
        budget: Int
    ) async -> PrefetchResult {
        guard let memories = try? await searchMemory(userId: "default", query: userMessage, limit: 10), !memories.isEmpty else {
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

    // MARK: - Phase 5 ticket 4: SwiftData bridge helpers
    //
    // When `store` is nil, MemoryManager delegates reads/writes to
    // WSMemoryRepository.shared (= the @MainActor SwiftData wrapper for
    // `WSMemory` @Model class per phase 3 deferred commit 43).
    //
    // The bridge uses `await MainActor.run { ... }` because:
    //   - WSMemoryRepository is @MainActor (= synchronous SwiftData ops).
    //   - MemoryManager is an actor (= async methods run on the actor's
    //     executor; = not MainActor).
    //
    // All helpers return results matching the MemoryStore API shape so the
    // existing prefetch/sync callsites don't need to know which backend is used.

    /// searchMemory: actor-isolated read (= prefers store; falls back to SwiftData).
    private func searchMemory(
        userId: String,
        query: String,
        limit: Int
    ) async -> [Memory] {
        if let store {
            return (try? await searchMemory(userId: userId, query: query, limit: limit)) ?? []
        }
        return await MainActor.run {
            (try? WSMemoryRepository.shared.search(userId: userId, query: query, limit: limit)) ?? []
        }
    }

    /// addMemory: actor-isolated write.
    @discardableResult
    private func addMemory(userId: String, content: String) async -> Bool {
        if let store {
            return (try? await addMemory(userId: userId, content: content)) != nil
        }
        return await MainActor.run {
            (try? WSMemoryRepository.shared.add(userId: userId, content: content)) != nil
        }
    }

    /// countMemory: actor-isolated count.
    private func countMemory(userId: String) async -> Int {
        if let store {
            return (try? await countMemory(userId: userId)) ?? 0
        }
        return await MainActor.run {
            (try? WSMemoryRepository.shared.count(userId: userId)) ?? 0
        }
    }
}