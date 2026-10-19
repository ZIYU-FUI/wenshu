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
import os.log

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
        WenshuAgent.conductorSnapshot.withLock { $0 = conductor }
        // Boss 2026-10-19 mac-mini reproducer: the chat
        // view model subscribes to this notification in
        // its init (= before the AppDelegate publishes
        // the conductor; = the subscriber receives the
        // notification and patches its `conductor` field).
        // Posted on the main queue (= both production
        // call sites are @MainActor-isolated) so the
        // subscriber's `[weak self] in` block runs on
        // the same actor the @MainActor ChatViewModel
        // body lives on (= no actor-isolation warning
        // when the subscriber mutates `self.conductor`).
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .wenshuConductorInstalled,
                object: nil
            )
        }
    }

    /// Sync shim (= the Boss 2026-10-19 mac-mini reproducer
    /// "AI 思考中 20s" hung the chat because the chat path's
    /// `WenshuAgent.shared.currentConductorSync()` returned nil
    /// the moment the user pressed send; = the install was
    /// scheduled via `Task { await WenshuAgent.shared.installConductor
    /// (conductorInstance) }` (= actor hop; = the snapshot write
    /// was deferred to the next actor scheduler tick; = the chat
    /// `if let conductor = conductor` path took the else branch
    /// within the same UI tick the user pressed send).
    /// Writing the snapshot directly here (= the same lock the
    /// async path uses; = the actor-field write inside the
    /// async `installConductor` is still a best-effort update
    /// for callers that prefer the async variant) lets callers
    /// publish the conductor SYNCHRONOUSLY at app startup, so
    /// `currentConductorSync()` is non-nil by the time the first
    /// chat send fires.
    nonisolated static func installConductorSync(_ conductor: WenshuConductor) {
        // Boss 2026-10-19 chat hang reproducer: this
        // shim writes the snapshot synchronously so the
        // first ChatViewModel.init (= the SwiftUI @State
        // construction that happens when the chat zone
        // first appears) sees a non-nil conductor even if
        // the actor-isolated `installConductor` body
        // (= the same value with `self.conductor = ...`)
        // hasn't run yet. The log line below is the
        // canonical debug handle for the user's
        // "send a message, look at Console.app" flow.
        os_log("[wenshu.agent] installConductorSync published: thread=%{public}@", log: .default, type: .info, Thread.current.description)
        WenshuAgent.conductorSnapshot.withLock { $0 = conductor }
        // Same notification path as the actor-isolated
        // `installConductor`: the ChatSessionViewModel
        // subscriber patches its `conductor` field on the
        // main actor (= sync shim runs on the main
        // thread; = the post is already on the main
        // queue; = no extra `async` dispatch needed).
        // The async `installConductor` also posts (=
        // both paths converge on the same notification
        // name; = subscribers see one event per logical
        // install operation; the duplicate post is
        // coalesced by NotificationCenter's de-dupe
        // (= the second post within the same run loop
        // turn is collapsed to one delivery).
        NotificationCenter.default.post(
            name: .wenshuConductorInstalled,
            object: nil
        )
    }

    /// Removes the conductor instance (= cleanup on app
    /// termination; = symmetry with install). Most callers
    /// do not need to call this (= the singleton lives for
    /// the lifetime of the app process).
    func uninstallConductor() {
        self.conductor = nil
        WenshuAgent.conductorSnapshot.withLock { $0 = nil }
    }

    /// Returns the active conductor (= nil if not yet installed).
    /// Per AGENTS.md §11.4 (boundary policy): UI / App layers
    /// call this; = they do not construct `WenshuConductor`.
    func currentConductor() -> WenshuConductor? {
        conductor
    }

    /// Sync nonisolated accessor for the active conductor.
    /// WenshuAppDelegate.sharedConductor is a `var` (non-async
    /// static property) consumed from the SwiftUI main-actor
    /// context; = the existing async `currentConductor()`
    /// cannot be called there. The snapshot below (= a
    /// `nonisolated` `static let`) is updated whenever
    /// `installConductor` runs (= the WenshuAppDelegate path)
    /// or `uninstallConductor` runs (= cleanup).
    ///
    /// AUDIT.md §2.2 partial (2026-10-16): the public facade
    /// becomes the single source of truth for the conductor
    /// instance; = `WenshuAppDelegate.sharedConductor` reads
    /// from this snapshot (= the AppDelegate static is now
    /// a one-line forwarder; = the AppDelegate no longer
    /// holds the canonical instance).
    nonisolated func currentConductorSync() -> WenshuConductor? {
        let result = WenshuAgent.conductorSnapshot.withLock { $0 }
        os_log("[wenshu.agent] currentConductorSync read: thread=%{public}@ isNil=%{public}@", log: .default, type: .info, Thread.current.description, result == nil ? "true" : "false")
        return result
    }

    /// Install + uninstall also update the nonisolated snapshot
    /// (= so the sync accessor stays in sync with the actor-
    /// isolated source of truth).
    fileprivate static let conductorSnapshot = ConductorSnapshot()

    fileprivate final class ConductorSnapshot: @unchecked Sendable {
        private var value: WenshuConductor?
        private let lock = NSLock()
        func withLock<R>(_ body: (inout WenshuConductor?) -> R) -> R {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }
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
        let changed = (cachedProvidersWithKeys != result)
        cachedProvidersWithKeys = result
        _publishCachedSnapshot()
        // Apple canonical pattern for one-way broadcast: when the
        // cache contents change, post the same keychain-changed
        // notification that Settings already posts so every
        // ChatView / ChatZoneView subscriber re-evaluates its body
        // and the empty-state overlay disappears. Posting on `main`
        // is required = NotificationCenter's `forName:` observer
        // matching is documented on the main queue.
        if changed {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .wenshuProviderKeychainChanged,
                    object: nil
                )
            }
        }
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

    // MARK: - Sync facade (= the SettingView boundary)

    /// Sync read of the active keychain backend (=
    /// `MirroredKeychainStore` in production; = an
    /// `InMemoryKeychainStore` in tests). The SettingView
    /// uses this to drive its `keychainRevision` UI
    /// indicator and to format key previews; = the call
    /// is `var` (= non-async) so it cannot `await` the
    /// async version (= the actor's `nonisolated`
    /// `backend` property on `ProviderKeychain` is the
    /// canonical sync accessor; = this facade is a
    /// 1-line forwarder). Returns the typed protocol
    /// so SettingView can pass it to
    /// `SettingsOps.refreshProviderStatus(keychain:)`.
    nonisolated func keychainBackend() -> any ProviderKeychainStoring {
        ProviderKeychain.backend
    }

    /// Sync read of the formatted key preview (=
    /// the first 8 chars + ellipsis) for a provider.
    /// Used by the Settings → Providers UI to show
    /// the user a non-secret preview of their key.
    /// = `loadKeySync` is the canonical sync accessor
    /// on `ProviderKeychain`; = this facade is a
    /// 1-line forwarder (= AUDIT §2.2 partial to
    /// fully done; = the SettingView caller
    /// migrates in the same commit).
    nonisolated func loadKeyPreview(for provider: Provider) -> String {
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else {
            return ""
        }
        let prefix = String(key.prefix(8))
        return "\(prefix)…"
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

    /// Returns the active LLM connector (= the connector profile
    /// the user picked in LLMConnectorSettingsView; = falls back
    /// to `AnthropicConnector` for missing / unknown slugs).
    /// `nonisolated` (= the active connector is a static
    /// resolution; = no actor state; = safe to call from any
    /// context including the SwiftUI main-actor).
    ///
    /// AUDIT.md §2.2 partial (2026-10-16 boss "只做把之前的
    /// 调用方式改成调用包" arc): this facade forwards to
    /// `WenshuAppDelegateLLMHelpers.activeLLMConnector()`;
    /// = Features/ files that previously constructed
    /// `AnthropicConnector()` directly (= the 3 send/stream
    /// direct callers: ChatViewModelLongRunningGoal, PlanMode
    /// Engine, FormatToolbarButtons) now resolve through
    /// the public facade.
    nonisolated func activeLLMConnector() -> any LLMConnector {
        WenshuAppDelegateLLMHelpers.activeLLMConnector()
    }

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
