//
//  MemoryAdapter.swift · Wenshu · v0.35 ticket 009
//  + SETTINGS-PERSISTENCE-001 (2026-09-05).
//

import Foundation

public actor MemoryAdapter {
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

    public func setRetentionDays(_ days: Int) async -> Int {
        let clamped = min(max(days, 7), 365)
        defaults.set(clamped, forKey: DefaultsKey.retentionDays)
        let store = await Self.makeStoreOrNil()
        guard let store = store else { return 0 }
        return (try? await store.purgeOlderThan(userId: defaultUserId, retentionDays: clamped)) ?? 0
    }

    public func recentEntries(limit: Int = 20) async -> [MemoryEntry] {
        guard let store = await Self.makeStoreOrNil() else { return [] }
        let rows = (try? await store.listRecent(userId: defaultUserId, limit: limit)) ?? []
        return rows.map { row in
            MemoryEntry(
                id: row.memoryId,
                source: "memory:\(row.memoryId)",
                snippet: String(row.content.prefix(120)),
                relevanceScore: 1.0
            )
        }
    }

    public func retrieve(forUserMessage userMessage: String, bookId: String? = nil) async -> [MemoryEntry] {
        _ = bookId
        _ = userMessage
        guard isEnabled else { return [] }
        return []
    }

    public func write(snippet: String, source: String, bookId: String? = nil) async {
        _ = bookId
        _ = snippet
        _ = source
        guard isEnabled else { return }
    }

    private static func makeStoreOrNil() async -> MemoryStore? {
        do {
            let store = try MemoryStore()
            try? await store.bootstrap()
            return store
        } catch {
            return nil
        }
    }
}
