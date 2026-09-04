//
//  SubAgentPermissionsTests.swift · Wenshu · v0.23 ticket 012
//
//  Boss 2026-08-23 拍: 去 hermes 源码里扒, 一定有对应的解决方案.
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

    @Test("archivist does not have memory tool (hermes parity)")
    func testArchivistHasNoMemoryTool() {
        let tools = SubAgentIdentity.tools(name: .archivist)
        #expect(!tools.contains("memory"))
        #expect(tools.contains("bookmark"))
        #expect(tools.contains("backup"))
    }

    @Test("auditor has memory tool (read-only access via system prompt)")
    func testAuditorHasMemoryTool() {
        let tools = SubAgentIdentity.tools(name: .auditor)
        #expect(tools.contains("memory"))
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