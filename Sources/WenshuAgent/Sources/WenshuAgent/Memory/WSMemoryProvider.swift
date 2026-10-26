//
//  Core/Memory/WSMemoryProvider.swift · Wenshu
//
//  SwiftData-backed MemoryProvider implementation.
//
//  Persistence flows through WSMemoryRepository.shared (@MainActor
//  wrapper around the WSMemory @Model store). An in-memory mirror
//  cache (@MainActor writes; NSLock on read) lets sync methods
//  (getSystemPrompt, preCompressCheckpoint) answer without re-touching
//  SwiftData. Async methods (sync, prefetch) cross the actor boundary
//  via Task to keep the SwiftData writes on @MainActor.
//
//  Conforms to the Sendable MemoryProvider protocol (= thin facade
//  over WSMemoryRepository; = no extra storage of its own).

import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "wsmemoryprovider")

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

// (wenshuMemoryLogger removed 2026-10 in q99-spec-p0-batch2 — verify-dead.py
//  confirmed 0 external callers; = the file-private os.Logger was
//  retained for hermes-port parity but no WSMemoryProvider call site
//  emitted log entries; = wenshuLogger.info(...) lines throughout the file
//  handle the same observability concern. See wenshu-pocock-workflow
//  references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup
//  SKILL.md.)

public final class WSMemoryProvider: MemoryProvider, @unchecked Sendable {

    public let slug: String
    public var isEnabled: Bool

    /// Shared singleton (= matches the WSMemoryRepository.shared +
    /// MemoryManager.shared pattern). Created lazily on first access
    /// from a @MainActor context (= the init is @MainActor-isolated).
    @MainActor
    public static let shared: WSMemoryProvider = WSMemoryProvider()

    /// In-memory mirror cache (= thread-safe; = updated by async prefetch/sync).
    private let mirror = WSMemoryMirror()

    /// Last prefetch result (= cached for sync getSystemPrompt to read).
    private var lastPrefetch: String = ""
    private let prefetchQueue = DispatchQueue(label: "com.wenshu.WSMemoryProvider.prefetch")

    /// P1-01 (audit 2026-09-24): inject WSMemoryRepository via init;
    /// fall back to .shared (= every existing caller keeps working
    /// without changes). Same pattern as `WenshuConductor.repositories`
    /// and `MemoryManager.memory`.
    private let memory: WSMemoryRepository

    /// @MainActor: the fallback reads WSMemoryRepository.shared (= a
    /// @MainActor static). The isolation is declared here so the
    /// compiler rejects an off-MainActor construction, instead of the
    /// runtime trapping on an assumeIsolated assertion.
    @MainActor
    public init(slug: String = "swiftdata-memory", isEnabled: Bool = true, memory: WSMemoryRepository? = nil) {
        self.slug = slug
        self.isEnabled = isEnabled
        if let memory {
            self.memory = memory
        } else {
            self.memory = WSMemoryRepository.shared
        }

        // Initial mirror load (= bridge to @MainActor).
        Task { @MainActor [weak self] in
            await self?.refreshMirror()
        }
    }

    @MainActor
    private func refreshMirror() async {
        // convert WSMemory -> Memory inside MainActor.
        // WSMemory is non-Sendable, so we extract Sendable scalars
        // (memoryID + content) inside the @MainActor scope and
        // build the domain Memory type from those.
        let entries: [Memory] = (try? memory.listRecent(userId: "default", limit: 20))?
            .map { Self.toDomain($0) } ?? []
        mirror.update(entries)
    }

    public func getSystemPrompt() -> String {
        // Sync read from mirror (= no SwiftData hop; = safe from any actor).
        let entries = mirror.current()
        if entries.isEmpty { return "" }
        let bullets = entries.map { "- \($0.content)" }.joined(separator: "\n")
        return "Recent memories about this user:\n\(bullets)"
    }

    public func prefetch(forUserMessage message: String) async -> String {
        // Async (= bridges to @MainActor SwiftData + updates mirror).
        // extract Sendable scalars inside MainActor.run
        // (WSMemory is non-Sendable, = can't cross the boundary).
        let contentLines: [String] = await MainActor.run {
            ((try? memory.search(userId: "default", query: message, limit: ContextOverrides.memoryCap)) ?? [])
                .map { $0.content }
        }
        let mapped = contentLines.joined(separator: "\n")
        // Update prefetch cache (= sync via DispatchQueue; = safe in async).
        prefetchQueue.sync {
            lastPrefetch = mapped
        }
        Task { @MainActor [weak self] in
            await self?.refreshMirror()
        }
        return mapped
    }

    public func sync(userMessage: String, assistantResponse: String) async {
        let content = "User: \(userMessage)\nAssistant: \(assistantResponse)"
        // add() returns the inserted WSMemory (= non-Sendable).
        // The caller only needs the write to succeed; = drop the value via Void.
        await MainActor.run {
            _ = try? memory.add(userId: "default", content: content)
        }
        await refreshMirror()
    }

    public func getToolSchemas() -> [ToolSchema] {
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

    public func preCompressCheckpoint() -> String? {
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
    public func resetCache() {
        mirror.update([])
        prefetchQueue.sync {
            lastPrefetch = ""
        }
    }

        nonisolated private static func toDomain(_ model: WSMemory) -> Memory {
        Memory(
            userId: model.userID,
            memoryId: MemoryID(rawValue: model.memoryID),
            content: model.content,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}
