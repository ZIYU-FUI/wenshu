//
//  AgentBootstrapperTests.swift · Wenshu · HERMES-PARTIAL-005 (2026-09-04)
//
//  Round-trip tests for the AgentBootstrapper surface (= hermes
//  agent_init.py = 2,103 LOC):
//    1. testBootstrapSuccess             — all 6 steps succeed → isComplete
//    2. testBootstrapPartialFailure      — 1 step fails → others continue
//    3. testBootstrapNoopHooks           — no-op hooks → nothing loaded
//    4. testBootstrapFailedStepsList     — failedSteps captures errors
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentBootstrapper (HERMES-PARTIAL-005)")
struct AgentBootstrapperTests {

    // MARK: - Test 1: All success

    @Test("bootstrap with all success hooks returns isComplete=true")
    func testBootstrapSuccess() async {
        let bootstrapper = AgentBootstrapper(hooks: .success)
        let status = await bootstrapper.bootstrap()
        #expect(status.configLoaded == true)
        #expect(status.credentialsResolved == true)
        #expect(status.skillRegistryLoaded == true)
        #expect(status.memoryLoaded == true)
        #expect(status.contextEngineLoaded == true)
        #expect(status.systemPromptComposed == true)
        #expect(status.failedSteps.isEmpty)
        #expect(status.isComplete == true)
    }

    // MARK: - Test 2: Partial failure

    @Test("bootstrap continues past a credential-resolution failure")
    func testBootstrapPartialFailure() async {
        struct CredError: Error, Sendable {}
        let hooks = BootstrapHooks(
            loadConfig: {},
            resolveCredentials: { throw CredError() },
            loadSkillRegistry: {},
            loadMemory: {},
            loadContextEngine: {},
            composeSystemPrompt: {}
        )
        let bootstrapper = AgentBootstrapper(hooks: hooks)
        let status = await bootstrapper.bootstrap()
        #expect(status.configLoaded == true)
        #expect(status.credentialsResolved == false)
        #expect(status.skillRegistryLoaded == true)
        #expect(status.memoryLoaded == true)
        #expect(status.contextEngineLoaded == true)
        #expect(status.systemPromptComposed == true)
        #expect(status.failedSteps.count == 1)
        #expect(status.failedSteps[0].contains("resolve_credentials"))
        #expect(status.isComplete == false)
    }

    // MARK: - Test 3: No-op hooks

    @Test("bootstrap with no-op hooks reports nothing loaded")
    func testBootstrapNoopHooks() async {
        let bootstrapper = AgentBootstrapper()
        let status = await bootstrapper.bootstrap()
        #expect(status.configLoaded == false)
        #expect(status.credentialsResolved == false)
        #expect(status.skillRegistryLoaded == false)
        #expect(status.memoryLoaded == false)
        #expect(status.contextEngineLoaded == false)
        #expect(status.systemPromptComposed == false)
        #expect(status.failedSteps.isEmpty)
        #expect(status.isComplete == false)
    }

    // MARK: - Test 4: Multi-failure

    @Test("bootstrap captures multiple failed steps in order")
    func testBootstrapFailedStepsList() async {
        struct FailA: Error, Sendable {}
        struct FailB: Error, Sendable {}
        let hooks = BootstrapHooks(
            loadConfig: { throw FailA() },
            resolveCredentials: { throw FailB() },
            loadSkillRegistry: {},
            loadMemory: {},
            loadContextEngine: {},
            composeSystemPrompt: {}
        )
        let bootstrapper = AgentBootstrapper(hooks: hooks)
        let status = await bootstrapper.bootstrap()
        #expect(status.failedSteps.count == 2)
        #expect(status.failedSteps[0].contains("load_config"))
        #expect(status.failedSteps[1].contains("resolve_credentials"))
    }
}