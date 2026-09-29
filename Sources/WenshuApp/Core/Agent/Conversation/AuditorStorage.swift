//
//  AuditorStorage.swift · Wenshu · v2.7d
//
//  Read-only memory adapter for the Auditor sub-agent.
//
//  Background:
//  Auditor's domain (= verifying other sub-agents' outputs against
//  canonical memory) was wired through the LLM-facing ToolRegistry
//  in v0.23 (= hermes port with a `memory` tool). The memory
//  rewire moved the read/write path to `WSMemoryProvider.shared`
//  directly; = the LLM-facing tool surface was removed.
//
//  v2.7d: Auditor reads `WSMemoryProvider.shared.prefetch(...)`
//  directly (= same path the main agent uses on every turn). No
//  write access (= auditor is read-only by design; = writes happen
//  via the main agent's post-turn `_sync_memory` hook, NOT via
//  Auditor's output).
//
//  This protocol isolates the read so the runner can be tested
//  without a real SwiftData container (= the test passes an
//  in-memory AuditorStorage stub).
//
//  Threading: all methods are `@MainActor` (the underlying
//  WSMemoryProvider.shared is `@unchecked Sendable`; = the calls
//  hop to MainActor via the runner). AuditorStorage itself is
// `@MainActor`.
//

import Foundation

@MainActor
protocol AuditorStorage: Sendable {
    /// Prefetch canonical memory snippets relevant to the user message.
    /// Returns the assembled memory guidance string (= the same shape
    /// `MemoryProvider.prefetch(forUserMessage:)` returns; = can be
    /// empty when no canonical memory matches the query).
    func readMemory(forUserMessage message: String) async -> String
}

/// Production default implementation. Delegates to
/// `WSMemoryProvider.shared.prefetch(...)` (= the canonical
/// SwiftData-backed memory read path; = same one used by the main
/// agent's `composeSystemPrompt`).
@MainActor
final class LiveAuditorStorage: AuditorStorage {
    private let provider: WSMemoryProvider

    init(provider: WSMemoryProvider = .shared) {
        self.provider = provider
    }

    func readMemory(forUserMessage message: String) async -> String {
        await provider.prefetch(forUserMessage: message)
    }
}