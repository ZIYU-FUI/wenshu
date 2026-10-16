//
//  WenshuAgent.swift · Wenshu · WenshuAgent public facade
//
//  This file is the public entry point that chat / settings / import
//  layers call. It centralizes the call surface (= the hermes
//  `agent.Agent` Actor pattern) so future MCP / plugin support has
//  one stable surface to extend.
//
//  Active contract today (= 2026-10-16 P3 / P0 agent arc):
//
//      await WenshuAgent.shared.providersWithKeys() -> [String]
//      await WenshuAgent.shared.availableModels(for: provider, ...) -> [String]
//      await WenshuAgent.shared.currentConductor() -> WenshuConductor?
//      await WenshuAgent.shared.installConductor(_:) -> Void
//      await WenshuAgent.shared.chat(userMessage:sessionId:model:
//                                     streamCallback:) -> (reply, tokens, thinking)?
//
//  RATIONALE (= 14 caller migration enabler per commit a0b371b45):
//  The Chat / Settings / Import call sites currently import
//  `WenshuConductor` + `ProviderKeychain` + `LLMModelDiscovery`
//  directly. That boundary violation (= 9 of the 9 unreasonable
//  call paths in P1 AUDIT.md) is fixed by routing every caller
//  through `WenshuAgent.shared` (= this actor). The WenshuAppDelegate
//  becomes the single owner of the conductor instance; the 14
//  callers ask WenshuAgent for it (= and the chat() public method
//  becomes the single entry point for the LLM call).
//
//  Future tickets:
//   - migrate each of the 14 callers to call WenshuAgent.shared.*.
//   - add a `WenshuAgent.registerProvider(_:)` hook for MCP plugins.
//

import Foundation

actor WenshuAgent {
    static let shared = WenshuAgent()

    private let modelDiscovery = LLMModelDiscovery()
    // The conductor instance (= shared singleton; = WenshuAppDelegate
    // installs it once at app startup; = the 14 callers retrieve it
    // through `currentConductor()`).
    private var conductor: WenshuConductor?

    private init() {}

    // MARK: - Conductor lifecycle (= boss OOB 4-directive: "调用提供商 API 是否抽独立包")

    /// Installs the conductor instance (= called once by
    /// WenshuAppDelegate at app startup; = `WenshuAppDelegateLLMHelpers
    /// .activeLLMConnector()` is the source of the connector that
    /// the conductor wraps).
    func installConductor(_ conductor: WenshuConductor) {
        self.conductor = conductor
    }

    /// Returns the active conductor (= nil if not yet installed).
    /// Per AGENTS.md §11.4 (boundary policy): UI / App layers
    /// call this; = they do not construct `WenshuConductor`.
    func currentConductor() -> WenshuConductor? {
        conductor
    }

    // MARK: - Providers with keys

    /// Returns the slugs of providers that have an API key configured
    /// (= wenshu-internal flag; = no plaintext secrets leave this layer).
    /// Delegates to `ProviderKeychain.listProvidersWithKeys()`.
    func providersWithKeys() async -> [String] {
        let result = await Task.detached {
            ProviderKeychain.listProvidersWithKeys()
        }.value
        // Cache the result for sync read by SwiftUI view bodies
        // (= AUDIT.md §2.2 partial: ChatView.hasUsableKey +
        // ChatZoneView body are `var` (= non-async) and
        // cannot `await providersWithKeys()`).
        cachedProvidersWithKeys = result
        _publishCachedSnapshot()
        return result
    }

    /// Cached value of the last `providersWithKeys()` call.
    /// Initialized to `[]` (= "no provider configured yet" =
    /// the same value ChatView / ChatZoneView would see on
    /// first launch before the cache is warmed up). The
    /// cache is updated each time `providersWithKeys()` is
    /// awaited (= which happens at app launch + on every
    /// keychain change notification per the WenshuAgent /
    /// ProviderKeychain wiring in WenshuAppDelegate).
    private var cachedProvidersWithKeys: [String] = []

    /// Sync read of the cached provider-with-keys list.
    /// For SwiftUI view bodies (= `var hasUsableKey: Bool`
    /// is non-async). The cache is updated whenever
    /// `providersWithKeys()` runs (= 1x at app launch;
    /// = 1x per keychain change notification).
    /// Returns `false` if the cache is empty (= "no
    /// provider configured yet" = the conservative
    /// default).
    nonisolated func hasProvidersWithKeysCached() -> Bool {
        // Note: this is `nonisolated` to allow SwiftUI
        // view bodies (= main actor) to read without an
        // async hop. The cache is only ever written from
        // the `providersWithKeys()` method (= same actor),
        // so the read is naturally consistent.
        // (= the Swift 6 strict-concurrency warning about
        // "non-Sendable" private state is suppressed via
        // the explicit @unchecked Sendable below; = the
        // underlying type is a String array which IS
        // Sendable; = safe to read across actors.)
        WenshuAgent.cachedSnapshot.withLock { $0.isEmpty == false }
    }

    /// Cached snapshot for `nonisolated` sync reads.
    /// Updated from `providersWithKeys()` (= the actor-
    /// isolated write). Read from SwiftUI view bodies
    /// (= the non-async read path).
    private static let cachedSnapshot = CachedProviderList()

    /// Tiny lock-protected holder (= replaces the
    /// actor-isolated `cachedProvidersWithKeys` for the
    /// `nonisolated` read path).
    private final class CachedProviderList: @unchecked Sendable {
        private var value: [String] = []
        private let lock = NSLock()
        func withLock<R>(_ body: (inout [String]) -> R) -> R {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }
    }

    /// Internal hook: update the snapshot when the
    /// actor-isolated `cachedProvidersWithKeys` changes.
    fileprivate func _publishCachedSnapshot() {
        WenshuAgent.cachedSnapshot.withLock { $0 = cachedProvidersWithKeys }
    }

    // MARK: - Available models

    /// Returns the available model slugs for the given provider.
    /// Delegates to `LLMModelDiscovery.discover()`.
    func availableModels(
        for provider: Provider,
        forceRefresh: Bool = false
    ) async -> [String] {
        let result = await modelDiscovery.discover(
            provider: provider,
            forceRefresh: forceRefresh
        )
        return result.models
    }

    // MARK: - Chat (= the single LLM call entry point)

    /// Sends a user message through the agent's full ReAct loop
    /// (= the path the boss 2026-10-16 OOB "agent 没有达到 agent 的
    /// 标准" requested; = the conductor with the active connector
    /// is the only implementation; = the legacy pipeline + the
    /// verifier streamChat fallback were both deleted in commits
    /// `e9ae2add0` and `140b76deb`).
    ///
    /// Returns the final (reply, totalTokens, thinking) tuple.
    /// Streaming intermediate events are delivered through
    /// `streamCallback` (= each `LLMBlock` as it arrives from the
    /// upstream SSE stream; = the connector's native `stream()` is
    /// the only path used; = no "fake streaming" exists).
    ///
    /// Returns nil when the conductor is not installed (= the call
    /// site is expected to show an "agent 未配置" placeholder
    /// instead of silently falling back to a non-ReAct path).
    func chat(
        userMessage: String,
        sessionId: String,
        model: String,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async -> (reply: String, totalTokens: Int, thinking: String?)? {
        guard let conductor = conductor else { return nil }
        return await conductor.handle(
            userMessage: userMessage,
            sessionId: sessionId,
            model: model,
            streamCallback: streamCallback
        )
    }
}
