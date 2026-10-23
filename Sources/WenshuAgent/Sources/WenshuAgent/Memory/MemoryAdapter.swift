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
import WenshuData

@MainActor
public final class MemoryAdapter {
    public struct MemoryEntry: Sendable, Equatable, Identifiable {
        public let id: String
        public let source: String
        public let snippet: String
        public let relevanceScore: Double
        public var idString: String { id }

        public init(
            id: String,
            source: String,
            snippet: String,
            relevanceScore: Double
        ) {
            self.id = id
            self.source = source
            self.snippet = snippet
            self.relevanceScore = relevanceScore
        }
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

    /// The memory provider this adapter reads from and writes to.
    ///
    /// Injected so the turn can honour the backend the user picked
    /// (= the resolver decides; = the default is the local one, which
    /// is what a caller that does not care about backends gets).
    private let provider: any MemoryProvider

    /// P1-01 (audit 2026-09-24): inject WSMemoryRepository via init;
    /// fall back to .shared. Same pattern as WenshuConductor +
    /// MemoryManager + WSMemoryProvider.
    private let memory: WSMemoryRepository

    public init(
        defaults: UserDefaults = .standard,
        memory: WSMemoryRepository? = nil,
        provider: (any MemoryProvider)? = nil
    ) {
        self.defaults = defaults
        self.memory = memory ?? .shared
        self.provider = provider ?? WSMemoryProvider.shared
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
        return (try? memory.purgeOlderThan(userId: defaultUserId, retentionDays: clamped)) ?? 0
    }

    public func recentEntries(limit: Int = 20) -> [MemoryEntry] {
        // A1 boundary: convert WSMemory -> Memory inside this sync caller
        // (called on the @MainActor by the window surface, so the
        // PersistentModel stays on the same actor as its context).
        let rows: [Memory] = (try? memory.listRecent(userId: defaultUserId, limit: limit))?
            .map(Self.toDomain) ?? []
        return rows.map { row in
            MemoryEntry(
                id: row.memoryId.rawValue,
                source: "memory:\(row.memoryId.rawValue)",
                snippet: String(row.content.prefix(120)),
                relevanceScore: 1.0
            )
        }
    }

    /// The memories one recall brings back.
    ///
    /// The count cap is the user's number (= how many memories may reach the
    /// prompt) and it is applied here, where the entries become prompt
    /// content: a provider that returns more than the cap still cannot put
    /// more than the cap into the conversation.
    ///
    /// The character budget is the second bound, and it is what keeps a
    /// large count from becoming a large prompt. Hermes bounds the same
    /// thing (= `memory_char_limit` = 2200 chars), and the package's own
    /// `MemoryManager` carries the same number; without it, a cap of 500
    /// would put 500 rows of recall into every prompt.
    public func retrieve(
        forUserMessage userMessage: String,
        bookId: String? = nil,
        limit: Int = ContextOverrides.memoryCap
    ) async -> [MemoryEntry] {
        guard isEnabled else { return [] }
        // Sync read from WSMemoryProvider mirror cache (= thread-safe;
        // = no SwiftData hop). Falls back to WSMemoryRepository when
        // the mirror is empty (initial-launch case before the first
        // refresh completes).
        let raw = await provider.prefetch(forUserMessage: userMessage)
        guard !raw.isEmpty else { return [] }
        // A cap below one is not a cap (= the memory subsystem's own switch
        // is how recall is turned off), so it falls back to the default.
        let cap = limit >= 1 ? limit : ContextOverrides.memoryCap
        // Split on the newlines the provider emits between entries.
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        var entries: [MemoryEntry] = []
        var characters = 0
        for (idx, line) in lines.enumerated() {
            if entries.count >= cap { break }
            let next = characters + line.count
            if next > Self.characterBudget { break }
            characters = next
            entries.append(MemoryEntry(
                id: "mem:\(idx):\(bookId ?? "global")",
                source: "memory:recall",
                snippet: String(line.prefix(120)),
                relevanceScore: 1.0 - Double(idx) * 0.05
            ))
        }
        return entries
    }

    /// The characters one recall may carry into the prompt.
    ///
    /// Hermes bounds the same thing (= `memory_char_limit` = 2200), and the
    /// package's own `MemoryManager` carries the same number (= hermes
    /// parity). The count cap alone cannot do this job: the user picks
    /// how many memories may come back, and 500 memories of a few hundred
    /// characters each is more prompt than the conversation it serves.
    public static let characterBudget = 2200

    public func write(snippet: String, source: String, bookId: String? = nil) async {
        _ = bookId
        _ = source
        _ = snippet
        guard isEnabled else { return }
        // Persist via WSMemoryProvider (= SwiftData-backed; = same
        // userId canonicalization as the recentEntries path).
        await provider.sync(userMessage: snippet, assistantResponse: source)
    }

    /// The provider the user's memory backend resolves to.
    ///
    /// The user's choice goes through the resolver, so a backend that
    /// cannot run falls back to the local one and the reason travels with
    /// the result (= the settings screen can explain it). Without a remote
    /// provider registered, a cloud choice resolves to local with
    /// `.remoteNotConfigured`, which is the resolver's designed behaviour.
    @MainActor
    public static func resolveProvider(
        for settings: MemorySettings,
        additionalProviders: [any MemoryProvider] = []
    ) -> any MemoryProvider {
        let resolver = ContextEngine.makeBackendResolver(
            settings: settings,
            additionalProviders: additionalProviders
        )
        return resolver.resolve(settings: settings)?.provider ?? WSMemoryProvider.shared
    }

    /// A1 boundary bridge (Sendable-safe).
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
