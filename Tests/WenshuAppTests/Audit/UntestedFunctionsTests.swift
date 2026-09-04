//
//  UntestedFunctionsTests.swift · Wenshu · v0.23 audit #014 (boss 8/23 双轴 code-review)
//
//  Boss 2026-08-23 拍: '全项目代码 review, 跑一遍, 双轴测试没跑的需求, 跑一遍'.
//
//  Tests for functions found during Standards audit that had NO test coverage.
//  Each test corresponds to a public function found in:
//  - Sources/WenshuApp/Core/Agent/AgentProtocol.swift: getAgentCard
//  - Sources/WenshuApp/Core/Agent/WenshuConductor.swift: invokeSkill,
//    availableSkills, addMemory, searchMemory
//  - Sources/WenshuApp/Core/Tools/FileTools.swift: pathHasBlockedSymlink
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Audit: previously untested functions (boss 8/23 双轴 code-review)")
struct UntestedFunctionsTests {

    // MARK: - AgentProtocol.getAgentCard

    @Test("AgentProtocol.getAgentCard returns the agent's card (immutable)")
    func testGetAgentCard() async {
        let card = AgentCard(
            name: "test agent",
            description: "for testing",
            skills: ["read", "write"],
            endpoint: "local://test"
        )
        let protocol_ = AgentProtocol(agentCard: card)
        let retrieved = await protocol_.getAgentCard()
        #expect(retrieved.name == "test agent")
        #expect(retrieved.description == "for testing")
        #expect(retrieved.skills == ["read", "write"])
        #expect(retrieved.endpoint == "local://test")
    }

    @Test("AgentProtocol.getAgentCard returns same instance (or equal) each call")
    func testGetAgentCardStable() async {
        let card = AgentCard(
            name: "x", description: "x", skills: [], endpoint: "x"
        )
        let p = AgentProtocol(agentCard: card)
        let c1 = await p.getAgentCard()
        let c2 = await p.getAgentCard()
        #expect(c1 == c2)
    }

    // MARK: - WenshuConductor.invokeSkill + availableSkills
    // Note: WenshuConductor requires runtime + verifier + kanbanStore in init.
    // These tests construct minimal in-memory mocks to verify the public methods
    // exist and gracefully handle unavailable registries.

    @Test("WenshuConductor.availableSkills returns [] when skill registry is nil")
    func testAvailableSkillsEmpty() async throws {
        let runtime = AgentRuntime()  // actor — needs no args
        let verifier = WenshuVerifier(baseURL: "test://", apiKey: nil, model: .m3)
        let kanban = try await KanbanStore(path: NSTemporaryDirectory() + "audit-\(UUID().uuidString).db")
        try await kanban.bootstrap()
        let conductor = await WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            kanbanStore: kanban
            // sessionStore / memoryStore / skillRegistry = nil
        )
        let skills = await conductor.availableSkills()
        #expect(skills.isEmpty)
    }

    @Test("WenshuConductor.invokeSkill returns empty string when registry is nil")
    func testInvokeSkillEmpty() async throws {
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier(baseURL: "test://", apiKey: nil, model: .m3)
        let kanban = try await KanbanStore(path: NSTemporaryDirectory() + "audit-\(UUID().uuidString).db")
        try await kanban.bootstrap()
        let conductor = await WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            kanbanStore: kanban
        )
        let result = await conductor.invokeSkill(name: "non-existent", input: "")
        #expect(result.isEmpty)
    }

    // MARK: - WenshuConductor.addMemory + searchMemory

    @Test("WenshuConductor.searchMemory returns [] when memory store is nil")
    func testSearchMemoryEmpty() async throws {
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier(baseURL: "test://", apiKey: nil, model: .m3)
        let kanban = try await KanbanStore(path: NSTemporaryDirectory() + "audit-\(UUID().uuidString).db")
        try await kanban.bootstrap()
        let conductor = await WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            kanbanStore: kanban
            // memoryStore = nil
        )
        let memories = await conductor.searchMemory(query: "test")
        #expect(memories.isEmpty)
    }

    @Test("WenshuConductor.addMemory silently no-ops when memory store is nil")
    func testAddMemoryNoOp() async throws {
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier(baseURL: "test://", apiKey: nil, model: .m3)
        let kanban = try await KanbanStore(path: NSTemporaryDirectory() + "audit-\(UUID().uuidString).db")
        try await kanban.bootstrap()
        let conductor = await WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            kanbanStore: kanban
        )
        await conductor.addMemory(content: "test content")
        let memories = await conductor.searchMemory(query: "test content")
        #expect(memories.isEmpty)
    }

    // MARK: - FileTools.pathHasBlockedSymlink (gap 2 fix function)

    @Test("FileTools.pathHasBlockedSymlink: regular path returns false")
    func testSymlinkRegularPath() {
        let tools = FileTools()
        let result = tools.pathHasBlockedSymlink("/tmp/regular_file")
        #expect(result == false)
    }

    @Test("FileTools.pathHasBlockedSymlink: non-existent path returns false (no crash)")
    func testSymlinkNonExistentPath() {
        let tools = FileTools()
        let result = tools.pathHasBlockedSymlink("/tmp/does_not_exist_\(UUID().uuidString)")
        // resolvingSymlinksInPath on non-existent file just returns the input.
        #expect(result == false)
    }

    @Test("FileTools.pathHasBlockedSymlink: symlink to /dev/null handled (isBlockedDevice check)")
    func testSymlinkToDeviceFile() {
        // Create a symlink in /tmp pointing to /dev/null
        let linkPath = "/tmp/wenshu-symlink-test-\(UUID().uuidString)"
        let fm = FileManager.default
        // /dev/null is technically a character device but not blocked by isBlockedDevice (which checks /dev/* general).
        // The symlink should resolve to /dev/null → if isBlockedDevice returns true for /dev/null → blocked.
        // Currently isBlockedDevice doesn't block /dev/null specifically (it blocks specific sensitive files).
        // Test that pathHasBlockedSymlink doesn't crash on device file.
        do {
            try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: "/dev/null")
        } catch {
            // If we can't create symlink (sandbox), skip.
            return
        }
        defer { try? fm.removeItem(atPath: linkPath) }
        let tools = FileTools()
        let _ = tools.pathHasBlockedSymlink(linkPath)  // should not crash
        // No assertion on result — depends on isBlockedDevice behavior
    }
}