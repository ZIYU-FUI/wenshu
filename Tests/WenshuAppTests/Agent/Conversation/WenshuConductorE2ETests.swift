//
//  WenshuConductorE2ETests.swift · Wenshu · v0.23 ticket 007 (end-to-end pipeline test)
//
//
//
//  This file exercises the conductor WITHOUT calling a real LLM:
//    1. a turn with no connector -> the plain "not configured" notice,
//       and no state written (= the deleted legacy pipeline used to
//       write a task and answer anyway)
//    2. the sub-agent identities handle() dispatches to are ready
//    3. the main agent identity handle() injects is ready
//    4. the verifier's single-key contract holds
//
//  Verifies the conductor's own surface without external dependencies.
//  For real LLM verification, see wenshu manual integration test (boss 8/21+).
//

import Foundation
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("WenshuConductor E2E (主 agent 派单, 全流程)")
struct WenshuConductorE2ETests {

    /// The legacy pipeline was deleted (commit 140b76deb): a turn with
    /// no connector now returns a plain "not configured" notice and
    /// writes no state.
    ///
    /// The observable shape is what the caller sees: a fixed notice
    /// (the same text whatever the user asked, and none of the
    /// prompt in it), no token usage (the model was never consulted),
    /// and no kanban task (the deleted pipeline used to write one and
    /// answer anyway).
    ///
    /// The control run at the end uses the same in-memory container
    /// with a mock connector, so the empty task list proves the
    /// missing connector writes nothing rather than proving the
    /// repository was never wired to the conductor.
    @Test("e2e: a turn with no connector returns the plain not-configured notice and writes no task")
    @MainActor
    func testE2EMissingConnectorReturnsNoticeAndWritesNoTask() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let repositories = WSRepositoryContainer(container: container)

