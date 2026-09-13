//
//  Core/Memory/WSMemoryProvider.swift · Wenshu · v0.72 SwiftData migration Phase 3 deferred
//
//  Phase 3 deferred supplementary (= post-phase-4 work; = NOT part of
//  the 21-commit phase 1 sequence). Adds SwiftData-backed MemoryProvider
//  (= the canonical MemoryProvider implementation for code paths that
//  previously used the deprecated MemoryStore actor).
//  Per AGENTS.md §11.4.
//
//  New MemoryProvider implementation that conforms to the existing
//  MemoryProvider protocol (= Sendable; sync method shape).
//
//  Uses an in-memory mirror cache (= updated by async prefetch/sync
//  methods that bridge to @MainActor SwiftData via Task).
//  Sync methods (= getSystemPrompt, preCompressCheckpoint) read from the
//  cache without touching SwiftData (= safe from any actor).
//
//  Per AGENTS.md §11.4: old MemoryStore is deprecated; new code uses
//  SwiftData. WSMemoryProvider is the SwiftData-backed impl.

import Foundation

/// In-memory mirror of the SwiftData WSMemory store (= thread-safe via NSLock).
/// Updated by async prefetch/sync methods (= bridges to @MainActor SwiftData).
/// Read by sync getSystemPrompt/preCompressCheckpoint (= safe from any actor).
final class WSMemoryMirror: @unchecked Sendable {
    private var entries: [Memory] = []
    private let queue = DispatchQueue(label: "com.wenshu.WSMemoryMirror", attributes: .concurrent)

    func update(_ newEntries: [Memory]) {
        queue.sync(flags: .barrier) {
            entries = newEntries
        }
    }

    func current() -> [Memory] {
        queue.sync {
            entries
        }
    }
}

public final class WSMemoryProvider: MemoryProvider, @unchecked Sendable {

    let slug: String
    var isEnabled: Bool

    /// In-memory mirror cache (= thread-safe; = updated by async prefetch/sync).
    private let mirror = WSMemoryMirror()

    /// Last prefetch result (= cached for sync getSystemPrompt to read).
    private var lastPrefetch: String = ""
    private let prefetchQueue = DispatchQueue(label: "com.wenshu.WSMemoryProvider.prefetch")

    public init(slug: String = "swiftdata-memory", isEnabled: Bool = true) {
        self.slug = slug
        self.isEnabled = isEnabled

        // Initial mirror load (= bridge to @MainActor).
        Task { @MainActor [weak self] in
            await self?.refreshMirror()
        }
    }

    @MainActor
    private func refreshMirror() async {
        let entries = (try? WSMemoryRepository.shared.listRecent(userId: "default", limit: 20)) ?? []
        let mapped = entries.map { entry in
            Memory(
                userId: entry.userId,
                memoryId: entry.memoryId,
                content: entry.content,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
        }
        mirror.update(mapped)
    }

    func getSystemPrompt() -> String {
        // Sync read from mirror (= no SwiftData hop; = safe from any actor).
        let entries = mirror.current()
        if entries.isEmpty { return "" }
        let bullets = entries.map { "- \($0.content)" }.joined(separator: "\n")
        return "Recent memories about this user:\n\(bullets)"
    }

    func prefetch(forUserMessage message: String) async -> String {
        // Async (= bridges to @MainActor SwiftData + updates mirror).
        let results = await MainActor.run {
            (try? WSMemoryRepository.shared.search(userId: "default", query: message, limit: 5)) ?? []
        }
        let mapped = results.map { $0.content }.joined(separator: "\n")
        // Update prefetch cache (= sync via DispatchQueue; = safe in async).
        prefetchQueue.sync {
            lastPrefetch = mapped
        }
        Task { @MainActor [weak self] in
            await self?.refreshMirror()
        }
        return mapped
    }

    func sync(userMessage: String, assistantResponse: String) async {
        let content = "User: \(userMessage)\nAssistant: \(assistantResponse)"
        _ = await MainActor.run {
            try? WSMemoryRepository.shared.add(userId: "default", content: content)
        }
        await refreshMirror()
    }

    func getToolSchemas() -> [ToolSchema] {
        return [
            ToolSchema(
                name: "memory_add",
                description: "Persist a new memory entry for the current user.",
                parametersJSON: "{\"type\":\"object\",\"properties\":{\"content\":{\"type\":\"string\"}},\"required\":[\"content\"]}"
            ),
            ToolSchema(
                name: "memory_search",
                description: "Search existing memories for the current user.",
                parametersJSON: "{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"}},\"required\":[\"query\"]}"
            ),
            ToolSchema(
                name: "memory_get_recent",
                description: "Get the most recent memories for the current user.",
                parametersJSON: "{}"
            )
        ]
    }

    func preCompressCheckpoint() -> String? {
        // Sync read from mirror.
        let entries = mirror.current()
        if entries.isEmpty { return nil }
        return "Memory context (\(entries.count) entries): " + entries.map { String($0.content.prefix(80)) }.joined(separator: " | ")
    }

    /// Sync read of the mirror (= all current entries).
    /// Safe from any actor (= uses DispatchQueue under the hood).
    func mirrorSnapshot() -> [Memory] {
        mirror.current()
    }

    /// Reset in-memory state (= for tests).
    func resetCache() {
        mirror.update([])
        prefetchQueue.sync {
            lastPrefetch = ""
        }
    }
}
