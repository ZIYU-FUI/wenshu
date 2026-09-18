//
//  WenshuConductorInvokeSkillWithCallbackTests.swift · Wenshu · T4-SUBAGENT-UI (2026-09-18)
//
//  Verifies WenshuConductor.invokeSkillWithCallback emits
//  "[wenshu.subagent] <name>" text blocks via streamCallback before +
//  after the actual skill invocation. Lets ChatSubAgentTag surface
//  the active sub-agent name in real time.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuConductor invokeSkillWithCallback (T4-SUBAGENT-UI)")
struct WenshuConductorInvokeSkillWithCallbackTests {

    /// Actor wrapper for thread-safe captured blocks.
    private actor Sink {
        var blocks: [String] = []
        func append(_ s: String) { blocks.append(s) }
        func snapshot() -> [String] { blocks }
    }

    /// T4 contract: invokeSkillWithCallback emits:
    ///   1. "[wenshu.subagent] <name>" before the skill runs
    ///   2. The skill's actual output (= via invokeSkill)
    ///   3. "[wenshu.subagent] <name> done" after the skill finishes
    @Test @MainActor
    func emits_subagent_markers_around_invocation() async {
        _ = try? Self.makeKanbanRepository()
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        let conductor = WenshuConductor(runtime: runtime, verifier: verifier)
        let sink = Sink()
        let cb: @Sendable (LLMBlock) async -> Void = { block in
            if case .text(let s) = block { await sink.append(s) }
        }
        // Invoke a skill that doesn't exist (= returns "" but markers
        // should still emit).
        let result = await conductor.invokeSkillWithCallback(
            name: "research",
            input: "find stuff",
            streamCallback: cb
        )
        // Result is "" because the registry has no "research" skill;
        // = but the markers must still have been emitted.
        #expect(result.isEmpty, "non-existent skill returns empty")
        let captured = await sink.snapshot()
        let startMarkers = captured.filter { $0 == "[wenshu.subagent] research" }
        let endMarkers = captured.filter { $0 == "[wenshu.subagent] research done" }
        #expect(startMarkers.count == 1, "expected 1 start marker, got \(startMarkers.count)")
        #expect(endMarkers.count == 1, "expected 1 end marker, got \(endMarkers.count)")
    }

    /// T4 contract: nil streamCallback is safe (= no marker emission;
    /// = behaves like invokeSkill).
    @Test @MainActor
    func nil_callback_does_not_crash() async {
        _ = try? Self.makeKanbanRepository()
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        let conductor = WenshuConductor(runtime: runtime, verifier: verifier)
        // nil streamCallback must not throw (= back-compat).
        let result = await conductor.invokeSkillWithCallback(
            name: "noop",
            input: "",
            streamCallback: nil
        )
        // Non-existent skill returns "" (= graceful).
        #expect(result.isEmpty)
    }

    /// Per-test in-memory SwiftData container.
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }
}