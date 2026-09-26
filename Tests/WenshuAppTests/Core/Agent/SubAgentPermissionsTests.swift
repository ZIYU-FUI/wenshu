//
//  SubAgentPermissionsTests.swift · Wenshu · v0.23 ticket 012
//
// 
//  Verify hermes DELEGATE_BLOCKED_TOOLS parity in wenshu.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SubAgentPermissions (hermes DELEGATE_BLOCKED_TOOLS parity)")
struct SubAgentPermissionsTests {

    // MARK: - writeOnlyBlocked tools (5 hermes DELEGATE_BLOCKED minus memory)

    @Test("delegate_task is in writeOnlyBlocked (no recursive delegation)")
    func testDelegateTaskBlocked() {
        #expect(SubAgentPermissions.writeOnlyBlocked.contains("delegate_task"))
    }

    @Test("clarify is in writeOnlyBlocked (no user interaction)")
    func testClarifyBlocked() {
        #expect(SubAgentPermissions.writeOnlyBlocked.contains("clarify"))
    }

    @Test("send_message is in writeOnlyBlocked (no cross-platform side effects)")
    func testSendMessageBlocked() {
        #expect(SubAgentPermissions.writeOnlyBlocked.contains("send_message"))
    }

    @Test("cronjob is in writeOnlyBlocked (no scheduling in parent's name)")
    func testCronjobBlocked() {
        #expect(SubAgentPermissions.writeOnlyBlocked.contains("cronjob"))
    }

    // MARK: - checkPermission behavior

    @Test("checkPermission blocks delegate_task for any op")
    func testCheckPermissionBlocksDelegateTask() {
        #expect(SubAgentPermissions.checkPermission(tool: "delegate_task", op: "") != nil)
        #expect(SubAgentPermissions.checkPermission(tool: "delegate_task", op: "any") != nil)
    }

    @Test("checkPermission blocks clarify for any op")
    func testCheckPermissionBlocksClarify() {
        #expect(SubAgentPermissions.checkPermission(tool: "clarify", op: "") != nil)
    }

    @Test("checkPermission blocks cronjob for any op")
    func testCheckPermissionBlocksCronjob() {
        #expect(SubAgentPermissions.checkPermission(tool: "cronjob", op: "schedule") != nil)
    }

    @Test("checkPermission blocks send_message for any op")
    func testCheckPermissionBlocksSendMessage() {
        #expect(SubAgentPermissions.checkPermission(tool: "send_message", op: "send") != nil)
    }

    // MARK: - readOnlyAllowed: memory (read OK, write blocked)

    @Test("checkPermission allows memory with read op (no write)")
    func testCheckPermissionAllowsMemoryRead() {
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "read") == nil)
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "search") == nil)
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "") == nil)
    }

    @Test("checkPermission blocks memory with write ops")
    func testCheckPermissionBlocksMemoryWrite() {
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "add") != nil)
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "write") != nil)
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "delete") != nil)
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "patch") != nil)
        #expect(SubAgentPermissions.checkPermission(tool: "memory", op: "update") != nil)
    }

    // MARK: - Allowed tools (sanity check)

    @Test("checkPermission allows common tools (search / file / web)")
    func testCheckPermissionAllowsCommonTools() {
        #expect(SubAgentPermissions.checkPermission(tool: "search", op: "read") == nil)
        #expect(SubAgentPermissions.checkPermission(tool: "file", op: "read") == nil)
        #expect(SubAgentPermissions.checkPermission(tool: "web", op: "extract") == nil)
    }

    // MARK: - Sub-agent tool lists

    @Test("archivist does not have memory tool (v2.5: storage adapter path; empty LLM tools)")
    func testArchivistHasNoMemoryTool() {
        // v2.5 arc: bookmark / backup storage moved to
        // WSBookmarkRepository.shared + filesystem direct path
        // (per SubAgentIdentity.archivistPrompt). The archivist
        // tools(name:) list is therefore empty; the LLM tool path
        // is no longer involved.
        let tools = SubAgentIdentity.tools(name: .archivist)
        // Hermetic parity assertion (= what we actually want to assert):
        // archivist MUST NOT carry a memory tool (= memory writes are
        // main-agent exclusive per hermes DELEGATE_BLOCKED_TOOLS).
        #expect(!tools.contains("memory"),
               "archivist must NOT carry memory writes (= hermes DELEGATE_BLOCKED_TOOLS parity)")
        // The pre-v2.5 LLM-tool expectation (= archivist exposes
        // bookmark + backup on the LLM tool surface) is replaced by
        // the v2.5 storage-adapter expectation: archivist has zero
        // LLM tools. bookmark / backup are no longer LLM tools; =
        // archivist instead drives WSBookmarkRepository.shared
        // directly through the storage adapter (= no tool-dispatch
        // round-trip).
        #expect(tools.isEmpty,
               "archivist must NOT expose LLM tools post-v2.5 (= storage adapters relocate to WSBookmarkRepository.shared)")
    }

    @Test("auditor has memory tool (read-only access via system prompt) -- v2.4 moves memory off the LLM tool surface")
    func testAuditorHasMemoryTool() {
        // v2.4 contract: memory is removed from the LLM-facing tool
        // surface (= the deleted skill system + memory rewire arc).
        // Auditor reads via WSMemoryProvider.shared directly (the
        // SubAgentRunner.runAuditorSubAgent path), NOT through an
        // LLM-emitted tool_use block. Therefore the auditor's
        // tools(name:) list is empty even though the auditor can
        // still inspect memory (= the read path moved from LLM
        // dispatch to direct actor dispatch).
        let tools = SubAgentIdentity.tools(name: .auditor)
        #expect(tools.isEmpty,
               "auditor must NOT expose memory on the LLM tool surface post-v2.4 (= direct WSMemoryProvider.shared path)")
        // Hermetic: pre-v2.4 contract surfaced memory on the LLM
        // tool surface; post-v2.4 contract removes it.
        #expect(!tools.contains("memory"),
               "legacy: auditor must no longer carry memory (= v2.4 memory-rewire)")
    }

    @Test("researcher / writer / analyst do not have memory tool")
    func testOtherSubAgentsNoMemory() {
        #expect(!SubAgentIdentity.tools(name: .researcher).contains("memory"))
        #expect(!SubAgentIdentity.tools(name: .writer).contains("memory"))
        #expect(!SubAgentIdentity.tools(name: .analyst).contains("memory"))
    }

    // MARK: - AgentCaller

    @Test("AgentCaller.isSubAgent correctly identifies sub-agent")
    func testAgentCallerSubAgent() {
        let main = AgentCaller.main
        let sub = AgentCaller.subAgent(name: "researcher")
        #expect(main.isSubAgent == false)
        #expect(sub.isSubAgent == true)
    }
}
