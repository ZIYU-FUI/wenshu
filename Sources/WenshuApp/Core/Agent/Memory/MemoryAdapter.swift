//
//  MemoryAdapter.swift · Wenshu
//
//  @MainActor facade over WSMemoryRepository.shared.
//
//  Was an actor (= each call site did `await MemoryAdapter().method(...)`).
//  Now a @MainActor class with synchronous method shapes (= matches
//  SwiftUI view conventions; = no extra `await` per access).
//
//  Public surface (= preserved 1:1):
//    - struct MemoryEntry: id + source + snippet + relevanceScore
//    - enum DefaultsKey: enabled / scope / retentionDays (= UserDefaults keys)
//    - var isEnabled: Bool
//    - var scope: MemoryScope
//    - var retentionDays: Int
//    - func setEnabled(_:) (was public func setEnabled(_:) inside actor)
//    - func setScope(_:)
//    - func setRetentionDays(_:) -> Int  (now synchronous)
//    - func recentEntries(limit:) -> [MemoryEntry]  (now synchronous)
//    - func retrieve(forUserMessage:bookId:) -> [MemoryEntry]  (synchronous stub)
//    - func write(snippet:source:bookId:)  (synchronous stub)
//
//  init() preserved as a no-op (= backward compat for `MemoryAdapter()`).

import Foundation

@MainActor
final class MemoryAdapter {
    struct MemoryEntry: Sendable, Equatable, Identifiable {
        let id: String
        let source: String
        let snippet: String
        let relevanceScore: Double
        var idString: String { id }
    }

    enum DefaultsKey {
        static let enabled = "wenshu.memory.enabled"
        static let scope = "wenshu.memory.scope"
        static let retentionDays = "wenshu.memory.retentionDays"
    }

    enum MemoryScope: String, CaseIterable, Sendable {
        case perBook
        case global
        case libraryPublic
    }

    private let defaults: UserDefaults
    private let defaultUserId: String = "default"

    /// P1-01 (audit 2026-09-24): inject WSMemoryRepository via init;
    /// fall back to .shared. Same pattern as WenshuConductor +
    /// MemoryManager + WSMemoryProvider.
    private let memory: WSMemoryRepository

    init(defaults: UserDefaults = .standard, memory: WSMemoryRepository? = nil) {
        self.defaults = defaults
        self.memory = memory ?? .shared
    }

    var isEnabled: Bool {
        if defaults.object(forKey: DefaultsKey.enabled) == nil { return true }
        return defaults.bool(forKey: DefaultsKey.enabled)
    }

    var scope: MemoryScope {
        guard let raw = defaults.string(forKey: DefaultsKey.scope),
              let parsed = MemoryScope(rawValue: raw)
        else { return .perBook }
        return parsed
    }

    var retentionDays: Int {
        if defaults.object(forKey: DefaultsKey.retentionDays) == nil { return 90 }
        let stored = defaults.integer(forKey: DefaultsKey.retentionDays)
        return min(max(stored, 7), 365)
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: DefaultsKey.enabled)
    }

    func setScope(_ scope: MemoryScope) {
        defaults.set(scope.rawValue, forKey: DefaultsKey.scope)
    }

    func setRetentionDays(_ days: Int) -> Int {
        let clamped = min(max(days, 7), 365)
        defaults.set(clamped, forKey: DefaultsKey.retentionDays)
        return (try? memory.purgeOlderThan(userId: defaultUserId, retentionDays: clamped)) ?? 0
    }

    func recentEntries(limit: Int = 20) -> [MemoryEntry] {
        let rows = (try? memory.listRecent(userId: defaultUserId, limit: limit)) ?? []
        return rows.map { row in
            MemoryEntry(
                id: row.memoryId.rawValue,
                source: "memory:\(row.memoryId.rawValue)",
                snippet: String(row.content.prefix(120)),
                relevanceScore: 1.0
            )
        }
    }

    func retrieve(forUserMessage userMessage: String, bookId: String? = nil) async -> [MemoryEntry] {
        guard isEnabled else { return [] }
        // Sync read from WSMemoryProvider mirror cache (= thread-safe;
        // = no SwiftData hop). Falls back to WSMemoryRepository when
        // the mirror is empty (initial-launch case before the first
        // refresh completes).
        let raw = await WSMemoryProvider.shared.prefetch(forUserMessage: userMessage)
        guard !raw.isEmpty else { return [] }
        // Split on the newlines the provider emits between entries.
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return lines.enumerated().map { idx, line in
            MemoryEntry(
                id: "mem:\(idx):\(bookId ?? "global")",
                source: "memory:recall",
                snippet: String(line.prefix(120)),
                relevanceScore: 1.0 - Double(idx) * 0.05
            )
        }
    }

    func write(snippet: String, source: String, bookId: String? = nil) async {
        _ = bookId
        _ = source
        _ = snippet
        guard isEnabled else { return }
        // Persist via WSMemoryProvider (= SwiftData-backed; = same
        // userId canonicalization as the recentEntries path).
        await WSMemoryProvider.shared.sync(userMessage: snippet, assistantResponse: source)
    }
}
