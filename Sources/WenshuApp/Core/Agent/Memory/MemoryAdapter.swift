//
//  MemoryAdapter.swift · Wenshu · v0.72 SwiftData migration Phase 3
//
//  Migration commit 34 of 42: MemoryAdapter → @MainActor + WSMemoryRepository.
//  Per AGENTS.md §11.4.
//
//  Was `public actor MemoryAdapter` (= each call site did
//  `await MemoryAdapter().method(...)`). Now `public final class` @MainActor
//  that delegates to WSMemoryRepository.shared (= synchronous calls;
//  matches SwiftUI view conventions).
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
public final class MemoryAdapter {
    public struct MemoryEntry: Sendable, Equatable, Identifiable {
        public let id: String
        public let source: String
        public let snippet: String
        public let relevanceScore: Double
        public var idString: String { id }
    }

    public enum DefaultsKey {
        public static let enabled = "wenshu.memory.enabled"
        public static let scope = "wenshu.memory.scope"
        public static let retentionDays = "wenshu.memory.retentionDays"
    }

    public enum MemoryScope: String, CaseIterable, Sendable {
        case perBook
        case global
        case libraryPublic
    }

    private let defaults: UserDefaults
    private let defaultUserId: String = "default"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        if defaults.object(forKey: DefaultsKey.enabled) == nil { return true }
        return defaults.bool(forKey: DefaultsKey.enabled)
    }

    public var scope: MemoryScope {
        guard let raw = defaults.string(forKey: DefaultsKey.scope),
              let parsed = MemoryScope(rawValue: raw)
        else { return .perBook }
        return parsed
    }

    public var retentionDays: Int {
        if defaults.object(forKey: DefaultsKey.retentionDays) == nil { return 90 }
        let stored = defaults.integer(forKey: DefaultsKey.retentionDays)
        return min(max(stored, 7), 365)
    }

    public func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: DefaultsKey.enabled)
    }

    public func setScope(_ scope: MemoryScope) {
        defaults.set(scope.rawValue, forKey: DefaultsKey.scope)
    }

    public func setRetentionDays(_ days: Int) -> Int {
        let clamped = min(max(days, 7), 365)
        defaults.set(clamped, forKey: DefaultsKey.retentionDays)
        return (try? WSMemoryRepository.shared.purgeOlderThan(userId: defaultUserId, retentionDays: clamped)) ?? 0
    }

    public func recentEntries(limit: Int = 20) -> [MemoryEntry] {
        let rows = (try? WSMemoryRepository.shared.listRecent(userId: defaultUserId, limit: limit)) ?? []
        return rows.map { row in
            MemoryEntry(
                id: row.memoryId,
                source: "memory:\(row.memoryId)",
                snippet: String(row.content.prefix(120)),
                relevanceScore: 1.0
            )
        }
    }

    public func retrieve(forUserMessage userMessage: String, bookId: String? = nil) -> [MemoryEntry] {
        _ = bookId
        _ = userMessage
        guard isEnabled else { return [] }
        return []
    }

    public func write(snippet: String, source: String, bookId: String? = nil) {
        _ = bookId
        _ = snippet
        _ = source
        guard isEnabled else { return }
    }
}
