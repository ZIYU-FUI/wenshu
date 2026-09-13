//
//  Core/Memory/WSMemoryManager.swift · Wenshu · v0.72 SwiftData migration Phase 3 deferred
//
//  Migration commit 44 of 50: WSMemoryManager.
//  Per AGENTS.md §11.4.
//
//  SwiftData-backed alternative to MemoryManager. Same public surface
//  (= prefetch + sync + fetch returning PrefetchResult / SyncResult / [Memory])
//  but uses WSMemoryProvider (= SwiftData-backed) instead of MemoryStore.

import Foundation

/// MemoryManager that uses WSMemoryProvider (= SwiftData-backed) instead of
/// MemoryStore (= deprecated).
public actor WSMemoryManager {
    private let provider: WSMemoryProvider
    private let maxCharBudget: Int

    public init(provider: WSMemoryProvider = WSMemoryProvider(),
                maxCharBudget: Int = 2200) {
        self.provider = provider
        self.maxCharBudget = maxCharBudget
    }

    /// prefetch: pre-turn — load relevant memories based on user message.
    public func prefetch(userMessage: String) async -> PrefetchResult {
        // Trigger async prefetch (= populates mirror via SwiftData search)
        _ = await provider.prefetch(forUserMessage: userMessage)
        // Return current mirror (= post-search)
        return prefetchFromMirror(matching: userMessage, limit: 10)
    }

    /// prefetch: pre-turn with explicit candidate limit.
    public func prefetch(userMessage: String, limit: Int) async -> PrefetchResult {
        guard limit > 0 else { return .empty }
        _ = await provider.prefetch(forUserMessage: userMessage)
        return prefetchFromMirror(matching: userMessage, limit: limit)
    }

    /// fetch: raw top-N memory rows.
    public func fetch(limit: Int = 20) async -> [Memory] {
        guard limit > 0 else { return [] }
        // Trigger sync refresh (= ensures mirror is current)
        _ = await provider.prefetch(forUserMessage: "")
        return Array(provider.mirrorSnapshot().prefix(limit))
    }

    /// sync: post-turn — persist assistant's response.
    public func sync(userMessage: String, assistantResponse: String) async -> SyncResult {
        await provider.sync(userMessage: userMessage, assistantResponse: assistantResponse)
        return .synced(writtenCount: 1, totalChars: userMessage.count + assistantResponse.count)
    }

    /// queuePrefetch (= no-op for SwiftData; = search is synchronous via mirror).
    public func queuePrefetch(userMessage: String) {
        // Background prefetch was a hermes optimization for the old SQLite store;
        // SwiftData is fast enough (= no queue needed).
    }

    /// Helper: filter + budget from mirror snapshot.
    private func prefetchFromMirror(matching query: String, limit: Int) -> PrefetchResult {
        let all = provider.mirrorSnapshot()
        if all.isEmpty { return .empty }
        // Simple keyword match (= mirrors MemoryManager behavior)
        let lowerQuery = query.lowercased()
        let filtered = lowerQuery.isEmpty
            ? all
            : all.filter { $0.content.lowercased().contains(lowerQuery) }
        if filtered.isEmpty { return .empty }
        var totalChars = 0
        var prefetched: [Memory] = []
        for memory in filtered.prefix(limit) {
            let next = totalChars + memory.content.count
            if next > maxCharBudget { break }
            prefetched.append(memory)
            totalChars = next
        }
        return .prefetched(memories: prefetched, totalChars: totalChars)
    }
}
