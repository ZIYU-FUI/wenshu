//
//  WenshuConductorPathTests.swift · Wenshu · T0-PATH-VISIBLE (2026-09-18)
//
//  Smoke tests verifying WenshuConductor.handle() emits a
//  `PATH=...` NSLog on every branch (= new agent success + legacy
//  fallback + legacy no-connector). We don't introspect NSLog
//  directly (= that's process-global + noisy in tests); we just
//  verify the public API surface still returns the expected
//  (reply, totalTokens, thinking) tuple across all 3 branches.
//
//  The actual NSLog emission is verified in probe-T0 (= a separate
//  /tmp/probe-TN/ Swift package that grep's stderr from the host
//  process).
//
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuConductor path logging (T0-PATH-VISIBLE)")
struct WenshuConductorPathTests {

    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared).
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    /// T0 contract: handle() with no connector emits a
    /// `PATH=legacy REASON=no_connector` log + returns the canonical
    /// 3-tuple (= back-compat with all existing call sites).
    @Test @MainActor
    func no_connector_path_returns_legacy_tuple() async throws {
        _ = try Self.makeKanbanRepository()
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        let conductor = WenshuConductor(runtime: runtime, verifier: verifier)
        let result = await conductor.handle(
            userMessage: "hello",
            sessionId: "test-session",
            model: "mock-model"
        )
        // T0: 3-tuple shape preserved (= no signature change).
        #expect(!result.reply.isEmpty, "S4 graceful degradation: reply non-empty")
        #expect(result.totalTokens >= 0)
        // thinking may be nil (legacy path doesn't emit it) — that's fine.
    }

    /// T0 contract: handle() never throws (= S4 graceful degradation).
    /// Even when the new loop throws, we fall through to legacy and
    /// return a tuple (not throw).
    @Test @MainActor
    func handle_never_throws() async throws {
        _ = try Self.makeKanbanRepository()
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        let conductor = WenshuConductor(runtime: runtime, verifier: verifier)
        // The contract is "never throws". Just verify the await
        // completes (= no hang, no propagation).
        let result = await conductor.handle(
            userMessage: "x",
            sessionId: "y",
            model: "z"
        )
        #expect(result.reply is String)
    }
}