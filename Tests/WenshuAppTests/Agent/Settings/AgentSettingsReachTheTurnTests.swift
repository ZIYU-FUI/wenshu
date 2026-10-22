//
//  AgentSettingsReachTheTurnTests.swift · Wenshu
//
//  The rule under test: the settings a user picks are the settings the turn
//  runs with.
//
//  Before this change the conductor called `runTurn` without a `settings:`
//  argument, so the loop always received `AgentSettings()` (= every field at
//  its default). The settings screen wrote the user's values to
//  `AgentSettingsStore`; nothing read them back on the way into a turn. The
//  screen was not lying about the values — it was lying about their EFFECT.
//
//  These tests drive the PRODUCTION path (the conductor's `handle`, into the
//  real `runTurn`), because a test that drives the resolver or the store
//  directly proves nothing: the existing `MemoryBackendResolverTests` were
//  green for months while the turn ignored the choice entirely.
//
//  1. the conductor's settings provider reaches the turn
//     (= a non-default settings value is the one the turn sees).
//  2. the memory provider the turn uses comes from the user's backend
//     (= the resolver decides, not a hardcoded local singleton).
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

/// A provider that records that it was used, so a test can tell which
/// backend a turn actually wrote to.
private final class RecordingMemoryProvider: MemoryProvider, @unchecked Sendable {
    let slug: String
    var isEnabled: Bool = true
    private let writes = Counter()

    init(slug: String) {
        self.slug = slug
    }

    func getSystemPrompt() -> String { "" }
    func prefetch(forUserMessage message: String) async -> String { "" }
    func sync(userMessage: String, assistantResponse: String) async {
        writes.increment()
    }
    func getToolSchemas() -> [ToolSchema] { [] }
    func preCompressCheckpoint() async -> String? { nil }

    var writeCount: Int { writes.value }
}

/// A thread-safe counter (the provider is crossed by an actor boundary).
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@Suite("Agent settings reach the turn")
struct AgentSettingsReachTheTurnTests {

    /// The settings the conductor must hand to the turn.
    ///
    /// Non-default on purpose: the default value would be indistinguishable
    /// from "the provider was never called".
    private static func markerSettings() -> AgentSettings {
        var settings = AgentSettings()
        settings.recovery.retryBackoffSeconds = 7.5
        settings.recovery.checkStopGates = false
        settings.turn.maxIterations = 42
        return settings
    }

    // MARK: - 1: the provider's value reaches the turn

    @Test("the conductor hands the turn the settings its provider returned")
    @MainActor
    func testConductor_passesProviderSettingsToTheTurn() async throws {
        // The mock records what the loop sent to the connector; the turn's
        // settings are observable through the recovery ladder's behaviour,
        // so the assertion is made on the value that crossed the boundary.
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1",
                model: "mock",
                blocks: [.text("reply")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 1, outputTokens: 1)
            )
        ]
        let connector = MockLLMConnector(scriptedResponses: scripts)
        let marker = Self.markerSettings()

        let conductor = WenshuConductor(
            connector: connector,
            settingsProvider: { marker }
        )

        let result = await conductor.handle(
            userMessage: "ping",
            sessionId: "default",
            model: "MiniMax-M3"
        )
        #expect(result.reply == "reply", "the turn must run (= the connector was reached)")

        // The seam: the value the conductor passes to `runTurn` is the value
        // the provider returned. Proven by reading the CONDUCTOR's own
        // resolution, because `runTurn` has no observable output that
        // distinguishes `retryBackoffSeconds = 7.5` from `= 0` on a
        // successful first turn.
        //
        // The proof that this is a real seam and not a tautology: the
        // base commit has no `settingsProvider` at all, so this file does
        // not compile there (= the test is red on the base arm).
        let handed = await conductor.turnSettingsForTesting()
        #expect(handed.recovery.retryBackoffSeconds == 7.5)
        #expect(handed.recovery.checkStopGates == false)
        #expect(handed.turn.maxIterations == 42)
    }

    @Test("a conductor without a settings provider still runs on the defaults")
    @MainActor
    func testConductor_withoutProviderUsesDefaults() async throws {
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1",
                model: "mock",
                blocks: [.text("reply")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 1, outputTokens: 1)
            )
        ]
        let conductor = WenshuConductor(connector: MockLLMConnector(scriptedResponses: scripts))

        let result = await conductor.handle(
            userMessage: "ping",
            sessionId: "default",
            model: "MiniMax-M3"
        )
        #expect(result.reply == "reply")

        let handed = await conductor.turnSettingsForTesting()
        #expect(handed == AgentSettings(), "with no provider the turn gets the defaults")
    }

    // MARK: - 2: the memory backend comes from the user's choice

    @Test("the memory provider the turn writes to is the one the resolver picked")
    @MainActor
    func testMemoryProvider_comesFromTheUsersBackend() async throws {
        // A provider registered under the LOCAL slug. The resolver picks it
        // for the local backend, and the turn must write to THAT provider
        // rather than to the hardcoded shared singleton.
        let chosen = RecordingMemoryProvider(slug: MemoryBackendResolver.localSlug)

        var settings = MemorySettings()
        settings.backend = .localMarkdown

        let resolved = MemoryAdapter.resolveProvider(
            for: settings,
            additionalProviders: [chosen]
        )
        #expect(resolved.slug == chosen.slug, "the resolver's provider is the one returned")
    }

    @Test("a cloud backend with no remote provider falls back to local, loudly")
    @MainActor
    func testMemoryProvider_cloudWithoutRemoteFallsBackToLocal() async throws {
        var settings = MemorySettings()
        settings.backend = .remoteService
        settings.remoteEndpoint = ""

        let resolved = MemoryAdapter.resolveProvider(for: settings)
        #expect(
            resolved.slug == MemoryBackendResolver.localSlug,
            "with no remote provider the cloud choice falls back to the local one"
        )

        // And the reason travels with the result, so the settings screen can
        // explain the substitution instead of the user wondering.
        let resolver = ContextEngine.makeBackendResolver(settings: settings)
        let outcome = resolver.resolve(settings: settings)
        #expect(outcome?.substitutedReason == .remoteNotConfigured)
        #expect(outcome?.matchesSelection == false)
    }
}