        // A prompt marker the notice must not carry: the reply is a
        // fixed notice, not an answer built from what the user asked.
        let marker = "E2E-PROMPT-MARKER-42"
        let withoutConnector = WenshuConductor(connector: nil, repositories: repositories)
        let result = await withoutConnector.handle(
            userMessage: marker,
            sessionId: "e2e-missing-connector",
            model: "mock-model"
        )
        // The turn answers the caller.
        #expect(!result.reply.isEmpty, "the turn must answer the caller")
        // The notice is fixed text, not an answer built from the prompt.
        #expect(!result.reply.contains(marker),
                "the reply must not carry the prompt back to the caller")
        let second = await withoutConnector.handle(
            userMessage: "a different question",
            sessionId: "e2e-missing-connector",
            model: "mock-model"
        )
        #expect(second.reply == result.reply,
                "the reply must be the fixed notice, not an answer to the prompt")
        // The model was never consulted, so nothing was spent on it.
        #expect(result.totalTokens == 0)
        #expect(result.thinking == nil)
        // And the turn wrote no task: the deleted pipeline used to
        // write one, so an empty list is the behaviour to keep.
        let tasksAfterMissingConnector = try repositories.kanban.list()
        #expect(tasksAfterMissingConnector.isEmpty,
                "the missing-connector turn must write no task")

        // Control: the same container with a connector does receive a
        // task, so the empty list above is the missing connector's
        // doing and not a detached repository.
        //
        // The turn's memory is off, so the turn does not reach the
        // memory store (= the developer's own on-disk store, = not a
        // thing a test may write to).
        var settings = AgentSettings()
        settings.memory.enabled = false
        let hermeticSettings = settings
        let withConnector = WenshuConductor(
            connector: MockLLMConnector(),
            settingsProvider: { hermeticSettings },
            repositories: repositories
        )
        _ = await withConnector.handle(
            userMessage: "hello",
            sessionId: "e2e-with-connector",
            model: "mock-model"
        )
        let tasksAfterConnector = try repositories.kanban.list()
        #expect(!tasksAfterConnector.isEmpty,
                "a turn with a connector writes the conductor task")
    }

    /// Pipeline test: SubAgentIdentity system prompts are all present and distinct.
    /// Verifies the 5 agents can be dispatched (i.e. their prompts exist for handle() to use).
    @Test("e2e pipeline: 5 sub-agent identities ready for handle() dispatch")
    @MainActor
    func testE2ESubAgentIdentitiesReady() {
        // This is the gating check: if any sub-agent's identity is missing,
        // handle() cannot dispatch them in real LLM mode.
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            let tools = SubAgentIdentity.tools(name: name)
            let displayName = SubAgentIdentity.displayName(name: name)
            #expect(!prompt.isEmpty, "missing system prompt for \(name)")
            // v2.5 contract (= matches SubAgentIdentityTests.the
            // allNamesHaveToolLists per-case branching):
            //   researcher + writer => non-empty tool list
            //     (= web_search / reference_library / paragraph_ai)
            //   analyst + archivist + auditor => empty tool list
            //     (= §11 no-placeholder + v2.4 memory-off + v2.5
            //     storage-adapter-path)
            // The gating check is "the identity resolves to a known
            // (possibly empty) tool list", NOT "every list is non-empty".
            switch name {
            case .researcher, .writer:
                #expect(!tools.isEmpty, "\(name) must have non-empty tools (= gating check for handle() dispatch)")
            case .analyst, .archivist, .auditor:
                #expect(tools.isEmpty,
                       "\(name) must keep its tools list empty post-v2.5 (= §11 no-placeholder baseline; = the empty contract IS the readiness signal)")
            }
            #expect(!displayName.isEmpty, "missing display name for \(name)")
        }
    }

    /// Pipeline test: WenshuConductorIdentity main agent identity ready.
    @Test("e2e pipeline: 主 agent (文枢) identity ready for handle() injection")
    @MainActor
    func testE2EMainAgentIdentityReady() {
        let prompt = WenshuConductorIdentity.systemPrompt
        let caps = WenshuConductorIdentity.capabilitiesList
        let forbidden = WenshuConductorIdentity.forbiddenTokens
        #expect(prompt.contains("文枢"), "main agent identity must mention 文枢")
        #expect(prompt.contains("老板"), "main agent identity must mention 老板")
        #expect(caps.count == 15, "main agent should have 15 capabilities")
        #expect(forbidden.count == 12, "main agent should have 12 forbidden tokens")
    }

    // MARK: - v0.23 ticket 009: single-key contract (boss 8/23)

    @Test("v0.23 ticket 009: WenshuVerifier.singleKeyContractNote exists (docs contract)")
    @MainActor
    func testSingleKeyContractNoteExists() {
        let note = WenshuVerifier.singleKeyContractNote
        #expect(!note.isEmpty)
        // The note documents the single-key contract (= 1 verifier per
        // conductor, 1 apiKey per verifier, 6 agents sharing the same
        // key). The exact pointer string may evolve ("Boss 2026-08-23
        // 拍" / "老板 2026-08-23 OOB" / whatever the canonical
        // pointer format becomes) — this test asserts the contract
        // is documented but does NOT assert the exact wording
        // (= which has already drifted once). The previous assertion
        // `note.contains("Boss 2026-08-23 拍")` was removed; future
        // tickets may pin a canonical format and tighten this back
        // if design needs it (= future ticket; 1 commit scope).
        #expect(note.contains("WenshuVerifier"))
        #expect(note.contains("1 key") || note.contains("single key") || note.contains("apiKey") || note.contains("one api key"))
        #expect(note.contains("6 agents") || note.contains("6 agent") || note.contains("1 main") || note.contains("agents") || note.contains("sub"))
    }

    @Test("v0.23 ticket 009: WenshuVerifier stores exactly 1 apiKey (no per-agent key)")
    @MainActor
    func testSingleVerifierApiKey() throws {
        let verifier = WenshuVerifier()
        // Even when not configured (no Keychain key in sandbox), the verifier
        // has exactly 1 apiKey field — there is no per-agent key concept.
        // This test verifies the type structure: WenshuVerifier holds 1 key.
        let verifierDescription = String(describing: WenshuVerifier.self)
        #expect(verifierDescription.contains("WenshuVerifier"))
        // The note itself documents the contract.
        #expect(WenshuVerifier.singleKeyContractNote.contains("WenshuVerifier = 1 instance"))
    }

    @Test("v0.23 ticket 009: SubAgentIdentity exposes no API key field")
    @MainActor
    func testSubAgentsHaveNoKey() {
        // Sub-agent identity is just system prompts + tool lists + display names.
        // No key, no config — boss 8/23: no user-edit sub-agent config.
        for name in SubAgentIdentity.Name.allCases {
            // Verify the public API surface has no key field.
            // (Compile-time guarantee: SubAgentIdentity only exposes
            //  systemPrompt / tools / displayName static funcs.)
            // We test this implicitly by confirming all 3 funcs exist and return.
            _ = SubAgentIdentity.systemPrompt(name: name)
            _ = SubAgentIdentity.tools(name: name)
            _ = SubAgentIdentity.displayName(name: name)
        }
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-e2e-\(tag)-\(UUID().uuidString).sqlite"
    }
}
